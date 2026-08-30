import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fireraccoon/deployment/deployment_providers.dart';
import 'package:fireraccoon/deployment/fireraccoon_mode.dart';
import 'package:fireraccoon/providers/locale_provider.dart';
import 'package:fireraccoon/providers/prognosis_settings_provider.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/server_session_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/providers/transaction_page_size_provider.dart';
import 'package:fireraccoon/providers/undo_history_provider.dart';
import 'package:fireraccoon/fun_modes/fun_mode.dart';
import 'package:fireraccoon/store/remote_server_client.dart';
import 'package:fireraccoon/theme/app_colors.dart';
import 'package:fireraccoon/theme/theme_palette.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../helpers/mock_firefly_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Map<String, String> secureStorage;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('undo-history-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return tempDir.path;
          }
          return null;
        });
    secureStorage = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureStorage,
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

  Future<ProviderContainer> createContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  File historyFile() => File('${tempDir.path}/undo_history_v1.json');

  Future<UndoHistoryState> waitHydrated(ProviderContainer container) async {
    var state = container.read(undoHistoryProvider);
    for (var i = 0; i < 50 && !state.isHydrated; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      state = container.read(undoHistoryProvider);
    }
    return state;
  }

  test(
    'a container disposed mid-hydration is left alone, not written to',
    () async {
      // Reading the history file spans several async gaps. Whoever asked for the
      // notifier can be gone by the end of any of them, and touching state then
      // throws "Ref used after dispose" out of a future nobody is awaiting, which
      // surfaces as an unrelated test failing under load.
      await historyFile().writeAsString(
        jsonEncode({
          'cursor': 0,
          'entries': [
            {
              'id': 'e1',
              'label': 'Created a transaction',
              'kind': 'createTransaction',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'payload': <String, Object?>{},
            },
          ],
        }),
      );

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      // Start hydration, then pull the container out from under it.
      container.read(undoHistoryProvider);
      container.dispose();

      // Long enough for every gap in the read to complete.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    },
  );

  test('normalizeUndoHistoryLimit clamps to bounds', () {
    expect(normalizeUndoHistoryLimit(1), kUndoHistoryMinLimit);
    expect(normalizeUndoHistoryLimit(999999), kUndoHistoryMaxLimit);
  });

  test('UndoEntry serialization and invalid payload handling', () {
    final entry = UndoEntry(
      id: '1',
      timestampUtc: DateTime.utc(2026, 1, 1),
      title: 'Title',
      details: 'Details',
      type: UndoActionType.themeMode,
      undoPayload: const {'mode': 'light'},
      redoPayload: const {'mode': 'dark'},
    );
    final restored = UndoEntry.fromJson(entry.toJson());
    expect(restored, isNotNull);
    expect(restored!.type, UndoActionType.themeMode);

    expect(UndoEntry.fromJson(const {'id': 'missing-fields'}), isNull);
  });

  test('hydrates empty state when no file exists', () async {
    final container = await createContainer();
    final state = await waitHydrated(container);

    expect(state.entries, isEmpty);
    expect(state.isHydrated, isTrue);
  });

  group('server mode hydrate and persist', () {
    Future<ProviderContainer> createServerContainer({
      required RemoteServerClient client,
    }) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deploymentConfigProvider.overrideWithValue(
            const DeploymentConfig(
              mode: FireraccoonMode.server,
              apiBase: 'http://example.test',
            ),
          ),
          authProvider.overrideWith(
            () => AuthNotifier(storage: const FlutterSecureStorage()),
          ),
          serverSessionProvider.overrideWith(
            () => ServerSessionNotifier(
              storage: const FlutterSecureStorage(),
              clientFactory: (_) => client,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Force server session build so UndoHistory can read `.client`.
      await container.read(serverSessionProvider.future);
      return container;
    }

    test('hydrates from server undo snapshot', () async {
      final entry = UndoEntry(
        id: 'srv-1',
        timestampUtc: DateTime.utc(2026, 2, 1),
        title: 'Server theme',
        details: 'details',
        type: UndoActionType.themeMode,
        undoPayload: const {'mode': 'light'},
        redoPayload: const {'mode': 'dark'},
      );
      final client = RemoteServerClient(
        baseUrl: 'http://example.test',
        sessionToken: 'sess',
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
            return http.Response(
              jsonEncode({
                'undo': {
                  'cursor': 0,
                  'entries': [entry.toJson()],
                },
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );

      final container = await createServerContainer(client: client);
      final state = await waitHydrated(container);
      expect(state.entries, hasLength(1));
      expect(state.entries.single.id, 'srv-1');
      expect(state.isHydrated, isTrue);
    });

    test('hydrates empty when undo payload missing or fetch fails', () async {
      var calls = 0;
      final client = RemoteServerClient(
        baseUrl: 'http://example.test',
        sessionToken: 'sess',
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
            calls++;
            if (calls == 1) {
              return http.Response(jsonEncode({'undo': null}), 200);
            }
            return http.Response('nope', 500);
          }
          return http.Response('{}', 200);
        }),
      );

      final first = await createServerContainer(client: client);
      final emptyUndo = await waitHydrated(first);
      expect(emptyUndo.entries, isEmpty);
      expect(emptyUndo.isHydrated, isTrue);

      // Second container with a client that fails fetchState.
      final failing = RemoteServerClient(
        baseUrl: 'http://example.test',
        sessionToken: 'sess',
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
          return http.Response(jsonEncode({'error': 'no'}), 500);
        }),
      );
      final second = await createServerContainer(client: failing);
      final failed = await waitHydrated(second);
      expect(failed.isHydrated, isTrue);
    });

    test('hydrates using index when cursor is absent', () async {
      final entry = UndoEntry(
        id: 'idx-1',
        timestampUtc: DateTime.utc(2026, 3, 1),
        title: 'Indexed',
        details: 'd',
        type: UndoActionType.themeMode,
        undoPayload: const {'mode': 'light'},
        redoPayload: const {'mode': 'dark'},
      );
      final client = RemoteServerClient(
        baseUrl: 'http://example.test',
        sessionToken: 'sess',
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
            return http.Response(
              jsonEncode({
                'undo': {
                  'index': 0,
                  'entries': [entry.toJson()],
                },
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      final container = await createServerContainer(client: client);
      final state = await waitHydrated(container);
      expect(state.cursor, 0);
      expect(state.entries.single.id, 'idx-1');
    });

    test('persists undo payload to server on record', () async {
      final putBodies = <String>[];
      final client = RemoteServerClient(
        baseUrl: 'http://example.test',
        sessionToken: 'sess',
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
            return http.Response(
              jsonEncode({
                'undo': {'cursor': -1, 'entries': []},
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state/undo')) {
            putBodies.add(request.body);
            return http.Response(jsonEncode({'ok': true}), 200);
          }
          return http.Response('{}', 200);
        }),
      );

      final container = await createServerContainer(client: client);
      await waitHydrated(container);
      container
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Theme',
            details: 'light → dark',
            type: UndoActionType.themeMode,
            undoPayload: const {'mode': 'light'},
            redoPayload: const {'mode': 'dark'},
          );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(putBodies, isNotEmpty);
      final decoded = jsonDecode(putBodies.last) as Map<String, dynamic>;
      expect(decoded['entries'], isA<List>());
    });

    test('survives putUndo failure without dropping memory state', () async {
      final client = RemoteServerClient(
        baseUrl: 'http://example.test',
        sessionToken: 'sess',
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
            return http.Response(
              jsonEncode({
                'undo': {'cursor': -1, 'entries': []},
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state/undo')) {
            return http.Response(jsonEncode({'error': 'boom'}), 500);
          }
          return http.Response('{}', 200);
        }),
      );

      final container = await createServerContainer(client: client);
      await waitHydrated(container);
      container
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Theme',
            details: 'light → dark',
            type: UndoActionType.themeMode,
            undoPayload: const {'mode': 'light'},
            redoPayload: const {'mode': 'dark'},
          );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final state = container.read(undoHistoryProvider);
      expect(state.entries, isNotEmpty);
    });
  });

  test('hydrates empty state when file contains empty content', () async {
    await historyFile().writeAsString('', flush: true);
    final container = await createContainer();
    final state = await waitHydrated(container);
    expect(state.entries, isEmpty);
    expect(state.isHydrated, isTrue);
  });

  test('hydrates empty state when file contains non-map json', () async {
    await historyFile().writeAsString(jsonEncode(['x']), flush: true);
    final container = await createContainer();
    final state = await waitHydrated(container);
    expect(state.entries, isEmpty);
    expect(state.isHydrated, isTrue);
  });

  test('hydrates empty state when file has invalid json', () async {
    await historyFile().writeAsString('not-json', flush: true);
    final container = await createContainer();
    final state = await waitHydrated(container);
    expect(state.entries, isEmpty);
    expect(state.isHydrated, isTrue);
  });

  test('hydrate trims entries to configured limit and clamps cursor', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('undoHistoryLimit', 10);

    final entries = List.generate(
      12,
      (i) => UndoEntry(
        id: '$i',
        timestampUtc: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
        title: 't$i',
        details: 'd$i',
        type: UndoActionType.themeMode,
        undoPayload: const {'mode': 'light'},
        redoPayload: const {'mode': 'dark'},
      ).toJson(),
    );
    await historyFile().writeAsString(
      jsonEncode({'cursor': 99, 'entries': entries}),
      flush: true,
    );

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    UndoHistoryState state = await waitHydrated(container);
    for (var i = 0; i < 20 && state.entries.length != 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      state = container.read(undoHistoryProvider);
    }
    expect(state.limit, 10);
    expect(state.entries.length, 10);
    expect(state.cursor, 9);
  });

  test('record, undo and redo theme mode action', () async {
    final container = await createContainer();
    final notifier = container.read(undoHistoryProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    notifier.record(
      title: 'Theme mode',
      details: 'Switch to dark',
      type: UndoActionType.themeMode,
      undoPayload: const {'mode': 'light'},
      redoPayload: const {'mode': 'dark'},
    );

    expect(container.read(undoHistoryProvider).canUndo, isTrue);
    await notifier.undo();
    expect(container.read(themeProvider).themeMode.name, 'light');
    expect(container.read(undoHistoryProvider).canRedo, isTrue);

    await notifier.redo();
    expect(container.read(themeProvider).themeMode.name, 'dark');
  });

  test('undo applies locale, view mode and transaction page size', () async {
    final container = await createContainer();
    final notifier = container.read(undoHistoryProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    notifier.record(
      title: 'Locale',
      details: 'Change locale',
      type: UndoActionType.locale,
      undoPayload: const {'locale': 'fr'},
      redoPayload: const {'locale': 'en'},
    );
    notifier.record(
      title: 'View mode',
      details: 'Compact',
      type: UndoActionType.viewMode,
      undoPayload: const {'viewMode': 'compact'},
      redoPayload: const {'viewMode': 'standard'},
    );
    notifier.record(
      title: 'Page size',
      details: 'Bigger page',
      type: UndoActionType.transactionPageSize,
      undoPayload: const {'pageSize': 120},
      redoPayload: const {'pageSize': 50},
    );

    await notifier.undo();
    expect(container.read(transactionPageSizeProvider), 120);
    await notifier.undo();
    // ViewMode notifier loads persisted state asynchronously; here we verify undo
    // flow can apply the payload without breaking history replay.
    expect(container.read(undoHistoryProvider).cursor, 0);
    await notifier.undo();
    expect(container.read(localeProvider).languageCode, 'fr');
  });

  test('undo applies prognosis settings actions and clear history', () async {
    final container = await createContainer();
    final notifier = container.read(undoHistoryProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    notifier.record(
      title: 'Prognosis mode',
      details: 'Projected',
      type: UndoActionType.prognosisMode,
      undoPayload: const {'mode': 'projected'},
      redoPayload: const {'mode': 'expected'},
    );
    notifier.record(
      title: 'Prognosis horizon',
      details: 'Month',
      type: UndoActionType.prognosisHorizon,
      undoPayload: const {'horizon': 'endOfMonth'},
      redoPayload: const {'horizon': 'endOfNextMonth'},
    );
    notifier.record(
      title: 'Prognosis inclusion',
      details: 'Disable expenses',
      type: UndoActionType.prognosisInclusion,
      undoPayload: const {'includeExpenses': false},
      redoPayload: const {'includeExpenses': true},
    );
    notifier.record(
      title: 'Prognosis margin',
      details: '25%',
      type: UndoActionType.prognosisMarginPercent,
      undoPayload: const {'marginPercent': 25},
      redoPayload: const {'marginPercent': 15},
    );

    await notifier.undo();
    await notifier.undo();
    await notifier.undo();
    await notifier.undo();

    final settings = container.read(prognosisSettingsProvider);
    expect(settings.mode, PrognosisViewMode.projected);
    expect(settings.horizon, PrognosisHorizon.endOfMonth);
    expect(settings.inclusion.includeExpenses, isFalse);
    expect(settings.marginPercent, 25);

    await notifier.clearHistory();
    final state = container.read(undoHistoryProvider);
    expect(state.entries, isEmpty);
    expect(state.cursor, -1);
  });

  test('setLimit trims entries and persists history file', () async {
    final container = await createContainer();
    final notifier = container.read(undoHistoryProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    for (var i = 0; i < 15; i++) {
      notifier.record(
        title: 'Entry $i',
        details: 'd',
        type: UndoActionType.themeAccent,
        undoPayload: {'accent': AccentColorType.blue.name},
        redoPayload: {'accent': AccentColorType.green.name},
      );
    }

    await notifier.setLimit(10);
    final state = container.read(undoHistoryProvider);
    expect(state.limit, 10);
    expect(state.entries.length, lessThanOrEqualTo(10));
    expect(state.cursor, state.entries.length - 1);

    final file = File('${tempDir.path}/undo_history_v1.json');
    expect(await file.exists(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final raw = await file.readAsString();
    expect(raw, contains('"entries"'));
  });

  test('record trims when entry count exceeds limit', () async {
    final container = await createContainer();
    final notifier = container.read(undoHistoryProvider.notifier);
    await waitHydrated(container);
    await notifier.setLimit(10);

    for (var i = 0; i < 12; i++) {
      notifier.record(
        title: 'Trim $i',
        details: 'd',
        type: UndoActionType.themeMode,
        undoPayload: const {'mode': 'light'},
        redoPayload: const {'mode': 'dark'},
      );
    }

    final state = container.read(undoHistoryProvider);
    expect(state.entries.length, 10);
    expect(state.cursor, 9);
  });

  test('theme palette/fun mode undo payloads are applied', () async {
    final container = await createContainer();
    final notifier = container.read(undoHistoryProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    notifier.record(
      title: 'Palette',
      details: 'Raccoon',
      type: UndoActionType.themePalette,
      undoPayload: {'palette': ThemePaletteType.raccoon.name},
      redoPayload: {'palette': ThemePaletteType.classic.name},
    );
    notifier.record(
      title: 'Fun mode',
      details: 'Birthday',
      type: UndoActionType.themeFunMode,
      undoPayload: {'funMode': FunMode.birthday.name},
      redoPayload: {'funMode': FunMode.none.name},
    );

    await notifier.undo();
    await notifier.undo();

    final theme = container.read(themeProvider);
    expect(theme.paletteType, ThemePaletteType.raccoon);
    expect(theme.funMode, FunMode.birthday);
  });

  test('domain action undo types are no-op but replay succeeds', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiServiceProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(undoHistoryProvider.notifier);
    await waitHydrated(container);

    notifier.record(
      title: 'Account create',
      details: 'placeholder',
      type: UndoActionType.accountCreate,
      undoPayload: const {},
      redoPayload: const {},
    );

    final before = container.read(undoHistoryProvider).cursor;
    await notifier.undo();
    final after = container.read(undoHistoryProvider).cursor;
    expect(after, before - 1);
  });

  test('entity undo/redo actions call service operations', () async {
    final prefs = await SharedPreferences.getInstance();
    final fake = _RecordingFireflyService();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(undoHistoryProvider.notifier);
    await waitHydrated(container);

    Future<void> apply(
      UndoActionType type,
      Map<String, Object?> undoPayload,
      Map<String, Object?> redoPayload,
    ) async {
      notifier.record(
        title: type.name,
        details: 'd',
        type: type,
        undoPayload: undoPayload,
        redoPayload: redoPayload,
      );
      await notifier.undo();
      await notifier.redo();
    }

    await apply(
      UndoActionType.accountCreate,
      {'accountId': 'a1'},
      {'name': 'Checking', 'type': 'asset', 'currencyCode': 'EUR'},
    );
    await apply(
      UndoActionType.accountUpdate,
      {'accountId': 'a1', 'name': 'Renamed'},
      {'accountId': 'a1', 'name': 'Again'},
    );
    await apply(
      UndoActionType.accountDelete,
      {'name': 'Restored', 'type': 'asset', 'currencyCode': 'EUR'},
      {'accountId': 'a1'},
    );
    await apply(
      UndoActionType.budgetCreate,
      {'budgetId': 'b1'},
      {'name': 'Food', 'amount': 100.0, 'currencyCode': 'EUR'},
    );
    await apply(
      UndoActionType.budgetUpdate,
      {'budgetId': 'b1', 'name': 'Food+', 'amount': 120.0},
      {'budgetId': 'b1', 'name': 'Food++', 'amount': 140.0},
    );
    await apply(
      UndoActionType.budgetDelete,
      {'name': 'Recreated', 'amount': 90.0, 'currencyCode': 'EUR'},
      {'budgetId': 'b1'},
    );
    await apply(UndoActionType.transactionCreate, {
      'transactionId': 't1',
    }, _txPayload());
    await apply(
      UndoActionType.transactionUpdate,
      _txPayload(id: 't2'),
      _txPayload(id: 't2', amount: 11),
    );
    await apply(UndoActionType.transactionDelete, _txPayload(id: 't3'), {
      'transactionId': 't3',
    });
    await apply(UndoActionType.billCreate, {'billId': 'bill1'}, _billPayload());
    await apply(
      UndoActionType.billUpdate,
      {'billId': 'bill1', ..._billPayload(name: 'Rent+')},
      {'billId': 'bill1', ..._billPayload(name: 'Rent++')},
    );
    await apply(UndoActionType.billDelete, _billPayload(name: 'Recreate'), {
      'billId': 'bill1',
    });
    await apply(UndoActionType.recurrenceCreate, {
      'recurrenceId': 'r1',
    }, _recurrencePayload());
    await apply(
      UndoActionType.recurrenceUpdate,
      {'recurrenceId': 'r1', ..._recurrencePayload(title: 'Gym+')},
      {'recurrenceId': 'r1', ..._recurrencePayload(title: 'Gym++')},
    );
    await apply(
      UndoActionType.recurrenceDelete,
      _recurrencePayload(title: 'Recreate'),
      {'recurrenceId': 'r1'},
    );
    await apply(UndoActionType.piggyBankCreate, {
      'piggyBankId': 'p1',
    }, _piggyPayload());
    await apply(
      UndoActionType.piggyBankUpdate,
      {'piggyBankId': 'p1', ..._piggyPayload(name: 'Trip+')},
      {'piggyBankId': 'p1', ..._piggyPayload(name: 'Trip++')},
    );
    await apply(
      UndoActionType.piggyBankDelete,
      _piggyPayload(name: 'Recreate'),
      {'piggyBankId': 'p1'},
    );
    await apply(UndoActionType.liabilityCreate, {
      'accountId': 'l1',
    }, _liabilityPayload());

    expect(fake.deleteAccountCalls, greaterThanOrEqualTo(3));
    expect(fake.createAccountCalls, greaterThanOrEqualTo(1));
    expect(fake.createBudgetCalls, greaterThanOrEqualTo(2));
    expect(fake.updateBudgetCalls, greaterThanOrEqualTo(1));
    expect(fake.createTransactionCalls, greaterThanOrEqualTo(2));
    expect(fake.deleteTransactionCalls, greaterThanOrEqualTo(1));
    expect(fake.createBillCalls, greaterThanOrEqualTo(2));
    expect(fake.updateBillCalls, greaterThanOrEqualTo(1));
    expect(fake.createRecurrenceCalls, greaterThanOrEqualTo(2));
    expect(fake.updateRecurrenceCalls, greaterThanOrEqualTo(1));
    expect(fake.createPiggyBankCalls, greaterThanOrEqualTo(2));
    expect(fake.updatePiggyBankCalls, greaterThanOrEqualTo(1));
    expect(fake.createLiabilityCalls, greaterThanOrEqualTo(1));
  });

  test('fallback enum/date parsing paths apply safe defaults', () async {
    final prefs = await SharedPreferences.getInstance();
    final fake = _RecordingFireflyService();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(undoHistoryProvider.notifier);
    await waitHydrated(container);

    notifier.record(
      title: 'theme fallback',
      details: 'd',
      type: UndoActionType.themeMode,
      undoPayload: const {'mode': 'invalid'},
      redoPayload: const {'mode': 'invalid'},
    );
    notifier.record(
      title: 'palette fallback',
      details: 'd',
      type: UndoActionType.themePalette,
      undoPayload: const {'palette': 'invalid'},
      redoPayload: const {'palette': 'invalid'},
    );
    notifier.record(
      title: 'accent fallback',
      details: 'd',
      type: UndoActionType.themeAccent,
      undoPayload: const {'accent': 'invalid'},
      redoPayload: const {'accent': 'invalid'},
    );
    notifier.record(
      title: 'fun fallback',
      details: 'd',
      type: UndoActionType.themeFunMode,
      undoPayload: const {'funMode': 'invalid'},
      redoPayload: const {'funMode': 'invalid'},
    );
    notifier.record(
      title: 'view fallback',
      details: 'd',
      type: UndoActionType.viewMode,
      undoPayload: const {'viewMode': 'invalid'},
      redoPayload: const {'viewMode': 'invalid'},
    );
    notifier.record(
      title: 'horizon fallback',
      details: 'd',
      type: UndoActionType.prognosisHorizon,
      undoPayload: const {'horizon': 'invalid'},
      redoPayload: const {'horizon': 'invalid'},
    );
    notifier.record(
      title: 'bill enum/date fallback',
      details: 'd',
      type: UndoActionType.billCreate,
      undoPayload: const {'billId': 'existing'},
      redoPayload: {
        ..._billPayload(name: 'Fallback'),
        'repeatFrequency': 'invalid',
        'endDate': 'invalid',
        'extensionDate': 'invalid',
      },
    );
    notifier.record(
      title: 'recurrence enum fallback',
      details: 'd',
      type: UndoActionType.recurrenceCreate,
      undoPayload: const {'recurrenceId': 'existing'},
      redoPayload: {
        ..._recurrencePayload(title: 'Fallback'),
        'type': 'invalid',
        'repetitionType': 'invalid',
        'weekendMode': 'invalid',
      },
    );
    notifier.record(
      title: 'liability enum fallback',
      details: 'd',
      type: UndoActionType.liabilityCreate,
      undoPayload: const {'accountId': 'existing'},
      redoPayload: {
        ..._liabilityPayload(),
        'liabilityType': 'invalid',
        'liabilityDirection': 'invalid',
        'startDate': 'invalid',
      },
    );

    for (var i = 0; i < 9; i++) {
      await notifier.undo();
    }
    for (var i = 0; i < 9; i++) {
      await notifier.redo();
    }

    expect(fake.createBillCalls, greaterThanOrEqualTo(1));
    expect(fake.createRecurrenceCalls, greaterThanOrEqualTo(1));
    expect(fake.createLiabilityCalls, greaterThanOrEqualTo(1));
  });

  test('invalid prognosis/transaction payloads are ignored safely', () async {
    final prefs = await SharedPreferences.getInstance();
    final fake = _RecordingFireflyService();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(undoHistoryProvider.notifier);
    await waitHydrated(container);

    notifier.record(
      title: 'invalid prognosis mode',
      details: 'd',
      type: UndoActionType.prognosisMode,
      undoPayload: const {'mode': 'invalid'},
      redoPayload: const {'mode': 'invalid'},
    );
    notifier.record(
      title: 'invalid tx payload',
      details: 'd',
      type: UndoActionType.transactionUpdate,
      undoPayload: const {'description': 'missing type+amount'},
      redoPayload: const {'description': 'missing type+amount'},
    );

    await notifier.undo();
    await notifier.undo();

    final settings = container.read(prognosisSettingsProvider);
    expect(settings.mode, PrognosisViewMode.expected);
    expect(fake.updateTransactionCalls, 0);
  });
}

Map<String, Object?> _txPayload({String id = '', double amount = 10}) => {
  'id': id,
  'type': 'withdrawal',
  'date': '2026-01-01',
  'amount': amount,
  'description': 'Coffee',
  'sourceName': 'Checking',
  'destinationName': 'Cafe',
  'categoryName': 'Food',
  'currencySymbol': '€',
  'currencyCode': 'EUR',
};

Map<String, Object?> _billPayload({String name = 'Rent'}) => {
  'name': name,
  'amountMin': 100,
  'amountMax': 120,
  'currencyCode': 'EUR',
  'date': '2026-01-01',
  'repeatFrequency': BillRepeatFrequency.monthly.name,
};

Map<String, Object?> _recurrencePayload({String title = 'Gym'}) => {
  'title': title,
  'type': RecurrenceTransactionType.withdrawal.name,
  'repetitionType': RecurrenceRepetitionType.monthly.name,
  'weekendMode': RecurrenceWeekendMode.createAnyway.name,
  'sourceId': '1',
  'destinationId': '2',
  'amount': 50,
  'currencyCode': 'EUR',
  'transactionDescription': 'Gym membership',
  'moment': '1',
};

Map<String, Object?> _piggyPayload({String name = 'Trip'}) => {
  'name': name,
  'targetAmount': 500,
  'currencyCode': 'EUR',
  'accountIds': const ['1'],
  'startDate': '2026-01-01',
};

Map<String, Object?> _liabilityPayload() => {
  'name': 'Credit Card',
  'currencyCode': 'EUR',
  'liabilityType': LiabilityType.debt.name,
  'liabilityDirection': LiabilityDirection.credit.name,
};

class _RecordingFireflyService extends FakeFireflyService {
  int createAccountCalls = 0;
  int deleteAccountCalls = 0;
  int updateAccountCalls = 0;
  int createBudgetCalls = 0;
  int updateBudgetCalls = 0;
  int deleteBudgetCalls = 0;
  int createTransactionCalls = 0;
  int updateTransactionCalls = 0;
  int deleteTransactionCalls = 0;
  int createBillCalls = 0;
  int updateBillCalls = 0;
  int deleteBillCalls = 0;
  int createRecurrenceCalls = 0;
  int updateRecurrenceCalls = 0;
  int deleteRecurrenceCalls = 0;
  int createPiggyBankCalls = 0;
  int updatePiggyBankCalls = 0;
  int deletePiggyBankCalls = 0;
  int createLiabilityCalls = 0;

  @override
  Future<Account> createAccount({
    required String name,
    required String type,
    required String currencyCode,
    String? role,
  }) async {
    createAccountCalls++;
    return super.createAccount(
      name: name,
      type: type,
      currencyCode: currencyCode,
    );
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    deleteAccountCalls++;
    return super.deleteAccount(accountId);
  }

  @override
  Future<void> updateAccount(
    String accountId, {
    String? name,
    String? type,
    String? iban,
    String? bic,
    String? accountNumber,
    String? notes,
    bool? active,
    String? role,
    String? currencyCode,
    String? liabilityType,
    String? liabilityDirection,
    bool? includeNetWorth,
    double? openingBalance,
    DateTime? openingBalanceDate,
    double? virtualBalance,
    double? interest,
    String? interestPeriod,
  }) async {
    updateAccountCalls++;
    return super.updateAccount(
      accountId,
      name: name,
      type: type,
      iban: iban,
      bic: bic,
      accountNumber: accountNumber,
      notes: notes,
      active: active,
      role: role,
      currencyCode: currencyCode,
      liabilityType: liabilityType,
      liabilityDirection: liabilityDirection,
      includeNetWorth: includeNetWorth,
      openingBalance: openingBalance,
      openingBalanceDate: openingBalanceDate,
      virtualBalance: virtualBalance,
      interest: interest,
      interestPeriod: interestPeriod,
    );
  }

  @override
  Future<Budget> createBudget(BudgetInput input) async {
    createBudgetCalls++;
    return super.createBudget(input);
  }

  @override
  Future<void> updateBudget(String budgetId, BudgetInput input) async {
    updateBudgetCalls++;
    return super.updateBudget(budgetId, input);
  }

  @override
  Future<void> deleteBudget(String budgetId) async {
    deleteBudgetCalls++;
    return super.deleteBudget(budgetId);
  }

  @override
  Future<Transaction> createTransaction(Transaction transaction) async {
    createTransactionCalls++;
    return super.createTransaction(transaction);
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    updateTransactionCalls++;
    return super.updateTransaction(transaction);
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    deleteTransactionCalls++;
    return super.deleteTransaction(transactionId);
  }

  @override
  Future<Bill> createBill(BillInput input) async {
    createBillCalls++;
    return super.createBill(input);
  }

  @override
  Future<Bill> updateBill(String billId, BillInput input) async {
    updateBillCalls++;
    return super.updateBill(billId, input);
  }

  @override
  Future<void> deleteBill(String billId) async {
    deleteBillCalls++;
    return super.deleteBill(billId);
  }

  @override
  Future<Recurrence> createRecurrence(RecurrenceInput input) async {
    createRecurrenceCalls++;
    return super.createRecurrence(input);
  }

  @override
  Future<Recurrence> updateRecurrence(
    String recurrenceId,
    RecurrenceInput input, {
    Recurrence? current,
  }) async {
    updateRecurrenceCalls++;
    return super.updateRecurrence(recurrenceId, input, current: current);
  }

  @override
  Future<void> deleteRecurrence(String recurrenceId) async {
    deleteRecurrenceCalls++;
    return super.deleteRecurrence(recurrenceId);
  }

  @override
  Future<PiggyBank> createPiggyBank(PiggyBankInput input) async {
    createPiggyBankCalls++;
    return super.createPiggyBank(input);
  }

  @override
  Future<PiggyBank> updatePiggyBank(
    String piggyBankId,
    PiggyBankInput input,
  ) async {
    updatePiggyBankCalls++;
    return super.updatePiggyBank(piggyBankId, input);
  }

  @override
  Future<void> deletePiggyBank(String piggyBankId) async {
    deletePiggyBankCalls++;
    return super.deletePiggyBank(piggyBankId);
  }

  @override
  Future<Account> createLiability(LiabilityInput input) async {
    createLiabilityCalls++;
    return super.createLiability(input);
  }
}
