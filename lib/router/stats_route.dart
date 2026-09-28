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

/// What the page lays its totals out along: one of the ways to break a
/// total down, or time.
enum StatsGrouping { category, tag, budget, account, payee, time }

/// How the totals are drawn. A breakdown takes a donut or ranked bars, a
/// series over time takes bars, stacked bars or lines.
enum StatsChart { donut, bars, stacked, line }

/// What stacked bars over time are cut into.
enum StatsSplit { category, tag, budget }

const _breakdownCharts = [StatsChart.donut, StatsChart.bars];
const _timeCharts = [StatsChart.bars, StatsChart.stacked, StatsChart.line];

class StatsRouteFilters {
  static const defaultTypes = {
    TransactionTypeFilter.expense,
    TransactionTypeFilter.income,
  };

  /// Which of [statsTypes] are shown; never empty and never holds `all`.
  final Set<TransactionTypeFilter> types;

  /// Each narrows to legs matching any one of its names; empty narrows
  /// nothing.
  final Set<String> categories;
  final Set<String> tags;
  final Set<String> budgets;
  final Set<String> accounts;
  final ExpensePeriod period;
  final DateTime? from;
  final DateTime? to;
  final DashboardPeriod defaultDashboardPeriod;

  /// How the page is laid out rather than what it counts, so clearing the
  /// filters leaves these alone. A `null` [interval] follows the period.
  final StatsGrouping grouping;
  final StatsInterval? interval;

  /// As the link named it; [effectiveChart] is what is drawn.
  final StatsChart? chart;
  final StatsSplit split;
  final bool showNet;

  const StatsRouteFilters({
    this.types = defaultTypes,
    this.categories = const {},
    this.tags = const {},
    this.budgets = const {},
    this.accounts = const {},
    this.period = ExpensePeriod.month,
    this.from,
    this.to,
    this.defaultDashboardPeriod = kDefaultDashboardPeriod,
    this.grouping = StatsGrouping.category,
    this.interval,
    this.chart,
    this.split = StatsSplit.category,
    this.showNet = false,
  });

  bool get overTime => grouping == StatsGrouping.time;

  /// The charts [grouping] can be drawn as, the default first.
  List<StatsChart> get charts => overTime ? _timeCharts : _breakdownCharts;

  /// [chart] when it suits [grouping], else that grouping's default.
  StatsChart get effectiveChart =>
      chart != null && charts.contains(chart) ? chart! : charts.first;

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
    if (categories.isNotEmpty ||
        tags.isNotEmpty ||
        budgets.isNotEmpty ||
        accounts.isNotEmpty) {
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
  /// A filter passed as an empty set is cleared. Choosing a [period] drops
  /// custom dates, and passing [from] and [to] replaces the period with them.
  String location({
    Set<TransactionTypeFilter>? types,
    Set<String>? categories,
    Set<String>? tags,
    Set<String>? budgets,
    Set<String>? accounts,
    ExpensePeriod? period,
    DateTime? from,
    DateTime? to,
    StatsGrouping? grouping,
    StatsInterval? interval,
    bool autoInterval = false,
    StatsChart? chart,
    StatsSplit? split,
    bool? showNet,
  }) {
    // Crossing between a breakdown and time leaves the chart behind, since
    // no chart suits both.
    final nextGrouping = grouping ?? this.grouping;
    final crossed =
        (nextGrouping == StatsGrouping.time) !=
        (this.grouping == StatsGrouping.time);
    final hasNewDates = from != null || to != null;
    final keepDates = period == null && !hasNewDates;
    final datedFrom = keepDates ? this.from : from;
    final datedTo = keepDates ? this.to : to;
    return StatsRoute.location(
      types: types ?? this.types,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      budgets: budgets ?? this.budgets,
      accounts: accounts ?? this.accounts,
      period: hasNewDates ? null : (period ?? this.period),
      from: datedFrom != null ? formatDate(datedFrom) : null,
      to: datedTo != null ? formatDate(datedTo) : null,
      defaultDashboardPeriod: defaultDashboardPeriod,
      grouping: grouping ?? this.grouping,
      interval: autoInterval ? null : (interval ?? this.interval),
      chart: chart ?? (crossed ? null : this.chart),
      split: split ?? this.split,
      showNet: showNet ?? this.showNet,
    );
  }

  /// Every filter back to its default, the layout kept.
  String get clearedLocation => StatsRoute.location(
    defaultDashboardPeriod: defaultDashboardPeriod,
    grouping: grouping,
    interval: interval,
    chart: chart,
    split: split,
    showNet: showNet,
  );

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

bool _sameTypes(Set<TransactionTypeFilter> a, Set<TransactionTypeFilter> b) =>
    a.length == b.length && a.containsAll(b);

class StatsRoute {
  static const path = '/stats';

  static String location({
    Set<TransactionTypeFilter> types = StatsRouteFilters.defaultTypes,
    Iterable<String> categories = const [],
    Iterable<String> tags = const [],
    Iterable<String> budgets = const [],
    ExpensePeriod? period,
    Iterable<String> accounts = const [],
    String? from,
    String? to,
    DashboardPeriod defaultDashboardPeriod = kDefaultDashboardPeriod,
    StatsGrouping grouping = StatsGrouping.category,
    StatsInterval? interval,
    StatsChart? chart,
    StatsSplit split = StatsSplit.category,
    bool showNet = false,
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
      'category': categories,
      'tag': tags,
      'budget': budgets,
      'period': encodeExpensePeriodParam(
        resolvedPeriod: resolvedPeriod,
        defaultParams: defaultParams,
        from: resolvedFrom,
        to: resolvedTo,
        periodWasExplicit: period != null,
      ),
      'account': accounts,
      'from': resolvedFrom,
      'to': resolvedTo,
      'view': grouping == StatsGrouping.category ? null : grouping.name,
      'interval': interval?.name,
      'chart': chart?.name,
      'split': split == StatsSplit.category ? null : split.name,
      'net': showNet ? '1' : null,
    });
  }

  /// The paths Stats replaced, each with the type it showed by default.
  static const retiredPaths = {
    '/expenses': TransactionTypeFilter.expense,
    '/income': TransactionTypeFilter.income,
    '/transfers': TransactionTypeFilter.transfer,
  };

  /// Where a link to one of [retiredPaths] lands now. Its filters come along,
  /// and its single `type` becomes `types`, with `all` meaning all three.
  /// None of those is the two-type default, so `types` is always written.
  static String fromRetiredLink(Uri uri) {
    final named = RouteQuery.enumFrom(
      uri,
      'type',
      TransactionTypeFilter.values,
      retiredPaths[uri.path] ?? TransactionTypeFilter.expense,
    );
    final types = named == TransactionTypeFilter.all
        ? statsTypes.toSet()
        : {named};
    final params = Map<String, Object?>.from(uri.queryParametersAll)
      ..remove('type');
    params['types'] = statsTypes
        .where(types.contains)
        .map((type) => type.name)
        .join(',');
    return RouteQuery.build(path, params);
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
      categories: RouteQuery.values(uri, 'category'),
      tags: RouteQuery.values(uri, 'tag'),
      budgets: RouteQuery.values(uri, 'budget'),
      period: useDefaultPeriod
          ? defaultParams.period
          : RouteQuery.enumFrom(
              uri,
              'period',
              ExpensePeriod.values,
              defaultParams.period,
            ),
      accounts: RouteQuery.values(uri, 'account'),
      from: useDefaultPeriod
          ? defaultParams.from
          : _parseDate(RouteQuery.param(uri, 'from')),
      to: useDefaultPeriod
          ? defaultParams.to
          : _parseDate(RouteQuery.param(uri, 'to')),
      defaultDashboardPeriod: defaultDashboardPeriod,
      grouping: RouteQuery.enumFrom(
        uri,
        'view',
        StatsGrouping.values,
        StatsGrouping.category,
      ),
      interval: _intervalFrom(uri),
      chart: _enumOrNull(uri, 'chart', StatsChart.values),
      split: RouteQuery.enumFrom(
        uri,
        'split',
        StatsSplit.values,
        StatsSplit.category,
      ),
      showNet: RouteQuery.param(uri, 'net') == '1',
    );
  }

  static StatsInterval? _intervalFrom(Uri uri) =>
      _enumOrNull(uri, 'interval', StatsInterval.values);

  static T? _enumOrNull<T extends Enum>(Uri uri, String key, List<T> values) {
    final raw = RouteQuery.param(uri, key);
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
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
