import 'package:fireracoon/providers/people_providers.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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

  test('router keeps one GoRouter across people hydration', () async {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
