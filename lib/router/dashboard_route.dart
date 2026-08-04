import 'package:go_router/go_router.dart';

import '../utils/dashboard_period.dart';
import '../utils/period_defaults.dart';
import 'expenses_route.dart';
import 'route_query.dart';

enum DashboardTab { insights, accounts, focus }

class DashboardRouteFilters {
  final DashboardTab tab;
  final DashboardPeriod period;
  final DateTime? from;
  final DateTime? to;
  final DashboardPeriod defaultPeriod;

  const DashboardRouteFilters({
    this.tab = DashboardTab.insights,
    this.period = kDefaultDashboardPeriod,
    this.from,
    this.to,
    this.defaultPeriod = kDefaultDashboardPeriod,
  });

  bool get hasCustomDateRange => from != null || to != null;
}

class DashboardRoute {
  static const path = '/';

  static String location({
    DashboardTab tab = DashboardTab.insights,
    DashboardPeriod period = kDefaultDashboardPeriod,
    String? from,
    String? to,
    DashboardPeriod omitPeriodWhen = kDefaultDashboardPeriod,
  }) {
    return RouteQuery.build(path, {
      if (tab != DashboardTab.insights) 'tab': tab.name,
      if (!hasCustomDates(from, to) && period != omitPeriodWhen)
        'period': period.name,
      if (hasCustomDates(from, to)) ...{'from': from, 'to': to},
    });
  }

  static bool hasCustomDates(String? from, String? to) =>
      (from != null && from.isNotEmpty) || (to != null && to.isNotEmpty);

  static DashboardTab tabFrom(GoRouterState state) => filtersFrom(state).tab;

  static DashboardTab tabFromUri(Uri uri) => filtersFromUri(uri).tab;

  static DashboardRouteFilters filtersFrom(
    GoRouterState state, {
    DashboardPeriod defaultPeriod = kDefaultDashboardPeriod,
  }) => filtersFromUri(state.uri, defaultPeriod: defaultPeriod);

  static DashboardRouteFilters filtersFromUri(
    Uri uri, {
    DashboardPeriod defaultPeriod = kDefaultDashboardPeriod,
  }) {
    final from = _parseDate(RouteQuery.param(uri, 'from'));
    final to = _parseDate(RouteQuery.param(uri, 'to'));
    final hasPeriodParam = uri.queryParameters.containsKey('period');

    return DashboardRouteFilters(
      tab: RouteQuery.enumFrom(
        uri,
        'tab',
        DashboardTab.values,
        DashboardTab.insights,
      ),
      period: from != null || to != null
          ? defaultPeriod
          : hasPeriodParam
          ? RouteQuery.enumFrom(
              uri,
              'period',
              DashboardPeriod.values,
              defaultPeriod,
            )
          : defaultPeriod,
      from: from,
      to: to,
      defaultPeriod: defaultPeriod,
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static String formatDate(DateTime date) => ExpensesRoute.formatDate(date);
}
