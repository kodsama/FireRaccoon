import 'date_range.dart';

enum DashboardPeriod {
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisQuarter,
  lastQuarter,
  thisYear,
  lastYear,
  last2Years,
  last5Years,
  last10Years,
  all,
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _startOfWeek(DateTime date) {
  final day = _startOfDay(date);
  return day.subtract(Duration(days: day.weekday - 1));
}

DateTime _startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

DateTime _startOfQuarter(DateTime date) {
  final quarterStartMonth = ((date.month - 1) ~/ 3) * 3 + 1;
  return DateTime(date.year, quarterStartMonth, 1);
}

DateTime _startOfYear(DateTime date) => DateTime(date.year, 1, 1);

DateRangeBounds resolveDashboardDateRange({
  required DashboardPeriod period,
  DateTime? customFrom,
  DateTime? customTo,
  DateTime? reference,
}) {
  if (customFrom != null || customTo != null) {
    final end = customTo != null
        ? _startOfDay(customTo).add(const Duration(days: 1))
        : null;
    final start = customFrom != null ? _startOfDay(customFrom) : null;
    return DateRangeBounds(start: start, end: end);
  }

  if (period == DashboardPeriod.all) {
    return const DateRangeBounds();
  }

  final now = reference ?? DateTime.now();
  final today = _startOfDay(now);

  switch (period) {
    case DashboardPeriod.thisWeek:
      return DateRangeBounds(
        start: _startOfWeek(today),
        end: today.add(const Duration(days: 1)),
      );
    case DashboardPeriod.lastWeek:
      final thisWeekStart = _startOfWeek(today);
      return DateRangeBounds(
        start: thisWeekStart.subtract(const Duration(days: 7)),
        end: thisWeekStart,
      );
    case DashboardPeriod.thisMonth:
      return DateRangeBounds(
        start: _startOfMonth(today),
        end: DateTime(today.year, today.month + 1, 1),
      );
    case DashboardPeriod.lastMonth:
      final thisMonthStart = _startOfMonth(today);
      return DateRangeBounds(
        start: DateTime(thisMonthStart.year, thisMonthStart.month - 1, 1),
        end: thisMonthStart,
      );
    case DashboardPeriod.thisQuarter:
      final quarterStart = _startOfQuarter(today);
      return DateRangeBounds(
        start: quarterStart,
        end: DateTime(quarterStart.year, quarterStart.month + 3, 1),
      );
    case DashboardPeriod.lastQuarter:
      final thisQuarterStart = _startOfQuarter(today);
      final lastQuarterStart = DateTime(
        thisQuarterStart.year,
        thisQuarterStart.month - 3,
        1,
      );
      return DateRangeBounds(start: lastQuarterStart, end: thisQuarterStart);
    case DashboardPeriod.thisYear:
      return DateRangeBounds(
        start: _startOfYear(today),
        end: DateTime(today.year + 1, 1, 1),
      );
    case DashboardPeriod.lastYear:
      final thisYearStart = _startOfYear(today);
      return DateRangeBounds(
        start: DateTime(thisYearStart.year - 1, 1, 1),
        end: thisYearStart,
      );
    case DashboardPeriod.last2Years:
      return DateRangeBounds(
        start: DateTime(today.year - 2, today.month, today.day),
        end: today.add(const Duration(days: 1)),
      );
    case DashboardPeriod.last5Years:
      return DateRangeBounds(
        start: DateTime(today.year - 5, today.month, today.day),
        end: today.add(const Duration(days: 1)),
      );
    case DashboardPeriod.last10Years:
      return DateRangeBounds(
        start: DateTime(today.year - 10, today.month, today.day),
        end: today.add(const Duration(days: 1)),
      );
    case DashboardPeriod.all:
      return const DateRangeBounds();
  }
}

DateRangeBounds? previousDashboardPeriodRange({
  required DashboardPeriod period,
  DateTime? customFrom,
  DateTime? customTo,
  DateTime? reference,
}) {
  if (customFrom != null || customTo != null) {
    final current = resolveDashboardDateRange(
      period: period,
      customFrom: customFrom,
      customTo: customTo,
      reference: reference,
    );
    return previousRangeForBounds(current, reference: reference);
  }

  final now = reference ?? DateTime.now();
  final today = _startOfDay(now);

  switch (period) {
    case DashboardPeriod.thisWeek:
      return resolveDashboardDateRange(
        period: DashboardPeriod.lastWeek,
        reference: now,
      );
    case DashboardPeriod.lastWeek:
      final thisWeekStart = _startOfWeek(today);
      return DateRangeBounds(
        start: thisWeekStart.subtract(const Duration(days: 14)),
        end: thisWeekStart.subtract(const Duration(days: 7)),
      );
    case DashboardPeriod.thisMonth:
      return resolveDashboardDateRange(
        period: DashboardPeriod.lastMonth,
        reference: now,
      );
    case DashboardPeriod.lastMonth:
      final thisMonthStart = _startOfMonth(today);
      return DateRangeBounds(
        start: DateTime(thisMonthStart.year, thisMonthStart.month - 2, 1),
        end: DateTime(thisMonthStart.year, thisMonthStart.month - 1, 1),
      );
    case DashboardPeriod.thisQuarter:
      return resolveDashboardDateRange(
        period: DashboardPeriod.lastQuarter,
        reference: now,
      );
    case DashboardPeriod.lastQuarter:
      final thisQuarterStart = _startOfQuarter(today);
      return DateRangeBounds(
        start: DateTime(thisQuarterStart.year, thisQuarterStart.month - 6, 1),
        end: DateTime(thisQuarterStart.year, thisQuarterStart.month - 3, 1),
      );
    case DashboardPeriod.thisYear:
      return resolveDashboardDateRange(
        period: DashboardPeriod.lastYear,
        reference: now,
      );
    case DashboardPeriod.lastYear:
      final thisYearStart = _startOfYear(today);
      return DateRangeBounds(
        start: DateTime(thisYearStart.year - 2, 1, 1),
        end: DateTime(thisYearStart.year - 1, 1, 1),
      );
    case DashboardPeriod.last2Years:
    case DashboardPeriod.last5Years:
    case DashboardPeriod.last10Years:
      final current = resolveDashboardDateRange(period: period, reference: now);
      return previousRangeForBounds(current, reference: reference);
    case DashboardPeriod.all:
      return null;
  }
}

DateRangeBounds? previousRangeForBounds(
  DateRangeBounds current, {
  DateTime? reference,
}) {
  if (current.start == null) return null;

  final end =
      current.end ??
      _startOfDay(reference ?? DateTime.now()).add(const Duration(days: 1));
  final duration = end.difference(current.start!);
  if (duration.inDays <= 0) return null;

  return DateRangeBounds(
    start: current.start!.subtract(duration),
    end: current.start,
  );
}
