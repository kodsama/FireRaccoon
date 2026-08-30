import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/utils/period_defaults.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

void main() {
  group('expenseParamsFromDashboardPeriod', () {
    test('maps preset periods directly', () {
      expect(
        expenseParamsFromDashboardPeriod(DashboardPeriod.thisWeek).period,
        ExpensePeriod.week,
      );
      expect(
        expenseParamsFromDashboardPeriod(DashboardPeriod.thisMonth).period,
        ExpensePeriod.month,
      );
      expect(
        expenseParamsFromDashboardPeriod(DashboardPeriod.lastMonth).period,
        ExpensePeriod.lastMonth,
      );
      expect(
        expenseParamsFromDashboardPeriod(DashboardPeriod.thisYear).period,
        ExpensePeriod.year,
      );
      expect(
        expenseParamsFromDashboardPeriod(DashboardPeriod.all).period,
        ExpensePeriod.all,
      );
    });

    test('maps rolling windows to custom date bounds', () {
      final params = expenseParamsFromDashboardPeriod(
        DashboardPeriod.last2Years,
        reference: DateTime(2026, 7, 9),
      );
      expect(params.period, ExpensePeriod.month);
      expect(params.from, DateTime(2024, 7, 9));
      expect(params.to, DateTime(2026, 7, 9));
    });
  });

  group('expenseFiltersMatchParams', () {
    test('matches preset defaults', () {
      final expected = expenseParamsFromDashboardPeriod(
        DashboardPeriod.thisMonth,
      );
      expect(
        expenseFiltersMatchParams(ExpensePeriod.month, null, null, expected),
        isTrue,
      );
      expect(
        expenseFiltersMatchParams(ExpensePeriod.year, null, null, expected),
        isFalse,
      );
    });
  });
}
