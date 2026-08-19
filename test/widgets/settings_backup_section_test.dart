import 'dart:convert';

// The picker seam lives in file_selector's platform interface, which comes in
// transitively with file_selector itself.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/models/settings_bundle.dart';
import 'package:fireracoon/providers/people_providers.dart';
import 'package:fireracoon/providers/settings_export_import_provider.dart';
import 'package:fireracoon/utils/app_feedback.dart';
import 'package:fireracoon/widgets/settings_backup_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/localized_test_app.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/static_people_notifier.dart';

/// Stands in for the OS file picker.
///
/// The real one blocks on a native dialog, so the import flow could otherwise
/// never be driven past its confirmation.
class _FakePicker extends FileSelectorPlatform {
  _FakePicker(this._file);

  final XFile? _file;
  int calls = 0;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    calls++;
    return _file;
  }
}

/// Records what the section asked the settings service to do.
///
/// Standing in for the real service keeps these tests on the widget's gates:
/// buildBundle reads every stored preference and applyBundle rewrites them,
/// which test/providers/settings_export_import_provider_test.dart covers.
class _RecordingBackup extends SettingsExportImport {
  _RecordingBackup(super.ref, this._bundle);

  final SettingsBundle? _bundle;
  int builds = 0;
  final applied = <SettingsBundle>[];

  @override
  Future<SettingsBundle> buildBundle() async {
    builds++;
    return _bundle!;
  }

  @override
  Future<void> applyBundle(SettingsBundle bundle) async => applied.add(bundle);
}

/// A backup file with a Firefly token, so export must seal it.
SettingsBundle _bundleNeedingPassphrase() => const SettingsBundle(
  schemaVersion: kSettingsBundleSchemaVersion,
  exportedAtIso: '2026-08-19T09:00:00.000Z',
  device: {'themeMode': 'dark'},
  people: SettingsPeopleBundle(),
  firefly: SettingsFireflyBundle(
    serverUrl: 'https://firefly.test',
    apiToken: 'secret-token',
  ),
);

/// Serialises a backup exactly as the app writes it.
Future<String> _backupSource({List<Person> people = const []}) {
  return SettingsBundle(
    schemaVersion: kSettingsBundleSchemaVersion,
    exportedAtIso: '2026-08-19T09:00:00.000Z',
    device: const {'themeMode': 'dark'},
    people: SettingsPeopleBundle(people: people),
  ).encodeSealed(null);
}

XFile _pickedFile(String contents) => XFile.fromData(
  utf8.encode(contents),
  mimeType: 'application/json',
  name: 'fireracoon_settings.json',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileSelectorPlatform originalPicker;

  setUp(() {
    originalPicker = FileSelectorPlatform.instance;
  });

  tearDown(() {
    FileSelectorPlatform.instance = originalPicker;
    dismissToast();
  });

  /// Swaps in a picker that answers with [file] and reports whether it ran.
  _FakePicker usePicker(XFile? file) {
    final picker = _FakePicker(file);
    FileSelectorPlatform.instance = picker;
    return picker;
  }

  Future<_RecordingBackup> pumpSection(
    WidgetTester tester, {
    List<Person> people = const [],
    SettingsBundle? exportBundle,
  }) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peopleProvider.overrideWith(() => StaticPeopleNotifier(people)),
          settingsExportImportProvider.overrideWith(
            (ref) => _RecordingBackup(ref, exportBundle),
          ),
        ],
        child: buildLocalizedTestApp(
          child: const SingleChildScrollView(child: SettingsBackupSection()),
        ),
      ),
    );
    await settleIgnoringOverflow(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsBackupSection)),
    );
    return container.read(settingsExportImportProvider) as _RecordingBackup;
  }

  Text explainerContaining(WidgetTester tester, String fragment) {
    return tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data ?? '').contains(fragment),
      ),
    );
  }

  ThemeData themeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsBackupSection)));

  Future<void> openDisclosure(WidgetTester tester) async {
    await tester.tap(find.text('Export settings'));
    await settleIgnoringOverflow(tester);
  }

  /// Walks the import flow up to the picker call.
  Future<void> confirmImport(WidgetTester tester) async {
    await tester.tap(find.text('Import settings'));
    await settleIgnoringOverflow(tester);
    await confirmDialogWithChallenge(tester);
  }

  testWidgets('each row explains what a backup carries and what it drops', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('Export settings'), findsOneWidget);
    expect(find.text('Import settings'), findsOneWidget);
    // The paragraphs are the only place the omissions are stated on screen.
    expect(
      explainerContaining(tester, 'Left out: MCP agent keys').data,
      contains('custom profile photos'),
    );
    expect(
      explainerContaining(tester, 'Replaces what is on this device').data,
      contains('Deletes MCP agent keys'),
    );
  });

  testWidgets('a non-admin cannot import, and its explainer greys out', (
    tester,
  ) async {
    final backup = await pumpSection(
      tester,
      people: [testPerson('p1', 'Ada', role: PersonRole.user)],
    );

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Import settings'),
    );
    expect(tile.enabled, isFalse);
    expect(tile.onTap, isNull);

    final theme = themeOf(tester);
    expect(
      explainerContaining(
        tester,
        'Replaces what is on this device',
      ).style?.color,
      theme.disabledColor,
      reason: 'the paragraph has to read as unavailable, not merely quiet',
    );
    // Export stays open to everyone: it writes nothing on this device.
    expect(
      explainerContaining(tester, 'Left out: MCP agent keys').style?.color,
      theme.colorScheme.onSurfaceVariant,
    );

    await tester.tap(find.text('Import settings'));
    await settleIgnoringOverflow(tester);
    expect(find.text('Overwrite settings?'), findsNothing);
    expect(backup.applied, isEmpty);
  });

  testWidgets('export states what goes into the file before building it', (
    tester,
  ) async {
    final backup = await pumpSection(
      tester,
      exportBundle: _bundleNeedingPassphrase(),
    );

    await openDisclosure(tester);

    expect(find.text('What goes into the file?'), findsOneWidget);
    expect(find.textContaining('NOT INCLUDED'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Export'), findsOneWidget);
    expect(
      backup.builds,
      0,
      reason: 'the disclosure comes before any settings are read',
    );
  });

  testWidgets('cancelling the disclosure exports nothing', (tester) async {
    final backup = await pumpSection(
      tester,
      exportBundle: _bundleNeedingPassphrase(),
    );
    await openDisclosure(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settleIgnoringOverflow(tester);

    expect(find.text('What goes into the file?'), findsNothing);
    expect(backup.builds, 0);
    expect(find.textContaining('Settings exported to'), findsNothing);
  });

  testWidgets('continuing past the disclosure seals secrets first', (
    tester,
  ) async {
    final backup = await pumpSection(
      tester,
      exportBundle: _bundleNeedingPassphrase(),
    );
    await openDisclosure(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Export'));
    await settleIgnoringOverflow(tester);

    expect(backup.builds, 1);
    // A bundle carrying a Firefly token must not reach a file unsealed. The run
    // stops at the open dialog: closing it trips a disposed-controller
    // assertion inside backup_passphrase_dialog.dart.
    expect(find.text('Protect backup'), findsOneWidget);
    expect(find.textContaining('Settings exported to'), findsNothing);
  });

  testWidgets('import opens no picker until the challenge word is typed', (
    tester,
  ) async {
    final picker = usePicker(null);
    final backup = await pumpSection(tester);

    await tester.tap(find.text('Import settings'));
    await settleIgnoringOverflow(tester);

    expect(find.text('Overwrite settings?'), findsOneWidget);
    expect(find.textContaining('REPLACED on this device'), findsOneWidget);
    expect(picker.calls, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settleIgnoringOverflow(tester);

    expect(
      picker.calls,
      0,
      reason: 'a cancelled overwrite must not ask for a file',
    );
    expect(backup.applied, isEmpty);
  });

  testWidgets('a confirmed import applies the file the picker returned', (
    tester,
  ) async {
    usePicker(
      _pickedFile(await _backupSource(people: [testPerson('p9', 'Grace')])),
    );
    final backup = await pumpSection(tester);

    await confirmImport(tester);

    expect(backup.applied.single.people.people.single.name, 'Grace');
    expect(find.text('Settings imported.'), findsOneWidget);

    // The confirmation schedules its own dismissal; let it run or the test ends
    // with a pending timer.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Settings imported.'), findsNothing);
  });

  testWidgets('dismissing the picker leaves settings untouched', (
    tester,
  ) async {
    final picker = usePicker(null);
    final backup = await pumpSection(tester);

    await confirmImport(tester);

    expect(picker.calls, 1);
    expect(backup.applied, isEmpty);
    expect(find.text('Settings imported.'), findsNothing);
  });

  testWidgets('a malformed file stays on screen until it is dismissed', (
    tester,
  ) async {
    usePicker(_pickedFile('this is not a backup'));
    final backup = await pumpSection(tester);

    await confirmImport(tester);

    expect(find.textContaining('Could not import settings'), findsOneWidget);
    expect(backup.applied, isEmpty);

    // Failures are not transient status: they must outlive a glance away.
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('Could not import settings'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await settleIgnoringOverflow(tester);
    expect(find.textContaining('Could not import settings'), findsNothing);
  });

  testWidgets('a sealed file asks for its passphrase before applying', (
    tester,
  ) async {
    final source = jsonDecode(await _backupSource()) as Map<String, dynamic>;
    source['secrets'] = const {'v': 1, 'salt': 'AA==', 'ciphertext': 'AA=='};
    usePicker(_pickedFile(jsonEncode(source)));
    final backup = await pumpSection(tester);

    await confirmImport(tester);

    expect(find.text('Unlock backup'), findsOneWidget);
    expect(
      backup.applied,
      isEmpty,
      reason: 'sealed people and tokens cannot be applied before the unlock',
    );
  });
}
