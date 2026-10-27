import 'package:file_selector/file_selector.dart' show XTypeGroup;
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../utils/export_delivery.dart';
import '../l10n/l10n_extensions.dart';
import '../providers/backup_providers.dart';
import '../utils/app_feedback.dart';
import 'backup_passphrase_dialog.dart';
import 'confirmation_dialog.dart';
import 'small_loading_indicator.dart';

/// What to say while a backup or a restore runs.
///
/// A percentage only once there is one to give: a page walk cannot say how far
/// along it is until the first page comes back, and a number invented to fill
/// the gap is one that has to jump backwards later.
String backupActivityLabel(BuildContext context, BackupActivity activity) {
  final l10n = context.l10n;
  if (activity.isRestore) {
    return l10n.backupRestoring(
      activity.restoreStep ?? 0,
      activity.restoreTotal ?? 0,
    );
  }
  final reading = l10n.backupReading(activity.stage ?? '');
  final fraction = activity.fraction;
  if (fraction == null) return reading;
  final percent = NumberFormat.percentPattern(
    Localizations.localeOf(context).toString(),
  ).format(fraction);
  return '$reading  $percent';
}

/// Backups of the Firefly ledger, next to the settings backup that is not one.
///
/// The same backups an agent takes over MCP: one list, whether it was a person
/// pressing the button here or a tool called before a bulk change.
class FireflyBackupSection extends ConsumerStatefulWidget {
  const FireflyBackupSection({super.key});

  @override
  ConsumerState<FireflyBackupSection> createState() =>
      _FireflyBackupSectionState();
}

class _FireflyBackupSectionState extends ConsumerState<FireflyBackupSection> {
  static final _log = AppLogger.scoped('widgets.fireflyBackup');

  final Set<String> _selected = {};

  String _kilobytes(Iterable<BackupManifest> manifests) =>
      (manifests.fold(0, (total, manifest) => total + manifest.totalBytes) /
              1024)
          .toStringAsFixed(1);

  Future<void> _deleteAll(List<BackupManifest> doomed) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmationDialog(
      context: context,
      title: l10n.backupDeleteManyTitle(doomed.length),
      message: l10n.backupDeleteManyBody(_kilobytes(doomed)),
      confirmLabel: l10n.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed != true || !mounted) return;
    final results = await ref
        .read(backupsProvider.notifier)
        .deleteAll(doomed.map((manifest) => manifest.id));
    if (!mounted) return;
    setState(() => _selected.removeAll(results.keys));
    final deleted = results.values
        .where((result) => result == BackupDeletion.deleted)
        .length;
    final failed = results.values
        .where((result) => result == BackupDeletion.failed)
        .length;
    final message = l10n.backupsDeleted(deleted, failed);
    failed == 0
        ? showInfoToast(context, message)
        : showErrorToast(context, message);
  }

  Future<void> _prune(List<BackupManifest> manifests) async {
    final days = await showDialog<int>(
      context: context,
      builder: (context) => const _PruneDialog(),
    );
    if (days == null || !mounted) return;
    final doomed = backupsTakenBefore(
      manifests,
      DateTime.now().subtract(Duration(days: days)),
    );
    if (doomed.isEmpty) {
      showInfoToast(context, context.l10n.backupPruneNothing);
      return;
    }
    await _deleteAll(doomed);
  }

  Future<void> _download(List<BackupManifest> chosen) async {
    final bytes = await ref
        .read(backupsProvider.notifier)
        .archive(chosen.map((manifest) => manifest.id));
    if (!mounted) return;
    final path = await deliverExportBytes(
      fileName: 'fireraccoon-backups.zip',
      bytes: bytes,
      typeGroup: const XTypeGroup(label: 'ZIP', extensions: ['zip']),
      mimeType: 'application/zip',
      subject: 'fireraccoon-backups',
    );
    if (!mounted || path == null) return;
    showInfoToast(context, context.l10n.fireflyDataExportedTo(path));
  }

  Widget _selectionBar(List<BackupManifest> manifests) {
    final l10n = context.l10n;
    final chosen = [
      for (final manifest in manifests)
        if (_selected.contains(manifest.id)) manifest,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          Checkbox(
            tristate: true,
            value: chosen.isEmpty
                ? false
                : chosen.length == manifests.length
                ? true
                : null,
            semanticLabel: l10n.backupSelectAll,
            onChanged: (_) => setState(() {
              if (chosen.length == manifests.length) {
                _selected.clear();
              } else {
                _selected.addAll(manifests.map((manifest) => manifest.id));
              }
            }),
          ),
          Expanded(child: Text(l10n.backupSelected(chosen.length))),
          IconButton(
            tooltip: l10n.backupDownloadSelected,
            icon: const Icon(LucideIcons.download, size: 18),
            onPressed: chosen.isEmpty ? null : () => _download(chosen),
          ),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(LucideIcons.trash2, size: 18),
            onPressed: chosen.isEmpty ? null : () => _deleteAll(chosen),
          ),
          TextButton(
            onPressed: () => _prune(manifests),
            child: Text(l10n.backupPrune),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final available = ref.watch(backupServiceProvider) != null;
    final backups = ref.watch(backupsProvider);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.fireflyBackupsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (!available)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                l10n.backupUnavailableHere,
                style: theme.textTheme.bodyMedium,
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Expanded(child: _TakeBackupButton()),
                  // An agent taking a backup over MCP writes to the same place
                  // this list reads, and nothing tells an open screen about it.
                  IconButton(
                    tooltip: l10n.refreshFromFirefly,
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    onPressed: () =>
                        ref.read(backupsProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            backups.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: SmallLoadingIndicator(),
              ),
              error: (error, stackTrace) {
                _log.severe('Backup list failed', error, stackTrace);
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '$error',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                );
              },
              data: (manifests) => manifests.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.backupNone),
                    )
                  : Column(
                      children: [
                        _selectionBar(manifests),
                        for (final manifest in manifests)
                          _BackupTile(
                            manifest: manifest,
                            selected: _selected.contains(manifest.id),
                            onSelected: (selected) => setState(
                              () => selected
                                  ? _selected.add(manifest.id)
                                  : _selected.remove(manifest.id),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TakeBackupButton extends ConsumerWidget {
  const _TakeBackupButton();

  static final _log = AppLogger.scoped('widgets.fireflyBackup');

  Future<void> _take(
    BuildContext context,
    WidgetRef ref, {
    bool protected = false,
  }) async {
    final l10n = context.l10n;
    String? password;
    if (protected) {
      // Confirmed twice, because a password nobody can reproduce is a backup
      // nobody can restore.
      password = await showBackupPassphraseDialog(
        context: context,
        confirm: true,
        confirmLabel: l10n.backupTakeNow,
      );
      if (password == null || !context.mounted) return;
    }
    try {
      final manifest = await ref
          .read(backupsProvider.notifier)
          .create(password: password);
      if (!context.mounted) return;
      showInfoToast(context, l10n.backupTaken(manifest.id));
    } on Object catch (error, stackTrace) {
      _log.severe('Backup failed', error, stackTrace);
      if (!context.mounted) return;
      showErrorToast(context, l10n.backupFailed('$error'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ValueListenableBuilder<BackupActivity>(
      valueListenable: ref.watch(backupsProvider.notifier).progress,
      builder: (context, progress, _) {
        // A whole ledger takes minutes to read, and a button that only greys
        // out looks like it did nothing. The bar says it is moving; the
        // percentage says how much is left; the stage says what it is on.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: progress.running
                      ? null
                      : () => _take(context, ref),
                  icon: const Icon(LucideIcons.databaseBackup, size: 18),
                  label: Text(l10n.backupTakeNow),
                ),
                IconButton(
                  tooltip: l10n.backupTakeProtected,
                  icon: const Icon(LucideIcons.lock, size: 18),
                  onPressed: progress.running
                      ? null
                      : () => _take(context, ref, protected: true),
                ),
                if (!progress.running) const Spacer(),
                if (progress.running) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      backupActivityLabel(context, progress),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
            if (progress.running) ...[
              const SizedBox(height: 8),
              // Indeterminate until the work is countable: a page walk cannot
              // say how many pages there are until the first one answers.
              LinearProgressIndicator(value: progress.fraction),
            ],
          ],
        );
      },
    );
  }
}

/// Asks how old a backup has to be to go: a few common ages, or any number
/// of days.
class _PruneDialog extends StatefulWidget {
  const _PruneDialog();

  @override
  State<_PruneDialog> createState() => _PruneDialogState();
}

class _PruneDialogState extends State<_PruneDialog> {
  static const _presets = [30, 90, 365];

  int? _days = 90;
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.backupPruneTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final days in _presets)
                ChoiceChip(
                  label: Text(
                    days == 365
                        ? l10n.backupPruneYear
                        : l10n.backupPruneDays(days),
                  ),
                  selected: _days == days && _custom.text.isEmpty,
                  onSelected: (_) => setState(() {
                    _custom.clear();
                    _days = days;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _custom,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.backupPruneCustom),
            onChanged: (text) => setState(
              () => _days = text.isEmpty ? 90 : int.tryParse(text.trim()),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _days == null || _days! < 0
              ? null
              : () => Navigator.of(context).pop(_days),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}

class _BackupTile extends ConsumerWidget {
  const _BackupTile({
    required this.manifest,
    required this.selected,
    required this.onSelected,
  });

  final BackupManifest manifest;
  final bool selected;
  final ValueChanged<bool> onSelected;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmationDialog(
      context: context,
      title: l10n.backupDeleteTitle,
      message: l10n.backupDeleteBody(manifest.id),
      confirmLabel: l10n.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed != true) return;
    await ref.read(backupsProvider.notifier).delete(manifest.id);
  }

  /// The password for a sealed backup, or null when the person backed out.
  ///
  /// Asked for only when the manifest says the payload is sealed, so an
  /// unprotected backup never prompts for nothing.
  Future<String?> _passwordIfSealed(BuildContext context) async {
    if (!manifest.encrypted) return '';
    return showBackupPassphraseDialog(
      context: context,
      confirm: false,
      confirmLabel: context.l10n.backupOpen,
    );
  }

  /// Checks the backup opens and still matches its manifest, then how far the
  /// ledger has moved from it. Writes nothing either way.
  Future<void> _verify(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final password = await _passwordIfSealed(context);
    if (password == null || !context.mounted) return;
    try {
      final result = await ref
          .read(backupsProvider.notifier)
          .verify(manifest.id, password: password);
      if (!context.mounted) return;
      final problems = result.integrity.problems;
      if (problems.isNotEmpty) {
        showErrorToast(
          context,
          l10n.backupVerifyBroken(problems.length, problems.first),
        );
        return;
      }
      final drift = result.drift;
      if (drift == null || drift.isEmpty) {
        showInfoToast(context, l10n.backupVerifyIntact);
        return;
      }
      final counts = drift.countsByAction;
      showInfoToast(
        context,
        l10n.backupVerifyDrifted(
          counts['create'] ?? 0,
          counts['update'] ?? 0,
          counts['delete'] ?? 0,
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      showErrorToast(context, l10n.backupRestoreFailed('$error'));
    }
  }

  /// Plans first, always, and writes only after someone reads the plan.
  ///
  /// A restore is the one thing here that changes the ledger, so what it would
  /// do is on screen before it does any of it.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final notifier = ref.read(backupsProvider.notifier);
    final password = await _passwordIfSealed(context);
    if (password == null || !context.mounted) return;
    final RestorePlan plan;
    try {
      plan = await notifier.planRestoreOf(manifest.id, password: password);
    } on WrongLedgerException {
      if (!context.mounted) return;
      showErrorToast(context, l10n.backupRestoreWrongLedger);
      return;
    } on Object catch (error) {
      if (!context.mounted) return;
      showErrorToast(context, l10n.backupRestoreFailed('$error'));
      return;
    }
    if (!context.mounted) return;
    if (plan.isEmpty) {
      showInfoToast(context, l10n.backupRestoreNothing);
      return;
    }

    final counts = plan.countsByAction;
    final confirmed = await showConfirmationDialog(
      context: context,
      title: l10n.backupRestoreTitle,
      message:
          '${l10n.backupRestoreSummary(counts['create'] ?? 0, counts['update'] ?? 0, counts['delete'] ?? 0)}'
          '\n\n${l10n.backupRestoreNote}',
      confirmLabel: l10n.backupRestore,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed != true) return;

    try {
      final outcomes = await notifier.applyRestore(plan, password: password);
      final failed = outcomes.where((outcome) => !outcome.applied).length;
      if (!context.mounted) return;
      showInfoToast(
        context,
        l10n.backupRestoreDone(outcomes.length - failed, failed),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      showErrorToast(context, l10n.backupRestoreFailed('$error'));
    }
  }

  Future<void> _saveSnapshot(BuildContext context, WidgetRef ref) async {
    final password = await _passwordIfSealed(context);
    if (password == null || !context.mounted) return;
    final contents = await ref
        .read(backupsProvider.notifier)
        .file(manifest.id, kBackupSnapshotFile, password: password);
    if (contents == null || !context.mounted) return;
    final l10n = context.l10n;
    final path = await deliverExportFile(
      fileName: 'fireraccoon-backup-${manifest.id}.json',
      contents: contents,
      subject: 'fireraccoon-backup-${manifest.id}',
    );
    if (!context.mounted || path == null) return;
    showInfoToast(context, l10n.fireflyDataExportedTo(path));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final taken = manifest.takenAt.toLocal();
    final kilobytes = (manifest.totalBytes / 1024).toStringAsFixed(1);

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => onSelected(value ?? false),
          ),
          Icon(
            !manifest.complete
                ? LucideIcons.triangleAlert
                : manifest.encrypted
                ? LucideIcons.lock
                : LucideIcons.archive,
            color: manifest.complete ? null : theme.colorScheme.error,
          ),
        ],
      ),
      title: Text(
        '${DateFormat.yMMMd().add_Hm().format(taken)} '
        '(${manifest.timeZoneName})',
      ),
      subtitle: Text(
        [
          l10n.backupCountsSummary(
            manifest.counts['transactions'] ?? 0,
            manifest.counts['accounts'] ?? 0,
          ),
          l10n.backupSize(manifest.entries.length, kilobytes),
          if (manifest.encrypted) l10n.backupEncryptedBadge,
          // The warning icon is for a backup nothing can be restored from. An
          // export Firefly could not produce is worth a word, not an alarm.
          if (!manifest.complete || manifest.failedExports.isNotEmpty)
            l10n.backupIncomplete,
        ].join(' · '),
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          PopupMenuItem(value: 'verify', child: Text(l10n.backupVerify)),
          PopupMenuItem(value: 'restore', child: Text(l10n.backupRestore)),
          PopupMenuItem(value: 'save', child: Text(l10n.backupSaveSnapshot)),
          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
        ],
        onSelected: (value) => switch (value) {
          'verify' => _verify(context, ref),
          'restore' => _restore(context, ref),
          'save' => _saveSnapshot(context, ref),
          _ => _delete(context, ref),
        },
      ),
    );
  }
}
