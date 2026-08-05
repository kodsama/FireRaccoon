import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import '../theme/app_theme.dart';
import '../providers/budget_period_providers.dart';
import '../providers/data_providers.dart';
import '../providers/default_period_provider.dart';
import '../providers/undo_history_provider.dart';
import '../providers/theme_provider.dart';
import '../router/budgets_route.dart';
import '../router/route_navigation.dart';
import '../router/route_query.dart';
import '../utils/search_filter.dart';
import '../utils/create_flows.dart';
import '../widgets/budget_form_dialog.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/entity_header_actions.dart';
import '../widgets/entity_list_layout.dart';
import '../widgets/entity_screen_header.dart';
import '../widgets/expandable_entity_shell.dart';
import '../widgets/transactions_expanded_panel.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../utils/locale_formatting.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final defaultPeriod = ref.watch(defaultDashboardPeriodProvider);
    final routeFilters = BudgetsRoute.filtersFrom(
      GoRouterState.of(context),
      defaultDashboardPeriod: defaultPeriod,
    );
    final expandedBudget = BudgetsRoute.budgetFrom(GoRouterState.of(context));
    final searchQuery = RouteQuery.searchFrom(GoRouterState.of(context).uri);
    final budgetsAsync = ref.watch(budgetsProvider);
    final metricsKey = (
      routeFilters.period,
      routeFilters.from,
      routeFilters.to,
    );
    final metricsAsync = ref.watch(budgetPeriodMetricsProvider(metricsKey));

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: budgetsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.errorGeneric(e.toString()))),
        data: (budgets) {
          final visibleBudgets = budgets
              .where((b) => b.matchesSearch(searchQuery))
              .toList();
          final metrics = metricsAsync.value;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntityScreenHeader(
                  title: fun.budgetsTitle,
                  createLabel: fun.newBudget,
                  onCreate: () => openCreateBudgetDialog(context, ref),
                ),
                const SizedBox(height: 16),
                _BudgetPeriodFilterBar(
                  filters: routeFilters,
                  defaultDashboardPeriod: defaultPeriod,
                ),
                const SizedBox(height: 24),
                EntityListLayout(
                  gridItems: visibleBudgets
                      .map(
                        (b) => _BudgetCard(
                          budget: b,
                          filters: routeFilters,
                          metrics: metrics?[b.id],
                          metricsLoading:
                              metricsAsync.isLoading && metrics == null,
                          isExpandedFromRoute: expandedBudget == b.name,
                        ),
                      )
                      .toList(),
                  compactItems: visibleBudgets
                      .map(
                        (b) => _BudgetCompactRow(
                          budget: b,
                          filters: routeFilters,
                          metrics: metrics?[b.id],
                          metricsLoading:
                              metricsAsync.isLoading && metrics == null,
                          isExpandedFromRoute: expandedBudget == b.name,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BudgetPeriodFilterBar extends StatelessWidget {
  final BudgetRouteFilters filters;
  final DashboardPeriod defaultDashboardPeriod;

  const _BudgetPeriodFilterBar({
    required this.filters,
    required this.defaultDashboardPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _BudgetPeriodFilterButton(
          filters: filters,
          defaultDashboardPeriod: defaultDashboardPeriod,
        ),
        _BudgetDateRangeFilterButton(
          filters: filters,
          defaultDashboardPeriod: defaultDashboardPeriod,
        ),
      ],
    );
  }
}

class _BudgetPeriodFilterButton extends StatelessWidget {
  final BudgetRouteFilters filters;
  final DashboardPeriod defaultDashboardPeriod;

  const _BudgetPeriodFilterButton({
    required this.filters,
    required this.defaultDashboardPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = LocaleFormatting(Localizations.localeOf(context));
    return PopupMenuButton<ExpensePeriod>(
      onSelected: (period) {
        context.goPreservingSearch(
          BudgetsRoute.location(
            budget: BudgetsRoute.budgetFrom(GoRouterState.of(context)),
            period: period,
            defaultDashboardPeriod: defaultDashboardPeriod,
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
      child: _BudgetFilterChip(
        icon: LucideIcons.calendar,
        label: filters.localizedPeriodLabel(l10n, format),
        tooltip: l10n.viewPeriod,
      ),
    );
  }
}

class _BudgetDateRangeFilterButton extends StatelessWidget {
  final BudgetRouteFilters filters;
  final DashboardPeriod defaultDashboardPeriod;

  const _BudgetDateRangeFilterButton({
    required this.filters,
    required this.defaultDashboardPeriod,
  });

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
              BudgetsRoute.location(
                budget: BudgetsRoute.budgetFrom(GoRouterState.of(context)),
                from: BudgetRouteFilters.formatDate(range.start),
                to: BudgetRouteFilters.formatDate(range.end),
                defaultDashboardPeriod: defaultDashboardPeriod,
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Icon(
              LucideIcons.calendarRange,
              size: 16,
              color: colors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;

  const _BudgetFilterChip({
    required this.icon,
    required this.label,
    this.tooltip,
  });

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

String? _budgetCadenceLabel(Budget budget, AppLocalizations l10n) {
  final period = budget.autoBudgetPeriod;
  if (period == null || budget.autoBudgetAmount <= 0) return null;
  return period.localizedCadence(l10n);
}

BudgetPeriodMetrics _fallbackMetrics(
  Budget budget,
  BudgetRouteFilters filters,
) {
  return resolveBudgetPeriodMetrics(
    budget: budget,
    viewingRange: filters.dateRange,
    transactions: const [],
  );
}

String _budgetInfoLine({
  required Budget budget,
  required BudgetRouteFilters filters,
  required BudgetPeriodMetrics metrics,
  required AppLocalizations l10n,
  required LocaleFormatting format,
}) {
  final cadence = _budgetCadenceLabel(budget, l10n);
  if (cadence != null) {
    return l10n.budgetPerPeriod(
      format.formatMoney(budget.autoBudgetAmount, budget.currencySymbol),
      cadence,
    );
  }
  return l10n.ofAmount(
    format.formatMoney(budget.autoBudgetAmount, budget.currencySymbol),
  );
}

String _budgetLimitLine({
  required Budget budget,
  required BudgetRouteFilters filters,
  required BudgetPeriodMetrics metrics,
  required AppLocalizations l10n,
  required LocaleFormatting format,
}) {
  final viewPeriod = filters.localizedPeriodLabel(l10n, format);
  final limitText = format.formatMoney(
    metrics.periodLimit,
    budget.currencySymbol,
  );

  if (metrics.periodLimit != budget.autoBudgetAmount) {
    return l10n.budgetLimitForPeriod(limitText, viewPeriod);
  }

  return l10n.ofAmount(limitText);
}

class _BudgetCard extends ConsumerStatefulWidget {
  final Budget budget;
  final BudgetRouteFilters filters;
  final BudgetPeriodMetrics? metrics;
  final bool metricsLoading;
  final bool isExpandedFromRoute;

  const _BudgetCard({
    required this.budget,
    required this.filters,
    required this.metrics,
    required this.metricsLoading,
    required this.isExpandedFromRoute,
  });

  @override
  ConsumerState<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends ConsumerState<_BudgetCard> {
  List<Transaction>? _transactions;
  bool _loadingTx = false;

  bool get _expanded => widget.isExpandedFromRoute;

  @override
  void initState() {
    super.initState();
    if (_expanded) _loadTransactions();
  }

  @override
  void didUpdateWidget(covariant _BudgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The fetch is range-scoped, so a period/date change invalidates any
    // previously loaded rows.
    final filtersChanged =
        oldWidget.filters.period != widget.filters.period ||
        oldWidget.filters.from != widget.filters.from ||
        oldWidget.filters.to != widget.filters.to;
    if (!_expanded) {
      _transactions = null;
      _loadingTx = false;
    } else if (filtersChanged || (_transactions == null && !_loadingTx)) {
      _transactions = null;
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _loadingTx = true);
    try {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        final range = widget.filters.dateRange;
        final txs = await service.getBudgetTransactions(
          widget.budget.id,
          start: range.start,
          end: range.end,
        );
        if (mounted) {
          setState(() {
            _transactions = txs;
            _loadingTx = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingTx = false;
          _transactions = [];
        });
      }
    }
  }

  void _toggleExpand() {
    final defaultPeriod = ref.read(defaultDashboardPeriodProvider);
    final filters = widget.filters;
    context.goPreservingSearch(
      BudgetsRoute.location(
        budget: _expanded ? null : widget.budget.name,
        period: filters.period,
        from: filters.from != null
            ? BudgetRouteFilters.formatDate(filters.from!)
            : null,
        to: filters.to != null
            ? BudgetRouteFilters.formatDate(filters.to!)
            : null,
        defaultDashboardPeriod: defaultPeriod,
      ),
    );
  }

  List<Transaction>? get _visibleTransactions {
    if (_transactions == null) return null;
    return filterByDateRange(
      _transactions!,
      widget.filters.dateRange,
      (transaction) => transaction.date,
    );
  }

  Future<void> _deleteBudget() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: context.l10n.deleteBudget,
      message: context.l10n.deleteBudgetConfirmBody(widget.budget.name),
      confirmLabel: context.l10n.delete,
    );
    if (confirmed == true) {
      try {
        final service = ref.read(apiServiceProvider);
        await service?.deleteBudget(widget.budget.id);
        ref
            .read(undoHistoryProvider.notifier)
            .record(
              title: 'Budget deleted',
              details: 'Deleted budget "${widget.budget.name}"',
              type: UndoActionType.budgetDelete,
              undoPayload: {
                'name': widget.budget.name,
                'amount': widget.budget.autoBudgetAmount,
                'currencyCode': widget.budget.currencyCode,
              },
              redoPayload: {'budgetId': widget.budget.id},
            );
        ref.invalidate(budgetsProvider);
        ref.invalidate(budgetPeriodMetricsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.budgetDeleted(widget.budget.name)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.failedToDeleteBudget(e.toString())),
            ),
          );
        }
      }
    }
  }

  void _editBudget() {
    showBudgetFormDialog(context: context, ref: ref, budget: widget.budget);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final format = ref.watch(localeFormattingProvider);
    final b = widget.budget;
    final metrics = widget.metrics ?? _fallbackMetrics(b, widget.filters);
    final spent = widget.metricsLoading ? b.spent : metrics.spent;
    final periodLimit = metrics.periodLimit;
    final progress = periodLimit > 0 ? spent / periodLimit : 0.0;
    final isOver = periodLimit > 0 && spent > periodLimit;
    final remaining = periodLimit - spent;
    final budgetInfo = _budgetInfoLine(
      budget: b,
      filters: widget.filters,
      metrics: metrics,
      l10n: l10n,
      format: format,
    );
    final limitLine = _budgetLimitLine(
      budget: b,
      filters: widget.filters,
      metrics: metrics,
      l10n: l10n,
      format: format,
    );

    return ExpandableEntityCard(
      expanded: _expanded,
      onToggleExpand: _toggleExpand,
      expandedChild: TransactionsExpandedPanel(
        loading: _loadingTx,
        transactions: _visibleTransactions,
        emptyLabel: l10n.noTransactionsForBudget,
        onTransactionMutated: _loadTransactions,
      ),
      header: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    b.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                EntityHeaderActions(
                  leading: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOver
                            ? colors.danger.withValues(alpha: 0.1)
                            : colors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOver
                            ? l10n.budgetStatusOver
                            : l10n.budgetStatusOnTrack,
                        style: TextStyle(
                          color: isOver ? colors.danger : colors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  onEdit: _editBudget,
                  onDelete: _deleteBudget,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              budgetInfo,
              style: TextStyle(color: colors.text2, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fun.spent,
                      style: TextStyle(color: colors.text3, fontSize: 12),
                    ),
                    widget.metricsLoading
                        ? Text(
                            '…',
                            style: TextStyle(
                              color: colors.text3,
                              fontFamily: 'Roboto Slab',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : Text(
                            format.formatMoney(spent, b.currencySymbol),
                            style: const TextStyle(
                              fontFamily: 'Roboto Slab',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ],
                ),
                Text(
                  limitLine,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: colors.text2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: colors.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? colors.danger : colors.accent.acc,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOver
                      ? l10n.overBudget(
                          format.formatMoney(remaining.abs(), b.currencySymbol),
                        )
                      : l10n.leftInBudget(
                          format.formatMoney(remaining, b.currencySymbol),
                        ),
                  style: TextStyle(
                    color: isOver ? colors.danger : colors.text2,
                    fontSize: 13,
                  ),
                ),
                ExpandChevron(expanded: _expanded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCompactRow extends ConsumerStatefulWidget {
  final Budget budget;
  final BudgetRouteFilters filters;
  final BudgetPeriodMetrics? metrics;
  final bool metricsLoading;
  final bool isExpandedFromRoute;

  const _BudgetCompactRow({
    required this.budget,
    required this.filters,
    required this.metrics,
    required this.metricsLoading,
    required this.isExpandedFromRoute,
  });

  @override
  ConsumerState<_BudgetCompactRow> createState() => _BudgetCompactRowState();
}

class _BudgetCompactRowState extends ConsumerState<_BudgetCompactRow> {
  List<Transaction>? _transactions;
  bool _loadingTx = false;

  bool get _expanded => widget.isExpandedFromRoute;

  @override
  void initState() {
    super.initState();
    if (_expanded) _loadTransactions();
  }

  @override
  void didUpdateWidget(covariant _BudgetCompactRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The fetch is range-scoped, so a period/date change invalidates any
    // previously loaded rows.
    final filtersChanged =
        oldWidget.filters.period != widget.filters.period ||
        oldWidget.filters.from != widget.filters.from ||
        oldWidget.filters.to != widget.filters.to;
    if (!_expanded) {
      _transactions = null;
      _loadingTx = false;
    } else if (filtersChanged || (_transactions == null && !_loadingTx)) {
      _transactions = null;
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _loadingTx = true);
    try {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        final range = widget.filters.dateRange;
        final txs = await service.getBudgetTransactions(
          widget.budget.id,
          start: range.start,
          end: range.end,
        );
        if (mounted) {
          setState(() {
            _transactions = txs;
            _loadingTx = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingTx = false;
          _transactions = [];
        });
      }
    }
  }

  void _toggleExpand() {
    final defaultPeriod = ref.read(defaultDashboardPeriodProvider);
    final filters = widget.filters;
    context.goPreservingSearch(
      BudgetsRoute.location(
        budget: _expanded ? null : widget.budget.name,
        period: filters.period,
        from: filters.from != null
            ? BudgetRouteFilters.formatDate(filters.from!)
            : null,
        to: filters.to != null
            ? BudgetRouteFilters.formatDate(filters.to!)
            : null,
        defaultDashboardPeriod: defaultPeriod,
      ),
    );
  }

  List<Transaction>? get _visibleTransactions {
    if (_transactions == null) return null;
    return filterByDateRange(
      _transactions!,
      widget.filters.dateRange,
      (transaction) => transaction.date,
    );
  }

  Future<void> _deleteBudget() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: context.l10n.deleteBudget,
      message: context.l10n.deleteBudgetConfirmBody(widget.budget.name),
      confirmLabel: context.l10n.delete,
    );
    if (confirmed == true) {
      try {
        final service = ref.read(apiServiceProvider);
        await service?.deleteBudget(widget.budget.id);
        ref
            .read(undoHistoryProvider.notifier)
            .record(
              title: 'Budget deleted',
              details: 'Deleted budget "${widget.budget.name}"',
              type: UndoActionType.budgetDelete,
              undoPayload: {
                'name': widget.budget.name,
                'amount': widget.budget.autoBudgetAmount,
                'currencyCode': widget.budget.currencyCode,
              },
              redoPayload: {'budgetId': widget.budget.id},
            );
        ref.invalidate(budgetsProvider);
        ref.invalidate(budgetPeriodMetricsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.budgetDeleted(widget.budget.name)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.failedToDeleteBudget(e.toString())),
            ),
          );
        }
      }
    }
  }

  void _editBudget() {
    showBudgetFormDialog(context: context, ref: ref, budget: widget.budget);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);
    final b = widget.budget;
    final metrics = widget.metrics ?? _fallbackMetrics(b, widget.filters);
    final spent = widget.metricsLoading ? b.spent : metrics.spent;
    final periodLimit = metrics.periodLimit;
    final progress = periodLimit > 0 ? spent / periodLimit : 0.0;
    final isOver = periodLimit > 0 && spent > periodLimit;
    final remaining = periodLimit - spent;
    final budgetInfo = _budgetInfoLine(
      budget: b,
      filters: widget.filters,
      metrics: metrics,
      l10n: l10n,
      format: format,
    );

    return ExpandableEntityCompactRow(
      expanded: _expanded,
      onToggleExpand: _toggleExpand,
      expandedChild: TransactionsExpandedPanel(
        loading: _loadingTx,
        transactions: _visibleTransactions,
        emptyLabel: l10n.noTransactionsForBudget,
        onTransactionMutated: _loadTransactions,
      ),
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    b.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                widget.metricsLoading
                    ? Text(
                        '…',
                        style: TextStyle(
                          color: colors.text3,
                          fontFamily: 'Roboto Slab',
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Text(
                        l10n.budgetSpentFraction(
                          format.formatMoney(spent, b.currencySymbol),
                          format.formatMoney(periodLimit, b.currencySymbol),
                        ),
                        style: const TextStyle(
                          fontFamily: 'Roboto Slab',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                const SizedBox(width: 12),
                EntityHeaderActions(
                  iconSize: 16,
                  onEdit: _editBudget,
                  onDelete: _deleteBudget,
                ),
                const SizedBox(width: 4),
                ExpandChevron(expanded: _expanded, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                budgetInfo,
                style: TextStyle(color: colors.text3, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: colors.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? colors.danger : colors.accent.acc,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOver
                      ? l10n.overBudget(
                          format.formatMoney(remaining.abs(), b.currencySymbol),
                        )
                      : l10n.leftInBudget(
                          format.formatMoney(remaining, b.currencySymbol),
                        ),
                  style: TextStyle(
                    color: isOver ? colors.danger : colors.text3,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
