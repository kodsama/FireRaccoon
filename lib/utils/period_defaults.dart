import 'package:fireraccoon_engine/fireraccoon_engine.dart';

const kDefaultDashboardPeriod = DashboardPeriod.thisMonth;

typedef ExpensePeriodParams = ({
  ExpensePeriod period,
  DateTime? from,
  DateTime? to,
});

ExpensePeriodParams expenseParamsFromDashboardPeriod(
  DashboardPeriod period, {
  DateTime? reference,
}) {
  if (period == DashboardPeriod.all) {
    return (period: ExpensePeriod.all, from: null, to: null);
  }

  final directPeriod = switch (period) {
    DashboardPeriod.thisWeek || DashboardPeriod.lastWeek => ExpensePeriod.week,
    DashboardPeriod.thisMonth => ExpensePeriod.month,
    DashboardPeriod.lastMonth => ExpensePeriod.lastMonth,
    DashboardPeriod.thisQuarter ||
    DashboardPeriod.lastQuarter => ExpensePeriod.quarter,
    DashboardPeriod.thisYear || DashboardPeriod.lastYear => ExpensePeriod.year,
    _ => null,
  };

  if (directPeriod != null) {
    return (period: directPeriod, from: null, to: null);
  }

  final range = resolveDashboardDateRange(period: period, reference: reference);
  final inclusiveTo = range.end?.subtract(const Duration(days: 1));

  return (period: ExpensePeriod.month, from: range.start, to: inclusiveTo);
}

bool expenseFiltersMatchParams(
  ExpensePeriod period,
  DateTime? from,
  DateTime? to,
  ExpensePeriodParams expected,
) {
  if (period != expected.period) return false;
  if (from != expected.from || to != expected.to) return false;
  return true;
}

String? expensePeriodQueryValue(
  ExpensePeriod period, {
  required ExpensePeriodParams defaultParams,
  String? from,
  String? to,
}) {
  if (from != null || to != null) return null;
  if (expenseFiltersMatchParams(period, null, null, defaultParams)) {
    return null;
  }
  return period.name;
}

String? encodeExpensePeriodParam({
  required ExpensePeriod resolvedPeriod,
  required ExpensePeriodParams defaultParams,
  String? from,
  String? to,
  required bool periodWasExplicit,
}) {
  if (from != null || to != null) {
    return periodWasExplicit ? resolvedPeriod.name : null;
  }
  return expensePeriodQueryValue(
    resolvedPeriod,
    defaultParams: defaultParams,
    from: from,
    to: to,
  );
}

DashboardPeriod dashboardPeriodFromPrefs(String? stored) {
  if (stored == null || stored.isEmpty) return kDefaultDashboardPeriod;
  for (final value in DashboardPeriod.values) {
    if (value.name == stored) return value;
  }
  return kDefaultDashboardPeriod;
}
