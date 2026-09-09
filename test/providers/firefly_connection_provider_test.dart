import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/cosmos_session_provider.dart';
import 'package:fireraccoon/providers/firefly_connection_provider.dart';
import 'package:fireraccoon/providers/firefly_reconnect_provider.dart';
import 'package:fireraccoon/store/cosmos_session.dart';
import 'package:fireraccoon/store/cosmos_session_store.dart';

import '../helpers/static_auth_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FlutterSecureStorage testStorage() => const FlutterSecureStorage();

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
  });

  Future<ProviderContainer> containerWithAuth({
    required AuthSettings auth,
    required http.Client httpClient,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => AuthNotifier(httpClient: httpClient, storage: testStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authProvider.notifier)
        .saveSettings(auth.serverUrl, auth.apiToken, auth.allowInsecure);
    return container;
  }

  Future<FireflyConnectionStatus> waitForStatus(
    ProviderContainer container, {
    bool Function(FireflyConnectionStatus status)? until,
  }) async {
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final status = container.read(fireflyConnectionProvider);
      if (until != null
          ? until(status)
          : status != FireflyConnectionStatus.checking) {
        return status;
      }
    }
    return container.read(fireflyConnectionProvider);
  }

  test('a connection coming back says so, once', () async {
    // Otherwise the sidebar goes back to saying connected while every screen
    // keeps showing the failure it hit while the server was away.
    var answer = 500;
    final container = ProviderContainer(
      overrides: [
        cosmosSessionStoreProvider.overrideWithValue(_EmptyStore()),
        authProvider.overrideWith(
          () => StaticAuthNotifier(
            AuthSettings(serverUrl: 'https://cash.example', apiToken: 'token'),
            storage: testStorage(),
            httpClient: MockClient(
              (_) async => http.Response(
                answer == 200 ? '{"data":{}}' : 'boom',
                answer,
                headers: const {'content-type': 'application/json'},
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(fireflyConnectionProvider, (_, _) {});
    container.listen(fireflyReconnectProvider, (_, _) {});
    // Waited for explicitly: a probe whose answer arrives after the next one
    // has started is discarded, and then nothing has settled to come back from.
    await waitForStatus(
      container,
      until: (s) => s == FireflyConnectionStatus.unreachable,
    );
    expect(
      container.read(fireflyConnectionProvider),
      FireflyConnectionStatus.unreachable,
    );
    // The first settled answer is a failure, so nothing has come back yet.
    expect(container.read(fireflyReconnectProvider), 0);

    answer = 200;
    container.read(fireflyConnectionProvider.notifier).refresh();
    await waitForStatus(
      container,
      until: (s) => s == FireflyConnectionStatus.connected,
    );

    expect(container.read(fireflyReconnectProvider), 1);

    // Still connected on the next check, which is not a second coming back.
    container.read(fireflyConnectionProvider.notifier).refresh();
    await waitForStatus(
      container,
      until: (s) => s == FireflyConnectionStatus.connected,
    );

    expect(container.read(fireflyReconnectProvider), 1);
  });

  test('a first connection at startup is not a reconnection', () async {
    // The screens are loading already; reloading them costs a second fetch of
    // everything for nothing.
    final container = ProviderContainer(
      overrides: [
        cosmosSessionStoreProvider.overrideWithValue(_EmptyStore()),
        authProvider.overrideWith(
          () => StaticAuthNotifier(
            AuthSettings(serverUrl: 'https://cash.example', apiToken: 'token'),
            storage: testStorage(),
            httpClient: MockClient(
              (_) async => http.Response('{"data":{}}', 200),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(fireflyConnectionProvider, (_, _) {});
    container.listen(fireflyReconnectProvider, (_, _) {});
    await waitForStatus(
      container,
      until: (s) => s == FireflyConnectionStatus.connected,
    );

    expect(container.read(fireflyReconnectProvider), 0);
  });

  test('a Cosmos session arriving re-checks the connection', () async {
    // Waiting out the poll left someone who had just signed in looking at a
    // disconnected server and pressing Test connection to learn otherwise.
    var probes = 0;
    final container = ProviderContainer(
      overrides: [
        cosmosSessionStoreProvider.overrideWithValue(_EmptyStore()),
        authProvider.overrideWith(
          () => StaticAuthNotifier(
            AuthSettings(serverUrl: 'https://cash.example', apiToken: 'token'),
            storage: testStorage(),
            httpClient: MockClient((_) async {
              probes++;
              return http.Response(
                '{"data":{}}',
                200,
                headers: const {'content-type': 'application/json'},
              );
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(fireflyConnectionProvider, (_, _) {});
    await waitForStatus(container);
    final beforeSignIn = probes;

    await container
        .read(cosmosSessionProvider.notifier)
        .signedIn(
          CosmosSession(
            host: 'cash.example',
            cookie: 'jwt-value',
            obtainedAt: DateTime.utc(2026, 9, 9),
          ),
        );
    await waitForStatus(container);

    expect(probes, greaterThan(beforeSignIn));
  });

  test('reports disconnected when credentials are missing', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => StaticAuthNotifier(AuthSettings(), storage: testStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(fireflyConnectionProvider);
    final status = await waitForStatus(container);

    expect(status, FireflyConnectionStatus.disconnected);
  });

  test('reports connected when Firefly responds with 200', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"data":{"version":"6.6.6"}}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final container = await containerWithAuth(
      auth: AuthSettings(serverUrl: 'https://firefly.test', apiToken: 'token'),
      httpClient: client,
    );

    container.read(fireflyConnectionProvider);
    final status = await waitForStatus(container);

    expect(status, FireflyConnectionStatus.connected);
  });

  test('reports unreachable when Firefly is down', () async {
    final client = MockClient((_) async => throw Exception('offline'));
    final container = await containerWithAuth(
      auth: AuthSettings(serverUrl: 'https://firefly.test', apiToken: 'token'),
      httpClient: client,
    );

    container.read(fireflyConnectionProvider);
    final status = await waitForStatus(container);

    expect(status, FireflyConnectionStatus.unreachable);
  });

  test('updates to unreachable when a later probe fails', () async {
    var shouldFail = false;
    final client = MockClient((_) async {
      if (shouldFail) throw Exception('offline');
      return http.Response(
        '{"data":{"version":"6.6.6"}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final container = await containerWithAuth(
      auth: AuthSettings(serverUrl: 'https://firefly.test', apiToken: 'token'),
      httpClient: client,
    );

    container.read(fireflyConnectionProvider);
    expect(await waitForStatus(container), FireflyConnectionStatus.connected);

    shouldFail = true;
    container.read(fireflyConnectionProvider.notifier).refresh();
    expect(
      await waitForStatus(
        container,
        until: (status) => status == FireflyConnectionStatus.unreachable,
      ),
      FireflyConnectionStatus.unreachable,
    );
  });

  test(
    'backs off after repeated successes and refresh resets polling',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(
          '{"data":{"version":"6.6.6"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final container = await containerWithAuth(
        auth: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
        httpClient: client,
      );
      final notifier = container.read(fireflyConnectionProvider.notifier);
      expect(await waitForStatus(container), FireflyConnectionStatus.connected);

      for (var i = 0; i < kFireflyConnectionStableThreshold; i++) {
        final targetRequests = requests + 1;
        notifier.refresh();
        while (requests < targetRequests) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(
          await waitForStatus(container),
          FireflyConnectionStatus.connected,
        );
      }

      final targetRequests = requests + 1;
      notifier.refresh();
      while (requests < targetRequests) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(await waitForStatus(container), FireflyConnectionStatus.connected);
    },
  );
}

/// A store with nothing in it, so the session under test is only what the
/// test puts there.
class _EmptyStore extends CosmosSessionStore {
  _EmptyStore() : super(storage: null);

  CosmosSession? saved;

  @override
  Future<CosmosSession?> load() async => null;

  @override
  Future<void> save(CosmosSession session) async => saved = session;

  @override
  Future<void> clear() async => saved = null;
}
