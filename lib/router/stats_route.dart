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
    ExpensePeriod.lastYear => 'Last Year',
    ExpensePeriod.last3Years => 'Last 3 Years',
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

/// The kinds of movement Stats can show, in the order the page lists them.
const statsTypes = [
  TransactionTypeFilter.expense,
  TransactionTypeFilter.income,
  TransactionTypeFilter.transfer,
];

class StatsRouteFilters {
  static const defaultTypes = {TransactionTypeFilter.expense};

  /// Which of [statsTypes] are shown; never empty and never holds `all`.
  final Set<TransactionTypeFilter> types;
  final String? category;
  final String? tag;
  final String? budget;
  final ExpensePeriod period;
  final String? account;
  final DateTime? from;
  final DateTime? to;
  final DashboardPeriod defaultDashboardPeriod;

  const StatsRouteFilters({
    this.types = defaultTypes,
    this.category,
    this.tag,
    this.budget,
    this.period = ExpensePeriod.month,
    this.account,
    this.from,
    this.to,
    this.defaultDashboardPeriod = kDefaultDashboardPeriod,
  });

  /// [types] in page order, whatever order the link named them in.
  List<TransactionTypeFilter> get orderedTypes =>
      statsTypes.where(types.contains).toList();

  /// The one type shown, or `null` when several are.
  TransactionTypeFilter? get singleType =>
      types.length == 1 ? types.first : null;

  bool get hasCustomDateRange => from != null || to != null;

  ExpensePeriodParams get _defaultPeriodParams =>
      expenseParamsFromDashboardPeriod(defaultDashboardPeriod);

  bool get hasActiveFilters {
    if (category != null || tag != null || budget != null || account != null) {
      return true;
    }
    if (!_sameTypes(types, defaultTypes)) return true;
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

  /// This view with the named filters changed and the rest kept.
  ///
  /// A filter passed as `null` is cleared. Choosing a [period] drops custom
  /// dates, and passing [from] and [to] replaces the period with them.
  String location({
    Set<TransactionTypeFilter>? types,
    Object? category = _keep,
    Object? tag = _keep,
    Object? budget = _keep,
    Object? account = _keep,
    ExpensePeriod? period,
    DateTime? from,
    DateTime? to,
  }) {
    final hasNewDates = from != null || to != null;
    final keepDates = period == null && !hasNewDates;
    final datedFrom = keepDates ? this.from : from;
    final datedTo = keepDates ? this.to : to;
    return StatsRoute.location(
      types: types ?? this.types,
      category: _pick(category, this.category),
      tag: _pick(tag, this.tag),
      budget: _pick(budget, this.budget),
      account: _pick(account, this.account),
      period: hasNewDates ? null : (period ?? this.period),
      from: datedFrom != null ? formatDate(datedFrom) : null,
      to: datedTo != null ? formatDate(datedTo) : null,
      defaultDashboardPeriod: defaultDashboardPeriod,
    );
  }

  static const _keep = Object();

  static String? _pick(Object? change, String? current) =>
      identical(change, _keep) ? current : change as String?;

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

bool _sameTypes(Set<TransactionTypeFilter> a, Set<TransactionTypeFilter> b) =>
    a.length == b.length && a.containsAll(b);

class StatsRoute {
  static const path = '/stats';

  static String location({
    Set<TransactionTypeFilter> types = StatsRouteFilters.defaultTypes,
    String? category,
    String? tag,
    String? budget,
    ExpensePeriod? period,
    String? account,
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
            ? StatsRouteFilters.formatDate(defaultParams.from!)
            : null);
    final resolvedTo =
        to ??
        (period == null && defaultParams.to != null
            ? StatsRouteFilters.formatDate(defaultParams.to!)
            : null);
    final shown = statsTypes.where(types.contains);
    return RouteQuery.build(path, {
      'types':
          _sameTypes(types, StatsRouteFilters.defaultTypes) || shown.isEmpty
          ? null
          : shown.map((type) => type.name).join(','),
      'category': category,
      'tag': tag,
      'budget': budget,
      'period': encodeExpensePeriodParam(
        resolvedPeriod: resolvedPeriod,
        defaultParams: defaultParams,
        from: resolvedFrom,
        to: resolvedTo,
        periodWasExplicit: period != null,
      ),
      'account': account,
      'from': resolvedFrom,
      'to': resolvedTo,
    });
  }

  static StatsRouteFilters filtersFrom(
    GoRouterState state, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) =>
      filtersFromUri(state.uri, defaultDashboardPeriod: defaultDashboardPeriod);

  static StatsRouteFilters filtersFromUri(
    Uri uri, {
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
  }) {
    final defaultParams = expenseParamsFromDashboardPeriod(
      defaultDashboardPeriod,
    );
    final hasPeriodParam = uri.queryParameters.containsKey('period');
    final hasCustomDates =
        uri.queryParameters.containsKey('from') ||
        uri.queryParameters.containsKey('to');
    final useDefaultPeriod = !hasPeriodParam && !hasCustomDates;

    return StatsRouteFilters(
      types: typesFromUri(uri),
      category: RouteQuery.param(uri, 'category'),
      tag: RouteQuery.param(uri, 'tag'),
      budget: RouteQuery.param(uri, 'budget'),
      period: useDefaultPeriod
          ? defaultParams.period
          : RouteQuery.enumFrom(
              uri,
              'period',
              ExpensePeriod.values,
              defaultParams.period,
            ),
      account: RouteQuery.param(uri, 'account'),
      from: useDefaultPeriod
          ? defaultParams.from
          : _parseDate(RouteQuery.param(uri, 'from')),
      to: useDefaultPeriod
          ? defaultParams.to
          : _parseDate(RouteQuery.param(uri, 'to')),
      defaultDashboardPeriod: defaultDashboardPeriod,
    );
  }

  /// The types named in `types`, skipping anything unrecognised; a link
  /// that names none of them shows the default rather than an empty page.
  static Set<TransactionTypeFilter> typesFromUri(Uri uri) {
    final raw = RouteQuery.param(uri, 'types');
    if (raw == null) return StatsRouteFilters.defaultTypes;
    final named = raw.split(',').map((name) => name.trim()).toSet();
    final types = statsTypes.where((type) => named.contains(type.name)).toSet();
    return types.isEmpty ? StatsRouteFilters.defaultTypes : types;
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
