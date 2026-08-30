import 'package:go_router/go_router.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../utils/locale_formatting.dart';
import '../utils/period_defaults.dart';
import 'route_query.dart';

extension ExpensePeriodX on ExpensePeriod {
  String get label => switch (this) {
    ExpensePeriod.week => 'This Week',
    ExpensePeriod.month => 'This Month',
    ExpensePeriod.lastMonth => 'Last Month',
    ExpensePeriod.quarter => 'This Quarter',
    ExpensePeriod.semester => 'This Semester',
    ExpensePeriod.year => 'This Year',
    ExpensePeriod.all => 'All Time',
  };
}

extension TransactionTypeFilterX on TransactionTypeFilter {
  String get label => switch (this) {
    TransactionTypeFilter.all => 'All Types',
    TransactionTypeFilter.expense => 'Expenses',
    TransactionTypeFilter.income => 'Income',
    TransactionTypeFilter.transfer => 'Transfers',
  };
}

class ExpenseRouteFilters {
  final String? category;
  final ExpensePeriod period;
  final TransactionTypeFilter type;
  final String? account;
  final DateTime? from;
  final DateTime? to;
  final TransactionTypeFilter defaultType;
  final DashboardPeriod defaultDashboardPeriod;

  const ExpenseRouteFilters({
    this.category,
    this.period = ExpensePeriod.month,
    this.type = TransactionTypeFilter.expense,
    this.account,
    this.from,
    this.to,
    this.defaultType = TransactionTypeFilter.expense,
    this.defaultDashboardPeriod = kDefaultDashboardPeriod,
  });

  bool get hasCustomDateRange => from != null || to != null;

  ExpensePeriodParams get _defaultPeriodParams =>
      expenseParamsFromDashboardPeriod(defaultDashboardPeriod);

  bool get hasActiveFilters {
    if (category != null || type != defaultType || account != null) {
      return true;
    }
    return !expenseFiltersMatchParams(period, from, to, _defaultPeriodParams);
  }

  String get periodLabel {
    if (hasCustomDateRange) {
      final fromLabel = from != null ? formatDate(from!) : '…';
      final toLabel = to != null ? formatDate(to!) : '…';
      return '$fromLabel – $toLabel';
    }
    return period.label;
  }

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

class TransactionAnalyticsRoute {
  final String path;
  final TransactionTypeFilter defaultType;

  const TransactionAnalyticsRoute({
    required this.path,
    required this.defaultType,
  });

  String location({
    String? category,
    ExpensePeriod? period,
    TransactionTypeFilter? type,
    String? account,
    String? from,
    String? to,
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) {
    final defaultParams = expenseParamsFromDashboardPeriod(
      defaultDashboardPeriod,
    );
    final resolvedPeriod = period ?? defaultParams.period;
    final resolvedType = type ?? defaultType;
    final resolvedFrom =
        from ??
        (period == null && defaultParams.from != null
            ? ExpenseRouteFilters.formatDate(defaultParams.from!)
            : null);
    final resolvedTo =
        to ??
        (period == null && defaultParams.to != null
            ? ExpenseRouteFilters.formatDate(defaultParams.to!)
            : null);
    return RouteQuery.build(path, {
      'category': category,
      'period': encodeExpensePeriodParam(
        resolvedPeriod: resolvedPeriod,
        defaultParams: defaultParams,
        from: resolvedFrom,
        to: resolvedTo,
        periodWasExplicit: period != null,
      ),
      'type': resolvedType != defaultType ? resolvedType.name : null,
      'account': account,
      'from': resolvedFrom,
      'to': resolvedTo,
    });
  }

  ExpenseRouteFilters filtersFrom(
    GoRouterState state, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) =>
      filtersFromUri(state.uri, defaultDashboardPeriod: defaultDashboardPeriod);

  ExpenseRouteFilters filtersFromUri(
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
      return ExpenseRouteFilters(
        category: RouteQuery.param(uri, 'category'),
        period: defaultParams.period,
        type: RouteQuery.enumFrom(
          uri,
          'type',
          TransactionTypeFilter.values,
          defaultType,
        ),
        account: RouteQuery.param(uri, 'account'),
        from: defaultParams.from,
        to: defaultParams.to,
        defaultType: defaultType,
        defaultDashboardPeriod: defaultDashboardPeriod,
      );
    }

    return ExpenseRouteFilters(
      category: RouteQuery.param(uri, 'category'),
      period: RouteQuery.enumFrom(
        uri,
        'period',
        ExpensePeriod.values,
        defaultParams.period,
      ),
      type: RouteQuery.enumFrom(
        uri,
        'type',
        TransactionTypeFilter.values,
        defaultType,
      ),
      account: RouteQuery.param(uri, 'account'),
      from: from,
      to: to,
      defaultType: defaultType,
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

const expensesAnalyticsRoute = TransactionAnalyticsRoute(
  path: '/expenses',
  defaultType: TransactionTypeFilter.expense,
);

const incomeAnalyticsRoute = TransactionAnalyticsRoute(
  path: '/income',
  defaultType: TransactionTypeFilter.income,
);

const transfersAnalyticsRoute = TransactionAnalyticsRoute(
  path: '/transfers',
  defaultType: TransactionTypeFilter.transfer,
);
