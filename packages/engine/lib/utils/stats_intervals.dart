import 'date_range.dart';

/// How finely a stretch of time is cut into buckets for a series.
enum StatsInterval { day, week, month, quarter, year }

/// The interval that keeps a series readable over [range]: a bar a day for
/// a month, a bar a month for a year, a bar a year beyond three of them.
/// Weeks start on Monday, as ISO weeks do.
StatsInterval autoStatsInterval(DateRangeBounds range) {
  final start = range.start;
  final end = range.end;
  if (start == null || end == null) return StatsInterval.year;
  final days = end.difference(start).inDays;
  if (days <= 31) return StatsInterval.day;
  if (days <= 92) return StatsInterval.week;
  if (days <= 3 * 366) return StatsInterval.month;
  return StatsInterval.year;
}

/// The first day of the bucket [date] falls in.
DateTime statsBucketStart(DateTime date, StatsInterval interval) {
  final day = DateTime(date.year, date.month, date.day);
  return switch (interval) {
    StatsInterval.day => day,
    StatsInterval.week => DateTime(
      day.year,
      day.month,
      day.day - (day.weekday - 1),
    ),
    StatsInterval.month => DateTime(day.year, day.month),
    StatsInterval.quarter => DateTime(day.year, ((day.month - 1) ~/ 3) * 3 + 1),
    StatsInterval.year => DateTime(day.year),
  };
}

/// The first day of the bucket after the one starting at [start].
DateTime statsNextBucket(DateTime start, StatsInterval interval) =>
    switch (interval) {
      StatsInterval.day => DateTime(start.year, start.month, start.day + 1),
      StatsInterval.week => DateTime(start.year, start.month, start.day + 7),
      StatsInterval.month => DateTime(start.year, start.month + 1),
      StatsInterval.quarter => DateTime(start.year, start.month + 3),
      StatsInterval.year => DateTime(start.year + 1),
    };

/// Every bucket from the one holding [first] to the one holding [last],
/// empty ones included, so a quiet month shows as a gap rather than being
/// skipped and making its neighbours look adjacent.
List<DateRangeBounds> statsBuckets(
  DateTime first,
  DateTime last,
  StatsInterval interval,
) {
  final buckets = <DateRangeBounds>[];
  var start = statsBucketStart(first, interval);
  final stop = statsBucketStart(last, interval);
  while (!start.isAfter(stop)) {
    final next = statsNextBucket(start, interval);
    buckets.add(DateRangeBounds(start: start, end: next));
    start = next;
  }
  return buckets;
}
