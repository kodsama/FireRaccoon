import 'package:go_router/go_router.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../utils/period_defaults.dart';
import 'transaction_analytics_route.dart';

export 'transaction_analytics_route.dart'
    show
        ExpensePeriodX,
        TransactionTypeFilterX,
        ExpenseRouteFilters,
        TransactionAnalyticsRoute,
        expensesAnalyticsRoute,
        incomeAnalyticsRoute;

class ExpensesRoute {
  static const path = '/expenses';
  static final _route = expensesAnalyticsRoute;

  static String formatDate(DateTime date) =>
      ExpenseRouteFilters.formatDate(date);

  static String location({
    String? category,
    ExpensePeriod? period,
    TransactionTypeFilter type = TransactionTypeFilter.expense,
    String? account,
    String? from,
    String? to,
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) => _route.location(
    category: category,
    period: period,
    type: type,
    account: account,
    from: from,
    to: to,
    defaultDashboardPeriod: defaultDashboardPeriod,
  );

  static ExpenseRouteFilters filtersFrom(
    GoRouterState state, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) =>
      _route.filtersFrom(state, defaultDashboardPeriod: defaultDashboardPeriod);

  static ExpenseRouteFilters filtersFromUri(
    Uri uri, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) => _route.filtersFromUri(
    uri,
    defaultDashboardPeriod: defaultDashboardPeriod,
  );

  static String? categoryFrom(GoRouterState state) =>
      filtersFrom(state).category;

  static String? categoryFromUri(Uri uri) => filtersFromUri(uri).category;
}

class IncomeRoute {
  static const path = '/income';
  static final _route = incomeAnalyticsRoute;

  static String formatDate(DateTime date) =>
      ExpenseRouteFilters.formatDate(date);

  static String location({
    String? category,
    ExpensePeriod? period,
    TransactionTypeFilter type = TransactionTypeFilter.income,
    String? account,
    String? from,
    String? to,
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) => _route.location(
    category: category,
    period: period,
    type: type,
    account: account,
    from: from,
    to: to,
    defaultDashboardPeriod: defaultDashboardPeriod,
  );

  static ExpenseRouteFilters filtersFrom(
    GoRouterState state, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) =>
      _route.filtersFrom(state, defaultDashboardPeriod: defaultDashboardPeriod);

  static ExpenseRouteFilters filtersFromUri(
    Uri uri, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) => _route.filtersFromUri(
    uri,
    defaultDashboardPeriod: defaultDashboardPeriod,
  );
}
