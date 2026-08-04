import 'dart:io';

import 'package:fireracoon/models/account_prognosis.dart';
import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/models/settings_bundle.dart';
import 'package:fireracoon/providers/account_classification_provider.dart';
import 'package:fireracoon/providers/default_period_provider.dart';
import 'package:fireracoon/providers/locale_provider.dart';
import 'package:fireracoon/providers/people_providers.dart';
import 'package:fireracoon/providers/prognosis_settings_provider.dart';
import 'package:fireracoon/providers/settings_export_import_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/providers/tight_rows_columns_provider.dart';
import 'package:fireracoon/providers/transaction_page_size_provider.dart';
import 'package:fireracoon/providers/undo_history_provider.dart';
import 'package:fireracoon/providers/view_mode_provider.dart';
import 'package:fireracoon/providers/write_ahead_provider.dart';
import 'package:fireracoon/theme/app_colors.dart';
import 'package:fireracoon/theme/theme_palette.dart';
import 'package:fireracoon_engine/utils/dashboard_period.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_biometric_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settings-export-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return tempDir.path;
          }
          return null;
        });
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        peopleProvider.overrideWith(
          () => PeopleNotifier(
            storage: const FlutterSecureStorage(),
            biometricAuth: FakeBiometricAuth(),
          ),
        ),
      ],
    );
  }

  Future<void> waitHydrated(ProviderContainer container) async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (container.read(peopleProvider).isHydrated) return;
    }
    fail('people provider never hydrated');
  }

  Uint8List tinyPng() {
    final image = img.Image(width: 32, height: 32);
    img.fill(image, color: img.ColorRgb8(10, 20, 30));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('buildBundle captures device, people, and prognosis settings', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await waitHydrated(container);

    await container
        .read(peopleProvider.notifier)
        .addPerson(name: 'Alex', colorValue: 0xFF3B82F6);
    container
        .read(themeProvider.notifier)
        .applyStyle(
          themeMode: ThemeMode.dark,
          paletteType: ThemePaletteType.classic,
          accentType: AccentColorType.blue,
        );
    await container
        .read(localeProvider.notifier)
        .setLocale(AppLocale.fromCode('ja'));
    await container
        .read(defaultDashboardPeriodProvider.notifier)
        .setPeriod(DashboardPeriod.thisYear);
    await container.read(transactionPageSizeProvider.notifier).setPageSize(50);
    await container.read(writeAheadDaysProvider.notifier).setDays(14);
    await container.read(undoHistoryProvider.notifier).setLimit(20);
    await container.read(viewModeProvider.notifier).setMode(ViewMode.compact);
    await container.read(tightRowsColumnsProvider.notifier).setColumns({
      TightRowColumn.date,
      TightRowColumn.description,
    });
    await container.read(accountClassificationProvider.notifier).replaceAll({
      'acc1': AccountCategory.asset,
    });
    container
        .read(prognosisSettingsProvider.notifier)
        .replaceAll(
          const PrognosisSettings(
            mode: PrognosisViewMode.projected,
            horizon: PrognosisHorizon.oneYear,
            inclusion: PrognosisInclusionOptions(),
            marginPercent: 12,
          ),
        );

    final bundle = container.read(settingsExportImportProvider).buildBundle();
    expect(bundle.schemaVersion, kSettingsBundleSchemaVersion);
    expect(bundle.device['themeMode'], 'dark');
    expect(bundle.device['locale'], 'ja');
    expect(bundle.device['defaultDashboardPeriod'], 'thisYear');
    expect(bundle.device['transactionPageSize'], isA<int>());
    expect(bundle.device['recurrenceWriteAheadDays'], isA<int>());
    expect(bundle.device['undoHistoryLimit'], isA<int>());
    expect(bundle.people.people.single.name, 'Alex');
    expect(bundle.accountClassifications['acc1'], 'asset');
    expect(bundle.viewMode, isA<String>());
    expect(bundle.tightRowsColumns, isNotNull);
    expect(bundle.prognosis?['mode'], 'projected');
    expect(bundle.prognosis?['horizon'], 'oneYear');
    expect(bundle.prognosis?['marginPercent'], 12);
    expect(bundle.sideMenu, isNotNull);
    expect(bundle.accountColumns, isNotNull);
    expect(bundle.transactionColumns, isNotNull);
  });

  test('applyBundle overwrites people and device settings', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await waitHydrated(container);

    await container
        .read(peopleProvider.notifier)
        .addPerson(name: 'Local', colorValue: 0xFF3B82F6);

    final existing = container.read(settingsExportImportProvider).buildBundle();
    final bundle = SettingsBundle(
      schemaVersion: kSettingsBundleSchemaVersion,
      exportedAtIso: '2026-08-04T00:00:00.000Z',
      device: {
        'locale': 'ja',
        'themeMode': 'dark',
        'paletteType': 'classic',
        'accentType': 'blue',
        'funMode': 'none',
        'defaultDashboardPeriod': 'thisMonth',
        'transactionPageSize': 25,
        'recurrenceWriteAheadDays': 7,
        'undoHistoryLimit': 10,
      },
      people: SettingsPeopleBundle(
        people: const [
          Person(
            id: 'imported',
            name: 'Imported',
            colorValue: 0xFF10B981,
            role: PersonRole.admin,
            createdAtIso: '2026-01-01T00:00:00.000Z',
            preferences: PersonPreferences(localeCode: 'ja'),
          ),
        ],
        accountOwnerships: {
          'acc_x': const AccountOwnership(
            accountId: 'acc_x',
            personShares: {'imported': 1.0},
          ),
        },
        requirePasswordLogin: true,
      ),
      accountClassifications: {'acc_x': 'asset'},
      sideMenu: existing.sideMenu,
      accountColumns: existing.accountColumns,
      transactionColumns: existing.transactionColumns,
      viewMode: 'standard',
      tightRowsColumns: ['date'],
      prognosis: {
        'mode': 'expected',
        'horizon': 'endOfNextMonth',
        'marginPercent': 15,
        'inclusion': {
          'includeScheduledTransactions': true,
          'includeRecurringTransactions': true,
          'includeBills': true,
          'includeIncome': true,
          'includeExpenses': true,
          'includeTransfers': false,
          'includeCreditCards': true,
          'includeLiabilities': true,
        },
      },
    );

    await container.read(settingsExportImportProvider).applyBundle(bundle);

    final state = container.read(peopleProvider);
    expect(state.people.map((p) => p.name), ['Imported']);
    expect(state.config.accountOwnerships.containsKey('acc_x'), isTrue);
    expect(state.requirePasswordLogin, isFalse);
    expect(container.read(localeProvider).languageCode, 'ja');
    expect(container.read(themeProvider).themeMode, ThemeMode.dark);
    expect(container.read(transactionPageSizeProvider), isA<int>());
    expect(container.read(writeAheadDaysProvider), isA<int>());
    expect(container.read(undoHistoryProvider).limit, isA<int>());
    expect(
      container.read(accountClassificationProvider)['acc_x'],
      AccountCategory.asset,
    );
    expect(
      container.read(prognosisSettingsProvider).inclusion.includeTransfers,
      isFalse,
    );
  });

  test('applyBundle ignores unknown enum names with fallbacks', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await waitHydrated(container);

    final bundle = SettingsBundle(
      schemaVersion: kSettingsBundleSchemaVersion,
      exportedAtIso: '2026-08-04T00:00:00.000Z',
      device: {
        'themeMode': 'not-a-mode',
        'paletteType': 'nope',
        'accentType': 'nope',
        'funMode': 'nope',
        'defaultDashboardPeriod': 'nope',
      },
      people: const SettingsPeopleBundle(),
      viewMode: 'nope',
      tightRowsColumns: ['nope'],
      prognosis: {'mode': 'nope', 'horizon': 'nope', 'marginPercent': 'bad'},
      accountClassifications: {'bad': 'not-a-category'},
    );

    await container.read(settingsExportImportProvider).applyBundle(bundle);
    expect(container.read(themeProvider).themeMode, ThemeMode.system);
    expect(container.read(viewModeProvider), ViewMode.standard);
    expect(container.read(prognosisSettingsProvider).marginPercent, 15);
    expect(
      container.read(accountClassificationProvider)['bad'],
      AccountCategory.asset,
    );
  });

  test('custom avatar bytes round-trip through people notifier', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await waitHydrated(container);

    final notifier = container.read(peopleProvider.notifier);
    final person = await notifier.addPerson(
      name: 'Alex',
      colorValue: 0xFF3B82F6,
    );
    final bytes = tinyPng();
    await notifier.saveCustomAvatar(person.id, bytes);
    var updated = container.read(peopleProvider).people.single;
    expect(updated.avatarKind, AvatarKind.custom);
    final resolved = await notifier.resolveCustomAvatarBytes(updated);
    expect(resolved, isNotNull);
    expect(resolved, isNotEmpty);

    await notifier.setPresetAvatar(person.id, 'raccoon_1');
    updated = container.read(peopleProvider).people.single;
    expect(updated.avatarKind, AvatarKind.preset);
    expect(updated.avatarValue, 'raccoon_1');

    await notifier.clearAvatar(person.id);
    updated = container.read(peopleProvider).people.single;
    expect(updated.avatarKind, AvatarKind.none);
    expect(updated.avatarValue, isNull);
  });

  test('normalizeAvatarPng shrinks large images', () {
    final image = img.Image(width: 512, height: 512);
    img.fill(image, color: img.ColorRgb8(1, 2, 3));
    final large = Uint8List.fromList(img.encodePng(image));
    final normalized = normalizeAvatarPng(large);
    final decoded = img.decodeImage(normalized)!;
    expect(decoded.width, kAvatarStoredEdge);
    expect(decoded.height, kAvatarStoredEdge);
  });
}
