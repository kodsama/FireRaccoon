import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon/l10n/app_localizations.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/budget_period_providers.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/locale_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/providers/view_mode_provider.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon/theme/app_colors.dart';
import 'package:fireracoon/theme/app_theme.dart';
import '../helpers/static_auth_notifier.dart';
import '../helpers/fixed_accounts_notifier.dart';
import '../helpers/fixed_transactions_notifier.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/test_data.dart';

Future<Widget> buildScreenTestApp({
  required Widget child,
  String initialLocation = '/',
  List<RouteBase> extraRoutes = const [],
  FireflyService? fireflyService,
  ViewMode viewMode = ViewMode.standard,
  AuthSettings? authSettings,
  Map<String, Object> prefsValues = const {'isRacoonMode': false},
}) async {
  SharedPreferences.setMockInitialValues({
    'transactionPageSize': 50,
    'viewMode': viewMode.name,
    ...prefsValues,
  });
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('viewMode', viewMode.name);
  for (final entry in prefsValues.entries) {
    if (entry.value is bool) {
      await prefs.setBool(entry.key, entry.value as bool);
    }
    if (entry.value is String) {
      await prefs.setString(entry.key, entry.value as String);
    }
    if (entry.value is int) {
      await prefs.setInt(entry.key, entry.value as int);
    }
    if (entry.value is double) {
      await prefs.setDouble(entry.key, entry.value as double);
    }
  }

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/budgets',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/income',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/liabilities',
        builder: (context, state) => Scaffold(body: child),
      ),
      ...extraRoutes,
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      viewModeProvider.overrideWith(() => _StaticViewModeNotifier(viewMode)),
      authProvider.overrideWith(
        () => StaticAuthNotifier(
          authSettings ??
              AuthSettings(
                serverUrl: 'https://firefly.test',
                apiToken: 'token',
              ),
          storage: const FlutterSecureStorage(),
        ),
      ),
      budgetPeriodMetricsProvider.overrideWith((ref, key) async {
        final budgets = await ref.watch(budgetsProvider.future);
        final service = ref.watch(apiServiceProvider);
        final range = budgetFiltersFromKey(key).dateRange;
        final results = <String, BudgetPeriodMetrics>{};
        for (final budget in budgets) {
          final transactions = service == null
              ? const <Transaction>[]
              : await service.getBudgetTransactions(budget.id);
          results[budget.id] = resolveBudgetPeriodMetrics(
            budget: budget,
            viewingRange: range,
            transactions: transactions,
          );
        }
        return results;
      }),
      if (fireflyService != null)
        apiServiceProvider.overrideWithValue(fireflyService),
      if (fireflyService == null) ...[
        apiServiceProvider.overrideWithValue(
          FakeFireflyService(
            accounts: sampleAccounts,
            transactions: sampleTransactions,
            budgets: sampleBudgets,
            primaryCurrency: sampleCurrency,
            currentUser: sampleUser,
          ),
        ),
        transactionsProvider.overrideWith(
          () => FixedTransactionsNotifier(sampleTransactions),
        ),
        accountsProvider.overrideWith(
          () => FixedAccountsNotifier(sampleAccounts),
        ),
        budgetsProvider.overrideWith((ref) async => sampleBudgets),
        primaryCurrencyProvider.overrideWith((ref) async => sampleCurrency),
        currentUserProvider.overrideWith((ref) async => sampleUser),
      ],
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

class _StaticViewModeNotifier extends ViewModeNotifier {
  _StaticViewModeNotifier(this.mode);

  final ViewMode mode;

  @override
  ViewMode build() => mode;
}

void configureLargeScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1200);
  tester.view.devicePixelRatio = 1.0;
}

Future<void> pumpScreen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
