import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon/l10n/app_localizations.dart';
import 'package:fireracoon/models/account.dart';
import 'package:fireracoon/models/budget.dart';
import 'package:fireracoon/models/currency.dart';
import 'package:fireracoon/models/transaction.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/locale_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/screens/dashboard_screen.dart';
import 'package:fireracoon/theme/app_colors.dart';
import 'package:fireracoon/theme/app_theme.dart';
import '../helpers/fixed_accounts_notifier.dart';
import '../helpers/fixed_transactions_notifier.dart';

DateTime _sampleDay(int preferredDay, {int hour = 12}) {
  final now = DateTime.now();
  final day = preferredDay.clamp(1, now.day).toInt();
  return DateTime(now.year, now.month, day, hour);
}

final _sampleTransactions = [
  Transaction(
    id: '1',
    type: 'deposit',
    date: _sampleDay(5, hour: 14),
    amount: 1200,
    description: 'Salary',
    sourceName: 'Employer',
    destinationName: 'Checking',
    categoryName: 'Income',
    currencySymbol: '€',
    currencyCode: 'EUR',
  ),
  Transaction(
    id: '2',
    type: 'withdrawal',
    date: _sampleDay(8, hour: 10),
    amount: 45,
    description: 'Groceries',
    sourceName: 'Checking',
    destinationName: 'Store',
    categoryName: 'Food',
    currencySymbol: '€',
    currencyCode: 'EUR',
  ),
];

final _sampleAccounts = [
  Account(
    id: '1',
    name: 'Checking',
    type: 'asset',
    role: 'defaultAsset',
    currentBalance: 2500,
    currencySymbol: '€',
    currencyCode: 'EUR',
  ),
];

final _sampleBudgets = [
  Budget(
    id: '1',
    name: 'Food',
    active: true,
    spent: 120,
    autoBudgetAmount: 400,
    currencySymbol: '€',
    currencyCode: 'EUR',
  ),
];

Future<Widget> buildTestApp({
  bool racoonMode = false,
  String initialLocation = '/',
}) async {
  SharedPreferences.setMockInitialValues({'isRacoonMode': racoonMode});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: DashboardScreen()),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const Scaffold(body: Text('Transactions')),
      ),
      GoRoute(
        path: '/projection',
        builder: (context, state) => const Scaffold(body: Text('Projection')),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const Scaffold(body: Text('Accounts')),
      ),
      GoRoute(
        path: '/income',
        builder: (context, state) => const Scaffold(body: Text('Income')),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const Scaffold(body: Text('Expenses')),
      ),
      GoRoute(
        path: '/piggy-banks',
        builder: (context, state) => const Scaffold(body: Text('Piggy banks')),
      ),
      GoRoute(
        path: '/budgets',
        builder: (context, state) => const Scaffold(body: Text('Budgets')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      transactionsProvider.overrideWith(
        () => FixedTransactionsNotifier(_sampleTransactions),
      ),
      accountsProvider.overrideWith(
        () => FixedAccountsNotifier(_sampleAccounts),
      ),
      budgetsProvider.overrideWith((ref) async => _sampleBudgets),
      primaryCurrencyProvider.overrideWith(
        (ref) async => const FireflyCurrency(
          id: '1',
          code: 'EUR',
          name: 'Euro',
          symbol: '€',
        ),
      ),
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

void main() {
  testWidgets('DashboardScreen renders KPIs from live data in normal mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Income ·'), findsOneWidget);
    expect(find.textContaining('Spending ·'), findsOneWidget);
    expect(find.textContaining('Saved ·'), findsOneWidget);
    expect(find.textContaining('€2,500.00'), findsWidgets);
    expect(find.textContaining('€1,200.00'), findsWidgets);
    expect(find.textContaining('€45.00'), findsWidgets);
    expect(find.text('Salary'), findsOneWidget);
  });

  testWidgets('DashboardScreen renders KPIs correctly in Racoon mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await buildTestApp(racoonMode: true));
    await tester.pumpAndSettle();

    expect(find.text('Snatched Funds'), findsOneWidget);
    expect(find.text('Burnt Cash'), findsOneWidget);
    expect(find.text('Stash'), findsOneWidget);
  });

  testWidgets('Dashboard toggles layouts', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Cash flow'), findsOneWidget);

    await tester.tap(find.text('Accounts').first);
    await tester.pumpAndSettle();
    expect(find.text('Your Accounts'), findsOneWidget);
    expect(find.text('Budgets at a glance'), findsOneWidget);

    await tester.tap(find.text('Focus').first);
    await tester.pumpAndSettle();
    expect(find.text('Net worth'), findsOneWidget);
    expect(find.text("Today's timeline"), findsOneWidget);
  });

  testWidgets('Dashboard KPI cards navigate to their destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Total balance'));
    await tester.pumpAndSettle();
    expect(find.text('Transactions'), findsOneWidget);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Income ·'));
    await tester.pumpAndSettle();
    expect(find.text('Income'), findsOneWidget);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Spending ·'));
    await tester.pumpAndSettle();
    expect(find.text('Expenses'), findsOneWidget);

    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Saved ·'));
    await tester.pumpAndSettle();
    expect(find.text('Piggy banks'), findsOneWidget);
  });
}
