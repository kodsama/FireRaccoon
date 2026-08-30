import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../providers/theme_provider.dart';
import '../providers/data_providers.dart';
import '../router/accounts_route.dart';
import '../router/budgets_route.dart';
import '../router/dashboard_route.dart';
import '../router/expenses_route.dart';
import '../router/projection_route.dart';
import '../router/route_navigation.dart';
import '../router/route_query.dart';
import '../router/transactions_route.dart';
import '../utils/search_filter.dart';
import '../theme/app_theme.dart';
import '../utils/dashboard_navigation.dart';
import '../utils/dashboard_period.dart';
import '../utils/dashboard_stats.dart';
import '../utils/display_labels.dart';
import '../widgets/firefly_refresh_button.dart';
import '../widgets/simple_charts.dart';
import '../widgets/fun_decorated_surface.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../utils/locale_formatting.dart';
import '../providers/default_period_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/dashboard_stats_providers.dart';
import '../models/account_prognosis.dart';
import '../utils/transaction_filters.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  void _navigate(DashboardRouteFilters filters) {
    context.goPreservingSearch(
      DashboardRoute.location(
        tab: filters.tab,
        period: filters.period,
        omitPeriodWhen: filters.defaultPeriod,
        from: filters.from != null
            ? DashboardRoute.formatDate(filters.from!)
            : null,
        to: filters.to != null ? DashboardRoute.formatDate(filters.to!) : null,
      ),
    );
  }

  void _openPrognosis() {
    context.goPreservingSearch(ProjectionRoute.location());
  }

  void _openTransactions() {
    final defaultPeriod = ref.read(defaultDashboardPeriodProvider);
    context.goPreservingSearch(
      TransactionsRoute.location(defaultDashboardPeriod: defaultPeriod),
    );
  }

  void _openIncome(DashboardRouteFilters filters) {
    final params = analyticsRouteParamsFromDashboard(filters);
    context.goPreservingSearch(
      IncomeRoute.location(
        period: params.period,
        from: params.from,
        to: params.to,
      ),
    );
  }

  void _openExpenses(DashboardRouteFilters filters) {
    final params = analyticsRouteParamsFromDashboard(filters);
    context.goPreservingSearch(
      ExpensesRoute.location(
        period: params.period,
        from: params.from,
        to: params.to,
      ),
    );
  }

  void _openPiggyBanks() {
    context.goPreservingSearch('/piggy-banks');
  }

  void _openProjection() {
    context.goPreservingSearch(ProjectionRoute.location());
  }

  void _openAccounts() {
    context.goPreservingSearch(AccountsRoute.location());
  }

  void _openBudgets() {
    context.goPreservingSearch(BudgetsRoute.location());
  }

  ({
    DateRangeBounds range,
    DateRangeBounds? comparison,
    String periodLabel,
    String? comparisonPeriodLabel,
  })
  _periodContext(
    DashboardRouteFilters filters,
    AppLocalizations l10n,
    LocaleFormatting format,
  ) {
    final range = resolveDashboardDateRange(
      period: filters.period,
      customFrom: filters.from,
      customTo: filters.to,
    );
    final comparison = previousDashboardPeriodRange(
      period: filters.period,
      customFrom: filters.from,
      customTo: filters.to,
    );
    final periodLabel = filters.localizedPeriodLabel(l10n, format);
    final comparisonPeriodLabel = comparison == null
        ? null
        : localizedDashboardComparisonLabel(
            l10n,
            format,
            period: filters.period,
            customFrom: filters.from,
            customTo: filters.to,
          );
    return (
      range: range,
      comparison: comparison,
      periodLabel: periodLabel,
      comparisonPeriodLabel: comparisonPeriodLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final defaultPeriod = ref.watch(defaultDashboardPeriodProvider);
    final filters = DashboardRoute.filtersFrom(
      GoRouterState.of(context),
      defaultPeriod: defaultPeriod,
    );
    final searchQuery = RouteQuery.searchFrom(GoRouterState.of(context).uri);
    final tab = filters.tab;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 30, right: 30, top: 26, bottom: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LayoutPill(fun.tabInsights, DashboardTab.insights, tab, (t) {
                    _navigate(
                      DashboardRouteFilters(
                        tab: t,
                        period: filters.period,
                        from: filters.from,
                        to: filters.to,
                      ),
                    );
                  }),
                  _LayoutPill(fun.tabAccounts, DashboardTab.accounts, tab, (t) {
                    _navigate(
                      DashboardRouteFilters(
                        tab: t,
                        period: filters.period,
                        from: filters.from,
                        to: filters.to,
                      ),
                    );
                  }),
                  _LayoutPill(fun.tabFocus, DashboardTab.focus, tab, (t) {
                    _navigate(
                      DashboardRouteFilters(
                        tab: t,
                        period: filters.period,
                        from: filters.from,
                        to: filters.to,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DashboardPeriodBar(filters: filters, onNavigate: _navigate),
          const SizedBox(height: 24),
          if (tab == DashboardTab.insights)
            _buildInsightsLayout(context, filters, searchQuery),
          if (tab == DashboardTab.accounts)
            _buildAccountsLayout(context, filters, searchQuery),
          if (tab == DashboardTab.focus)
            _buildFocusLayout(context, filters, searchQuery),
        ],
      ),
    );
  }

  Widget _buildInsightsLayout(
    BuildContext context,
    DashboardRouteFilters filters,
    String? searchQuery,
  ) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final format = ref.watch(localeFormattingProvider);
    final languageCode = ref.watch(localeProvider).languageCode;
    final transactionsAsync = ref.watch(transactionsProvider);

    return transactionsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) =>
          Center(child: Text(l10n.errorLoadingData(error.toString()))),
      data: (transactions) {
        final period = _periodContext(filters, l10n, format);
        final comparisonPeriodLabel = period.comparisonPeriodLabel;
        final periodKey = filters.periodKey;
        final netWorth = ref.watch(netWorthBreakdownProvider);
        final kpis = ref.watch(
          dashboardKpisProvider((
            period: periodKey.period,
            from: periodKey.from,
            to: periodKey.to,
            periodLabel: period.periodLabel,
          )),
        );
        final cashFlow = ref.watch(
          cashFlowBucketsProvider((
            period: periodKey.period,
            from: periodKey.from,
            to: periodKey.to,
            languageCode: languageCode,
          )),
        );
        final categories = ref
            .watch(categoryBreakdownProvider(periodKey))
            .where((c) => matchesSearchQuery(searchQuery, [c.name]))
            .toList();
        final recent = recentTransactions(
          transactions,
          period.range,
        ).where((t) => t.matchesSearch(searchQuery)).toList();
        final outlook = ref.watch(endOfMonthOutlookProvider);

        final donutValues = categories.isEmpty
            ? <double>[]
            : categories.map((category) => category.amount).toList();
        final donutColors = <Color>[
          colors.accent.acc,
          colors.success,
          colors.danger,
          colors.warning,
          colors.accent.deep,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResponsiveKpiGrid(
              cards: [
                _KPICard(
                  fun.totalBalance,
                  format.formatMoney(kpis.totalBalance, kpis.currency),
                  '',
                  true,
                  LucideIcons.wallet,
                  onTap: _openTransactions,
                  tooltip: fun.totalBalance,
                  breakdownRows: [
                    (
                      l10n.filterAssetsShort,
                      format.formatMoney(netWorth.assets, kpis.currency),
                    ),
                    (
                      l10n.filterLiabilitiesShort,
                      format.formatMoney(netWorth.liabilities, kpis.currency),
                    ),
                  ],
                ),
                _KPICard(
                  fun.kpiIncome(kpis.periodLabel),
                  format.formatMoney(kpis.periodIncome, kpis.currency),
                  formatDeltaLabel(
                    l10n,
                    format,
                    kpis.incomeDelta,
                    comparisonPeriodLabel: comparisonPeriodLabel,
                  ),
                  kpis.incomeDelta.isPositive,
                  LucideIcons.trendingUp,
                  onTap: () => _openIncome(filters),
                  tooltip: fun.kpiIncome(kpis.periodLabel),
                ),
                _KPICard(
                  fun.kpiSpending(kpis.periodLabel),
                  format.formatMoney(kpis.periodSpending, kpis.currency),
                  formatDeltaLabel(
                    l10n,
                    format,
                    kpis.spendingDelta,
                    comparisonPeriodLabel: comparisonPeriodLabel,
                  ),
                  kpis.spendingDelta.isPositive,
                  LucideIcons.shoppingBag,
                  onTap: () => _openExpenses(filters),
                  tooltip: fun.kpiSpending(kpis.periodLabel),
                ),
                _KPICard(
                  fun.kpiSaved(kpis.periodLabel),
                  format.formatMoney(kpis.periodSaved, kpis.currency),
                  formatDeltaLabel(
                    l10n,
                    format,
                    kpis.savedDelta,
                    comparisonPeriodLabel: comparisonPeriodLabel,
                  ),
                  kpis.savedDelta.isPositive,
                  LucideIcons.piggyBank,
                  onTap: _openPiggyBanks,
                  tooltip: fun.kpiSaved(kpis.periodLabel),
                ),
              ],
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: _CashFlowCard(
                      title: fun.cashFlow,
                      tooltip: fun.cashFlow,
                      incomeLabel: fun.income,
                      spendingLabel: fun.spending,
                      cashFlow: cashFlow,
                      currency: kpis.currency,
                      format: format,
                      onTap: _openTransactions,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: _CategoryDonutCard(
                      title: fun.whereMoneyGoes,
                      tooltip: fun.whereMoneyGoes,
                      emptyLabel: l10n.noSpendingThisMonth,
                      categories: categories,
                      donutValues: donutValues,
                      donutColors: donutColors,
                      currency: kpis.currency,
                      format: format,
                      l10n: l10n,
                      onTap: () => _openExpenses(filters),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DashboardTappableCard(
              tooltip: fun.recentActivity,
              onTap: _openTransactions,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          fun.recentActivity,
                          style: context.textTheme.titleMedium,
                        ),
                        Tooltip(
                          message: l10n.viewAll,
                          child: TextButton(
                            onPressed: () => context.goPreservingSearch(
                              TransactionsRoute.location(),
                            ),
                            child: Text(
                              l10n.viewAll,
                              style: TextStyle(color: colors.accent.acc),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (recent.isEmpty)
                      Text(
                        fun.noTransactionsYet,
                        style: TextStyle(color: colors.text3),
                      )
                    else
                      ...recent.map((transaction) {
                        final isIncome = transaction.type == 'deposit';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ActivityRow(
                            transaction.description,
                            transaction.displayCategory(l10n),
                            format.formatSignedMoney(
                              isIncome
                                  ? transaction.totalAmount
                                  : -transaction.totalAmount,
                              transaction.currencySymbol,
                            ),
                            isIncome
                                ? LucideIcons.arrowDownLeft
                                : LucideIcons.arrowUpRight,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: colors.accent.deep,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _openProjection,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.accent.deep,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fun.lookingAhead,
                              style: TextStyle(
                                color: colors.accent.hi,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.projectedSavingsHeadline(
                                format.formatMoney(
                                  outlook.projectedSavings,
                                  kpis.currency,
                                  decimalDigits: 0,
                                ),
                              ),
                              style: const TextStyle(
                                fontFamily: 'Roboto Slab',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              outlook.savedSoFarPositive
                                  ? l10n.onPaceDetail(
                                      format.formatMoney(
                                        outlook.projectedSavings,
                                        kpis.currency,
                                        decimalDigits: 0,
                                      ),
                                    )
                                  : l10n.spendingOutpacingDetail(
                                      format.formatMoney(
                                        outlook.projectedSavings.abs(),
                                        kpis.currency,
                                        decimalDigits: 0,
                                      ),
                                    ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            if (outlook.showWarning) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.alertTriangle,
                                      color: colors.warning,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l10n.spendingPaceWarning,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Tooltip(
                        message: fun.openProjection,
                        child: FilledButton(
                          onPressed: () => context.goPreservingSearch(
                            ProjectionRoute.location(),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.accent.hi,
                            foregroundColor: colors.accent.deep,
                          ),
                          child: Text(fun.openProjection),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountsLayout(
    BuildContext context,
    DashboardRouteFilters filters,
    String? searchQuery,
  ) {
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final format = ref.watch(localeFormattingProvider);
    final languageCode = ref.watch(localeProvider).languageCode;
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final currencyAsync = ref.watch(primaryCurrencyProvider);
    final colors = context.colors;

    return accountsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) =>
          Center(child: Text(l10n.errorGeneric(error.toString()))),
      data: (accounts) {
        final transactions = transactionsAsync.value ?? [];
        final budgets = budgetsAsync.value ?? [];
        final assets = ref
            .watch(assetAccountsProvider)
            .where((a) => a.matchesSearch(searchQuery))
            .toList();
        final prognosis = ref.watch(accountPrognosisProvider);
        final balanceHistories =
            ref.watch(accountBalanceHistoriesProvider).value ?? const {};
        final netWorth = ref.watch(netWorthBreakdownProvider);
        final currency = resolveCurrency(
          currencyAsync.value?.symbol,
          transactions,
        );
        final periodKey = filters.periodKey;
        final sparkline = ref.watch(
          netWorthSparklineProvider((
            period: periodKey.period,
            from: periodKey.from,
            to: periodKey.to,
            languageCode: languageCode,
          )),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MonthEndPrognosisPanel(
              prognosis: prognosis,
              accounts: assets,
              format: format,
              onOpenPrognosis: _openPrognosis,
            ),
            const SizedBox(height: 24),
            Text(fun.yourAccounts, style: context.textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: assets
                  .map(
                    (account) => _AccountTile(
                      account: account,
                      balanceHistory: balanceHistories[account.name],
                      prognosis: prognosis.forAccount(account.id),
                      format: format,
                      onTap: () => context.goPreservingSearch(
                        TransactionsRoute.location(account: account.name),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Material(
              color: colors.accent.deep,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _openAccounts,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.accent.deep,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fun.totalBalance,
                              style: TextStyle(color: colors.accent.hi),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              format.formatMoney(netWorth.netWorth, currency),
                              style: const TextStyle(
                                fontFamily: 'Roboto Slab',
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SimpleSparkline(
                        values: sparkline,
                        color: colors.accent.hi,
                        width: 180,
                        height: 50,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (budgets.isNotEmpty) ...[
              const SizedBox(height: 24),
              _DashboardTappableCard(
                tooltip: fun.budgetsAtGlance,
                onTap: _openBudgets,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fun.budgetsAtGlance,
                        style: context.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      ...budgets
                          .take(4)
                          .map(
                            (budget) => _BudgetGlanceRow(
                              budget: budget,
                              format: format,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: fun.viewAllAccounts,
                child: TextButton(
                  onPressed: () =>
                      context.goPreservingSearch(AccountsRoute.location()),
                  child: Text(
                    fun.viewAllAccounts,
                    style: TextStyle(color: colors.accent.acc),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFocusLayout(
    BuildContext context,
    DashboardRouteFilters filters,
    String? searchQuery,
  ) {
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final format = ref.watch(localeFormattingProvider);
    final languageCode = ref.watch(localeProvider).languageCode;
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final colors = context.colors;

    return accountsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) =>
          Center(child: Text(l10n.errorGeneric(error.toString()))),
      data: (accounts) {
        final transactions = transactionsAsync.value ?? [];
        final periodKey = filters.periodKey;
        final periodLabels = _periodContext(filters, l10n, format);
        final kpis = ref.watch(
          dashboardKpisProvider((
            period: periodKey.period,
            from: periodKey.from,
            to: periodKey.to,
            periodLabel: periodLabels.periodLabel,
          )),
        );
        final sparkline = ref.watch(
          netWorthSparklineProvider((
            period: periodKey.period,
            from: periodKey.from,
            to: periodKey.to,
            languageCode: languageCode,
          )),
        );
        final outlook = ref.watch(projectionOutlookProvider(periodKey));
        final now = DateTime.now();
        final todayRange = DateRangeBounds(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(
            now.year,
            now.month,
            now.day,
          ).add(const Duration(days: 1)),
        );
        final today = transactionsInRange(
          transactions,
          todayRange,
        ).where((t) => t.matchesSearch(searchQuery)).toList();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Material(
                color: colors.accent.deep,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _openAccounts,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colors.accent.deep,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fun.netWorth,
                          style: TextStyle(color: colors.accent.hi),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          format.formatMoney(kpis.totalBalance, kpis.currency),
                          style: const TextStyle(
                            fontFamily: 'Roboto Slab',
                            fontSize: 46,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatDeltaLabel(
                            l10n,
                            format,
                            kpis.savedDelta,
                            comparisonPeriodLabel:
                                periodLabels.comparisonPeriodLabel,
                          ),
                          style: TextStyle(
                            color: kpis.savedDelta.isPositive
                                ? colors.success
                                : colors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SimpleSparkline(
                          values: sparkline,
                          color: colors.accent.hi,
                          width: double.infinity,
                          height: 70,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _InsetStat(
                                label: fun.income,
                                value: format.formatMoney(
                                  kpis.periodIncome,
                                  kpis.currency,
                                  decimalDigits: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InsetStat(
                                label: fun.spending,
                                value: format.formatMoney(
                                  kpis.periodSpending,
                                  kpis.currency,
                                  decimalDigits: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _DashboardTappableCard(
                    tooltip: l10n.thirtyDayOutlook,
                    onTap: _openProjection,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.thirtyDayOutlook,
                            style: context.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          SimpleSparkline(
                            values: outlook,
                            color: colors.accent.acc,
                            width: double.infinity,
                            height: 80,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DashboardTappableCard(
                    tooltip: l10n.todaysTimeline,
                    onTap: _openTransactions,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.todaysTimeline,
                            style: context.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          if (today.isEmpty)
                            Text(
                              l10n.noActivityToday,
                              style: TextStyle(color: colors.text3),
                            )
                          else
                            ...today.map((transaction) {
                              final isIncome = transaction.type == 'deposit';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ActivityRow(
                                  transaction.displayTitle(),
                                  transaction.displayCategorySummary(l10n),
                                  format.formatSignedMoney(
                                    isIncome
                                        ? transaction.totalAmount
                                        : -transaction.totalAmount,
                                    transaction.currencySymbol,
                                  ),
                                  isIncome
                                      ? LucideIcons.arrowDownLeft
                                      : LucideIcons.arrowUpRight,
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardPeriodBar extends StatelessWidget {
  final DashboardRouteFilters filters;
  final ValueChanged<DashboardRouteFilters> onNavigate;

  const _DashboardPeriodBar({required this.filters, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = context.format;
    final colors = context.colors;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        PopupMenuButton<DashboardPeriod>(
          onSelected: (period) {
            onNavigate(DashboardRouteFilters(tab: filters.tab, period: period));
          },
          itemBuilder: (context) => DashboardPeriod.values
              .map(
                (period) => PopupMenuItem(
                  value: period,
                  child: Text(period.localizedLabel(l10n)),
                ),
              )
              .toList(),
          child: Tooltip(
            message: l10n.expensePeriodMonth,
            child: _DashboardFilterChip(
              icon: LucideIcons.calendar,
              label: filters.localizedPeriodLabel(l10n, format),
            ),
          ),
        ),
        Tooltip(
          message: l10n.pickDates,
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

                onNavigate(
                  DashboardRouteFilters(
                    tab: filters.tab,
                    from: range.start,
                    to: range.end,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.calendarRange,
                      size: 16,
                      color: colors.text,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      filters.hasCustomDateRange
                          ? l10n.customDateRange
                          : l10n.pickDates,
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
        ),
        FireflyRefreshButton(backgroundColor: colors.surface2),
      ],
    );
  }
}

class _DashboardFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DashboardFilterChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
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
    );
  }
}

class _MonthEndPrognosisPanel extends StatelessWidget {
  final AccountPrognosisResult prognosis;
  final List<Account> accounts;
  final LocaleFormatting format;
  final VoidCallback onOpenPrognosis;

  const _MonthEndPrognosisPanel({
    required this.prognosis,
    required this.accounts,
    required this.format,
    required this.onOpenPrognosis,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenPrognosis,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.monthEndPrognosis,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenPrognosis,
                    child: Text(l10n.openPrognosis),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...accounts.take(3).map((account) {
                final item = prognosis.forAccount(account.id);
                if (item == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            format.formatMoney(
                              item.endOfMonth.expected,
                              account.currencySymbol,
                            ),
                            style: TextStyle(
                              fontFamily: 'Roboto Slab',
                              fontWeight: FontWeight.w700,
                              color: item.showWarning
                                  ? colors.warning
                                  : colors.text,
                            ),
                          ),
                          Text(
                            '${format.formatMoney(item.endOfMonth.pessimistic, account.currencySymbol)} – '
                            '${format.formatMoney(item.endOfMonth.optimistic, account.currencySymbol)}',
                            style: TextStyle(color: colors.text3, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final Account account;
  final List<double>? balanceHistory;
  final AccountPrognosis? prognosis;
  final LocaleFormatting format;
  final VoidCallback onTap;

  const _AccountTile({
    required this.account,
    required this.balanceHistory,
    required this.prognosis,
    required this.format,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final history = [...?balanceHistory];
    if (history.length < 2) {
      history.addAll([account.currentBalance, account.currentBalance]);
    }
    if (prognosis != null) {
      history.add(prognosis!.endOfMonth.expected);
    }

    return Tooltip(
      message: account.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.landmark, color: colors.accent.acc),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      account.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                format.formatMoney(
                  account.currentBalance,
                  account.currencySymbol,
                ),
                style: context.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Roboto Slab',
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (prognosis != null) ...[
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.projectedEndOfMonth,
                      style: TextStyle(color: colors.text3, fontSize: 12),
                    ),
                    Text(
                      format.formatMoney(
                        prognosis!.endOfMonth.expected,
                        account.currencySymbol,
                      ),
                      style: TextStyle(
                        fontFamily: 'Roboto Slab',
                        fontWeight: FontWeight.w700,
                        color: prognosis!.showWarning
                            ? colors.warning
                            : colors.text2,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SimpleSparkline(
                values: history,
                color: account.currentBalance >= 0
                    ? colors.success
                    : colors.danger,
                width: 260,
                height: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetGlanceRow extends StatelessWidget {
  final Budget budget;
  final LocaleFormatting format;

  const _BudgetGlanceRow({required this.budget, required this.format});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final progress = budget.autoBudgetAmount == 0
        ? 0.0
        : budget.spent / budget.autoBudgetAmount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                l10n.budgetSpentFraction(
                  format.formatMoney(
                    budget.spent,
                    budget.currencySymbol,
                    decimalDigits: 0,
                  ),
                  format.formatMoney(
                    budget.autoBudgetAmount,
                    budget.currencySymbol,
                    decimalDigits: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: colors.surface2,
            color: progress > 0.9 ? colors.danger : colors.accent.acc,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

class _InsetStat extends StatelessWidget {
  final String label;
  final String value;

  const _InsetStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Roboto Slab',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool highlighted;

  const _LegendDot({
    required this.color,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: highlighted ? context.colors.text : context.colors.text3,
            fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LayoutPill extends StatelessWidget {
  final String label;
  final DashboardTab tab;
  final DashboardTab currentTab;
  final ValueChanged<DashboardTab> onTap;

  const _LayoutPill(this.label, this.tab, this.currentTab, this.onTap);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isActive = tab == currentTab;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => onTap(tab),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? colors.accent.acc : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Comfortaa',
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? Colors.white : colors.text2,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTappableCard extends StatelessWidget {
  final VoidCallback onTap;
  final String? tooltip;
  final Widget child;

  const _DashboardTappableCard({
    required this.onTap,
    this.tooltip,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: child),
    );

    if (tooltip == null) return card;
    return Tooltip(message: tooltip!, child: card);
  }
}

/// Lays the KPI cards out in a responsive grid: one column on phones, two on
/// small tablets, and a single row on wide screens. Prevents the cards from
/// being squeezed into unreadable vertical text on narrow viewports.
/// Ensures all cards in each row have equal height.
class _ResponsiveKpiGrid extends StatelessWidget {
  const _ResponsiveKpiGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 520
            ? 1
            : width < 960
            ? 2
            : cards.length;
        const gap = 16.0;

        final rows = <List<Widget>>[];
        for (var i = 0; i < cards.length; i += columns) {
          rows.add(
            cards.sublist(
              i,
              i + columns > cards.length ? cards.length : i + columns,
            ),
          );
        }

        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < rows[r].length; c++) ...[
                      if (c > 0) const SizedBox(width: gap),
                      Expanded(child: rows[r][c]),
                    ],
                    if (rows[r].length < columns)
                      for (
                        var empty = 0;
                        empty < columns - rows[r].length;
                        empty++
                      ) ...[
                        const SizedBox(width: gap),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String delta;
  final bool isPositive;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final List<(String, String)> breakdownRows;

  const _KPICard(
    this.title,
    this.value,
    this.delta,
    this.isPositive,
    this.icon, {
    required this.onTap,
    required this.tooltip,
    this.breakdownRows = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: FunDecoratedSurface(
        decorationKey: 'kpi-$title',
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.iconBg,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(icon, size: 18, color: colors.iconFg),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Comfortaa',
                                fontSize: 13,
                                color: colors.text3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        value,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontFamily: 'Roboto Slab',
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                  if (breakdownRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...breakdownRows.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.$1,
                                style: TextStyle(
                                  fontFamily: 'Comfortaa',
                                  fontSize: 11,
                                  color: colors.text3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              row.$2,
                              style: TextStyle(
                                fontFamily: 'Roboto Slab',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (delta.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      delta,
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontSize: 12,
                        color: isPositive ? colors.success : colors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;

  const _ActivityRow(this.title, this.subtitle, this.amount, this.icon);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isIncome = amount.startsWith('+');
    return FunDecoratedSurface(
      decorationKey: 'activity-$title',
      borderRadius: BorderRadius.zero,
      compact: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: colors.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.text3, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontFamily: 'Roboto Slab',
              fontWeight: FontWeight.w700,
              color: isIncome ? colors.success : colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cash-flow chart card owning its own hover state so pointer movement only
/// rebuilds this card instead of the whole dashboard.
class _CashFlowCard extends StatefulWidget {
  final String title;
  final String tooltip;
  final String incomeLabel;
  final String spendingLabel;
  final List<CashFlowBucket> cashFlow;
  final String currency;
  final LocaleFormatting format;
  final VoidCallback onTap;

  const _CashFlowCard({
    required this.title,
    required this.tooltip,
    required this.incomeLabel,
    required this.spendingLabel,
    required this.cashFlow,
    required this.currency,
    required this.format,
    required this.onTap,
  });

  @override
  State<_CashFlowCard> createState() => _CashFlowCardState();
}

class _CashFlowCardState extends State<_CashFlowCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cashFlow = widget.cashFlow;
    final hovered = _hoveredIndex != null && _hoveredIndex! < cashFlow.length
        ? _hoveredIndex
        : null;

    return _DashboardTappableCard(
      tooltip: widget.tooltip,
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: context.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendDot(
                  color: colors.accent.acc,
                  label: widget.incomeLabel,
                  highlighted: hovered != null,
                ),
                const SizedBox(width: 16),
                _LegendDot(
                  color: colors.text3,
                  label: widget.spendingLabel,
                  highlighted: hovered != null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            GroupedBarChart(
              labels: [for (final bucket in cashFlow) bucket.label],
              incomeValues: [for (final bucket in cashFlow) bucket.income],
              spendingValues: [for (final bucket in cashFlow) bucket.spending],
              incomeColor: colors.accent.acc,
              spendingColor: colors.text3.withValues(alpha: 0.45),
              height: 190,
              highlightedGroupIndex: hovered,
              onGroupHover: (index) {
                if (_hoveredIndex == index) return;
                setState(() => _hoveredIndex = index);
              },
            ),
            if (hovered != null) ...[
              const SizedBox(height: 12),
              Text(
                '${cashFlow[hovered].label} - '
                '${widget.incomeLabel}: ${widget.format.formatMoney(cashFlow[hovered].income, widget.currency, decimalDigits: 0)} - '
                '${widget.spendingLabel}: ${widget.format.formatMoney(cashFlow[hovered].spending, widget.currency, decimalDigits: 0)}',
                style: TextStyle(
                  color: colors.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Category donut card owning its own hover state so pointer movement only
/// rebuilds this card instead of the whole dashboard.
class _CategoryDonutCard extends StatefulWidget {
  final String title;
  final String tooltip;
  final String emptyLabel;
  final List<CategoryBreakdown> categories;
  final List<double> donutValues;
  final List<Color> donutColors;
  final String currency;
  final LocaleFormatting format;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _CategoryDonutCard({
    required this.title,
    required this.tooltip,
    required this.emptyLabel,
    required this.categories,
    required this.donutValues,
    required this.donutColors,
    required this.currency,
    required this.format,
    required this.l10n,
    required this.onTap,
  });

  @override
  State<_CategoryDonutCard> createState() => _CategoryDonutCardState();
}

class _CategoryDonutCardState extends State<_CategoryDonutCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categories = widget.categories;
    final donutValues = widget.donutValues;
    final hovered = _hoveredIndex != null && _hoveredIndex! < categories.length
        ? _hoveredIndex
        : null;

    return _DashboardTappableCard(
      tooltip: widget.tooltip,
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: context.textTheme.titleMedium),
            const SizedBox(height: 24),
            if (donutValues.isEmpty)
              Center(
                child: Text(
                  widget.emptyLabel,
                  style: TextStyle(color: colors.text3),
                ),
              )
            else ...[
              Center(
                child: SimpleDonutChart(
                  values: donutValues,
                  sliceColors: widget.donutColors,
                  size: 140,
                  highlightedIndex: hovered,
                  onSliceHover: (index) {
                    if (_hoveredIndex == index) return;
                    setState(() => _hoveredIndex = index);
                  },
                ),
              ),
              const SizedBox(height: 20),
              ...categories.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                final categoryLabel = category.displayName(widget.l10n);
                final isHovered = index == hovered;
                final total = donutValues.fold<double>(
                  0,
                  (sum, value) => sum + value,
                );
                final percent = total == 0
                    ? 0
                    : ((category.amount / total) * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isHovered ? colors.surface2 : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isHovered
                                ? '$categoryLabel ($percent%)'
                                : categoryLabel,
                            style: TextStyle(
                              fontWeight: isHovered
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          widget.format.formatMoney(
                            category.amount,
                            widget.currency,
                            decimalDigits: 0,
                          ),
                          style: TextStyle(
                            fontFamily: 'Roboto Slab',
                            fontWeight: isHovered
                                ? FontWeight.w800
                                : FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
