import 'dart:convert';
import 'dart:io';

import 'package:fireracoon/deployment/deployment_providers.dart';
import 'package:fireracoon/deployment/fireracoon_mode.dart';
import 'package:fireracoon/models/account_prognosis.dart';
import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/models/settings_bundle.dart';
import 'package:fireracoon/providers/account_classification_provider.dart';
import 'package:fireracoon/providers/agent_keys_provider.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/default_period_provider.dart';
import 'package:fireracoon/providers/locale_provider.dart';
import 'package:fireracoon/providers/people_providers.dart';
import 'package:fireracoon/providers/prognosis_settings_provider.dart';
import 'package:fireracoon/providers/server_session_provider.dart';
import 'package:fireracoon/providers/settings_export_import_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/providers/tight_rows_columns_provider.dart';
import 'package:fireracoon/providers/transaction_page_size_provider.dart';
import 'package:fireracoon/providers/undo_history_provider.dart';
import 'package:fireracoon/providers/view_mode_provider.dart';
import 'package:fireracoon/providers/write_ahead_provider.dart';
import 'package:fireracoon/store/remote_server_client.dart';
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

import '../helpers/password_cost.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_biometric_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const passphrase = 'Correct-Horse9!';

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
        // Without a stub loader the real one reads .env from the working
        // directory, so what this suite asserts depends on whichever Firefly
        // credentials the developer happens to have on disk.
        authProvider.overrideWith(
          () => AuthNotifier(
            storage: const FlutterSecureStorage(),
            debugEnvLoader: () async => const {},
          ),
        ),
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

    final bundle = await container
        .read(settingsExportImportProvider)
        .buildBundle();
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

  test('an exported bundle carries no agent key material', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await waitHydrated(container);
    await container
        .read(peopleProvider.notifier)
        .addPerson(name: 'Alex', colorValue: 0xFF3B82F6);
    await container.read(agentKeysProvider.future);
    final secret = await container
        .read(agentKeysProvider.notifier)
        .issue('Claude Desktop');
    final record = container
        .read(agentKeysProvider.notifier)
        .localRecords
        .single;

    final bundle = await container
        .read(settingsExportImportProvider)
        .buildBundle();
    final encoded = await bundle.encodeSealed(passphrase);

    // Keys live in the keychain or the sealed store and go nowhere else: a
    // backup file is a copy someone can carry off the machine.
    for (final material in [secret, record.hash, record.id]) {
      expect(
        encoded,
        isNot(contains(material)),
        reason: 'agent key material must not reach a settings backup',
      );
      expect(bundle.toString(), isNot(contains(material)));
    }
  });

  test('applyBundle overwrites people and device settings', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await waitHydrated(container);

    await container
        .read(peopleProvider.notifier)
        .addPerson(name: 'Local', colorValue: 0xFF3B82F6);

    final existing = await container
        .read(settingsExportImportProvider)
        .buildBundle();
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
      people: const SettingsPeopleBundle(
        people: [
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
          'acc_x': AccountOwnership(
            accountId: 'acc_x',
            personShares: {'imported': 1.0},
          ),
        },
        requirePasswordLogin: true,
      ),
      accountClassifications: const {'acc_x': 'asset'},
      sideMenu: existing.sideMenu,
      accountColumns: existing.accountColumns,
      transactionColumns: existing.transactionColumns,
      viewMode: 'standard',
      tightRowsColumns: const ['date'],
      prognosis: const {
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

  test(
    'sealed round-trip restores salted passwords and Firefly credentials',
    () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      await container
          .read(authProvider.notifier)
          .saveSettings('https://firefly.example', 'ff-token-secret', true);

      final notifier = container.read(peopleProvider.notifier);
      final person = await notifier.addPerson(
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        password: passphrase,
      );
      await notifier.setRequirePasswordLogin(true);

      final exported = await container
          .read(settingsExportImportProvider)
          .buildBundle();
      expect(exported.needsSecretsPassphrase, isTrue);
      final sealed = await exported.encodeSealed(passphrase);
      expect(sealed.contains('ff-token-secret'), isFalse);

      await container.read(authProvider.notifier).clearSettings();
      await notifier.importSettings(
        people: const [
          Person(
            id: 'other',
            name: 'Other',
            colorValue: 0xFF10B981,
            role: PersonRole.admin,
            createdAtIso: '2026-01-01T00:00:00.000Z',
          ),
        ],
        accountOwnerships: const {},
        requirePasswordLogin: false,
      );

      final restored = await SettingsBundle.decode(
        sealed,
        passphrase: passphrase,
      );
      await container.read(settingsExportImportProvider).applyBundle(restored);

      final auth = container.read(authProvider);
      expect(auth.serverUrl, 'https://firefly.example');
      expect(auth.apiToken, 'ff-token-secret');
      expect(auth.allowInsecure, isTrue);

      final state = container.read(peopleProvider);
      expect(state.people.single.id, person.id);
      expect(state.people.single.hasPassword, isTrue);
      expect(state.requirePasswordLogin, isTrue);
      expect(await notifier.login('Alex', passphrase), isNotNull);
    },
  );

  test(
    'applyBundle keeps destination Firefly when file omits connection',
    () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      await container
          .read(authProvider.notifier)
          .saveSettings('https://keep.example', 'keep-token', false);

      final bundle = SettingsBundle(
        schemaVersion: kSettingsBundleSchemaVersion,
        exportedAtIso: '2026-08-04T00:00:00.000Z',
        device: const {},
        people: const SettingsPeopleBundle(),
      );
      await container.read(settingsExportImportProvider).applyBundle(bundle);

      final auth = container.read(authProvider);
      expect(auth.serverUrl, 'https://keep.example');
      expect(auth.apiToken, 'keep-token');
    },
  );

  test('applyBundle ignores unknown enum names with fallbacks', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await waitHydrated(container);

    final bundle = SettingsBundle(
      schemaVersion: kSettingsBundleSchemaVersion,
      exportedAtIso: '2026-08-04T00:00:00.000Z',
      device: const {
        'themeMode': 'not-a-mode',
        'paletteType': 'nope',
        'accentType': 'nope',
        'funMode': 'nope',
        'defaultDashboardPeriod': 'nope',
      },
      people: const SettingsPeopleBundle(),
      viewMode: 'nope',
      tightRowsColumns: const ['nope'],
      prognosis: const {
        'mode': 'nope',
        'horizon': 'nope',
        'marginPercent': 'bad',
      },
      accountClassifications: const {'bad': 'not-a-category'},
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

  group('server mode backup secrets', () {
    Future<ProviderContainer> buildServerContainer({
      required http.Client httpClient,
      String? sessionToken = 'sess',
    }) async {
      final prefs = await SharedPreferences.getInstance();
      if (sessionToken != null) {
        FlutterSecureStoragePlatform.instance =
            TestFlutterSecureStoragePlatform({
              'serverSessionToken': sessionToken,
            });
      } else {
        FlutterSecureStoragePlatform.instance =
            TestFlutterSecureStoragePlatform({});
      }
      final client = RemoteServerClient(
        baseUrl: 'http://example.test',
        sessionToken: sessionToken,
        httpClient: httpClient,
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deploymentConfigProvider.overrideWithValue(
            const DeploymentConfig(
              mode: FireracoonMode.server,
              apiBase: 'http://example.test',
            ),
          ),
          authProvider.overrideWith(
            () => AuthNotifier(
              storage: const FlutterSecureStorage(),
              debugEnvLoader: () async => const {},
            ),
          ),
          serverSessionProvider.overrideWith(
            () => ServerSessionNotifier(
              storage: const FlutterSecureStorage(),
              clientFactory: (_) => client,
            ),
          ),
          peopleProvider.overrideWith(
            () => PeopleNotifier(
              storage: const FlutterSecureStorage(),
              biometricAuth: FakeBiometricAuth(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(serverSessionProvider.future);
      return container;
    }

    Map<String, dynamic> serverState() => {
      'storeLocked': false,
      'storeExists': true,
      'setupRequired': false,
      'me': {'id': 'admin_1', 'name': 'Alex', 'role': 'admin'},
      'people': [
        {
          'id': 'admin_1',
          'name': 'Alex',
          'role': 'admin',
          'hasPassword': true,
          'createdAt': '2026-08-01T00:00:00.000Z',
        },
      ],
      'accountOwnerships': const <dynamic>[],
      'requirePasswordLogin': true,
    };

    test(
      'buildBundle seals PAT and portable hashes from backup-secrets',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = await buildServerContainer(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/api/capabilities')) {
              return http.Response(
                jsonEncode({
                  'storeLocked': false,
                  'storeExists': true,
                  'setupRequired': false,
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/api/state/backup-secrets')) {
              return http.Response(
                jsonEncode({
                  'ok': true,
                  'firefly': {
                    'url': 'https://firefly.example',
                    'token': 'ff-token-secret',
                    'allowInsecure': true,
                  },
                  'requirePasswordLogin': true,
                  'peopleAuth': {
                    'admin_1': {
                      'passwordHash': 'portable-hash',
                      'salt': 'portable-salt',
                    },
                  },
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/api/state')) {
              return http.Response(jsonEncode(serverState()), 200);
            }
            return http.Response('{}', 200);
          }),
        );
        await waitHydrated(container);
        await container
            .read(peopleProvider.notifier)
            .syncFromServerStore(loggedInPersonId: 'admin_1');

        final bundle = await container
            .read(settingsExportImportProvider)
            .buildBundle();
        expect(bundle.needsSecretsPassphrase, isTrue);
        expect(bundle.firefly?.serverUrl, 'https://firefly.example');
        expect(bundle.firefly?.apiToken, 'ff-token-secret');
        expect(bundle.firefly?.allowInsecure, isTrue);
        expect(bundle.people.requirePasswordLogin, isTrue);
        expect(bundle.people.people.single.passwordHash, 'portable-hash');
        expect(bundle.people.people.single.salt, 'portable-salt');
      },
    );

    test('buildBundle clears passwords when peopleAuth is missing', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state/backup-secrets')) {
            return http.Response(
              jsonEncode({
                'ok': true,
                'firefly': {
                  'url': 'https://firefly.example',
                  'token': 'ff-token-secret',
                },
                'requirePasswordLogin': false,
                'peopleAuth': 'not-a-map',
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(jsonEncode(serverState()), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);
      await container
          .read(peopleProvider.notifier)
          .syncFromServerStore(loggedInPersonId: 'admin_1');

      final bundle = await container
          .read(settingsExportImportProvider)
          .buildBundle();
      expect(bundle.people.people.single.hasPassword, isFalse);
      expect(bundle.people.requirePasswordLogin, isFalse);
    });

    test('buildBundle accepts passwordSalt and drops placeholders', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state/backup-secrets')) {
            return http.Response(
              jsonEncode({
                'ok': true,
                'firefly': {'url': '', 'token': ''},
                'requirePasswordLogin': true,
                'peopleAuth': {
                  'admin_1': {
                    'passwordHash': 'portable-hash',
                    'passwordSalt': 'portable-salt',
                  },
                  'other': {'passwordHash': 'server', 'salt': 'server'},
                  'missing': 'not-a-map',
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(
              jsonEncode({
                ...serverState(),
                'people': [
                  ...serverState()['people'] as List,
                  {
                    'id': 'other',
                    'name': 'Other',
                    'role': 'user',
                    'hasPassword': true,
                    'createdAt': '2026-08-01T00:00:00.000Z',
                  },
                  {
                    'id': 'missing',
                    'name': 'Missing',
                    'role': 'user',
                    'hasPassword': false,
                    'createdAt': '2026-08-01T00:00:00.000Z',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);
      await container
          .read(peopleProvider.notifier)
          .syncFromServerStore(loggedInPersonId: 'admin_1');

      final bundle = await container
          .read(settingsExportImportProvider)
          .buildBundle();
      expect(bundle.firefly, isNull);
      final byId = {for (final p in bundle.people.people) p.id: p};
      expect(byId['admin_1']?.passwordHash, 'portable-hash');
      expect(byId['admin_1']?.salt, 'portable-salt');
      expect(byId['other']?.hasPassword, isFalse);
      expect(byId['missing']?.hasPassword, isFalse);
    });

    test('buildBundle ignores backup-secrets fetch failures', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state/backup-secrets')) {
            return http.Response(jsonEncode({'error': 'forbidden'}), 403);
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(jsonEncode(serverState()), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);

      final bundle = await container
          .read(settingsExportImportProvider)
          .buildBundle();
      expect(bundle.firefly, isNull);
      expect(bundle.needsSecretsPassphrase, isFalse);
    });

    test('applyBundle pushes Firefly PAT to the server', () async {
      SharedPreferences.setMockInitialValues({});
      Map<String, dynamic>? putFireflyBody;
      Map<String, dynamic>? putPeopleBody;
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(jsonEncode(serverState()), 200);
          }
          if (request.url.path.endsWith('/api/state/firefly')) {
            putFireflyBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(jsonEncode({'ok': true}), 200);
          }
          if (request.url.path.endsWith('/api/state/people')) {
            putPeopleBody = jsonDecode(request.body) as Map<String, dynamic>;
            final people = (putPeopleBody!['people'] as List)
                .cast<Map<String, dynamic>>();
            return http.Response(
              jsonEncode({
                ...serverState(),
                'people': people
                    .map(
                      (p) => {
                        ...p,
                        'hasPassword': true,
                        'createdAt':
                            p['createdAt'] ?? '2026-08-01T00:00:00.000Z',
                      },
                    )
                    .toList(),
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);

      final hashed = await hashTestPassword('Correct-Horse9!');
      await container
          .read(settingsExportImportProvider)
          .applyBundle(
            SettingsBundle(
              schemaVersion: kSettingsBundleSchemaVersion,
              exportedAtIso: '2026-08-04T00:00:00.000Z',
              device: const {},
              people: SettingsPeopleBundle(
                people: [
                  Person(
                    id: 'admin_1',
                    name: 'Alex',
                    colorValue: 0xFF1565C0,
                    role: PersonRole.admin,
                    passwordHash: hashed.hash,
                    salt: hashed.salt,
                    createdAtIso: '2026-08-01T00:00:00.000Z',
                  ),
                ],
                requirePasswordLogin: true,
              ),
              firefly: const SettingsFireflyBundle(
                serverUrl: 'https://imported.example',
                apiToken: 'imported-token',
                allowInsecure: true,
              ),
            ),
          );

      expect(putFireflyBody?['url'], 'https://imported.example');
      expect(putFireflyBody?['token'], 'imported-token');
      expect(putFireflyBody?['allowInsecure'], isTrue);
      expect(putPeopleBody?['authImports'], isA<Map<String, dynamic>>());
      final authImports = putPeopleBody!['authImports'] as Map<String, dynamic>;
      expect(authImports['admin_1'], isA<Map<String, dynamic>>());
    });
  });
}
