import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/cosmos_gate_provider.dart';
import 'package:fireraccoon/providers/cosmos_session_provider.dart';
import 'package:fireraccoon/store/cosmos_session.dart';
import 'package:fireraccoon/store/cosmos_session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/static_auth_notifier.dart';

/// Keeps the session in memory, so the notifier can be driven without a
/// keychain, and records what it was asked to do.
class _MemoryStore extends CosmosSessionStore {
  _MemoryStore({this.saved, this.failLoad = false}) : super(storage: null);

  CosmosSession? saved;
  final bool failLoad;
  var cleared = 0;

  @override
  Future<CosmosSession?> load() async {
    if (failLoad) throw StateError('store would not answer');
    return saved;
  }

  @override
  Future<void> save(CosmosSession session) async => saved = session;

  @override
  Future<void> clear() async {
    cleared++;
    saved = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
  });

  final session = CosmosSession(
    host: 'firefly.example',
    cookie: 'jwt-value',
    obtainedAt: DateTime.utc(2026, 9, 8),
  );

  ProviderContainer containerWith(_MemoryStore store) {
    final container = ProviderContainer(
      overrides: [cosmosSessionStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a stored session is restored', () async {
    final container = containerWith(_MemoryStore(saved: session));
    container.listen(cosmosSessionProvider, (_, _) {});

    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
      if (container.read(cosmosSessionProvider) != null) break;
    }

    expect(container.read(cosmosSessionProvider)!.host, 'firefly.example');
  });

  test('a store that will not answer leaves no session, not a crash', () async {
    final container = containerWith(_MemoryStore(failLoad: true));
    container.listen(cosmosSessionProvider, (_, _) {});

    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(container.read(cosmosSessionProvider), isNull);
  });

  test('signing in holds the session and writes it', () async {
    final store = _MemoryStore();
    final container = containerWith(store);
    container.listen(cosmosSessionProvider, (_, _) {});

    await container.read(cosmosSessionProvider.notifier).signedIn(session);

    expect(container.read(cosmosSessionProvider), session);
    expect(store.saved, session);
  });

  test('signing out drops it from both', () async {
    final store = _MemoryStore(saved: session);
    final container = containerWith(store);
    container.listen(cosmosSessionProvider, (_, _) {});

    await container.read(cosmosSessionProvider.notifier).signedOut();

    expect(container.read(cosmosSessionProvider), isNull);
    expect(store.cleared, 1);
  });

  test('the connection test carries the session', () async {
    // The test button is the one thing whose whole job is to say whether the
    // connection works. Without the cookie it kept getting Cosmos's sign-in
    // page and reporting "not the Firefly III API", however signed in you
    // were.
    final store = _MemoryStore(saved: session);
    String? sentCookie;
    final container = ProviderContainer(
      overrides: [
        cosmosSessionStoreProvider.overrideWithValue(store),
        authProvider.overrideWith(
          () => AuthNotifier(
            storage: const FlutterSecureStorage(),
            debugEnvLoader: () async => const {},
            httpClient: MockClient((request) async {
              sentCookie = request.headers['Cookie'];
              return http.Response(
                '{"data":{"version":"6.0.0"}}',
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(cosmosSessionProvider, (_, _) {});
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
      if (container.read(cosmosSessionProvider) != null) break;
    }

    await container
        .read(authProvider.notifier)
        .testConnection('https://firefly.example', 'tok', false);

    expect(sentCookie, 'jwttoken=jwt-value');
  });

  test('a Cosmos sign-in page is named, not called a wrong address', () async {
    // Followed, the 302 lands on the login page as a perfectly successful 200
    // and reads as "not the Firefly III API", which sends someone off to
    // correct an address that was right.
    final container = ProviderContainer(
      overrides: [
        cosmosSessionStoreProvider.overrideWithValue(_MemoryStore()),
        authProvider.overrideWith(
          () => AuthNotifier(
            storage: const FlutterSecureStorage(),
            debugEnvLoader: () async => const {},
            httpClient: MockClient(
              (_) async => http.Response(
                '',
                302,
                headers: {
                  'location':
                      'https://cosmos.example/cosmos-ui/openid'
                      '?client_id=__route_Firefly-III',
                },
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(authProvider.notifier)
        .testConnection('https://firefly.example', 'tok', false);

    expect(result.ok, isFalse);
    expect(result.failure, ConnectionFailure.cosmosLoginRequired);
  });

  test('an ordinary web page is still a wrong address', () async {
    // Only a redirect to Cosmos means "sign in". A UI host answering with its
    // own page is the address being wrong, and must keep saying so.
    final container = ProviderContainer(
      overrides: [
        cosmosSessionStoreProvider.overrideWithValue(_MemoryStore()),
        authProvider.overrideWith(
          () => AuthNotifier(
            storage: const FlutterSecureStorage(),
            debugEnvLoader: () async => const {},
            httpClient: MockClient(
              (_) async => http.Response(
                '<!DOCTYPE html><html><body>hello</body></html>',
                200,
                headers: {'content-type': 'text/html'},
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(authProvider.notifier)
        .testConnection('https://firefly.example', 'tok', false);

    expect(result.failure, ConnectionFailure.notFirefly);
  });

  test('a refused address is not carried over to a corrected one', () async {
    // Correcting an address that Cosmos had refused left every request
    // blocked on a sign-in for the old host, so nothing was ever sent that
    // could prove the new one works.
    final container = ProviderContainer(
      overrides: [
        cosmosSessionStoreProvider.overrideWithValue(_MemoryStore()),
        authProvider.overrideWith(
          () => StaticAuthNotifier(
            AuthSettings(serverUrl: 'https://wrong.example', apiToken: 'tok'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final auth = container.read(authProvider.notifier);
    container
        .read(cosmosGateProvider.notifier)
        .rejected(Uri.parse('https://wrong.example/api/v1/about'));
    await pumpEventQueue(times: 10);
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);

    auth.state = AuthSettings(
      serverUrl: 'https://wrong.example',
      apiToken: 'tok2',
      isHydrated: true,
    );
    // Only the address matters: a reissued token for the same server says
    // nothing about the door in front of it.
    expect(container.read(cosmosGateProvider), CosmosGate.signInRequired);

    auth.state = AuthSettings(
      serverUrl: 'https://right.example',
      apiToken: 'tok2',
      isHydrated: true,
    );

    expect(container.read(cosmosGateProvider), CosmosGate.open);
  });

  test('a rolled-forward cookie is kept, in memory and in the store', () async {
    final store = _MemoryStore(saved: session);
    final container = containerWith(store);
    container.listen(cosmosSessionProvider, (_, _) {});
    await pumpEventQueue(times: 10);

    await container
        .read(cosmosSessionProvider.notifier)
        .rolledForward('fresh-value');

    // The host stays what it was: Cosmos replaced the token, not the route.
    expect(container.read(cosmosSessionProvider)!.cookie, 'fresh-value');
    expect(container.read(cosmosSessionProvider)!.host, 'firefly.example');
    // Kept, or the fortnight starts over from the sign-in on the next launch.
    expect(store.saved!.cookie, 'fresh-value');
  });

  test('there is nothing to roll forward without a session', () async {
    final store = _MemoryStore();
    final container = containerWith(store);
    container.listen(cosmosSessionProvider, (_, _) {});
    await pumpEventQueue(times: 10);

    await container
        .read(cosmosSessionProvider.notifier)
        .rolledForward('fresh-value');

    expect(container.read(cosmosSessionProvider), isNull);
    expect(store.saved, isNull);
  });

  test('the same cookie again is not written back', () async {
    final store = _MemoryStore(saved: session);
    final container = containerWith(store);
    container.listen(cosmosSessionProvider, (_, _) {});
    await pumpEventQueue(times: 10);
    final before = container.read(cosmosSessionProvider);

    await container
        .read(cosmosSessionProvider.notifier)
        .rolledForward('jwt-value');

    // Identical, so no keychain write and no rebuild of everything that
    // watches this for the sake of a cookie that did not change.
    expect(container.read(cosmosSessionProvider), same(before));
  });

  test('an expiry drops it, and only when there was one', () async {
    final store = _MemoryStore();
    final container = containerWith(store);
    container.listen(cosmosSessionProvider, (_, _) {});
    await container.read(cosmosSessionProvider.notifier).signedIn(session);

    container.read(cosmosSessionProvider.notifier).expired();
    expect(container.read(cosmosSessionProvider), isNull);
    expect(store.cleared, 1);

    // Every refused request calls this, and a gated route refuses every one of
    // them at once. Clearing a store that is already clear, once per request,
    // is a keychain write per request.
    container.read(cosmosSessionProvider.notifier).expired();
    expect(store.cleared, 1);
  });
}
