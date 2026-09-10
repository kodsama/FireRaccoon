import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../router/budgets_route.dart';
import 'data_providers.dart';

typedef BudgetMetricsMap = Map<String, BudgetPeriodMetrics>;
typedef BudgetPeriodMetricsKey = (
  ExpensePeriod period,
  DateTime? from,
  DateTime? to,
);

BudgetRouteFilters budgetFiltersFromKey(BudgetPeriodMetricsKey key) {
  final (period, from, to) = key;
  return BudgetRouteFilters(period: period, from: from, to: to);
}

final budgetPeriodMetricsProvider =
    FutureProvider.family<BudgetMetricsMap, BudgetPeriodMetricsKey>((
      ref,
      key,
    ) async {
      final service = await requireFireflyService(
        ref,
        'budgetPeriodMetricsProvider',
      );
      final range = budgetFiltersFromKey(key).dateRange;

      // Firefly scopes each budget's `spent` to the requested range, so one
      // budgets request replaces a per-budget full-history transaction fetch.
      // Firefly only computes `spent` when BOTH bounds are present, so
      // synthesize the missing one for open-ended ranges.
      final hasRange = range.start != null || range.end != null;
      final start = range.start ?? DateTime(2000, 1, 1);
      final now = DateTime.now();
      final end = range.end ?? DateTime(now.year, now.month, now.day + 2);
      final viewed = DateRangeBounds(start: start, end: end);
      final budgets = hasRange
          ? await service.getBudgets(start: start, end: end)
          : await ref.watch(budgetsProvider.future);

      // A budget kept over a period longer than the one being viewed has to be
      // asked about its own period, or Firefly answers for a twelfth of a year
      // and a yearly budget reads as nothing spent of nothing to spend.
      // Grouped by the window they need, so this is one request per distinct
      // cadence rather than one per budget.
      final widened = <String, DateRangeBounds>{};
      for (final budget in budgets) {
        final coverage = budgetCoverageRange(
          budgetPeriod: budget.autoBudgetPeriod,
          viewingRange: viewed,
        );
        if (coverage.start != viewed.start || coverage.end != viewed.end) {
          widened['${coverage.start}|${coverage.end}'] = coverage;
        }
      }

      final byWindow = <String, List<Budget>>{};
      for (final entry in widened.entries) {
        byWindow[entry.key] = await service.getBudgets(
          start: entry.value.start,
          end: entry.value.end,
        );
      }

      return {
        for (final budget in budgets)
          budget.id: _metricsFor(
            budget: budget,
            viewed: viewed,
            byWindow: byWindow,
          ),
      };
    });

/// The figures for one budget, over whichever window covers its own period.
BudgetPeriodMetrics _metricsFor({
  required Budget budget,
  required DateRangeBounds viewed,
  required Map<String, List<Budget>> byWindow,
}) {
  final coverage = budgetCoverageRange(
    budgetPeriod: budget.autoBudgetPeriod,
    viewingRange: viewed,
  );
  final widened = coverage.start != viewed.start || coverage.end != viewed.end;
  final source = widened
      ? (byWindow['${coverage.start}|${coverage.end}'] ?? const <Budget>[])
            .where((other) => other.id == budget.id)
            .firstOrNull
      : budget;

  return BudgetPeriodMetrics(
    spent: (source ?? budget).spent,
    periodLimit: aggregateBudgetLimit(
      perPeriodAmount: budget.autoBudgetAmount,
      budgetPeriod: budget.autoBudgetPeriod,
      viewingRange: coverage,
    ),
  );
}
