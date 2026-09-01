import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/backup_providers.dart';
import '../utils/app_feedback.dart';
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
class FireflyBackupSection extends ConsumerWidget {
  const FireflyBackupSection({super.key});

  static final _log = AppLogger.scoped('widgets.fireflyBackup');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        for (final manifest in manifests)
                          _BackupTile(manifest: manifest),
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

  Future<void> _take(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final manifest = await ref.read(backupsProvider.notifier).create();
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

class _BackupTile extends ConsumerWidget {
  const _BackupTile({required this.manifest});

  final BackupManifest manifest;

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

  /// Plans first, always, and writes only after someone reads the plan.
  ///
  /// A restore is the one thing here that changes the ledger, so what it would
  /// do is on screen before it does any of it.
  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final notifier = ref.read(backupsProvider.notifier);
    final RestorePlan plan;
    try {
      plan = await notifier.planRestoreOf(manifest.id);
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
      final outcomes = await notifier.applyRestore(plan);
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
    final contents = await ref
        .read(backupsProvider.notifier)
        .file(manifest.id, kBackupSnapshotFile);
    if (contents == null || !context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        subject: 'fireraccoon-backup-${manifest.id}',
        files: [
          XFile.fromData(
            utf8.encode(contents),
            mimeType: 'application/json',
            name: 'fireraccoon-backup-${manifest.id}.json',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final taken = manifest.takenAt.toLocal();
    final kilobytes = (manifest.totalBytes / 1024).toStringAsFixed(1);

    return ListTile(
      leading: Icon(
        manifest.complete ? LucideIcons.archive : LucideIcons.triangleAlert,
        color: manifest.complete ? null : theme.colorScheme.error,
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
          if (!manifest.complete) l10n.backupIncomplete,
        ].join(' · '),
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          PopupMenuItem(value: 'restore', child: Text(l10n.backupRestore)),
          PopupMenuItem(value: 'save', child: Text(l10n.backupSaveSnapshot)),
          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
        ],
        onSelected: (value) => switch (value) {
          'restore' => _restore(context, ref),
          'save' => _saveSnapshot(context, ref),
          _ => _delete(context, ref),
        },
      ),
    );
  }
}
