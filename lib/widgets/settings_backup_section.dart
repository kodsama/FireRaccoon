import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n_extensions.dart';
import '../models/settings_bundle.dart';
import '../providers/people_providers.dart';
import '../providers/settings_export_import_provider.dart';
import '../utils/json_file_store.dart';
import 'confirmation_dialog.dart';

/// Export / import FireRacoon settings (no passwords, tokens, or assets).
class SettingsBackupSection extends ConsumerWidget {
  const SettingsBackupSection({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final bundle = ref.read(settingsExportImportProvider).buildBundle();
    final contents = bundle.encodePretty();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'fireracoon_settings_$timestamp.json';
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
      final bundle = SettingsBundle.decode(raw);
      await ref.read(settingsExportImportProvider).applyBundle(bundle);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsImported)));
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsImportFailed(error.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final peopleEnabled = ref.watch(peopleProvider).isEnabled;
    final canManage = ref.watch(canManagePeopleProvider);
    // Import overwrites people; require admin once people exist.
    final canImport = !peopleEnabled || canManage;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(LucideIcons.download, size: 20),
            title: Text(l10n.exportSettings),
            subtitle: Text(l10n.exportSettingsDescription),
            onTap: () => _export(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(LucideIcons.upload, size: 20),
            title: Text(l10n.importSettings),
            subtitle: Text(l10n.importSettingsDescription),
            enabled: canImport,
            onTap: canImport ? () => _import(context, ref) : null,
          ),
        ],
      ),
    );
  }
}
