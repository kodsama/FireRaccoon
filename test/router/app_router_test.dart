import 'dart:convert';

import 'package:fireraccoon/deployment/deployment_providers.dart';
import 'package:fireraccoon/deployment/fireraccoon_mode.dart';
import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/people_providers.dart';
import 'package:fireraccoon/providers/server_session_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/router/app_router.dart';
import 'package:fireraccoon/store/remote_server_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/static_auth_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app router builders produce every configured screen', (
    tester,
  ) async {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // These tests build route widgets. The real notifier reads platform
        // secure storage and a .env file, neither of which answers under
        // flutter_test, so its deadline was still running at teardown.
        authProvider.overrideWith(() => StaticAuthNotifier(AuthSettings())),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final shell = router.configuration.routes.whereType<ShellRoute>().single;
    final shellState = _state(router, '/');
    expect(
      shell.builder!(context, shellState, const SizedBox.shrink()),
      isA<Widget>(),
    );

    for (final route in shell.routes.whereType<GoRoute>()) {
      final builder = route.builder;
      if (builder == null) continue;
      final path = route.path;
      expect(builder(context, _state(router, path)), isA<Widget>());
    }

    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('server mode router builds unlock setup and prognosis redirect', (
    tester,
  ) async {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => StaticAuthNotifier(AuthSettings())),
        deploymentConfigProvider.overrideWithValue(
          const DeploymentConfig(
            mode: FireraccoonMode.server,
            apiBase: 'http://example.test',
          ),
        ),
        serverSessionProvider.overrideWith(
          () => ServerSessionNotifier(
            storage: const FlutterSecureStorage(),
            clientFactory: (_) => RemoteServerClient(
              baseUrl: 'http://example.test',
              httpClient: MockClient(
                (_) async => http.Response(
                  jsonEncode({
                    'storeLocked': false,
                    'storeExists': true,
                    'setupRequired': false,
                  }),
                  200,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(serverSessionProvider.future);
    final router = container.read(routerProvider);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    for (final path in ['/unlock', '/setup', '/login']) {
      final route = router.configuration.routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == path,
      );
      expect(route.builder!(context, _state(router, path)), isA<Widget>());
    }

    final shell = router.configuration.routes.whereType<ShellRoute>().single;
    final prognosis = shell.routes.whereType<GoRoute>().firstWhere(
      (r) => r.path == '/prognosis',
    );
    expect(
      prognosis.redirect!(context, _state(router, '/prognosis')),
      '/projection',
    );

    // Touch server redirect listener by updating session.
    container.read(serverSessionProvider.notifier);
    await tester.pump();
  });

  test('router keeps one GoRouter across people hydration', () async {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // These tests build route widgets. The real notifier reads platform
        // secure storage and a .env file, neither of which answers under
        // flutter_test, so its deadline was still running at teardown.
        authProvider.overrideWith(() => StaticAuthNotifier(AuthSettings())),
      ],
    );
    addTearDown(container.dispose);

    final routerBefore = container.read(routerProvider);

    for (var i = 0; i < 40; i++) {
      if (container.read(peopleProvider).isHydrated) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(container.read(peopleProvider).isHydrated, isTrue);

    final routerAfter = container.read(routerProvider);
    expect(
      identical(routerBefore, routerAfter),
      isTrue,
      reason:
          'Recreating GoRouter reuses navigator GlobalKeys and blanks the '
          'shell child (Transactions and other routes).',
    );
  });
}

GoRouterState _state(GoRouter router, String path) {
  return GoRouterState(
    router.configuration,
    uri: Uri.parse(path),
    matchedLocation: path,
    fullPath: path,
    pathParameters: const {},
    pageKey: ValueKey(path),
  );
}
