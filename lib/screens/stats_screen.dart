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
    final breakdown = transactionsAsync.whenData(
      (transactions) => buildStatsBreakdown(
        transactions,
        types: filters.orderedTypes,
        categories: filters.categories,
        tags: filters.tags,
        budgets: filters.budgets,
        accounts: filters.accounts,
        words: words,
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
                      onPressed: () => context.go(
                        StatsRoute.location(
                          defaultDashboardPeriod: defaultPeriod,
                        ),
                      ),
                      child: Text(l10n.clearFilters),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _TypeToggles(filters: filters, fun: fun),
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
              data: (breakdown) => _StatsBody(
                key: ValueKey('${filters.scope.hashCode}|$uri'),
                breakdown: breakdown,
                filters: filters,
                currency: ref.watch(primaryCurrencyProvider).value?.symbol,
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

  String? _date(DateTime? date) =>
      date == null ? null : StatsRouteFilters.formatDate(date);

  String _transactionsLocation({
    String? category,
    TransactionTypeFilter? type,
  }) {
    final filters = widget.filters;
    return TransactionsRoute.location(
      categories: category != null ? [category] : filters.categories,
      tags: filters.tags,
      budgets: filters.budgets,
      period: filters.period,
      type: type ?? filters.singleType ?? TransactionTypeFilter.all,
      accounts: filters.accounts.toList(),
      from: _date(filters.from),
      to: _date(filters.to),
      defaultDashboardPeriod: filters.defaultDashboardPeriod,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final breakdown = widget.breakdown;
    final chartColors = _chartColors(context);
    final multiple = breakdown.types.length > 1;
    final net = breakdown.net;
    final categoryKeys = widget.filters.categories
        .map(categoryGroupKey)
        .toSet();

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
                      _typeOverview(
                        context,
                        totals,
                        categoryKeys: categoryKeys,
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
                Text(l10n.byCategory, style: context.textTheme.titleMedium),
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
    required Set<String> categoryKeys,
    required List<Color> chartColors,
    required double size,
  }) {
    final colors = context.colors;
    final values = <double>[];
    final sliceColors = <Color>[];
    final legend = totals.sortedCategories;
    for (var i = 0; i < legend.length; i++) {
      final entry = legend[i];
      if (categoryKeys.isNotEmpty && !categoryKeys.contains(entry.key)) {
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

  List<Widget> _legendRows(
    BuildContext context,
    StatsTypeTotals totals,
    List<Color> chartColors,
  ) {
    final colors = context.colors;
    final legend = totals.sortedCategories;
    if (legend.isEmpty) {
      return [
        Text(
          widget.l10n.noTransactionsMatchFilters,
          style: TextStyle(color: colors.text3),
        ),
      ];
    }
    final selectedKeys = widget.filters.categories
        .map(categoryGroupKey)
        .toSet();
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
                  _transactionsLocation(category: entry.key, type: totals.type),
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
                            displayLabelOrUnknown(entry.key, widget.l10n),
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
