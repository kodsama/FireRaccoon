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

/// The window to ask Firefly for, for a budget kept on [budgetPeriod] while
/// somebody is looking at [viewingRange].
///
/// Firefly scopes a budget's `spent` to exactly the window it is given, so a
/// yearly budget asked about one month is asked about a twelfth of its own
/// period and answers with whatever fell in that month, which for most months
/// is nothing. A budget reading 220,000 a year then showed 0 spent and 0 to
/// spend, and the figure was not wrong so much as answering a question nobody
/// asked.
///
/// A range already covering a whole period or more is left alone, because the
/// count it multiplies by is then meaningful. A shorter one snaps out to the
/// calendar period its start falls in, so the figures are the ones the budget
/// is actually kept in.
DateRangeBounds budgetCoverageRange({
  required AutoBudgetPeriod? budgetPeriod,
  required DateRangeBounds viewingRange,
}) {
  final start = viewingRange.start;
  final end = viewingRange.end;
  if (budgetPeriod == null || start == null || end == null) {
    return viewingRange;
  }
  final whole = _calendarPeriodAround(budgetPeriod, start);
  // Spanning a whole period already, so the count it multiplies by means
  // something and the view is left alone. Asked the other way round, as
  // whether the view ends before the period does, September reads as a whole
  // quarter because both end on 1 October.
  final coversAWholePeriod =
      !start.isAfter(whole.start!) && !end.isBefore(whole.end!);
  return coversAWholePeriod ? viewingRange : whole;
}

/// The calendar period of [budgetPeriod] that [anchor] falls in, end exclusive.
DateRangeBounds _calendarPeriodAround(
  AutoBudgetPeriod budgetPeriod,
  DateTime anchor,
) {
  final day = DateTime(anchor.year, anchor.month, anchor.day);
  return switch (budgetPeriod) {
    AutoBudgetPeriod.daily => DateRangeBounds(
      start: day,
      end: day.add(const Duration(days: 1)),
    ),
    // Monday to Monday, which is what a week means to a ledger kept in Europe.
    AutoBudgetPeriod.weekly => () {
      final monday = day.subtract(Duration(days: day.weekday - 1));
      return DateRangeBounds(
        start: monday,
        end: monday.add(const Duration(days: 7)),
      );
    }(),
    AutoBudgetPeriod.monthly => DateRangeBounds(
      start: DateTime(day.year, day.month, 1),
      end: DateTime(day.year, day.month + 1, 1),
    ),
    AutoBudgetPeriod.quarterly => () {
      final firstMonth = ((day.month - 1) ~/ 3) * 3 + 1;
      return DateRangeBounds(
        start: DateTime(day.year, firstMonth, 1),
        end: DateTime(day.year, firstMonth + 3, 1),
      );
    }(),
    AutoBudgetPeriod.halfYear => () {
      final firstMonth = day.month <= 6 ? 1 : 7;
      return DateRangeBounds(
        start: DateTime(day.year, firstMonth, 1),
        end: DateTime(day.year, firstMonth + 6, 1),
      );
    }(),
    AutoBudgetPeriod.yearly => DateRangeBounds(
      start: DateTime(day.year, 1, 1),
      end: DateTime(day.year + 1, 1, 1),
    ),
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
