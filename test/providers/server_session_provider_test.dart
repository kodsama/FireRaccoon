import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fireracoon/deployment/deployment_providers.dart';
import 'package:fireracoon/deployment/fireracoon_mode.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/server_session_provider.dart';
import 'package:fireracoon/store/remote_server_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStorage;

  setUp(() {
    secureStorage = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureStorage,
    );
  });

  group('ServerSession', () {
    test('isAuthenticated requires token and person', () {
      expect(
        const ServerSession(token: '', proxyBase: '/x').isAuthenticated,
        isFalse,
      );
      expect(
        const ServerSession(
          token: 't',
          proxyBase: '/x',
          person: {'id': '1'},
        ).isAuthenticated,
        isTrue,
      );
    });
  });

  group('RemoteServerClient', () {
    test(
      'capabilities unlock setup login logout and firefly helpers',
      () async {
        final seen = <String>[];
        final client = RemoteServerClient(
          baseUrl: 'http://example.test/',
          httpClient: MockClient((request) async {
            seen.add('${request.method} ${request.url.path}');
            if (request.url.path.endsWith('/api/capabilities')) {
              return http.Response(
                jsonEncode({
                  'storeLocked': false,
                  'storeExists': true,
                  'setupRequired': false,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path.endsWith('/api/store/unlock')) {
              return http.Response(jsonEncode({'ok': true}), 200);
            }
            if (request.url.path.endsWith('/api/setup')) {
              return http.Response(
                jsonEncode({
                  'ok': true,
                  'sessionToken': 'sess-1',
                  'person': {'id': 'a', 'name': 'Admin', 'role': 'admin'},
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/api/login')) {
              return http.Response(
                jsonEncode({
                  'ok': true,
                  'sessionToken': 'sess-2',
                  'person': {'id': 'a', 'name': 'Admin'},
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/api/logout')) {
              return http.Response(jsonEncode({'ok': true}), 200);
            }
            if (request.url.path.endsWith('/api/state')) {
              expect(request.headers['x-fireracoon-session'], 'sess-2');
              return http.Response(
                jsonEncode({
                  'ok': true,
                  'undo': {'entries': [], 'cursor': -1},
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/api/state/undo')) {
              return http.Response(jsonEncode({'ok': true}), 200);
            }
            if (request.url.path.endsWith('/api/state/firefly')) {
              return http.Response(jsonEncode({'ok': true}), 200);
            }
            if (request.url.path.endsWith('/api/state/people')) {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['people'], isA<List>());
              expect(body['requirePasswordLogin'], isTrue);
              expect(body['passwordUpdates'], isA<Map>());
              return http.Response(jsonEncode({'ok': true}), 200);
            }
            return http.Response('nope', 404);
          }),
        );

        final caps = await client.getCapabilities();
        expect(caps['storeExists'], isTrue);

        await client.unlockStore(
          password: 'abcdefghij',
          confirmPassword: 'abcdefghij',
        );
        final setup = await client.setup(
          adminName: 'Admin',
          adminPassword: 'Password1!',
          fireflyUrl: 'http://ff',
          fireflyToken: 'tok',
        );
        expect(client.sessionToken, 'sess-1');
        expect(setup['person'], isA<Map>());

        final login = await client.login(name: 'Admin', password: 'Password1!');
        expect(client.sessionToken, 'sess-2');
        expect(login['sessionToken'], 'sess-2');

        final state = await client.fetchState();
        expect(state['undo'], isA<Map>());
        await client.putUndo({'entries': [], 'cursor': -1});
        await client.putFirefly(url: 'http://ff', token: 'tok');
        final people = await client.putPeople(
          people: [
            {'id': 'a', 'name': 'Admin', 'role': 'admin'},
          ],
          accountOwnerships: {
            'acc-1': {
              'accountId': 'acc-1',
              'personShares': {'a': 1.0},
            },
          },
          requirePasswordLogin: true,
          passwordUpdates: {'a': 'Password1!'},
        );
        expect(people['ok'], isTrue);
        expect(client.fireflyProxyBase, 'http://example.test/api/firefly');
        await client.logout();
        expect(client.sessionToken, isNull);
        expect(seen, isNotEmpty);
      },
    );

    test('throws RemoteServerException with storeLocked body', () async {
      final client = RemoteServerClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'Encrypted store is locked',
              'code': 'store_locked',
              'storeLocked': true,
              'storeExists': true,
            }),
            503,
          ),
        ),
      );
      try {
        await client.fetchState();
        fail('expected exception');
      } on RemoteServerException catch (e) {
        expect(e.storeLocked, isTrue);
        expect(e.body['storeExists'], isTrue);
        expect(e.toString(), contains('locked'));
      }
    });

    test(
      'decode covers empty body non-map and default error message',
      () async {
        final empty = RemoteServerClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient((_) async => http.Response('', 200)),
        );
        expect(await empty.getCapabilities(), isEmpty);

        final nonMap = RemoteServerClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient((_) async => http.Response('[]', 200)),
        );
        expect(() => nonMap.getCapabilities(), throwsStateError);

        final noMessage = RemoteServerClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode({'ok': false}), 400),
          ),
        );
        try {
          await noMessage.getCapabilities();
          fail('expected');
        } on RemoteServerException catch (e) {
          expect(e.message, contains('400'));
        }
      },
    );
  });

  group('ServerSessionNotifier', () {
    ProviderContainer container({
      required RemoteServerClient Function(String base) factory,
      DeploymentConfig? deployment,
    }) {
      return ProviderContainer(
        overrides: [
          deploymentConfigProvider.overrideWithValue(
            deployment ??
                const DeploymentConfig(
                  mode: FireracoonMode.server,
                  apiBase: 'http://example.test',
                ),
          ),
          authProvider.overrideWith(
            () => AuthNotifier(storage: const FlutterSecureStorage()),
          ),
          serverSessionProvider.overrideWith(
            () => ServerSessionNotifier(
              storage: const FlutterSecureStorage(),
              clientFactory: factory,
            ),
          ),
        ],
      );
    }

    test('local mode returns null without calling backend', () async {
      var built = false;
      final c = container(
        deployment: const DeploymentConfig(mode: FireracoonMode.local),
        factory: (_) {
          built = true;
          return RemoteServerClient(baseUrl: 'http://x');
        },
      );
      addTearDown(c.dispose);
      final session = await c.read(serverSessionProvider.future);
      expect(session, isNull);
      expect(built, isFalse);
    });

    test('hydrates from capabilities when no saved session', () async {
      final c = container(
        factory: (_) => RemoteServerClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': true,
              }),
              200,
            ),
          ),
        ),
      );
      addTearDown(c.dispose);
      final session = await c.read(serverSessionProvider.future);
      expect(session?.setupRequired, isTrue);
      expect(session?.storeExists, isTrue);
      expect(session?.isAuthenticated, isFalse);
    });

    test(
      'uses Uri.base when apiBase empty and clears corrupt saved session',
      () async {
        secureStorage['serverSessionToken'] = 'saved';
        final c = ProviderContainer(
          overrides: [
            deploymentConfigProvider.overrideWithValue(
              const DeploymentConfig(mode: FireracoonMode.server),
            ),
            authProvider.overrideWith(
              () => AuthNotifier(storage: const FlutterSecureStorage()),
            ),
            serverSessionProvider.overrideWith(
              () => ServerSessionNotifier(
                storage: const FlutterSecureStorage(),
                clientFactory: (_) => RemoteServerClient(
                  baseUrl: 'http://example.test',
                  httpClient: MockClient((request) async {
                    if (request.url.path.endsWith('/api/state')) {
                      return http.Response('not-json', 200);
                    }
                    return http.Response(
                      jsonEncode({
                        'storeLocked': false,
                        'storeExists': true,
                        'setupRequired': false,
                      }),
                      200,
                    );
                  }),
                ),
              ),
            ),
          ],
        );
        addTearDown(c.dispose);
        final session = await c.read(serverSessionProvider.future);
        expect(secureStorage.containsKey('serverSessionToken'), isFalse);
        expect(session?.isAuthenticated, isFalse);
      },
    );

    test('restores saved session and applies auth', () async {
      secureStorage['serverSessionToken'] = 'saved';
      final c = container(
        factory: (_) => RemoteServerClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'setupRequired': false,
                'storeLocked': false,
                'storeExists': true,
                'me': {'id': '1', 'name': 'Alex', 'role': 'admin'},
              }),
              200,
            ),
          ),
        ),
      );
      addTearDown(c.dispose);
      final session = await c.read(serverSessionProvider.future);
      expect(session?.token, 'saved');
      expect(session?.isAuthenticated, isTrue);
      expect(c.read(authProvider).apiToken, 'saved');
    });

    test('clears saved session when store reports locked', () async {
      secureStorage['serverSessionToken'] = 'saved';
      final c = container(
        factory: (_) => RemoteServerClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'setupRequired': true,
                'storeLocked': true,
                'storeExists': true,
                'me': null,
              }),
              200,
            ),
          ),
        ),
      );
      addTearDown(c.dispose);
      final session = await c.read(serverSessionProvider.future);
      expect(session?.storeLocked, isTrue);
      expect(secureStorage.containsKey('serverSessionToken'), isFalse);
    });

    test('handles RemoteServerException store_locked on fetchState', () async {
      secureStorage['serverSessionToken'] = 'saved';
      final c = container(
        factory: (_) => RemoteServerClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': 'locked',
                'code': 'store_locked',
                'storeLocked': true,
                'storeExists': true,
                'setupRequired': true,
              }),
              503,
            ),
          ),
        ),
      );
      addTearDown(c.dispose);
      final session = await c.read(serverSessionProvider.future);
      expect(session?.storeLocked, isTrue);
      expect(session?.storeExists, isTrue);
    });

    test('setup login unlockStore and logout round-trip', () async {
      final c = container(
        factory: (_) => RemoteServerClient(
          baseUrl: 'http://example.test',
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
            if (request.url.path.endsWith('/api/store/unlock')) {
              return http.Response(jsonEncode({'ok': true}), 200);
            }
            if (request.url.path.endsWith('/api/setup') ||
                request.url.path.endsWith('/api/login')) {
              return http.Response(
                jsonEncode({
                  'sessionToken': 'tok',
                  'person': {'id': '1', 'name': 'A', 'role': 'admin'},
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/api/logout')) {
              return http.Response(jsonEncode({'ok': true}), 200);
            }
            return http.Response('{}', 200);
          }),
        ),
      );
      addTearDown(c.dispose);
      await c.read(serverSessionProvider.future);
      final notifier = c.read(serverSessionProvider.notifier);

      await notifier.unlockStore(password: 'abcdefghij');
      expect(c.read(serverSessionProvider).asData?.value?.storeLocked, isFalse);

      await notifier.setup(
        adminName: 'A',
        adminPassword: 'Password1!',
        fireflyUrl: 'http://ff',
        fireflyToken: 't',
      );
      expect(c.read(serverSessionProvider).asData?.value?.token, 'tok');
      expect(secureStorage['serverSessionToken'], 'tok');

      await notifier.login(name: 'A', password: 'Password1!');
      await notifier.logout();
      expect(c.read(serverSessionProvider).asData?.value, isNull);
      expect(secureStorage.containsKey('serverSessionToken'), isFalse);
    });

    test('methods throw when client missing', () async {
      final c = ProviderContainer(
        overrides: [
          deploymentConfigProvider.overrideWithValue(
            const DeploymentConfig(mode: FireracoonMode.local),
          ),
          serverSessionProvider.overrideWith(ServerSessionNotifier.new),
        ],
      );
      addTearDown(c.dispose);
      await c.read(serverSessionProvider.future);
      final n = c.read(serverSessionProvider.notifier);
      expect(() => n.unlockStore(password: 'abcdefghij'), throwsStateError);
      expect(
        () => n.setup(
          adminName: 'a',
          adminPassword: 'Password1!',
          fireflyUrl: 'u',
          fireflyToken: 't',
        ),
        throwsStateError,
      );
      expect(() => n.login(name: 'a', password: 'x'), throwsStateError);
    });
  });

  group('loadDeploymentConfig', () {
    test('reads server config.json', () async {
      final config = await loadDeploymentConfig(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'FIRERACOON_MODE': 'server', 'setupRequired': true}),
            200,
          ),
        ),
        configUri: Uri.parse('http://example.test/config.json'),
      );
      expect(config.isServer, isTrue);
      expect(config.setupRequired, isTrue);
      expect(config.apiBase, 'http://example.test');
    });

    test('falls back to local when request fails', () async {
      final config = await loadDeploymentConfig(
        client: MockClient((_) async => throw Exception('offline')),
        configUri: Uri.parse('http://example.test/config.json'),
      );
      expect(config.mode, FireracoonMode.local);
    });

    test('uses default client and closes it', () async {
      final config = await loadDeploymentConfig(
        configUri: Uri.parse('file:///tmp/config.json'),
      );
      expect(config.mode, FireracoonMode.local);
    });

    test('fireracoonModeProvider mirrors deployment config', () {
      final c = ProviderContainer(
        overrides: [
          deploymentConfigProvider.overrideWithValue(
            const DeploymentConfig(mode: FireracoonMode.server),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(fireracoonModeProvider), FireracoonMode.server);
    });
  });
}
