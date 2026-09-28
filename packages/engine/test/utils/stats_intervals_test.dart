import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('autoStatsInterval', () {
    DateRangeBounds days(int count) => DateRangeBounds(
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 1, 1 + count),
    );

    test('picks days for a month, weeks for a quarter, months for years', () {
      expect(autoStatsInterval(days(31)), StatsInterval.day);
      expect(autoStatsInterval(days(92)), StatsInterval.week);
      expect(autoStatsInterval(days(365)), StatsInterval.month);
      expect(autoStatsInterval(days(3 * 365)), StatsInterval.month);
      expect(autoStatsInterval(days(5 * 365)), StatsInterval.year);
    });

    test('an open range goes by year', () {
      expect(autoStatsInterval(const DateRangeBounds()), StatsInterval.year);
    });
  });

  group('statsBucketStart', () {
    final wednesday = DateTime(2026, 9, 30, 18, 45);

    test('snaps to the start of each kind of bucket', () {
      expect(
        statsBucketStart(wednesday, StatsInterval.day),
        DateTime(2026, 9, 30),
      );
      expect(
        statsBucketStart(wednesday, StatsInterval.week),
        DateTime(2026, 9, 28),
      );
      expect(
        statsBucketStart(wednesday, StatsInterval.month),
        DateTime(2026, 9),
      );
      expect(
        statsBucketStart(wednesday, StatsInterval.quarter),
        DateTime(2026, 7),
      );
      expect(statsBucketStart(wednesday, StatsInterval.year), DateTime(2026));
    });

    test('a week that starts in the previous month or year', () {
      expect(
        statsBucketStart(DateTime(2027, 1, 1), StatsInterval.week),
        DateTime(2026, 12, 28),
      );
    });
  });

  group('statsBuckets', () {
    test('covers every bucket between two dates, empty ones included', () {
      final months = statsBuckets(
        DateTime(2026, 11, 20),
        DateTime(2027, 2, 3),
        StatsInterval.month,
      );
      expect(months.map((b) => b.start), [
        DateTime(2026, 11),
        DateTime(2026, 12),
        DateTime(2027, 1),
        DateTime(2027, 2),
      ]);
      expect(months.last.end, DateTime(2027, 3));
    });

    test('days cross a DST change without drifting off midnight', () {
      final days = statsBuckets(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 30),
        StatsInterval.day,
      );
      expect(days.map((b) => b.start!.hour).toSet(), {0});
      expect(days, hasLength(3));
    });

    test('quarters and weeks step by their own length', () {
      expect(
        statsBuckets(
          DateTime(2026, 2, 1),
          DateTime(2026, 8, 1),
          StatsInterval.quarter,
        ).map((b) => b.start!.month),
        [1, 4, 7],
      );
      expect(
        statsBuckets(
          DateTime(2026, 9, 1),
          DateTime(2026, 9, 15),
          StatsInterval.week,
        ).map((b) => b.start!.day),
        [31, 7, 14],
      );
    });
  });
}
