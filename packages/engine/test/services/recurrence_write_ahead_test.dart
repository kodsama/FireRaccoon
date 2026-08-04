import 'package:fireracoon_engine/fireracoon_engine.dart';
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
}) {
  return Transaction(
    id: 'x1',
    type: 'withdrawal',
    date: date,
    amount: amount,
    description: description,
    sourceName: 'Checking',
    destinationName: 'Landlord',
    categoryName: '',
    currencySymbol: 'kr',
    currencyCode: 'SEK',
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
      expect(tx.notes, kWriteAheadMarker);
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

    test('uses DateTime.now when reference omitted', () {
      final planned = planWriteAheadTransactions(
        recurrences: [_monthly(momentDay: DateTime.now().day)],
        existing: const [],
        days: 1,
      );

      expect(planned, isA<List<Transaction>>());
    });
  });
}
