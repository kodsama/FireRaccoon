import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Recurrence _monthly({
  String id = 'r1',
  int momentDay = 20,
  double amount = 500,
  String description = 'Rent',
  bool active = true,
}) {
  return Recurrence(
    id: id,
    type: RecurrenceTransactionType.withdrawal,
    title: description,
    firstDate: DateTime(2026, 1, 20),
    active: active,
    repetitions: [
      RecurrenceRepetition(
        type: RecurrenceRepetitionType.monthly,
        moment: '$momentDay',
      ),
    ],
    transactions: [
      RecurrenceTransactionLine(
        description: description,
        amount: amount,
        currencyCode: 'SEK',
        sourceName: 'Checking',
        destinationName: 'Landlord',
      ),
    ],
  );
}

Transaction _existing({
  required DateTime date,
  double amount = 500,
  String description = 'Rent',
  String? notes,
  String id = 'x1',
  String sourceName = 'Checking',
  String destinationName = 'Landlord',
  String? sourceId,
  String? destinationId,
}) {
  return Transaction(
    id: id,
    type: 'withdrawal',
    date: date,
    amount: amount,
    description: description,
    sourceName: sourceName,
    destinationName: destinationName,
    categoryName: '',
    currencySymbol: 'kr',
    currencyCode: 'SEK',
    sourceId: sourceId,
    destinationId: destinationId,
    notes: notes,
  );
}

void main() {
  final reference = DateTime(2026, 7, 12);

  group('planWriteAheadTransactions', () {
    test('materializes occurrences within the horizon with the marker', () {
      final planned = planWriteAheadTransactions(
        recurrences: [_monthly()],
        existing: const [],
        days: 30,
        reference: reference,
      );

      expect(planned, hasLength(1));
      final tx = planned.single;
      expect(tx.date, DateTime(2026, 7, 20));
      expect(tx.type, 'withdrawal');
      expect(tx.amount, 500);
      expect(tx.notes, 'fireraccoon:auto-written:r1');
      expect(tx.sourceName, 'Checking');
      expect(tx.destinationName, 'Landlord');
    });

    test('longer horizons cover multiple occurrences', () {
      final planned = planWriteAheadTransactions(
        recurrences: [_monthly()],
        existing: const [],
        days: 90,
        reference: reference,
      );
      expect(planned.map((t) => t.date).toList(), [
        DateTime(2026, 7, 20),
        DateTime(2026, 8, 20),
        DateTime(2026, 9, 20),
      ]);
    });

    test('skips occurrences already present in the window', () {
      final planned = planWriteAheadTransactions(
        recurrences: [_monthly()],
        existing: [_existing(date: DateTime(2026, 7, 20))],
        days: 30,
        reference: reference,
      );
      expect(planned, isEmpty);
    });

    test('re-running after a write plans nothing new', () {
      final first = planWriteAheadTransactions(
        recurrences: [_monthly()],
        existing: const [],
        days: 60,
        reference: reference,
      );
      final second = planWriteAheadTransactions(
        recurrences: [_monthly()],
        existing: first,
        days: 60,
        reference: reference,
      );
      expect(first, hasLength(2));
      expect(second, isEmpty);
    });

    test('inactive recurrences and zero horizon are ignored', () {
      expect(
        planWriteAheadTransactions(
          recurrences: [_monthly(active: false)],
          existing: const [],
          days: 30,
          reference: reference,
        ),
        isEmpty,
      );
      expect(
        planWriteAheadTransactions(
          recurrences: [_monthly()],
          existing: const [],
          days: 0,
          reference: reference,
        ),
        isEmpty,
      );
    });

    test('every row names the rule that planned it', () {
      final planned = planWriteAheadTransactions(
        recurrences: [
          _monthly(id: 'r7'),
          _monthly(id: 'r8', momentDay: 21),
        ],
        existing: const [],
        days: 30,
        reference: reference,
      );

      expect(planned.map((t) => t.notes), [
        'fireraccoon:auto-written:r7',
        'fireraccoon:auto-written:r8',
      ]);
    });

    test('uses DateTime.now when reference omitted', () {
      final planned = planWriteAheadTransactions(
        recurrences: [_monthly(momentDay: DateTime.now().day)],
        existing: const [],
        days: 1,
      );

      expect(planned, isA<List<Transaction>>());
    });
  });

  group('writeAheadRowsFor', () {
    test('takes the rows whose marker names this rule', () {
      final mine = _existing(
        id: 'a',
        date: DateTime(2026, 8, 20),
        notes: writeAheadMarkerFor('r1'),
      );
      final theirs = _existing(
        id: 'b',
        date: DateTime(2026, 8, 20),
        notes: writeAheadMarkerFor('r2'),
      );
      final manual = _existing(id: 'c', date: DateTime(2026, 8, 20));

      final rows = writeAheadRowsFor(
        recurrence: _monthly(),
        transactions: [mine, theirs, manual],
      );

      expect(rows.map((r) => r.id), ['a']);
    });

    test('a row from before the id was carried is matched on its accounts and '
        'a date the schedule falls on', () {
      // The marker used to be the same constant on every row, so the only
      // things left pointing at a rule are the two accounts it moves between
      // and the day it falls on.
      final onSchedule = _existing(
        id: 'a',
        date: DateTime(2026, 8, 20),
        notes: kWriteAheadMarker,
      );
      final offSchedule = _existing(
        id: 'b',
        date: DateTime(2026, 8, 21),
        notes: kWriteAheadMarker,
      );
      final elsewhere = _existing(
        id: 'c',
        date: DateTime(2026, 8, 20),
        notes: kWriteAheadMarker,
        destinationName: 'Someone else',
      );

      final rows = writeAheadRowsFor(
        recurrence: _monthly(),
        transactions: [onSchedule, offSchedule, elsewhere],
      );

      expect(rows.map((r) => r.id), ['a']);
    });

    test('the spelling from before the raccoon rename is read too', () {
      final rows = writeAheadRowsFor(
        recurrence: _monthly(),
        transactions: [
          _existing(
            id: 'a',
            date: DateTime(2026, 8, 20),
            notes: 'fireracoon:auto-written',
          ),
          _existing(
            id: 'b',
            date: DateTime(2026, 8, 20),
            notes: 'fireracoon:auto-written:r1',
          ),
        ],
      );

      expect(rows.map((r) => r.id), ['a', 'b']);
    });

    test('accounts are matched by id when the rule names one', () {
      final recurrence = Recurrence(
        id: 'r1',
        type: RecurrenceTransactionType.withdrawal,
        title: 'Rent',
        firstDate: DateTime(2026, 1, 20),
        repetitions: [
          const RecurrenceRepetition(
            type: RecurrenceRepetitionType.monthly,
            moment: '20',
          ),
        ],
        transactions: [
          const RecurrenceTransactionLine(
            description: 'Rent',
            amount: 500,
            currencyCode: 'SEK',
            sourceId: '5',
            sourceName: 'Checking',
            destinationId: '9',
            destinationName: 'Landlord',
          ),
        ],
      );

      final rows = writeAheadRowsFor(
        recurrence: recurrence,
        transactions: [
          _existing(
            id: 'a',
            date: DateTime(2026, 8, 20),
            notes: kWriteAheadMarker,
            sourceId: '5',
            destinationId: '9',
          ),
          // The same account names, a different account pair underneath.
          _existing(
            id: 'b',
            date: DateTime(2026, 8, 20),
            notes: kWriteAheadMarker,
            sourceId: '5',
            destinationId: '11',
          ),
        ],
      );

      expect(rows.map((r) => r.id), ['a']);
    });

    test('a rule with no line claims only the rows that name it', () {
      final lineless = Recurrence(
        id: 'r1',
        type: RecurrenceTransactionType.withdrawal,
        title: 'Rent',
        firstDate: DateTime(2026, 1, 20),
        repetitions: [
          const RecurrenceRepetition(
            type: RecurrenceRepetitionType.monthly,
            moment: '20',
          ),
        ],
      );

      final rows = writeAheadRowsFor(
        recurrence: lineless,
        transactions: [
          _existing(
            id: 'a',
            date: DateTime(2026, 8, 20),
            notes: kWriteAheadMarker,
          ),
          _existing(
            id: 'b',
            date: DateTime(2026, 8, 20),
            notes: writeAheadMarkerFor('r1'),
          ),
        ],
      );

      expect(rows.map((r) => r.id), ['b']);
    });
  });

  group('write-ahead notes', () {
    test('a note is read for its marker and the rule it names', () {
      expect(isWriteAheadNote(null), isFalse);
      expect(isWriteAheadNote('bank text: ICA'), isFalse);
      expect(isWriteAheadNote(kWriteAheadMarker), isTrue);
      expect(writeAheadRecurrenceId(null), isNull);
      expect(writeAheadRecurrenceId(kWriteAheadMarker), isNull);
      expect(writeAheadRecurrenceId(writeAheadMarkerFor('r3')), 'r3');
    });

    test('the marker is found among other notes', () {
      const notes = 'bank text: ICA\nfireraccoon:auto-written:r4\nseen';

      expect(isWriteAheadNote(notes), isTrue);
      expect(writeAheadRecurrenceId(notes), 'r4');
    });
  });
}
