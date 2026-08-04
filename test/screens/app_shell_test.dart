import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon/l10n/app_localizations.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/locale_provider.dart';
import 'package:fireracoon/providers/firefly_connection_provider.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/models/account.dart';
import 'package:fireracoon/screens/app_shell.dart';
import 'package:fireracoon/theme/app_theme.dart';
import 'package:fireracoon/theme/app_colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../helpers/static_auth_notifier.dart';
import '../helpers/fixed_accounts_notifier.dart';
import '../helpers/test_data.dart';

class _StaticFireflyConnectionNotifier extends FireflyConnectionNotifier {
  @override
  FireflyConnectionStatus build() => FireflyConnectionStatus.disconnected;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<Widget> buildTestApp() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Text('Dashboard Content'),
            ),
            GoRoute(
              path: '/accounts',
              builder: (context, state) => const Text('Accounts Content'),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const Text('Settings Content'),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => StaticAuthNotifier(AuthSettings())),
        fireflyConnectionProvider.overrideWith(
          _StaticFireflyConnectionNotifier.new,
        ),
        accountsProvider.overrideWith(
          () => FixedAccountsNotifier(sampleAccounts),
        ),
        primaryCurrencyProvider.overrideWith((ref) async => sampleCurrency),
        currentUserProvider.overrideWith((ref) async => sampleUser),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final themeSettings = ref.watch(themeProvider);
          return MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocale.supported,
            theme: AppTheme.buildTheme(
              false,
              AppAccent.fromType(themeSettings.accentType),
            ),
            routerConfig: router,
          );
        },
      ),
    );
  }

  testWidgets('AppShell renders sidebar and header', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Content'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('AppShell navigation interactions', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    // Tap Accounts child in sidebar (since accounts group is expanded by default)
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();

    expect(find.text('Accounts Content'), findsOneWidget);

    // Tap Settings icon in sidebar profile row
    await tester.tap(find.byIcon(LucideIcons.settings).first);
    await tester.pumpAndSettle();

    expect(find.text('Settings Content'), findsOneWidget);
  });

  testWidgets('AppShell sidebar net worth subtracts negative liabilities', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;

    final accounts = [
      Account(
        id: '1',
        name: 'Checking',
        type: 'asset',
        role: 'defaultAsset',
        currentBalance: 187_008.05,
        currencySymbol: 'kr',
        currencyCode: 'SEK',
      ),
      Account(
        id: '2',
        name: 'Mortgage',
        type: 'liability',
        role: 'defaultAsset',
        currentBalance: -2_629_887,
        currencySymbol: 'kr',
        currencyCode: 'SEK',
      ),
    ];

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Text('Dashboard Content'),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(() => StaticAuthNotifier(AuthSettings())),
          fireflyConnectionProvider.overrideWith(
            _StaticFireflyConnectionNotifier.new,
          ),
          accountsProvider.overrideWith(() => FixedAccountsNotifier(accounts)),
          primaryCurrencyProvider.overrideWith((ref) async => sampleCurrency),
          currentUserProvider.overrideWith((ref) async => sampleUser),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final themeSettings = ref.watch(themeProvider);
            return MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocale.supported,
              theme: AppTheme.buildTheme(
                false,
                AppAccent.fromType(themeSettings.accentType),
              ),
              routerConfig: router,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('-€'), findsOneWidget);
    expect(find.textContaining('2,816,895'), findsNothing);
  });

  testWidgets('AppShell search updates URL query', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'savings');
    await tester.pumpAndSettle(const Duration(milliseconds: 350));

    final context = tester.element(find.byType(AppShell));
    expect(GoRouterState.of(context).uri.queryParameters['q'], 'savings');
  });

  testWidgets('AppShell hides the sidebar behind a drawer on small screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    // Hamburger is shown and the destinations are not visible inline.
    expect(find.byIcon(LucideIcons.menu), findsOneWidget);
    expect(find.text('Accounts'), findsNothing);

    // Opening the drawer reveals the destinations.
    await tester.tap(find.byIcon(LucideIcons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Accounts'), findsWidgets);

    // Tapping Accounts child item navigates and closes the drawer.
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    expect(find.text('Accounts Content'), findsOneWidget);
    expect(find.text('Accounts'), findsNothing);
  });
}
