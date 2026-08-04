import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/router/dashboard_route.dart';
import 'package:fireracoon/utils/dashboard_period.dart';

void main() {
  group('DashboardPeriod completeness', () {
    test('has all 12 requested presets', () {
      expect(DashboardPeriod.values, hasLength(12));
      expect(DashboardPeriod.values, contains(DashboardPeriod.thisWeek));
      expect(DashboardPeriod.values, contains(DashboardPeriod.lastWeek));
      expect(DashboardPeriod.values, contains(DashboardPeriod.thisMonth));
      expect(DashboardPeriod.values, contains(DashboardPeriod.lastMonth));
      expect(DashboardPeriod.values, contains(DashboardPeriod.thisQuarter));
      expect(DashboardPeriod.values, contains(DashboardPeriod.lastQuarter));
      expect(DashboardPeriod.values, contains(DashboardPeriod.thisYear));
      expect(DashboardPeriod.values, contains(DashboardPeriod.lastYear));
      expect(DashboardPeriod.values, contains(DashboardPeriod.last2Years));
      expect(DashboardPeriod.values, contains(DashboardPeriod.last5Years));
      expect(DashboardPeriod.values, contains(DashboardPeriod.last10Years));
      expect(DashboardPeriod.values, contains(DashboardPeriod.all));
    });
  });

  group('resolveDashboardDateRange presets', () {
    final reference = DateTime(2026, 7, 6); // Monday

    test('this week starts on Monday', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisWeek,
        reference: reference,
      );
      expect(range.start, DateTime(2026, 7, 6));
      expect(range.end, DateTime(2026, 7, 7));
    });

    test('last week is prior Mon–Sun block', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.lastWeek,
        reference: reference,
      );
      expect(range.start, DateTime(2026, 6, 29));
      expect(range.end, DateTime(2026, 7, 6));
    });

    test('this quarter is Q3 2026', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisQuarter,
        reference: reference,
      );
      expect(range.start, DateTime(2026, 7, 1));
      expect(range.end, DateTime(2026, 10, 1));
    });

    test('last quarter is Q2 2026', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.lastQuarter,
        reference: reference,
      );
      expect(range.start, DateTime(2026, 4, 1));
      expect(range.end, DateTime(2026, 7, 1));
    });

    test('last year is previous calendar year', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.lastYear,
        reference: reference,
      );
      expect(range.start, DateTime(2025, 1, 1));
      expect(range.end, DateTime(2026, 1, 1));
    });

    test('last 2 years is rolling window', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.last2Years,
        reference: reference,
      );
      expect(range.start, DateTime(2024, 7, 6));
      expect(range.end, DateTime(2026, 7, 7));
    });

    test('last 5 years is rolling window', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.last5Years,
        reference: reference,
      );
      expect(range.start, DateTime(2021, 7, 6));
      expect(range.end, DateTime(2026, 7, 7));
    });

    test('last 10 years is rolling window', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.last10Years,
        reference: reference,
      );
      expect(range.start, DateTime(2016, 7, 6));
      expect(range.end, DateTime(2026, 7, 7));
    });
  });

  group('custom date range', () {
    test('from-only is open-ended on the right', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        customFrom: DateTime(2026, 1, 1),
      );
      expect(range.start, DateTime(2026, 1, 1));
      expect(range.end, isNull);
    });

    test('to-only is open-ended on the left', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        customTo: DateTime(2026, 6, 30),
      );
      expect(range.start, isNull);
      expect(range.end, DateTime(2026, 7, 1));
    });

    test('custom range overrides preset period', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.all,
        customFrom: DateTime(2026, 3, 1),
        customTo: DateTime(2026, 3, 31),
      );
      expect(range.start, DateTime(2026, 3, 1));
      expect(range.end, DateTime(2026, 4, 1));
    });
  });

  group('previousDashboardPeriodRange', () {
    test('custom range compares equal-length prior window', () {
      final reference = DateTime(2026, 7, 6);
      final previous = previousDashboardPeriodRange(
        period: DashboardPeriod.thisYear,
        customFrom: DateTime(2026, 4, 1),
        customTo: DateTime(2026, 6, 30),
        reference: reference,
      );
      final current = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        customFrom: DateTime(2026, 4, 1),
        customTo: DateTime(2026, 6, 30),
        reference: reference,
      );
      final expected = previousRangeForBounds(current, reference: reference);
      expect(previous?.start, expected?.start);
      expect(previous?.end, expected?.end);
    });

    test('this week compares to last week calendar block', () {
      final previous = previousDashboardPeriodRange(
        period: DashboardPeriod.thisWeek,
        reference: DateTime(2026, 7, 6),
      );
      expect(previous?.start, DateTime(2026, 6, 29));
      expect(previous?.end, DateTime(2026, 7, 6));
    });

    test('this month compares to last month', () {
      final previous = previousDashboardPeriodRange(
        period: DashboardPeriod.thisMonth,
        reference: DateTime(2026, 7, 15),
      );
      expect(previous?.start, DateTime(2026, 6, 1));
      expect(previous?.end, DateTime(2026, 7, 1));
    });
  });

  group('DashboardRoute URL round-trip', () {
    test('default omits period query param', () {
      expect(DashboardRoute.location(), '/');
      final filters = DashboardRoute.filtersFromUri(Uri.parse('/'));
      expect(filters.period, DashboardPeriod.thisMonth);
      expect(filters.hasCustomDateRange, isFalse);
    });

    test('preset period round-trips', () {
      for (final period in DashboardPeriod.values) {
        if (period == DashboardPeriod.thisMonth) continue;
        final uri = Uri.parse(DashboardRoute.location(period: period));
        expect(DashboardRoute.filtersFromUri(uri).period, period);
      }
    });

    test('tab + period + custom dates compose', () {
      final location = DashboardRoute.location(
        tab: DashboardTab.focus,
        from: '2026-01-15',
        to: '2026-02-20',
      );
      final filters = DashboardRoute.filtersFromUri(Uri.parse(location));
      expect(filters.tab, DashboardTab.focus);
      expect(filters.from, DateTime(2026, 1, 15));
      expect(filters.to, DateTime(2026, 2, 20));
      expect(filters.hasCustomDateRange, isTrue);

      final range = resolveDashboardDateRange(
        period: filters.period,
        customFrom: filters.from,
        customTo: filters.to,
      );
      expect(range.start, DateTime(2026, 1, 15));
      expect(range.end, DateTime(2026, 2, 21));
    });
  });
}
