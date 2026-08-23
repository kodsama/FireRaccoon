import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

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
      final budgets = hasRange
          ? await service.getBudgets(start: start, end: end)
          : await ref.watch(budgetsProvider.future);

      return {
        for (final budget in budgets)
          budget.id: BudgetPeriodMetrics(
            spent: budget.spent,
            periodLimit: aggregateBudgetLimit(
              perPeriodAmount: budget.autoBudgetAmount,
              budgetPeriod: budget.autoBudgetPeriod,
              viewingRange: range,
            ),
          ),
      };
    });
