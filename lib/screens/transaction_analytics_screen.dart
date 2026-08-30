import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/default_period_provider.dart';
import '../providers/data_providers.dart';
import '../providers/transaction_analytics_providers.dart';
import '../providers/theme_provider.dart';
import '../router/route_navigation.dart';
import '../router/route_query.dart';
import '../router/transaction_analytics_route.dart';
import '../router/transactions_route.dart';
import '../theme/app_theme.dart';
import '../utils/search_filter.dart';
import '../utils/display_labels.dart';
import '../widgets/entity_screen_header.dart';
import '../widgets/simple_charts.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../utils/locale_formatting.dart';
import '../widgets/account_filter_dialog.dart';

class TransactionAnalyticsScreen extends ConsumerWidget {
  final String title;
  final TransactionAnalyticsRoute route;
  final Future<void> Function(BuildContext context, WidgetRef ref)? onAdd;
  final String addButtonLabel;

  const TransactionAnalyticsScreen({
    super.key,
    required this.title,
    required this.route,
    this.onAdd,
    required this.addButtonLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final format = ref.watch(localeFormattingProvider);
    final defaultPeriod = ref.watch(defaultDashboardPeriodProvider);
    final filters = route.filtersFrom(
      GoRouterState.of(context),
      defaultDashboardPeriod: defaultPeriod,
    );
    final searchQuery = RouteQuery.searchFrom(GoRouterState.of(context).uri);
    final analyticsAsync = ref.watch(
      transactionAnalyticsSummaryProvider(filters.analyticsKey),
    );
    final accountsAsync = ref.watch(accountsProvider);
    final currencyAsync = ref.watch(primaryCurrencyProvider);
    final categories =
        analyticsAsync.asData?.value.categoryNames ??
        [if (filters.category != null) filters.category!];

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EntityScreenHeader(
              title: title,
              subtitle: _filterSummary(l10n, format, filters, fun.isRaccoon),
              createLabel: addButtonLabel,
              onCreate: onAdd == null ? null : () => onAdd!(context, ref),
              trailing: [
                if (filters.hasActiveFilters)
                  Tooltip(
                    message: l10n.clearFilters,
                    child: TextButton(
                      onPressed: () => context.goPreservingSearch(
                        route.location(defaultDashboardPeriod: defaultPeriod),
                      ),
                      child: Text(l10n.clearFilters),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _PeriodFilterButton(route: route, filters: filters),
                _TypeFilterButton(
                  route: route,
                  filters: filters,
                  isRaccoon: fun.isRaccoon,
                ),
                _CategoryFilterButton(
                  route: route,
                  filters: filters,
                  categories: categories,
                ),
                _AccountFilterButton(
                  route: route,
                  filters: filters,
                  accountsAsync: accountsAsync,
                ),
                _DateRangeFilterButton(route: route, filters: filters),
              ],
            ),
            const SizedBox(height: 24),
            analyticsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.errorGeneric(e.toString())),
              ),
              data: (analytics) {
                final periodTxs = analytics.periodTransactions;
                final categorySums = analytics.categorySums;
                final displayTxs =
                    (filters.category == null
                            ? periodTxs
                            : periodTxs
                                  .where(
                                    (t) =>
                                        categoryGroupKey(t.categoryName) ==
                                        categoryGroupKey(filters.category),
                                  )
                                  .toList())
                        .where((t) => t.matchesSearch(searchQuery))
                        .toList();
                final grandTotal = periodTxs.fold(
                  0.0,
                  (sum, t) => sum + t.totalAmount,
                );

                final sortedCategories = analytics.sortedCategoryEntries
                    .where((e) => matchesSearchQuery(searchQuery, [e.key]))
                    .toList();

                final chartColors = <Color>[
                  colors.accent.acc,
                  colors.accent.deep,
                  colors.warning,
                  colors.danger,
                  colors.success,
                  colors.text3,
                ];
                final currency = currencyAsync.value?.symbol ?? '€';

                final plotCategories = filters.category == null
                    ? sortedCategories
                    : (categorySums[filters.category] != null
                          ? [
                              MapEntry(
                                filters.category!,
                                categorySums[filters.category]!,
                              ),
                            ]
                          : <MapEntry<String, double>>[]);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CategoryPlotSection(
                      key: ValueKey(
                        '${filters.analyticsKey.hashCode}|$searchQuery|${filters.category}',
                      ),
                      plotCategories: plotCategories,
                      legendCategories: sortedCategories,
                      filters: filters,
                      grandTotal: grandTotal,
                      currency: currency,
                      format: format,
                      l10n: l10n,
                      typeLabel: filters.type.localizedLabel(
                        l10n,
                        isRaccoon: fun.isRaccoon,
                      ),
                      chartColors: chartColors,
                    ),
                    if (displayTxs.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.transactionsCount(displayTxs.length),
                              style: context.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Tooltip(
                            message: l10n.tooltipOpenTransactions,
                            child: TextButton.icon(
                              onPressed: () {
                                context.goPreservingSearch(
                                  TransactionsRoute.location(
                                    account: filters.account,
                                    period: filters.period,
                                    type: filters.type,
                                    from: filters.from != null
                                        ? ExpenseRouteFilters.formatDate(
                                            filters.from!,
                                          )
                                        : null,
                                    to: filters.to != null
                                        ? ExpenseRouteFilters.formatDate(
                                            filters.to!,
                                          )
                                        : null,
                                    defaultDashboardPeriod: defaultPeriod,
                                  ),
                                );
                              },
                              icon: const Icon(LucideIcons.arrowLeftRight),
                              label: Text(l10n.navTransactions),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _filterSummary(
    AppLocalizations l10n,
    LocaleFormatting format,
    ExpenseRouteFilters filters,
    bool isRaccoon,
  ) {
    final parts = <String>[
      filters.localizedPeriodLabel(l10n, format),
      filters.type.localizedLabel(l10n, isRaccoon: isRaccoon),
      if (filters.category != null)
        displayLabelOrUnknown(filters.category, l10n),
      if (filters.account != null) filters.account!,
    ];
    return parts.join(' · ');
  }
}

class _CategoryPlotSection extends StatefulWidget {
  final List<MapEntry<String, double>> plotCategories;
  final List<MapEntry<String, double>> legendCategories;
  final ExpenseRouteFilters filters;
  final double grandTotal;
  final String currency;
  final LocaleFormatting format;
  final AppLocalizations l10n;
  final String typeLabel;
  final List<Color> chartColors;

  const _CategoryPlotSection({
    super.key,
    required this.plotCategories,
    required this.legendCategories,
    required this.filters,
    required this.grandTotal,
    required this.currency,
    required this.format,
    required this.l10n,
    required this.typeLabel,
    required this.chartColors,
  });

  @override
  State<_CategoryPlotSection> createState() => _CategoryPlotSectionState();
}

class _CategoryPlotSectionState extends State<_CategoryPlotSection> {
  final Set<String> _hiddenCategories = {};

  bool _isVisible(String category) => !_hiddenCategories.contains(category);

  void _toggleCategory(String category, bool visible) {
    setState(() {
      if (visible) {
        _hiddenCategories.remove(category);
      } else {
        _hiddenCategories.add(category);
      }
    });
  }

  void _openCategoryTransactions(String category) {
    context.goPreservingSearch(
      TransactionsRoute.location(
        category: category,
        period: widget.filters.period,
        type: widget.filters.type,
        account: widget.filters.account,
        from: widget.filters.from != null
            ? ExpenseRouteFilters.formatDate(widget.filters.from!)
            : null,
        to: widget.filters.to != null
            ? ExpenseRouteFilters.formatDate(widget.filters.to!)
            : null,
        defaultDashboardPeriod: widget.filters.defaultDashboardPeriod,
      ),
    );
  }

  Color _colorForIndex(int index) =>
      widget.chartColors[index % widget.chartColors.length];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final visiblePlotEntries = <MapEntry<String, double>>[];
    final plotValues = <double>[];
    final plotColors = <Color>[];

    for (var i = 0; i < widget.plotCategories.length; i++) {
      final entry = widget.plotCategories[i];
      if (!_isVisible(entry.key)) continue;
      visiblePlotEntries.add(entry);
      plotValues.add(entry.value);
      plotColors.add(_colorForIndex(i));
    }

    final plotTotal = visiblePlotEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(
                  widget.l10n.overview,
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 32),
                if (plotValues.isEmpty)
                  SizedBox(
                    height: 240,
                    child: Center(
                      child: Text(
                        widget.l10n.noTransactionsMatchFilters,
                        style: TextStyle(color: colors.text3),
                      ),
                    ),
                  )
                else
                  SimpleDonutChart(
                    values: plotValues,
                    sliceColors: plotColors,
                    size: 240,
                  ),
                const SizedBox(height: 32),
                Text(
                  widget.format.formatMoney(plotTotal, widget.currency),
                  style: const TextStyle(
                    fontFamily: 'Roboto Slab',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(widget.typeLabel, style: TextStyle(color: colors.text3)),
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
                  widget.l10n.byCategory,
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (widget.legendCategories.isEmpty)
                  Text(
                    widget.l10n.noTransactionsMatchFilters,
                    style: TextStyle(color: colors.text3),
                  )
                else
                  ...List.generate(widget.legendCategories.length, (index) {
                    final entry = widget.legendCategories[index];
                    final percentage = widget.grandTotal > 0
                        ? (entry.value / widget.grandTotal) * 100
                        : 0;
                    final color = _colorForIndex(index);
                    final isSelected = widget.filters.category == entry.key;
                    final isVisible = _isVisible(entry.key);
                    final rowOpacity = isVisible ? 1.0 : 0.45;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: isVisible,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (checked) {
                              if (checked == null) return;
                              _toggleCategory(entry.key, checked);
                            },
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _openCategoryTransactions(entry.key),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 4,
                                ),
                                child: Opacity(
                                  opacity: rowOpacity,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: isSelected
                                              ? Border.all(
                                                  color: colors.text,
                                                  width: 2,
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          displayLabelOrUnknown(
                                            entry.key,
                                            widget.l10n,
                                          ),
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${widget.format.formatPercent(percentage.toDouble())}%',
                                        style: TextStyle(color: colors.text3),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        widget.format.formatMoney(
                                          entry.value,
                                          widget.currency,
                                        ),
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
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;

  const _FilterButton({required this.icon, required this.label, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.text),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 14, color: colors.text3),
          ],
        ),
      ),
    );
  }
}

class _PeriodFilterButton extends StatelessWidget {
  final TransactionAnalyticsRoute route;
  final ExpenseRouteFilters filters;

  const _PeriodFilterButton({required this.route, required this.filters});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = LocaleFormatting(Localizations.localeOf(context));
    return PopupMenuButton<ExpensePeriod>(
      onSelected: (period) {
        context.goPreservingSearch(
          route.location(
            category: filters.category,
            period: period,
            type: filters.type,
            account: filters.account,
            defaultDashboardPeriod: filters.defaultDashboardPeriod,
          ),
        );
      },
      itemBuilder: (context) => ExpensePeriod.values
          .map(
            (period) => PopupMenuItem(
              value: period,
              child: Text(period.localizedLabel(l10n)),
            ),
          )
          .toList(),
      child: _FilterButton(
        icon: LucideIcons.calendar,
        label: filters.localizedPeriodLabel(l10n, format),
        tooltip: l10n.expensePeriodMonth,
      ),
    );
  }
}

class _TypeFilterButton extends StatelessWidget {
  final TransactionAnalyticsRoute route;
  final ExpenseRouteFilters filters;
  final bool isRaccoon;

  const _TypeFilterButton({
    required this.route,
    required this.filters,
    required this.isRaccoon,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<TransactionTypeFilter>(
      onSelected: (type) {
        context.goPreservingSearch(
          route.location(
            category: filters.category,
            period: filters.period,
            type: type,
            account: filters.account,
            from: filters.from != null
                ? ExpenseRouteFilters.formatDate(filters.from!)
                : null,
            to: filters.to != null
                ? ExpenseRouteFilters.formatDate(filters.to!)
                : null,
            defaultDashboardPeriod: filters.defaultDashboardPeriod,
          ),
        );
      },
      itemBuilder: (context) => TransactionTypeFilter.values
          .map(
            (type) => PopupMenuItem(
              value: type,
              child: Text(type.localizedLabel(l10n, isRaccoon: isRaccoon)),
            ),
          )
          .toList(),
      child: _FilterButton(
        icon: LucideIcons.arrowLeftRight,
        label: filters.type.localizedLabel(l10n, isRaccoon: isRaccoon),
        tooltip: l10n.allTypes,
      ),
    );
  }
}

class _CategoryFilterButton extends StatelessWidget {
  final TransactionAnalyticsRoute route;
  final ExpenseRouteFilters filters;
  final List<String> categories;

  const _CategoryFilterButton({
    required this.route,
    required this.filters,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const allCategoriesSentinel = '__all__';
    return PopupMenuButton<String>(
      onSelected: (value) {
        context.goPreservingSearch(
          route.location(
            category: value == allCategoriesSentinel ? null : value,
            period: filters.period,
            type: filters.type,
            account: filters.account,
            from: filters.from != null
                ? ExpenseRouteFilters.formatDate(filters.from!)
                : null,
            to: filters.to != null
                ? ExpenseRouteFilters.formatDate(filters.to!)
                : null,
            defaultDashboardPeriod: filters.defaultDashboardPeriod,
          ),
        );
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: allCategoriesSentinel,
          child: Text(l10n.allCategories),
        ),
        if (categories.isNotEmpty) const PopupMenuDivider(),
        ...categories.map(
          (category) => PopupMenuItem(
            value: category,
            child: Text(displayLabelOrUnknown(category, l10n)),
          ),
        ),
      ],
      child: _FilterButton(
        icon: LucideIcons.tag,
        label: filters.category != null
            ? displayLabelOrUnknown(filters.category, l10n)
            : l10n.category,
        tooltip: l10n.allCategories,
      ),
    );
  }
}

class _AccountFilterButton extends ConsumerWidget {
  final TransactionAnalyticsRoute route;
  final ExpenseRouteFilters filters;
  final AsyncValue<List<Account>> accountsAsync;

  const _AccountFilterButton({
    required this.route,
    required this.filters,
    required this.accountsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final accounts = accountsAsync.value ?? [];

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final selected = await showAccountFilterDialog(
          context: context,
          ref: ref,
          accounts: accounts,
          currentFilter: filters.account,
        );
        if (selected != null && context.mounted) {
          context.goPreservingSearch(
            route.location(
              category: filters.category,
              period: filters.period,
              type: filters.type,
              account: selected == allAccountsSentinel ? null : selected,
              from: filters.from != null
                  ? ExpenseRouteFilters.formatDate(filters.from!)
                  : null,
              to: filters.to != null
                  ? ExpenseRouteFilters.formatDate(filters.to!)
                  : null,
              defaultDashboardPeriod: filters.defaultDashboardPeriod,
            ),
          );
        }
      },
      child: _FilterButton(
        icon: LucideIcons.wallet,
        label: filters.account ?? l10n.accountFilterLabel,
        tooltip: l10n.accountFilterLabel,
      ),
    );
  }
}

class _DateRangeFilterButton extends StatelessWidget {
  final TransactionAnalyticsRoute route;
  final ExpenseRouteFilters filters;

  const _DateRangeFilterButton({required this.route, required this.filters});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      message: context.l10n.pickDates,
      child: Material(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            final now = DateTime.now();
            final initialRange = filters.from != null && filters.to != null
                ? DateTimeRange(start: filters.from!, end: filters.to!)
                : DateTimeRange(
                    start: DateTime(now.year, now.month, 1),
                    end: now,
                  );

            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: now,
              initialDateRange: initialRange,
            );

            if (!context.mounted || range == null) return;

            context.goPreservingSearch(
              route.location(
                category: filters.category,
                type: filters.type,
                account: filters.account,
                from: ExpenseRouteFilters.formatDate(range.start),
                to: ExpenseRouteFilters.formatDate(range.end),
                defaultDashboardPeriod: filters.defaultDashboardPeriod,
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.calendarRange, size: 16, color: colors.text),
                const SizedBox(width: 8),
                Text(
                  filters.hasCustomDateRange
                      ? context.l10n.customDateRange
                      : context.l10n.pickDates,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
