import 'package:test/test.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

void main() {
  group('resolveDashboardDateRange', () {
    final reference = DateTime(2026, 7, 15);

    test('covers every preset period', () {
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.thisWeek,
          reference: reference,
        ).start,
        DateTime(2026, 7, 13),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.lastWeek,
          reference: reference,
        ).start,
        DateTime(2026, 7, 6),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.thisMonth,
          reference: reference,
        ).start,
        DateTime(2026, 7, 1),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.lastMonth,
          reference: reference,
        ).start,
        DateTime(2026, 6, 1),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.thisQuarter,
          reference: reference,
        ).start,
        DateTime(2026, 7, 1),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.lastQuarter,
          reference: reference,
        ).start,
        DateTime(2026, 4, 1),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.thisYear,
          reference: reference,
        ).start,
        DateTime(2026, 1, 1),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.lastYear,
          reference: reference,
        ).start,
        DateTime(2025, 1, 1),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.last2Years,
          reference: reference,
        ).start,
        DateTime(2024, 7, 15),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.last5Years,
          reference: reference,
        ).start,
        DateTime(2021, 7, 15),
      );
      expect(
        resolveDashboardDateRange(
          period: DashboardPeriod.last10Years,
          reference: reference,
        ).start,
        DateTime(2016, 7, 15),
      );
      expect(
        resolveDashboardDateRange(period: DashboardPeriod.all).start,
        isNull,
      );
    });

    test('custom range variants and now fallback', () {
      final both = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        customFrom: DateTime(2026, 3, 10),
        customTo: DateTime(2026, 3, 20),
      );
      expect(both.start, DateTime(2026, 3, 10));
      expect(both.end, DateTime(2026, 3, 21));

      final fromOnly = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        customFrom: DateTime(2026, 3, 10),
      );
      expect(fromOnly.end, isNull);

      final toOnly = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        customTo: DateTime(2026, 3, 20),
      );
      expect(toOnly.start, isNull);

      final live = resolveDashboardDateRange(period: DashboardPeriod.thisMonth);
      final now = DateTime.now();
      expect(live.start, DateTime(now.year, now.month, 1));
    });
  });

  group('previousDashboardPeriodRange', () {
    final reference = DateTime(2026, 7, 15);

    test('covers calendar and rolling previous windows', () {
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.thisWeek,
          reference: reference,
        )?.start,
        DateTime(2026, 7, 6),
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.lastWeek,
          reference: reference,
        )?.start,
        DateTime(2026, 6, 29),
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.thisMonth,
          reference: reference,
        )?.start,
        DateTime(2026, 6, 1),
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.lastMonth,
          reference: reference,
        )?.start,
        DateTime(2026, 5, 1),
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.thisQuarter,
          reference: reference,
        )?.start,
        DateTime(2026, 4, 1),
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.lastQuarter,
          reference: reference,
        )?.start,
        DateTime(2026, 1, 1),
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.thisYear,
          reference: reference,
        )?.start,
        DateTime(2025, 1, 1),
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.lastYear,
          reference: reference,
        )?.start,
        DateTime(2024, 1, 1),
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.last2Years,
          reference: reference,
        )?.start,
        DateTime(2022, 7, 15),
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.last5Years,
          reference: reference,
        )?.start,
        isNotNull,
      );
      expect(
        previousDashboardPeriodRange(
          period: DashboardPeriod.last10Years,
          reference: reference,
        )?.start,
        isNotNull,
      );
      expect(previousDashboardPeriodRange(period: DashboardPeriod.all), isNull);
    });

    test('custom previousRangeForBounds paths', () {
      final previous = previousDashboardPeriodRange(
        period: DashboardPeriod.thisMonth,
        customFrom: DateTime(2026, 7, 1),
        customTo: DateTime(2026, 7, 31),
        reference: reference,
      );
      expect(previous?.end, DateTime(2026, 7, 1));

      expect(previousRangeForBounds(const DateRangeBounds()), isNull);
      expect(
        previousRangeForBounds(
          DateRangeBounds(
            start: DateTime(2026, 7, 1),
            end: DateTime(2026, 7, 1),
          ),
        ),
        isNull,
      );
      expect(
        previousRangeForBounds(
          DateRangeBounds(start: DateTime(2026, 7, 1)),
          reference: DateTime(2026, 7, 10),
        )?.start,
        isNotNull,
      );
    });
  });
}
