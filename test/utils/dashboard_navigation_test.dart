import 'package:fireracoon/router/dashboard_route.dart';
import 'package:fireracoon/utils/dashboard_navigation.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('analyticsRouteParamsFromDashboard', () {
    test('maps this year to expense year period', () {
      final params = analyticsRouteParamsFromDashboard(
        const DashboardRouteFilters(period: DashboardPeriod.thisYear),
      );

      expect(params.period, ExpensePeriod.year);
      expect(params.from, isNull);
      expect(params.to, isNull);
    });

    test('maps custom dashboard dates to route date params', () {
      final params = analyticsRouteParamsFromDashboard(
        DashboardRouteFilters(
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 6, 30),
        ),
      );

      expect(params.period, ExpensePeriod.month);
      expect(params.from, '2026-01-01');
      expect(params.to, '2026-06-30');
    });

    test('maps last month to expense lastMonth period', () {
      final params = analyticsRouteParamsFromDashboard(
        const DashboardRouteFilters(period: DashboardPeriod.lastMonth),
      );

      expect(params.period, ExpensePeriod.lastMonth);
      expect(params.from, isNull);
      expect(params.to, isNull);
    });

    test('maps multi-year dashboard periods to explicit date bounds', () {
      final params = analyticsRouteParamsFromDashboard(
        const DashboardRouteFilters(period: DashboardPeriod.last2Years),
      );

      expect(params.period, ExpensePeriod.month);
      expect(params.from, isNotNull);
      expect(params.to, isNotNull);
    });
  });
}
