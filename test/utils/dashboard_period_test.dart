import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/utils/dashboard_period.dart';

void main() {
  group('resolveDashboardDateRange', () {
    final reference = DateTime(2026, 7, 15);

    test('defaults this year to calendar year', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        reference: reference,
      );
      expect(range.start, DateTime(2026, 1, 1));
      expect(range.end, DateTime(2027, 1, 1));
    });

    test('last month is previous calendar month', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.lastMonth,
        reference: reference,
      );
      expect(range.start, DateTime(2026, 6, 1));
      expect(range.end, DateTime(2026, 7, 1));
    });

    test('custom range uses inclusive from and to', () {
      final range = resolveDashboardDateRange(
        period: DashboardPeriod.thisYear,
        customFrom: DateTime(2026, 3, 10),
        customTo: DateTime(2026, 3, 20),
      );
      expect(range.start, DateTime(2026, 3, 10));
      expect(range.end, DateTime(2026, 3, 21));
    });

    test('all time has no bounds', () {
      final range = resolveDashboardDateRange(period: DashboardPeriod.all);
      expect(range.start, isNull);
      expect(range.end, isNull);
    });
  });

  group('previousDashboardPeriodRange', () {
    test('this month compares to last calendar month', () {
      final previous = previousDashboardPeriodRange(
        period: DashboardPeriod.thisMonth,
        reference: DateTime(2026, 7, 15),
      );
      expect(previous?.start, DateTime(2026, 6, 1));
      expect(previous?.end, DateTime(2026, 7, 1));
    });

    test('rolling windows compare equal-length prior span', () {
      final previous = previousDashboardPeriodRange(
        period: DashboardPeriod.last2Years,
        reference: DateTime(2026, 7, 15),
      );
      expect(previous?.start, DateTime(2022, 7, 15));
      expect(previous?.end, DateTime(2024, 7, 15));
    });

    test('returns null for all time', () {
      final previous = previousDashboardPeriodRange(
        period: DashboardPeriod.all,
      );
      expect(previous, isNull);
    });
  });
}
