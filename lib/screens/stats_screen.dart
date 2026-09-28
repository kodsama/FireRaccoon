import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../l10n/fun_l10n.dart';
import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../providers/default_period_provider.dart';
import '../providers/people_providers.dart';
import '../providers/theme_provider.dart';
import '../providers/transaction_analytics_providers.dart';
import '../router/route_navigation.dart';
import '../router/route_query.dart';
import '../router/stats_route.dart';
import '../router/transactions_route.dart';
import '../theme/app_theme.dart';
import '../utils/create_flows.dart';
import '../utils/display_labels.dart';
import '../utils/locale_formatting.dart';
import '../utils/stats_breakdown.dart';
import '../widgets/entity_screen_header.dart';
import '../widgets/filter_pill.dart';
import '../widgets/loading_body.dart';
import '../widgets/name_filter_dialog.dart';
import '../widgets/simple_charts.dart';
import '../widgets/stats_over_time.dart';
import '../widgets/words_filter_dialog.dart';

/// Expenses, income and transfers on one page, any mix of them, narrowed by
/// category, tag, budget, account, period and words.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final format = ref.watch(localeFormattingProvider);
    final defaultPeriod = ref.watch(defaultDashboardPeriodProvider);
    final uri = GoRouterState.of(context).uri;
    final filters = StatsRoute.filtersFrom(
      GoRouterState.of(context),
      defaultDashboardPeriod: defaultPeriod,
    );
    final words = RouteQuery.searchFrom(uri);
    final transactionsAsync = ref.watch(
      statsTransactionsProvider(filters.scope),
    );
    final range = resolveExpenseDateRange(
      period: filters.period,
      customFrom: filters.from,
      customTo: filters.to,
    );
    final overTime = filters.overTime;
    final interval = filters.interval ?? autoStatsInterval(range);
    final breakdown = transactionsAsync.whenData(
      (transactions) => buildStatsBreakdown(
        transactions,
        types: filters.orderedTypes,
        categories: filters.categories,
        tags: filters.tags,
        budgets: filters.budgets,
        accounts: filters.accounts,
        words: words,
        grouping: overTime ? StatsGrouping.category : filters.grouping,
        interval: overTime ? interval : null,
        split: overTime && filters.effectiveChart == StatsChart.stacked
            ? filters.split
            : null,
        range: range,
      ),
    );
    final options = breakdown.asData?.value;
    final singleType = filters.singleType;

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EntityScreenHeader(
              title: fun.statsTitle,
              subtitle: _filterSummary(l10n, format, filters, words, fun),
              createLabel: switch (singleType) {
                TransactionTypeFilter.expense => fun.newExpense,
                TransactionTypeFilter.income => fun.newIncome,
                TransactionTypeFilter.transfer => fun.newTransfer,
                _ => fun.newTransaction,
              },
              onCreate: () => openNewTransactionFlow(
                context,
                ref,
                type: transactionTypeForFilter(
                  singleType ?? TransactionTypeFilter.expense,
                )!,
                lockType: singleType != null,
                invalidateTransactions: true,
              ),
              trailing: [
                if (filters.hasActiveFilters || words != null)
                  Tooltip(
                    message: l10n.clearFilters,
                    child: TextButton(
                      onPressed: () => context.go(filters.clearedLocation),
                      child: Text(l10n.clearFilters),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _TypeToggles(filters: filters, fun: fun),
            const SizedBox(height: 12),
            _ViewControls(filters: filters, autoInterval: interval),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _PeriodFilterButton(filters: filters),
                _NamesFilterButton(
                  icon: LucideIcons.folder,
                  idleLabel: l10n.category,
                  emptyLabel: l10n.noCategoriesFound,
                  names: options?.categories ?? const [],
                  selected: filters.categories,
                  labelOf: (name) => displayLabelOrUnknown(name, l10n),
                  onPicked: (names) => filters.location(categories: names),
                ),
                _NamesFilterButton(
                  icon: LucideIcons.tag,
                  idleLabel: l10n.filterTag,
                  emptyLabel: l10n.noTagsFound,
                  names: options?.tags ?? const [],
                  selected: filters.tags,
                  onPicked: (names) => filters.location(tags: names),
                ),
                _NamesFilterButton(
                  icon: LucideIcons.target,
                  idleLabel: l10n.filterBudget,
                  emptyLabel: l10n.noBudgetsFound,
                  names: options?.budgets ?? const [],
                  selected: filters.budgets,
                  onPicked: (names) => filters.location(budgets: names),
                ),
                _WordsFilterButton(words: words),
                _NamesFilterButton(
                  icon: LucideIcons.wallet,
                  idleLabel: l10n.accountFilterLabel,
                  emptyLabel: l10n.noAccountsFound,
                  names: [
                    for (final account in ref.watch(ownedAccountsProvider))
                      account.name,
                  ],
                  selected: filters.accounts,
                  onPicked: (names) => filters.location(accounts: names),
                ),
                _DateRangeFilterButton(filters: filters),
              ],
            ),
            const SizedBox(height: 24),
            breakdown.when(
              skipLoadingOnReload: true,
              loading: () => const LoadingBody(),
              error: (e, st) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.errorGeneric(e.toString())),
              ),
              data: (breakdown) => overTime
                  ? _StatsOverTimeBody(
                      breakdown: breakdown,
                      filters: filters,
                      interval: interval,
                      currency:
                          ref.watch(primaryCurrencyProvider).value?.symbol ??
                          '€',
                      format: format,
                      fun: fun,
                    )
                  : _StatsBody(
                      key: ValueKey('${filters.scope.hashCode}|$uri'),
                      breakdown: breakdown,
                      filters: filters,
                      currency: ref
                          .watch(primaryCurrencyProvider)
                          .value
                          ?.symbol,
                      format: format,
                      l10n: l10n,
                      fun: fun,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterSummary(
    AppLocalizations l10n,
    LocaleFormatting format,
    StatsRouteFilters filters,
    String? words,
    FunL10n fun,
  ) {
    final parts = <String>[
      filters.localizedPeriodLabel(l10n, format),
      filters.orderedTypes
          .map((type) => type.localizedLabel(l10n, isRaccoon: fun.isRaccoon))
          .join(' + '),
      for (final category in filters.categories)
        displayLabelOrUnknown(category, l10n),
      ...filters.tags,
      ...filters.budgets,
      ...filters.accounts,
      if (words != null) '"$words"',
    ];
    return parts.join(' · ');
  }
}

/// The transaction list holding what Stats counted, narrowed further to a
/// category, tag, budget or account, a [type], or the days from [from] to
/// [to] when given.
String _transactionsFor(
  StatsRouteFilters filters, {
  String? category,
  String? tag,
  String? budget,
  String? account,
  TransactionTypeFilter? type,
  DateTime? from,
  DateTime? to,
}) {
  String? date(DateTime? value) =>
      value == null ? null : StatsRouteFilters.formatDate(value);
  final dated = from != null || to != null;
  return TransactionsRoute.location(
    categories: category != null ? [category] : filters.categories,
    tags: tag != null ? [tag] : filters.tags,
    budgets: budget != null ? [budget] : filters.budgets,
    period: filters.period,
    type: type ?? filters.singleType ?? TransactionTypeFilter.all,
    accounts: account != null ? [account] : filters.accounts.toList(),
    from: date(dated ? from : filters.from),
    to: date(dated ? to : filters.to),
    defaultDashboardPeriod: filters.defaultDashboardPeriod,
  );
}

class _StatsBody extends StatefulWidget {
  final StatsBreakdown breakdown;
  final StatsRouteFilters filters;
  final String? currency;
  final LocaleFormatting format;
  final AppLocalizations l10n;
  final FunL10n fun;

  const _StatsBody({
    super.key,
    required this.breakdown,
    required this.filters,
    required this.currency,
    required this.format,
    required this.l10n,
    required this.fun,
  });

  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody> {
  /// Categories unticked in the legend, keyed per type because the same
  /// category can hold both spending and income.
  final Set<String> _hidden = {};

  String _hiddenKey(TransactionTypeFilter type, String category) =>
      '${type.name}|$category';

  List<Color> _chartColors(BuildContext context) {
    final colors = context.colors;
    return [
      colors.accent.acc,
      colors.accent.deep,
      colors.warning,
      colors.danger,
      colors.success,
      colors.text3,
    ];
  }

  String _money(double amount) =>
      widget.format.formatMoney(amount, widget.currency ?? '€');

  String _typeLabel(TransactionTypeFilter type) =>
      type.localizedLabel(widget.l10n, isRaccoon: widget.fun.isRaccoon);

  String _transactionsLocation() => _transactionsFor(widget.filters);

  StatsGrouping get _grouping => widget.filters.grouping;

  String _label(String key) => switch (_grouping) {
    StatsGrouping.tag ||
    StatsGrouping.budget => key.isEmpty ? widget.l10n.none : key,
    _ => displayLabelOrUnknown(key, widget.l10n),
  };

  /// The names the filter on the grouping's own dimension holds, which the
  /// chart narrows to while the list keeps showing the rest.
  Set<String> get _selectedKeys => switch (_grouping) {
    StatsGrouping.category =>
      widget.filters.categories.map(categoryGroupKey).toSet(),
    StatsGrouping.tag => widget.filters.tags,
    StatsGrouping.budget => widget.filters.budgets,
    StatsGrouping.account => widget.filters.accounts,
    StatsGrouping.payee || StatsGrouping.time => const {},
  };

  /// The transactions behind one row. Legs with no tag or no budget have
  /// no filter that finds them alone, so their row opens the whole list.
  String _transactionsForGroup(String key, TransactionTypeFilter type) {
    final filters = widget.filters;
    return switch (_grouping) {
      StatsGrouping.tag when key.isNotEmpty => _transactionsFor(
        filters,
        tag: key,
        type: type,
      ),
      StatsGrouping.budget when key.isNotEmpty => _transactionsFor(
        filters,
        budget: key,
        type: type,
      ),
      StatsGrouping.account || StatsGrouping.payee when key.isNotEmpty =>
        _transactionsFor(filters, account: key, type: type),
      StatsGrouping.category => _transactionsFor(
        filters,
        category: key,
        type: type,
      ),
      _ => _transactionsFor(filters, type: type),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final breakdown = widget.breakdown;
    final chartColors = _chartColors(context);
    final multiple = breakdown.types.length > 1;
    final net = breakdown.net;
    final selectedKeys = _selectedKeys;
    final asBars = widget.filters.effectiveChart == StatsChart.bars;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(l10n.overview, style: context.textTheme.titleMedium),
                const SizedBox(height: 32),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 48,
                  runSpacing: 32,
                  children: [
                    for (final totals in breakdown.types)
                      asBars
                          ? _rankedBars(
                              context,
                              totals: totals,
                              selectedKeys: selectedKeys,
                              chartColors: chartColors,
                              width: multiple ? 420 : 720,
                            )
                          : _typeOverview(
                              context,
                              totals,
                              selectedKeys: selectedKeys,
                              chartColors: chartColors,
                              size: multiple ? 180 : 240,
                            ),
                  ],
                ),
                if (net != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    '${l10n.netFlow}: ${_money(net)}',
                    style: const TextStyle(
                      fontFamily: 'Roboto Slab',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ViewControls.groupingLabel(l10n, _grouping),
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                for (final totals in breakdown.types) ...[
                  if (multiple)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _typeLabel(totals.type),
                              style: context.textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            _money(totals.total),
                            style: const TextStyle(
                              fontFamily: 'Roboto Slab',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ..._legendRows(context, totals, chartColors),
                ],
              ],
            ),
          ),
        ),
        if (breakdown.transactions.isNotEmpty) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.transactionsCount(breakdown.transactions.length),
                  style: context.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 16),
              Tooltip(
                message: l10n.tooltipOpenTransactions,
                child: TextButton.icon(
                  onPressed: () =>
                      context.goPreservingSearch(_transactionsLocation()),
                  icon: const Icon(LucideIcons.arrowLeftRight),
                  label: Text(l10n.navTransactions),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _typeOverview(
    BuildContext context,
    StatsTypeTotals totals, {
    required Set<String> selectedKeys,
    required List<Color> chartColors,
    required double size,
  }) {
    final colors = context.colors;
    final values = <double>[];
    final sliceColors = <Color>[];
    final legend = totals.sortedGroups;
    for (var i = 0; i < legend.length; i++) {
      final entry = legend[i];
      if (selectedKeys.isNotEmpty && !selectedKeys.contains(entry.key)) {
        continue;
      }
      if (_hidden.contains(_hiddenKey(totals.type, entry.key))) continue;
      values.add(entry.value);
      sliceColors.add(chartColors[i % chartColors.length]);
    }
    final shownTotal = values.fold<double>(0, (sum, value) => sum + value);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (values.isEmpty)
          SizedBox(
            height: size,
            width: size,
            child: Center(
              child: Text(
                widget.l10n.noTransactionsMatchFilters,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.text3),
              ),
            ),
          )
        else
          SimpleDonutChart(
            values: values,
            sliceColors: sliceColors,
            size: size,
          ),
        const SizedBox(height: 24),
        Text(
          _money(shownTotal),
          style: const TextStyle(
            fontFamily: 'Roboto Slab',
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(_typeLabel(totals.type), style: TextStyle(color: colors.text3)),
      ],
    );
  }

  /// The largest groups of one type as columns, largest first, coloured as
  /// in the list below, each opening its transactions.
  Widget _rankedBars(
    BuildContext context, {
    required StatsTypeTotals totals,
    required Set<String> selectedKeys,
    required List<Color> chartColors,
    required double width,
  }) {
    final colors = context.colors;
    final legend = totals.sortedGroups;
    final rows = <(int, MapEntry<String, double>)>[
      for (var i = 0; i < legend.length; i++)
        if ((selectedKeys.isEmpty || selectedKeys.contains(legend[i].key)) &&
            !_hidden.contains(_hiddenKey(totals.type, legend[i].key)))
          (i, legend[i]),
    ].take(12).toList();
    final shownTotal = rows.fold<double>(0, (sum, row) => sum + row.$2.value);
    final labelStyle = TextStyle(color: colors.text3, fontSize: 11);
    // Names turn to fit under a column once each has under ~90px of axis.
    final slanted = rows.length * 90 > width - 56;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _money(shownTotal),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Roboto Slab',
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _typeLabel(totals.type),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.text3),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(
              widget.l10n.noTransactionsMatchFilters,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.text3),
            )
          else
            SizedBox(
              height: slanted ? 320 : 280,
              child: BarChart(
                BarChartData(
                  barGroups: [
                    for (var i = 0; i < rows.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: rows[i].$2.value,
                            color: chartColors[rows[i].$1 % chartColors.length],
                            width: ((width - 56) / rows.length * 0.6).clamp(
                              6.0,
                              36.0,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                  ],
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: colors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        minIncluded: false,
                        maxIncluded: false,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            widget.format.formatCompactNumber(value),
                            style: labelStyle,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: slanted ? 72 : 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= rows.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            angle: slanted ? -0.6 : 0,
                            child: SizedBox(
                              width: slanted ? 80 : null,
                              child: Text(
                                _label(rows[index].$2.key),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: labelStyle,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => colors.surface2,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                            '${_label(rows[groupIndex].$2.key)}\n'
                            '${_money(rod.toY)}',
                            TextStyle(
                              color: rod.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    ),
                    touchCallback: (event, response) {
                      final spot = response?.spot;
                      if (event is FlTapUpEvent && spot != null) {
                        context.goPreservingSearch(
                          _transactionsForGroup(
                            rows[spot.touchedBarGroupIndex].$2.key,
                            totals.type,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _legendRows(
    BuildContext context,
    StatsTypeTotals totals,
    List<Color> chartColors,
  ) {
    final colors = context.colors;
    final legend = totals.sortedGroups;
    if (legend.isEmpty) {
      return [
        Text(
          widget.l10n.noTransactionsMatchFilters,
          style: TextStyle(color: colors.text3),
        ),
      ];
    }
    final selectedKeys = _selectedKeys;
    final grandTotal = totals.total;

    return List.generate(legend.length, (index) {
      final entry = legend[index];
      final hiddenKey = _hiddenKey(totals.type, entry.key);
      final isVisible = !_hidden.contains(hiddenKey);
      final isSelected = selectedKeys.contains(entry.key);
      final percentage = grandTotal > 0 ? entry.value / grandTotal * 100 : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Checkbox(
              value: isVisible,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (checked) {
                if (checked == null) return;
                setState(() {
                  if (checked) {
                    _hidden.remove(hiddenKey);
                  } else {
                    _hidden.add(hiddenKey);
                  }
                });
              },
            ),
            Expanded(
              child: InkWell(
                onTap: () => context.goPreservingSearch(
                  _transactionsForGroup(entry.key, totals.type),
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Opacity(
                    opacity: isVisible ? 1.0 : 0.45,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: chartColors[index % chartColors.length],
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: colors.text, width: 2)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _label(entry.key),
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${widget.format.formatPercent(percentage)}%',
                          style: TextStyle(color: colors.text3),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _money(entry.value),
                          style: const TextStyle(
                            fontFamily: 'Roboto Slab',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// How the page lays out what it counts: broken down by one dimension as a
/// donut or ranked bars, or over time with an interval, bars, stacked bars
/// or lines, and an optional net series.
class _ViewControls extends StatelessWidget {
  static const _automatic = 'automatic';

  final StatsRouteFilters filters;

  /// The interval the period picks when none is chosen, named in the menu.
  final StatsInterval autoInterval;

  const _ViewControls({required this.filters, required this.autoInterval});

  static String intervalLabel(AppLocalizations l10n, StatsInterval interval) =>
      switch (interval) {
        StatsInterval.day => l10n.statsIntervalDay,
        StatsInterval.week => l10n.statsIntervalWeek,
        StatsInterval.month => l10n.statsIntervalMonth,
        StatsInterval.quarter => l10n.statsIntervalQuarter,
        StatsInterval.year => l10n.statsIntervalYear,
      };

  static String groupingLabel(AppLocalizations l10n, StatsGrouping grouping) =>
      switch (grouping) {
        StatsGrouping.category => l10n.statsByCategory,
        StatsGrouping.tag => l10n.statsByTag,
        StatsGrouping.budget => l10n.statsByBudget,
        StatsGrouping.account => l10n.statsByAccount,
        StatsGrouping.payee => l10n.statsByPayee,
        StatsGrouping.time => l10n.statsOverTime,
      };

  static String splitLabel(AppLocalizations l10n, StatsSplit split) =>
      switch (split) {
        StatsSplit.category => l10n.statsStackedByCategory,
        StatsSplit.tag => l10n.statsStackedByTag,
        StatsSplit.budget => l10n.statsStackedByBudget,
      };

  static IconData _groupingIcon(StatsGrouping grouping) => switch (grouping) {
    StatsGrouping.category => LucideIcons.folder,
    StatsGrouping.tag => LucideIcons.tag,
    StatsGrouping.budget => LucideIcons.target,
    StatsGrouping.account => LucideIcons.wallet,
    StatsGrouping.payee => LucideIcons.store,
    StatsGrouping.time => LucideIcons.chartColumn,
  };

  static (IconData, String) _chart(AppLocalizations l10n, StatsChart chart) =>
      switch (chart) {
        StatsChart.donut => (LucideIcons.chartPie, l10n.statsChartDonut),
        StatsChart.bars => (LucideIcons.chartColumn, l10n.statsChartBars),
        StatsChart.stacked => (
          LucideIcons.chartColumnStacked,
          l10n.statsChartStacked,
        ),
        StatsChart.line => (LucideIcons.chartLine, l10n.statsChartLine),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overTime = filters.overTime;
    final chart = filters.effectiveChart;
    final canNet =
        filters.types.contains(TransactionTypeFilter.expense) &&
        filters.types.contains(TransactionTypeFilter.income);
    final chosen = filters.interval;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PopupMenuButton<StatsGrouping>(
          onSelected: (grouping) =>
              context.goPreservingSearch(filters.location(grouping: grouping)),
          itemBuilder: (context) => [
            for (final grouping in StatsGrouping.values) ...[
              if (grouping == StatsGrouping.time) const PopupMenuDivider(),
              PopupMenuItem(
                value: grouping,
                child: Row(
                  children: [
                    Icon(_groupingIcon(grouping), size: 16),
                    const SizedBox(width: 12),
                    Text(groupingLabel(l10n, grouping)),
                  ],
                ),
              ),
            ],
          ],
          child: FilterPill(
            icon: _groupingIcon(filters.grouping),
            label: groupingLabel(l10n, filters.grouping),
          ),
        ),
        SegmentedButton<StatsChart>(
          showSelectedIcon: false,
          segments: [
            for (final option in filters.charts)
              ButtonSegment(
                value: option,
                icon: Icon(_chart(l10n, option).$1, size: 16),
                label: Text(_chart(l10n, option).$2),
              ),
          ],
          selected: {chart},
          onSelectionChanged: (value) =>
              context.goPreservingSearch(filters.location(chart: value.single)),
        ),
        if (overTime) ...[
          // A menu treats a null pick as dismissed, so automatic has a value
          // of its own.
          PopupMenuButton<Object>(
            onSelected: (picked) => context.goPreservingSearch(
              picked is StatsInterval
                  ? filters.location(interval: picked)
                  : filters.location(autoInterval: true),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _automatic,
                child: Text(
                  '${l10n.statsIntervalAuto} · ${intervalLabel(l10n, autoInterval)}',
                ),
              ),
              const PopupMenuDivider(),
              for (final interval in StatsInterval.values)
                PopupMenuItem(
                  value: interval,
                  child: Text(intervalLabel(l10n, interval)),
                ),
            ],
            child: FilterPill(
              icon: LucideIcons.calendarDays,
              label: intervalLabel(l10n, chosen ?? autoInterval),
              tooltip: chosen == null ? l10n.statsIntervalAuto : null,
            ),
          ),
          if (chart == StatsChart.stacked)
            PopupMenuButton<StatsSplit>(
              onSelected: (split) =>
                  context.goPreservingSearch(filters.location(split: split)),
              itemBuilder: (context) => [
                for (final split in StatsSplit.values)
                  PopupMenuItem(
                    value: split,
                    child: Text(splitLabel(l10n, split)),
                  ),
              ],
              child: FilterPill(
                icon: LucideIcons.layers,
                label: splitLabel(l10n, filters.split),
              ),
            ),
          // A net series is one figure a stretch; it has no parts to stack.
          if (canNet && chart != StatsChart.stacked)
            FilterChip(
              label: Text(l10n.netFlow),
              selected: filters.showNet,
              onSelected: (value) =>
                  context.goPreservingSearch(filters.location(showNet: value)),
            ),
        ],
      ],
    );
  }
}

class _StatsOverTimeBody extends StatelessWidget {
  final StatsBreakdown breakdown;
  final StatsRouteFilters filters;
  final StatsInterval interval;
  final String currency;
  final LocaleFormatting format;
  final FunL10n fun;

  const _StatsOverTimeBody({
    required this.breakdown,
    required this.filters,
    required this.interval,
    required this.currency,
    required this.format,
    required this.fun,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canNet =
        filters.types.contains(TransactionTypeFilter.expense) &&
        filters.types.contains(TransactionTypeFilter.income);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatsOverTime(
          series: breakdown.series,
          types: filters.orderedTypes,
          interval: interval,
          chart: filters.effectiveChart,
          showNet:
              filters.showNet &&
              canNet &&
              filters.effectiveChart != StatsChart.stacked,
          splitKeys: breakdown.splitKeys,
          splitLabel: (key) => key == kStatsOtherSplit
              ? l10n.statsOtherSplit
              : key.isEmpty
              ? (filters.split == StatsSplit.category
                    ? l10n.unknown
                    : l10n.none)
              : key,
          currency: currency,
          format: format,
          fun: fun,
          onOpenBucket: (bucket) => context.goPreservingSearch(
            _transactionsFor(
              filters,
              from: bucket.start,
              to: DateTime(
                bucket.bounds.end!.year,
                bucket.bounds.end!.month,
                bucket.bounds.end!.day - 1,
              ),
            ),
          ),
        ),
        if (breakdown.transactions.isNotEmpty) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.transactionsCount(breakdown.transactions.length),
                  style: context.textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    context.goPreservingSearch(_transactionsFor(filters)),
                icon: const Icon(LucideIcons.arrowLeftRight),
                label: Text(l10n.navTransactions),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TypeToggles extends StatelessWidget {
  final StatsRouteFilters filters;
  final FunL10n fun;

  const _TypeToggles({required this.filters, required this.fun});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in statsTypes)
          Builder(
            builder: (context) {
              final selected = filters.types.contains(type);
              // The last type shown stays on: a page showing no kind of
              // movement has nothing to say. It is not disabled for that,
              // since a disabled chip greys out and reads as switched off.
              final isOnlyOne = selected && filters.types.length == 1;
              return FilterChip(
                label: Text(
                  type.localizedLabel(l10n, isRaccoon: fun.isRaccoon),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? colors.accent.acc : colors.text2,
                  ),
                ),
                selected: selected,
                showCheckmark: true,
                checkmarkColor: colors.accent.acc,
                side: BorderSide(
                  color: selected
                      ? colors.accent.acc.withValues(alpha: 0.6)
                      : colors.border,
                ),
                backgroundColor: colors.surface2,
                selectedColor: colors.accent.acc.withValues(alpha: 0.14),
                onSelected: (value) {
                  if (isOnlyOne) return;
                  context.goPreservingSearch(
                    filters.location(
                      types: value
                          ? {...filters.types, type}
                          : ({...filters.types}..remove(type)),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _PeriodFilterButton extends StatelessWidget {
  final StatsRouteFilters filters;

  const _PeriodFilterButton({required this.filters});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<ExpensePeriod>(
      onSelected: (period) =>
          context.goPreservingSearch(filters.location(period: period)),
      itemBuilder: (context) => ExpensePeriod.values
          .map(
            (period) => PopupMenuItem(
              value: period,
              child: Text(period.localizedLabel(l10n)),
            ),
          )
          .toList(),
      child: FilterPill(
        icon: LucideIcons.calendar,
        label: filters.localizedPeriodLabel(l10n, context.format),
        tooltip: l10n.expensePeriodMonth,
      ),
    );
  }
}

/// A picker over several names, such as categories or tags. [onPicked]
/// gets the names ticked, empty to clear the filter.
class _NamesFilterButton extends StatelessWidget {
  final IconData icon;
  final String idleLabel;
  final String emptyLabel;
  final List<String> names;
  final Set<String> selected;
  final String Function(String name)? labelOf;
  final String Function(Set<String> names) onPicked;

  const _NamesFilterButton({
    required this.icon,
    required this.idleLabel,
    required this.emptyLabel,
    required this.names,
    required this.selected,
    required this.onPicked,
    this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showNamesFilterDialog(
          context: context,
          title: idleLabel,
          emptyLabel: emptyLabel,
          names: names,
          selected: selected,
          icon: icon,
          labelOf: labelOf,
        );
        if (picked == null || !context.mounted) return;
        context.goPreservingSearch(onPicked(picked));
      },
      child: FilterPill(
        icon: icon,
        label: FilterPill.selectionLabel(selected, idleLabel, labelOf: labelOf),
        tooltip: selected.isEmpty
            ? idleLabel
            : selected.map(labelOf ?? (name) => name).join(', '),
        active: selected.isNotEmpty,
        onClear: () => context.goPreservingSearch(onPicked(const {})),
      ),
    );
  }
}

/// Edits the page's search words, which narrow the totals as well as the
/// list: every word has to turn up somewhere on a leg for it to count.
class _WordsFilterButton extends StatelessWidget {
  final String? words;

  const _WordsFilterButton({required this.words});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final result = await showWordsFilterDialog(context, words: words);
        if (result == null || !context.mounted) return;
        context.go(
          RouteQuery.withSearch(GoRouterState.of(context).uri, result),
        );
      },
      child: FilterPill(
        icon: LucideIcons.textSearch,
        label: words == null ? l10n.filterWords : '"$words"',
        tooltip: l10n.filterWordsHint,
        active: words != null,
        onClear: () => context.go(
          RouteQuery.withSearch(GoRouterState.of(context).uri, null),
        ),
      ),
    );
  }
}

class _DateRangeFilterButton extends StatelessWidget {
  final StatsRouteFilters filters;

  const _DateRangeFilterButton({required this.filters});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final now = DateTime.now();
        final initialRange = filters.from != null && filters.to != null
            ? DateTimeRange(start: filters.from!, end: filters.to!)
            : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);

        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: now,
          initialDateRange: initialRange,
        );

        if (!context.mounted || range == null) return;
        context.goPreservingSearch(
          filters.location(from: range.start, to: range.end),
        );
      },
      child: FilterPill(
        icon: LucideIcons.calendarRange,
        label: filters.hasCustomDateRange
            ? filters.localizedPeriodLabel(context.l10n, context.format)
            : context.l10n.pickDates,
        tooltip: context.l10n.pickDates,
        active: filters.hasCustomDateRange,
        onClear: () => context.goPreservingSearch(
          filters.location(period: filters.period),
        ),
      ),
    );
  }
}
