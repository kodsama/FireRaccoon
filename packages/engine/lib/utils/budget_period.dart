import '../models/budget.dart';
import '../models/transaction.dart';
import 'date_range.dart';

/// Firefly III auto-budget behavior (`auto_budget_type`).
enum AutoBudgetType {
  none,
  reset,
  rollover,
  adjusted;

  static AutoBudgetType parse(String? raw) {
    if (raw == null || raw.isEmpty) return AutoBudgetType.none;
    return switch (raw) {
      'reset' || '1' => AutoBudgetType.reset,
      'rollover' || '2' => AutoBudgetType.rollover,
      'adjusted' || '3' => AutoBudgetType.adjusted,
      'none' || '0' => AutoBudgetType.none,
      _ => AutoBudgetType.none,
    };
  }

  String get apiValue => switch (this) {
    AutoBudgetType.none => 'none',
    AutoBudgetType.reset => 'reset',
    AutoBudgetType.rollover => 'rollover',
    AutoBudgetType.adjusted => 'adjusted',
  };
}

/// Firefly III auto-budget cadence (`auto_budget_period`).
enum AutoBudgetPeriod {
  daily,
  weekly,
  monthly,
  quarterly,
  halfYear,
  yearly;

  static AutoBudgetPeriod? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return switch (raw) {
      'daily' => AutoBudgetPeriod.daily,
      'weekly' => AutoBudgetPeriod.weekly,
      'monthly' => AutoBudgetPeriod.monthly,
      'quarterly' => AutoBudgetPeriod.quarterly,
      'half_year' => AutoBudgetPeriod.halfYear,
      'yearly' => AutoBudgetPeriod.yearly,
      _ => null,
    };
  }

  String get apiValue => switch (this) {
    AutoBudgetPeriod.daily => 'daily',
    AutoBudgetPeriod.weekly => 'weekly',
    AutoBudgetPeriod.monthly => 'monthly',
    AutoBudgetPeriod.quarterly => 'quarterly',
    AutoBudgetPeriod.halfYear => 'half_year',
    AutoBudgetPeriod.yearly => 'yearly',
  };
}

/// Counts how many budget cadence units fit in [viewingRange] (exclusive end).
int countBudgetPeriodsInRange({
  required AutoBudgetPeriod budgetPeriod,
  required DateRangeBounds viewingRange,
}) {
  final start = viewingRange.start;
  final end = viewingRange.end;
  if (start == null || end == null) return 1;

  final days = end.difference(start).inDays;
  if (days <= 0) return 1;

  return switch (budgetPeriod) {
    AutoBudgetPeriod.daily => days,
    AutoBudgetPeriod.weekly => (days / 7).floor().clamp(1, days),
    AutoBudgetPeriod.monthly => _countCalendarMonths(start, end),
    AutoBudgetPeriod.quarterly => _countCalendarQuarters(start, end),
    AutoBudgetPeriod.halfYear => _countCalendarHalfYears(start, end),
    AutoBudgetPeriod.yearly => _countCalendarYears(start, end),
  };
}

double aggregateBudgetLimit({
  required double perPeriodAmount,
  required AutoBudgetPeriod? budgetPeriod,
  required DateRangeBounds viewingRange,
}) {
  if (perPeriodAmount <= 0) return 0;
  if (budgetPeriod == null) return perPeriodAmount;
  if (viewingRange.start == null && viewingRange.end == null) {
    return perPeriodAmount;
  }

  final count = countBudgetPeriodsInRange(
    budgetPeriod: budgetPeriod,
    viewingRange: viewingRange,
  );
  return perPeriodAmount * count;
}

double sumBudgetSpentInRange(
  Iterable<Transaction> transactions,
  DateRangeBounds range, {
  String? budgetId,
}) {
  var total = 0.0;
  for (final transaction in transactions) {
    if (transaction.type != 'withdrawal') continue;
    if (!range.contains(transaction.date)) continue;
    for (final split in transaction.resolvedSplits()) {
      if (budgetId != null &&
          budgetId.isNotEmpty &&
          split.budgetId != budgetId) {
        continue;
      }
      total += split.amount;
    }
  }
  return total;
}

BudgetPeriodMetrics resolveBudgetPeriodMetrics({
  required Budget budget,
  required DateRangeBounds viewingRange,
  required Iterable<Transaction> transactions,
}) {
  final periodLimit = aggregateBudgetLimit(
    perPeriodAmount: budget.autoBudgetAmount,
    budgetPeriod: budget.autoBudgetPeriod,
    viewingRange: viewingRange,
  );
  final spent = viewingRange.start == null && viewingRange.end == null
      ? budget.spent
      : sumBudgetSpentInRange(transactions, viewingRange, budgetId: budget.id);

  return BudgetPeriodMetrics(spent: spent, periodLimit: periodLimit);
}

class BudgetPeriodMetrics {
  final double spent;
  final double periodLimit;

  const BudgetPeriodMetrics({required this.spent, required this.periodLimit});

  double get remaining => periodLimit - spent;

  bool get isOver => periodLimit > 0 && spent > periodLimit;

  double get progress =>
      periodLimit > 0 ? (spent / periodLimit).clamp(0.0, double.infinity) : 0;
}

int _countCalendarMonths(DateTime start, DateTime end) {
  var count = 0;
  var cursor = DateTime(start.year, start.month, 1);
  while (cursor.isBefore(end)) {
    count++;
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  return count.clamp(1, count);
}

int _countCalendarQuarters(DateTime start, DateTime end) {
  var count = 0;
  final quarterStartMonth = ((start.month - 1) ~/ 3) * 3 + 1;
  var cursor = DateTime(start.year, quarterStartMonth, 1);
  while (cursor.isBefore(end)) {
    count++;
    cursor = DateTime(cursor.year, cursor.month + 3, 1);
  }
  return count.clamp(1, count);
}

int _countCalendarHalfYears(DateTime start, DateTime end) {
  var count = 0;
  final halfYearStartMonth = start.month <= 6 ? 1 : 7;
  var cursor = DateTime(start.year, halfYearStartMonth, 1);
  while (cursor.isBefore(end)) {
    count++;
    cursor = DateTime(cursor.year, cursor.month + 6, 1);
  }
  return count.clamp(1, count);
}

int _countCalendarYears(DateTime start, DateTime end) {
  var count = 0;
  var cursor = DateTime(start.year, 1, 1);
  while (cursor.isBefore(end)) {
    count++;
    cursor = DateTime(cursor.year + 1, 1, 1);
  }
  return count.clamp(1, count);
}
