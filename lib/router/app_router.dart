import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/people_providers.dart';
import '../screens/app_shell.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/accounts_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/budgets_screen.dart';
import '../screens/subscriptions_screen.dart';
import '../screens/piggy_banks_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/income_screen.dart';
import '../screens/transfers_screen.dart';
import '../screens/liabilities_screen.dart';
import '../screens/projection_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/history_screen.dart';
import '../screens/categories_tags_screen.dart';
import '../screens/payees_screen.dart';

/// Decides whether a navigation to [matchedLocation] must be redirected
/// because of the people login gate. Returns the target location, or
/// `null` to proceed unredirected.
String? resolvePeopleRedirect(PeopleState people, String matchedLocation) {
  final goingToLogin = matchedLocation == '/login';
  if (people.requiresLoginGate) {
    return goingToLogin ? null : '/login';
  }
  if (goingToLogin) return '/';
  return null;
}

/// Back-compat alias for older tests/call sites.
String? resolveAppUsersRedirect(PeopleState people, String matchedLocation) =>
    resolvePeopleRedirect(people, matchedLocation);

final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
  final refresh = ValueNotifier<int>(0);
  ref.listen<PeopleState>(peopleProvider, (_, _) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) =>
        resolvePeopleRedirect(ref.read(peopleProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/categories-tags',
            builder: (context, state) => const CategoriesTagsScreen(),
          ),
          GoRoute(
            path: '/payees',
            builder: (context, state) => const PayeesScreen(),
          ),
          GoRoute(
            path: '/budgets',
            builder: (context, state) => const BudgetsScreen(),
          ),
          GoRoute(
            path: '/subscriptions',
            builder: (context, state) => const SubscriptionsScreen(),
          ),
          GoRoute(
            path: '/piggy-banks',
            builder: (context, state) => const PiggyBanksScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/income',
            builder: (context, state) => const IncomeScreen(),
          ),
          GoRoute(
            path: '/transfers',
            builder: (context, state) => const TransfersScreen(),
          ),
          GoRoute(
            path: '/liabilities',
            builder: (context, state) => const LiabilitiesScreen(),
          ),
          GoRoute(
            path: '/projection',
            builder: (context, state) => const ProjectionScreen(),
          ),
          GoRoute(
            path: '/prognosis',
            redirect: (context, state) => '/projection',
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
