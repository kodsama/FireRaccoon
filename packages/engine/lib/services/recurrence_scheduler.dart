import '../models/account_prognosis.dart';
import '../models/bill.dart';
import '../models/recurrence.dart';

/// A cash-flow event derived from a bill or recurrence schedule.
class ScheduledCashFlow {
  final DateTime date;
  final String description;
  final String transactionType;
  final String? sourceId;
  final String? sourceName;
  final String? destinationId;
  final String? destinationName;
  final double amount;
  final double? amountMin;
  final double? amountMax;
  final String? billId;
  final String? recurrenceId;
  final ScheduledFlowSource source;

  const ScheduledCashFlow({
    required this.date,
    required this.description,
    required this.transactionType,
    this.sourceId,
    this.sourceName,
    this.destinationId,
    this.destinationName,
    required this.amount,
    this.amountMin,
    this.amountMax,
    this.billId,
    this.recurrenceId,
    this.source = ScheduledFlowSource.transaction,
  });
}

DateTime prognosisStartOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool prognosisIsAfterDay(DateTime date, DateTime reference) {
  return prognosisStartOfDay(date).isAfter(prognosisStartOfDay(reference));
}

DateTime prognosisEndOfMonth(DateTime reference) =>
    DateTime(reference.year, reference.month + 1, 1);

int prognosisDaysInMonth(int year, int month) =>
    DateTime(year, month + 1, 0).day;

DateTime prognosisClampDayOfMonth(int year, int month, int day) {
  final maxDay = prognosisDaysInMonth(year, month);
  return DateTime(year, month, day.clamp(1, maxDay));
}

DateTime prognosisAdjustWeekend(DateTime date, RecurrenceWeekendMode mode) {
  return switch (mode) {
    RecurrenceWeekendMode.createAnyway => date,
    RecurrenceWeekendMode.skipWeekend => date,
    RecurrenceWeekendMode.previousFriday => switch (date.weekday) {
      DateTime.saturday => date.subtract(const Duration(days: 1)),
      DateTime.sunday => date.subtract(const Duration(days: 2)),
      _ => date,
    },
    RecurrenceWeekendMode.nextMonday => switch (date.weekday) {
      DateTime.saturday => date.add(const Duration(days: 2)),
      DateTime.sunday => date.add(const Duration(days: 1)),
      _ => date,
    },
  };
}

bool prognosisIsWeekend(DateTime date) =>
    date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

DateTime? prognosisNthWeekdayOfMonth(int year, int month, int n, int weekday) {
  var count = 0;
  final days = prognosisDaysInMonth(year, month);
  for (var day = 1; day <= days; day++) {
    final date = DateTime(year, month, day);
    if (date.weekday == weekday) {
      count++;
      if (count == n) return date;
    }
  }
  return null;
}

List<DateTime> expandRecurrenceOccurrences({
  required Recurrence recurrence,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  if (!recurrence.active || recurrence.repetitions.isEmpty) {
    return const [];
  }

  final occurrences = <DateTime>[];
  var day = prognosisStartOfDay(rangeStart);
  final end = prognosisStartOfDay(rangeEnd);

  while (day.isBefore(end)) {
    if (_isRecurrenceOccurrence(recurrence, day)) {
      final repetition = recurrence.primaryRepetition!;
      var occurrence = prognosisAdjustWeekend(day, repetition.weekend);
      if (repetition.weekend == RecurrenceWeekendMode.skipWeekend &&
          prognosisIsWeekend(occurrence)) {
        day = day.add(const Duration(days: 1));
        continue;
      }
      if (!occurrence.isBefore(rangeStart) && occurrence.isBefore(rangeEnd)) {
        occurrences.add(occurrence);
      }
    }
    day = day.add(const Duration(days: 1));
  }

  return occurrences;
}

bool _isRecurrenceOccurrence(Recurrence recurrence, DateTime day) {
  final first = prognosisStartOfDay(recurrence.firstDate);
  if (day.isBefore(first)) return false;

  if (recurrence.repeatUntil != null &&
      day.isAfter(prognosisStartOfDay(recurrence.repeatUntil!))) {
    return false;
  }

  if (recurrence.latestDate != null &&
      !prognosisIsAfterDay(day, recurrence.latestDate!)) {
    return false;
  }

  final repetition = recurrence.primaryRepetition!;
  final matches = switch (repetition.type) {
    RecurrenceRepetitionType.daily => _matchesDaily(
      first,
      day,
      repetition.skip,
    ),
    RecurrenceRepetitionType.weekly => _matchesWeekly(first, day, repetition),
    RecurrenceRepetitionType.monthly => _matchesMonthly(first, day, repetition),
    RecurrenceRepetitionType.yearly => _matchesYearly(first, day, repetition),
    RecurrenceRepetitionType.ndom => _matchesNdom(day, repetition),
  };
  if (!matches) return false;

  if (recurrence.nrOfRepetitions != null) {
    final count = _countOccurrencesUpToIgnoringCount(recurrence, day);
    if (count > recurrence.nrOfRepetitions!) return false;
  }

  return true;
}

int _countOccurrencesUpToIgnoringCount(Recurrence recurrence, DateTime day) {
  var count = 0;
  var cursor = prognosisStartOfDay(recurrence.firstDate);
  final limit = prognosisStartOfDay(day);
  while (!cursor.isAfter(limit)) {
    if (_isRecurrenceOccurrenceIgnoringCount(recurrence, cursor)) {
      count++;
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return count;
}

bool _isRecurrenceOccurrenceIgnoringCount(Recurrence recurrence, DateTime day) {
  final first = prognosisStartOfDay(recurrence.firstDate);
  if (day.isBefore(first)) return false;
  if (recurrence.repeatUntil != null &&
      day.isAfter(prognosisStartOfDay(recurrence.repeatUntil!))) {
    return false;
  }
  if (recurrence.latestDate != null &&
      !prognosisIsAfterDay(day, recurrence.latestDate!)) {
    return false;
  }
  final repetition = recurrence.primaryRepetition!;
  return switch (repetition.type) {
    RecurrenceRepetitionType.daily => _matchesDaily(
      first,
      day,
      repetition.skip,
    ),
    RecurrenceRepetitionType.weekly => _matchesWeekly(first, day, repetition),
    RecurrenceRepetitionType.monthly => _matchesMonthly(first, day, repetition),
    RecurrenceRepetitionType.yearly => _matchesYearly(first, day, repetition),
    RecurrenceRepetitionType.ndom => _matchesNdom(day, repetition),
  };
}

bool _matchesDaily(DateTime first, DateTime day, int skip) {
  final step = skip + 1;
  final diff = day.difference(first).inDays;
  return diff >= 0 && diff % step == 0;
}

bool _matchesWeekly(
  DateTime first,
  DateTime day,
  RecurrenceRepetition repetition,
) {
  final targetWeekday = int.tryParse(repetition.moment) ?? first.weekday;
  if (day.weekday != targetWeekday) return false;
  final stepWeeks = repetition.skip + 1;
  final weeks = day.difference(first).inDays ~/ 7;
  return weeks >= 0 && weeks % stepWeeks == 0;
}

bool _matchesMonthly(
  DateTime first,
  DateTime day,
  RecurrenceRepetition repetition,
) {
  final targetDay = int.tryParse(repetition.moment) ?? first.day;
  final expected = prognosisClampDayOfMonth(day.year, day.month, targetDay);
  if (!prognosisStartOfDay(day).isAtSameMomentAs(expected)) return false;
  final monthsDiff = (day.year - first.year) * 12 + (day.month - first.month);
  if (monthsDiff < 0) return false;
  final stepMonths = repetition.skip + 1;
  return monthsDiff % stepMonths == 0;
}

bool _matchesYearly(
  DateTime first,
  DateTime day,
  RecurrenceRepetition repetition,
) {
  final parsed = DateTime.tryParse(repetition.moment);
  final anchor = parsed ?? first;
  final expected = prognosisClampDayOfMonth(day.year, anchor.month, anchor.day);
  if (!prognosisStartOfDay(day).isAtSameMomentAs(expected)) return false;
  final years = day.year - first.year;
  if (years < 0) return false;
  final stepYears = repetition.skip + 1;
  return years % stepYears == 0;
}

bool _matchesNdom(DateTime day, RecurrenceRepetition repetition) {
  final parts = repetition.moment.split(',');
  if (parts.length != 2) return false;
  final week = int.tryParse(parts[0]);
  final weekday = int.tryParse(parts[1]);
  if (week == null || weekday == null) return false;
  final expected = prognosisNthWeekdayOfMonth(
    day.year,
    day.month,
    week,
    weekday,
  );
  return expected != null &&
      prognosisStartOfDay(expected).isAtSameMomentAs(prognosisStartOfDay(day));
}

List<ScheduledCashFlow> expandRecurrenceCashFlows({
  required Recurrence recurrence,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final dates = expandRecurrenceOccurrences(
    recurrence: recurrence,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );
  final flows = <ScheduledCashFlow>[];
  for (final date in dates) {
    for (final line in recurrence.transactions) {
      flows.add(
        ScheduledCashFlow(
          date: date,
          description: line.description.isEmpty
              ? recurrence.title
              : line.description,
          transactionType: recurrence.type.apiValue,
          sourceId: line.sourceId,
          sourceName: line.sourceName,
          destinationId: line.destinationId,
          destinationName: line.destinationName,
          amount: line.amount,
          recurrenceId: recurrence.id,
          source: ScheduledFlowSource.recurrence,
        ),
      );
    }
  }
  return flows;
}

List<DateTime> expandBillOccurrences({
  required Bill bill,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  if (!bill.active) return const [];
  final anchor = prognosisStartOfDay(bill.extensionDate ?? bill.date);
  if (bill.endDate != null &&
      prognosisStartOfDay(bill.endDate!).isBefore(rangeStart)) {
    return const [];
  }

  if (bill.repeatFrequency == BillRepeatFrequency.weekly) {
    return _expandWeeklyBillOccurrences(
      bill: bill,
      anchor: anchor,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  final occurrences = <DateTime>[];
  var month = DateTime(rangeStart.year, rangeStart.month, 1);
  final lastMonth = DateTime(rangeEnd.year, rangeEnd.month, 1);

  while (!month.isAfter(lastMonth)) {
    final candidate = _billOccurrenceInMonth(bill, anchor, month);
    if (candidate != null &&
        !candidate.isBefore(rangeStart) &&
        candidate.isBefore(rangeEnd)) {
      if (bill.endDate == null ||
          !candidate.isAfter(prognosisStartOfDay(bill.endDate!))) {
        occurrences.add(candidate);
      }
    }
    month = DateTime(month.year, month.month + 1, 1);
  }

  return occurrences;
}

List<DateTime> _expandWeeklyBillOccurrences({
  required Bill bill,
  required DateTime anchor,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final occurrences = <DateTime>[];
  final stepDays = 7 * (bill.skip + 1);
  var cursor = anchor;
  while (cursor.isBefore(rangeStart)) {
    cursor = cursor.add(Duration(days: stepDays));
  }
  while (cursor.isBefore(rangeEnd)) {
    if (bill.endDate == null ||
        !cursor.isAfter(prognosisStartOfDay(bill.endDate!))) {
      occurrences.add(cursor);
    }
    cursor = cursor.add(Duration(days: stepDays));
  }
  return occurrences;
}

DateTime? _billOccurrenceInMonth(
  Bill bill,
  DateTime anchor,
  DateTime monthStart,
) {
  return switch (bill.repeatFrequency) {
    BillRepeatFrequency.weekly => null,
    BillRepeatFrequency.monthly => prognosisClampDayOfMonth(
      monthStart.year,
      monthStart.month,
      anchor.day,
    ),
    BillRepeatFrequency.quarterly =>
      ((monthStart.month - anchor.month) % 3 == 0 &&
              monthStart.year >= anchor.year)
          ? prognosisClampDayOfMonth(
              monthStart.year,
              monthStart.month,
              anchor.day,
            )
          : null,
    BillRepeatFrequency.halfYear =>
      ((monthStart.month - anchor.month) % 6 == 0 &&
              monthStart.year >= anchor.year)
          ? prognosisClampDayOfMonth(
              monthStart.year,
              monthStart.month,
              anchor.day,
            )
          : null,
    BillRepeatFrequency.yearly =>
      monthStart.month == anchor.month
          ? prognosisClampDayOfMonth(
              monthStart.year,
              monthStart.month,
              anchor.day,
            )
          : null,
  };
}

List<ScheduledCashFlow> expandBillCashFlows({
  required Bill bill,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required String? sourceId,
  required String? sourceName,
  required String? destinationId,
  required String? destinationName,
  required String transactionType,
}) {
  final dates = expandBillOccurrences(
    bill: bill,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );
  return dates
      .map(
        (date) => ScheduledCashFlow(
          date: date,
          description: bill.name,
          transactionType: transactionType,
          sourceId: sourceId,
          sourceName: sourceName,
          destinationId: destinationId,
          destinationName: destinationName,
          amount: bill.amountAvg,
          amountMin: bill.amountMin,
          amountMax: bill.amountMax,
          billId: bill.id,
          source: ScheduledFlowSource.bill,
        ),
      )
      .toList();
}
