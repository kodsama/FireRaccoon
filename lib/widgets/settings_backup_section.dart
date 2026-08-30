import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../l10n/l10n_extensions.dart';
import '../models/settings_bundle.dart';
import '../providers/data_providers.dart';
import '../providers/people_providers.dart';
import '../providers/settings_export_import_provider.dart';
import '../utils/app_feedback.dart';
import '../utils/json_file_store.dart';
import '../utils/settings_secrets_crypto.dart';
import 'backup_passphrase_dialog.dart';
import 'confirmation_dialog.dart';

/// Export / import FireRaccoon settings.
///
/// Firefly tokens and salted password hashes are sealed with a backup
/// passphrase (AES-256-GCM). Biometrics and custom avatar bytes are omitted.
class SettingsBackupSection extends ConsumerWidget {
  const SettingsBackupSection({super.key});

  static final _log = AppLogger.scoped('widgets.settingsBackup');

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    // Stated before the file is written, not after: what a backup leaves behind
    // is the thing people discover at restore time, when it is too late.
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exportSettingsDisclosureTitle),
        content: SingleChildScrollView(
          child: Text(l10n.exportSettingsDisclosure),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.exportSettingsContinue),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    final bundle = await ref.read(settingsExportImportProvider).buildBundle();
    if (!context.mounted) return;

    String? passphrase;
    if (bundle.needsSecretsPassphrase) {
      passphrase = await showBackupPassphraseDialog(
        context: context,
        confirm: true,
      );
      if (passphrase == null || !context.mounted) return;
    }

    final contents = await bundle.encodeSealed(passphrase);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'fireraccoon_settings_$timestamp.json';
    final path = await jsonStoreDocumentsPath(fileName);
    await jsonStoreWrite(path, contents);

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsExportedTo(path))));

    await SharePlus.instance.share(
      ShareParams(
        text: l10n.settingsExportText,
        subject: l10n.settingsExportSubject,
        files: [
          XFile.fromData(
            utf8.encode(contents),
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
      ),
    );
  }

  /// Writes a snapshot of the Firefly data itself, which the settings bundle
  /// deliberately leaves out.
  ///
  /// No share sheet, unlike the settings export: this is a full financial
  /// record, and its place is a file on disk rather than whatever the sheet
  /// happens to offer.
  Future<void> _exportFireflyData(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final api = ref.read(apiServiceProvider);
    if (api == null) {
      showErrorToast(context, l10n.notConnected);
      return;
    }

    try {
      final snapshot = await DataExportService(api).export();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = await jsonStoreDocumentsPath(
        'fireraccoon_firefly_data_$timestamp.json',
      );
      await jsonStoreWrite(
        path,
        const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
      );
      _log.info('Exported Firefly data snapshot: ${snapshot.counts}');
      if (!context.mounted) return;
      showInfoToast(context, l10n.fireflyDataExportedTo(path));
    } catch (error) {
      _log.severe('Firefly data export failed', error);
      if (!context.mounted) return;
      showErrorToast(context, '$error');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmationDialog(
      context: context,
      title: l10n.importSettingsConfirmTitle,
      message: l10n.importSettingsConfirmMessage,
      confirmLabel: l10n.importSettings,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed != true || !context.mounted) return;

    const typeGroup = XTypeGroup(label: 'json', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !context.mounted) return;

    try {
      final raw = await file.readAsString();
      if (!context.mounted) return;
      String? passphrase;
      if (SettingsBundle.sourceHasSecrets(raw)) {
        passphrase = await showBackupPassphraseDialog(
          context: context,
          confirm: false,
        );
        if (passphrase == null || !context.mounted) return;
      }

      final bundle = await SettingsBundle.decode(raw, passphrase: passphrase);
      _log.info(
        'Importing settings: schema ${bundle.schemaVersion}, '
        '${bundle.people.people.length} person(s), '
        '${bundle.people.accountOwnerships.length} ownership(s), '
        'firefly=${bundle.firefly != null}',
      );
      await ref.read(settingsExportImportProvider).applyBundle(bundle);
      if (!context.mounted) return;
      _log.info('Settings import finished');
      showInfoToast(context, l10n.settingsImported);
    } on SettingsSecretsUnlockException catch (error, stackTrace) {
      _log.severe(
        'Settings import could not unlock secrets',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      showErrorToast(context, error.message);
    } on Object catch (error, stackTrace) {
      _log.severe('Settings import failed', error, stackTrace);
      if (!context.mounted) return;
      showErrorToast(context, l10n.settingsImportFailed(error.toString()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final peopleEnabled = ref.watch(peopleProvider).isEnabled;
    final canManage = ref.watch(canManagePeopleProvider);
    // Import overwrites people; require admin once people exist.
    final canImport = !peopleEnabled || canManage;

    // The explanations sit outside the ListTile: a subtitle clips at a couple of
    // lines, and what a backup drops or overwrites is exactly the part nobody
    // should have to discover by trying it.
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.download, size: 20),
            title: Text(l10n.exportSettings),
            onTap: () => _export(context, ref),
          ),
          _explainer(context, l10n.exportSettingsDescription, enabled: true),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(LucideIcons.databaseBackup, size: 20),
            title: Text(l10n.exportFireflyData),
            onTap: () => _exportFireflyData(context, ref),
          ),
          _explainer(context, l10n.exportFireflyDataDescription, enabled: true),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(LucideIcons.upload, size: 20),
            title: Text(l10n.importSettings),
            enabled: canImport,
            onTap: canImport ? () => _import(context, ref) : null,
          ),
          _explainer(
            context,
            l10n.importSettingsDescription,
            enabled: canImport,
          ),
        ],
      ),
    );
  }

  Widget _explainer(
    BuildContext context,
    String text, {
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final color = enabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.disabledColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
