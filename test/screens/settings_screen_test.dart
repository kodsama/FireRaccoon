import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/screens/settings_screen.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../helpers/dialog_test_helpers.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStorage;

  setUp(() {
    secureStorage = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureStorage,
    );
    PackageInfo.setMockInitialValues(
      appName: 'FireRacoon',
      packageName: 'com.fireracoon.app',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('SettingsScreen toggles Racoon Mode', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Racoon Mode'), findsOneWidget);

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    Switch switchWidget = tester.widget(switchFinder);
    expect(switchWidget.value, false);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    switchWidget = tester.widget(switchFinder);
    expect(switchWidget.value, true);
  });

  testWidgets('SettingsScreen opens theme style picker', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Theme Style'));
    await tester.pumpAndSettle();

    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('Classic'), findsWidgets);
  });

  testWidgets('SettingsScreen opens language picker', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.text('Select language'), findsOneWidget);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(find.text('Français'), findsWidgets);
  });

  testWidgets('SettingsScreen shows currency when connected', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SettingsScreen(),
        fireflyService: FakeFireflyService(),
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Euro'), findsWidgets);
  });

  testWidgets('SettingsScreen opens currency picker', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final service = FakeFireflyService(
      currencies: const [
        FireflyCurrency(id: '1', code: 'EUR', name: 'Euro', symbol: '€'),
        FireflyCurrency(id: '2', code: 'USD', name: 'US Dollar', symbol: r'$'),
        FireflyCurrency(
          id: '3',
          code: '007',
          name: 'SEB Världenfond [007]',
          symbol: '007',
        ),
      ],
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SettingsScreen(),
        fireflyService: service,
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Default Currency'));
    await tester.pumpAndSettle();

    expect(find.text('Select currency'), findsOneWidget);
    expect(find.textContaining('US Dollar'), findsWidgets);
    expect(find.textContaining('SEB Världenfond'), findsNothing);
    expect(find.text('Current'), findsOneWidget);

    await tester.tap(find.textContaining('US Dollar').last);
    await tester.pumpAndSettle();

    expect(find.text('Change default currency'), findsOneWidget);
    await confirmDialogWithChallenge(tester);

    expect(find.text('Default currency set to USD'), findsOneWidget);
    expect(find.textContaining('USD'), findsWidgets);
  });

  testWidgets('SettingsScreen currency picker cancels confirmation', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final service = FakeFireflyService(
      currencies: const [
        FireflyCurrency(id: '1', code: 'EUR', name: 'Euro', symbol: '€'),
        FireflyCurrency(id: '2', code: 'USD', name: 'US Dollar', symbol: r'$'),
      ],
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SettingsScreen(),
        fireflyService: service,
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Default Currency'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('US Dollar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Change default currency'), findsNothing);
    expect(find.textContaining('Euro'), findsWidgets);
  });

  testWidgets('SettingsScreen adjusts transaction page size', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Slider).first, const Offset(100, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('per page'), findsWidgets);
  });

  testWidgets('SettingsScreen opens auth dialog', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    // Scroll down to reveal the backend connection section. `scrollUntilVisible`
    // is used instead of a fixed drag distance because the sliver list's
    // scroll extent is only an estimate until enough of it has been scrolled
    // through, so a fixed pixel offset is brittle as content above grows.
    await tester.scrollUntilVisible(
      find.text('Server URL'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    expect(find.text('Firefly III Connection'), findsOneWidget);
    expect(find.text('Test Connection'), findsOneWidget);
  });

  testWidgets('SettingsScreen shows app version footer', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Version 0.1.0+1'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 0.1.0+1'), findsOneWidget);
  });

  testWidgets('SettingsScreen disconnects when connected', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SettingsScreen(),
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down to reveal the backend connection section.
    await tester.scrollUntilVisible(
      find.text('Disconnect'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    final disconnect = find.text('Disconnect');
    expect(disconnect, findsOneWidget);
    await tester.tap(disconnect, warnIfMissed: false);
    await tester.pumpAndSettle();

    await confirmDialogWithChallenge(tester);
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);
  });

  testWidgets('Disconnect asks before deleting the credentials', (
    tester,
  ) async {
    // Deleting the token and URL from the keychain cannot be undone and there
    // is no copy anywhere else, so a stray tap must not do it.
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SettingsScreen(),
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Disconnect'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Disconnect'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Still connected, and the dialog is what is asking.
    expect(find.text('Not connected'), findsNothing);
    expect(find.byType(EditableText), findsWidgets);
  });
}
