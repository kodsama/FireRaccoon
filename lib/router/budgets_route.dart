import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../utils/locale_formatting.dart';
import '../utils/period_defaults.dart';
import 'route_query.dart';

class BudgetRouteFilters {
  final ExpensePeriod period;
  final DateTime? from;
  final DateTime? to;
  final DashboardPeriod defaultDashboardPeriod;

  const BudgetRouteFilters({
    this.period = ExpensePeriod.month,
    this.from,
    this.to,
    this.defaultDashboardPeriod = kDefaultDashboardPeriod,
  });

  bool get hasCustomDateRange => from != null || to != null;

  ExpensePeriodParams get _defaultPeriodParams =>
      expenseParamsFromDashboardPeriod(defaultDashboardPeriod);

  bool get hasActivePeriodFilter =>
      !expenseFiltersMatchParams(period, from, to, _defaultPeriodParams);

  DateRangeBounds get dateRange =>
      resolveExpenseDateRange(period: period, customFrom: from, customTo: to);

  String localizedPeriodLabel(AppLocalizations l10n, LocaleFormatting format) {
    if (hasCustomDateRange) {
      return format.formatDateRange(
        from,
        to,
        ellipsis: l10n.dateEllipsis,
        separator: l10n.dateRangeSeparator,
      );
    }
    return period.localizedLabel(l10n);
  }

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class BudgetsRoute {
  static const path = '/budgets';

  static String location({
    String? budget,
    ExpensePeriod? period,
    String? from,
    String? to,
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) {
    final defaultParams = expenseParamsFromDashboardPeriod(
      defaultDashboardPeriod,
    );
    final resolvedPeriod = period ?? defaultParams.period;
    final resolvedFrom =
        from ??
        (period == null && defaultParams.from != null
            ? BudgetRouteFilters.formatDate(defaultParams.from!)
            : null);
    final resolvedTo =
        to ??
        (period == null && defaultParams.to != null
            ? BudgetRouteFilters.formatDate(defaultParams.to!)
            : null);
    return RouteQuery.build(path, {
      'budget': budget,
      'period': encodeExpensePeriodParam(
        resolvedPeriod: resolvedPeriod,
        defaultParams: defaultParams,
        from: resolvedFrom,
        to: resolvedTo,
        periodWasExplicit: period != null,
      ),
      'from': resolvedFrom,
      'to': resolvedTo,
    });
  }

  static String? budgetFrom(GoRouterState state) => budgetFromUri(state.uri);

  static String? budgetFromUri(Uri uri) => RouteQuery.param(uri, 'budget');

  static BudgetRouteFilters filtersFrom(
    GoRouterState state, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) =>
      filtersFromUri(state.uri, defaultDashboardPeriod: defaultDashboardPeriod);

  static BudgetRouteFilters filtersFromUri(
    Uri uri, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) {
    final defaultParams = expenseParamsFromDashboardPeriod(
      defaultDashboardPeriod,
    );
    final from = _parseDate(RouteQuery.param(uri, 'from'));
    final to = _parseDate(RouteQuery.param(uri, 'to'));
    final hasPeriodParam = uri.queryParameters.containsKey('period');
    final hasCustomDates =
        uri.queryParameters.containsKey('from') ||
        uri.queryParameters.containsKey('to');

    if (!hasPeriodParam && !hasCustomDates) {
      return BudgetRouteFilters(
        period: defaultParams.period,
        from: defaultParams.from,
        to: defaultParams.to,
        defaultDashboardPeriod: defaultDashboardPeriod,
      );
    }

    return BudgetRouteFilters(
      period: RouteQuery.enumFrom(
        uri,
        'period',
        ExpensePeriod.values,
        defaultParams.period,
      ),
      from: from,
      to: to,
      defaultDashboardPeriod: defaultDashboardPeriod,
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
}
