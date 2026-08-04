import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../router/dashboard_route.dart';
import '../router/expenses_route.dart';
import '../utils/period_defaults.dart';

typedef DashboardAnalyticsRouteParams = ({
  ExpensePeriod period,
  String? from,
  String? to,
});

DashboardAnalyticsRouteParams analyticsRouteParamsFromDashboard(
  DashboardRouteFilters filters,
) {
  if (filters.hasCustomDateRange) {
    return (
      period: ExpensePeriod.month,
      from: filters.from != null
          ? DashboardRoute.formatDate(filters.from!)
          : null,
      to: filters.to != null ? DashboardRoute.formatDate(filters.to!) : null,
    );
  }

  final params = expenseParamsFromDashboardPeriod(filters.period);
  return (
    period: params.period,
    from: params.from != null
        ? ExpenseRouteFilters.formatDate(params.from!)
        : null,
    to: params.to != null ? ExpenseRouteFilters.formatDate(params.to!) : null,
  );
}
