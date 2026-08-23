import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/firefly_connection_provider.dart';
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
