import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Recurrence _recurrence({
  required RecurrenceRepetitionType type,
  String moment = '',
  int skip = 0,
  RecurrenceWeekendMode weekend = RecurrenceWeekendMode.createAnyway,
  DateTime? firstDate,
  DateTime? repeatUntil,
  DateTime? latestDate,
  int? nrOfRepetitions,
  bool active = true,
  List<RecurrenceTransactionLine>? transactions,
}) {
  return Recurrence(
    id: 'r1',
    title: 'Rent',
    type: RecurrenceTransactionType.withdrawal,
    active: active,
    firstDate: firstDate ?? DateTime(2026, 1, 5),
    repeatUntil: repeatUntil,
    latestDate: latestDate,
    nrOfRepetitions: nrOfRepetitions,
    repetitions: [
      RecurrenceRepetition(
        type: type,
        moment: moment,
        skip: skip,
        weekend: weekend,
      ),
    ],
    transactions:
        transactions ??
        [
          const RecurrenceTransactionLine(
            description: 'Rent',
            amount: 100,
            currencyCode: 'EUR',
            sourceName: 'Checking',
            destinationName: 'Landlord',
          ),
        ],
  );
}

Bill _bill({
  BillRepeatFrequency frequency = BillRepeatFrequency.monthly,
  DateTime? date,
  DateTime? endDate,
  DateTime? extensionDate,
  int skip = 0,
  bool active = true,
}) {
  return Bill(
    id: 'b1',
    name: 'Netflix',
    amountMin: 10,
    amountMax: 10,
    amountAvg: 10,
    currencyCode: 'EUR',
    currencySymbol: '€',
    date: date ?? DateTime(2026, 1, 15),
    endDate: endDate,
    extensionDate: extensionDate,
    repeatFrequency: frequency,
    skip: skip,
    active: active,
  );
}

void main() {
  test('day helpers', () {
    expect(
      prognosisStartOfDay(DateTime(2026, 7, 15, 12)),
      DateTime(2026, 7, 15),
    );
    expect(
      prognosisIsAfterDay(DateTime(2026, 7, 16), DateTime(2026, 7, 15)),
      isTrue,
    );
    expect(prognosisEndOfMonth(DateTime(2026, 7, 15)), DateTime(2026, 8, 1));
    expect(prognosisDaysInMonth(2026, 2), 28);
    expect(prognosisClampDayOfMonth(2026, 2, 31), DateTime(2026, 2, 28));
    expect(prognosisIsWeekend(DateTime(2026, 7, 11)), isTrue); // Sat
    expect(prognosisIsWeekend(DateTime(2026, 7, 10)), isFalse);
    expect(
      prognosisNthWeekdayOfMonth(2026, 7, 2, DateTime.monday),
      DateTime(2026, 7, 13),
    );
    expect(prognosisNthWeekdayOfMonth(2026, 7, 9, DateTime.monday), isNull);
  });

  test('prognosisAdjustWeekend modes', () {
    final saturday = DateTime(2026, 7, 11);
    final sunday = DateTime(2026, 7, 12);
    final friday = DateTime(2026, 7, 10);
    expect(
      prognosisAdjustWeekend(saturday, RecurrenceWeekendMode.createAnyway),
      saturday,
    );
    expect(
      prognosisAdjustWeekend(saturday, RecurrenceWeekendMode.skipWeekend),
      saturday,
    );
    expect(
      prognosisAdjustWeekend(saturday, RecurrenceWeekendMode.previousFriday),
      friday,
    );
    expect(
      prognosisAdjustWeekend(sunday, RecurrenceWeekendMode.previousFriday),
      friday,
    );
    expect(
      prognosisAdjustWeekend(friday, RecurrenceWeekendMode.previousFriday),
      friday,
    );
    expect(
      prognosisAdjustWeekend(saturday, RecurrenceWeekendMode.nextMonday),
      DateTime(2026, 7, 13),
    );
    expect(
      prognosisAdjustWeekend(sunday, RecurrenceWeekendMode.nextMonday),
      DateTime(2026, 7, 13),
    );
    expect(
      prognosisAdjustWeekend(friday, RecurrenceWeekendMode.nextMonday),
      friday,
    );
  });

  group('expandRecurrenceOccurrences', () {
    test('inactive or empty repetitions yield nothing', () {
      expect(
        expandRecurrenceOccurrences(
          recurrence: _recurrence(
            type: RecurrenceRepetitionType.daily,
            active: false,
          ),
          rangeStart: DateTime(2026, 1, 1),
          rangeEnd: DateTime(2026, 1, 10),
        ),
        isEmpty,
      );
      expect(
        expandRecurrenceOccurrences(
          recurrence: Recurrence(
            id: 'r',
            title: 'x',
            type: RecurrenceTransactionType.withdrawal,
            active: true,
            firstDate: DateTime(2026, 1, 1),
            repetitions: const [],
            transactions: const [],
          ),
          rangeStart: DateTime(2026, 1, 1),
          rangeEnd: DateTime(2026, 1, 10),
        ),
        isEmpty,
      );
    });

    test('daily weekly monthly yearly ndom', () {
      final daily = expandRecurrenceOccurrences(
        recurrence: _recurrence(
          type: RecurrenceRepetitionType.daily,
          firstDate: DateTime(2026, 1, 1),
          skip: 1,
        ),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 8),
      );
      expect(daily, [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 3),
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 7),
      ]);

      final weekly = expandRecurrenceOccurrences(
        recurrence: _recurrence(
          type: RecurrenceRepetitionType.weekly,
          moment: '1',
          firstDate: DateTime(2026, 1, 5), // Monday
        ),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 20),
      );
      expect(weekly.every((d) => d.weekday == DateTime.monday), isTrue);

      final monthly = expandRecurrenceOccurrences(
        recurrence: _recurrence(
          type: RecurrenceRepetitionType.monthly,
          moment: '15',
          firstDate: DateTime(2026, 1, 15),
        ),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 4, 1),
      );
      expect(monthly.map((d) => d.day).toSet(), {15});

      final yearly = expandRecurrenceOccurrences(
        recurrence: _recurrence(
          type: RecurrenceRepetitionType.yearly,
          moment: '2026-03-01',
          firstDate: DateTime(2024, 3, 1),
        ),
        rangeStart: DateTime(2024, 1, 1),
        rangeEnd: DateTime(2027, 1, 1),
      );
      expect(yearly, [
        DateTime(2024, 3, 1),
        DateTime(2025, 3, 1),
        DateTime(2026, 3, 1),
      ]);

      final ndom = expandRecurrenceOccurrences(
        recurrence: _recurrence(
          type: RecurrenceRepetitionType.ndom,
          moment: '2,1',
          firstDate: DateTime(2026, 1, 1),
        ),
        rangeStart: DateTime(2026, 7, 1),
        rangeEnd: DateTime(2026, 8, 1),
      );
      expect(ndom, [DateTime(2026, 7, 13)]);
    });

    test('weekend skip and nrOfRepetitions / repeatUntil / latestDate', () {
      final skipped = expandRecurrenceOccurrences(
        recurrence: _recurrence(
          type: RecurrenceRepetitionType.daily,
          firstDate: DateTime(2026, 7, 10),
          weekend: RecurrenceWeekendMode.skipWeekend,
        ),
        rangeStart: DateTime(2026, 7, 10),
        rangeEnd: DateTime(2026, 7, 14),
      );
      expect(skipped.every((d) => !prognosisIsWeekend(d)), isTrue);

      final limited = expandRecurrenceOccurrences(
        recurrence: _recurrence(
          type: RecurrenceRepetitionType.daily,
          firstDate: DateTime(2026, 1, 1),
          nrOfRepetitions: 2,
        ),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 10),
      );
      expect(limited, hasLength(2));

      final until = expandRecurrenceOccurrences(
        recurrence: _recurrence(
          type: RecurrenceRepetitionType.daily,
          firstDate: DateTime(2026, 1, 1),
          repeatUntil: DateTime(2026, 1, 3),
        ),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 10),
      );
      expect(until.last, DateTime(2026, 1, 3));

      final afterLatest = expandRecurrenceOccurrences(
        recurrence: _recurrence(
          type: RecurrenceRepetitionType.daily,
          firstDate: DateTime(2026, 1, 1),
          latestDate: DateTime(2026, 1, 2),
        ),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 10),
      );
      expect(afterLatest.first.isAfter(DateTime(2026, 1, 2)), isTrue);
    });
  });

  test('expandRecurrenceCashFlows builds scheduled flows', () {
    final flows = expandRecurrenceCashFlows(
      recurrence: _recurrence(
        type: RecurrenceRepetitionType.monthly,
        moment: '5',
        firstDate: DateTime(2026, 1, 5),
        transactions: const [
          RecurrenceTransactionLine(
            description: '',
            amount: 50,
            currencyCode: 'EUR',
            sourceId: '1',
            sourceName: 'Checking',
            destinationId: '2',
            destinationName: 'Landlord',
          ),
        ],
      ),
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2026, 3, 1),
    );
    expect(flows, hasLength(2));
    expect(flows.first.description, 'Rent');
    expect(flows.first.source, ScheduledFlowSource.recurrence);
    expect(flows.first.amount, 50);
  });

  group('bills', () {
    test('inactive and ended bills', () {
      expect(
        expandBillOccurrences(
          bill: _bill(active: false),
          rangeStart: DateTime(2026, 1, 1),
          rangeEnd: DateTime(2026, 3, 1),
        ),
        isEmpty,
      );
      expect(
        expandBillOccurrences(
          bill: _bill(endDate: DateTime(2025, 12, 1)),
          rangeStart: DateTime(2026, 1, 1),
          rangeEnd: DateTime(2026, 3, 1),
        ),
        isEmpty,
      );
    });

    test('monthly quarterly halfYear yearly and weekly', () {
      expect(
        expandBillOccurrences(
          bill: _bill(frequency: BillRepeatFrequency.monthly),
          rangeStart: DateTime(2026, 1, 1),
          rangeEnd: DateTime(2026, 4, 1),
        ),
        [DateTime(2026, 1, 15), DateTime(2026, 2, 15), DateTime(2026, 3, 15)],
      );
      expect(
        expandBillOccurrences(
          bill: _bill(
            frequency: BillRepeatFrequency.quarterly,
            date: DateTime(2026, 1, 10),
          ),
          rangeStart: DateTime(2026, 1, 1),
          rangeEnd: DateTime(2026, 10, 1),
        ),
        isNotEmpty,
      );
      expect(
        expandBillOccurrences(
          bill: _bill(
            frequency: BillRepeatFrequency.halfYear,
            date: DateTime(2026, 1, 10),
          ),
          rangeStart: DateTime(2026, 1, 1),
          rangeEnd: DateTime(2027, 1, 1),
        ),
        isNotEmpty,
      );
      expect(
        expandBillOccurrences(
          bill: _bill(
            frequency: BillRepeatFrequency.yearly,
            date: DateTime(2025, 3, 10),
          ),
          rangeStart: DateTime(2025, 1, 1),
          rangeEnd: DateTime(2027, 1, 1),
        ),
        [DateTime(2025, 3, 10), DateTime(2026, 3, 10)],
      );
      expect(
        expandBillOccurrences(
          bill: _bill(
            frequency: BillRepeatFrequency.weekly,
            date: DateTime(2026, 1, 6),
            skip: 0,
            endDate: DateTime(2026, 1, 27),
          ),
          rangeStart: DateTime(2026, 1, 1),
          rangeEnd: DateTime(2026, 2, 1),
        ),
        isNotEmpty,
      );
    });

    test('expandBillCashFlows', () {
      final flows = expandBillCashFlows(
        bill: _bill(),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 3, 1),
        sourceId: 's',
        sourceName: 'Checking',
        destinationId: 'd',
        destinationName: 'Netflix',
        transactionType: 'withdrawal',
      );
      expect(flows, isNotEmpty);
      expect(flows.first.source, ScheduledFlowSource.bill);
      expect(flows.first.billId, 'b1');
      expect(flows.first.amount, 10);
    });
  });
}
