import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:test/test.dart';

Transaction _tx({
  String id = '1',
  required String type,
  required DateTime date,
  required double amount,
  String source = 'Checking',
  String destination = 'Store',
  String category = 'Food',
  String? budgetId,
  List<Transaction> splits = const [],
}) {
  return Transaction(
    id: id,
    type: type,
    date: date,
    amount: amount,
    description: 'Parent',
    sourceName: source,
    destinationName: destination,
    categoryName: category,
    currencySymbol: '€',
    currencyCode: 'EUR',
    budgetId: budgetId,
    splits: splits,
  );
}

void main() {
  group('transactionTotalAmount', () {
    test('returns amount for single-line journals', () {
      final tx = _tx(
        type: 'withdrawal',
        date: DateTime(2026, 7, 1),
        amount: 42,
      );
      expect(tx.totalAmount, 42);
      expect(transactionTotalAmount(tx), 42);
    });

    test('sums every split in a group', () {
      final tx = _tx(
        type: 'withdrawal',
        date: DateTime(2026, 7, 1),
        amount: 30,
        splits: [
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 7, 1),
            amount: 30,
            category: 'Food',
          ),
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 7, 1),
            amount: 20,
            category: 'Health',
            destination: 'Pharmacy',
          ),
        ],
      );

      expect(tx.totalAmount, 50);
    });
  });

  group('signedAmountForAccount', () {
    test('sums split effects on the source account', () {
      final tx = _tx(
        type: 'withdrawal',
        date: DateTime(2026, 7, 1),
        amount: 30,
        splits: [
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 7, 1),
            amount: 30,
            destination: 'Market',
          ),
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 7, 1),
            amount: 20,
            destination: 'Pharmacy',
          ),
        ],
      );

      expect(signedAmountForAccount(tx, 'Checking'), -50);
    });

    test('transfer is negative on source and positive on destination', () {
      final tx = _tx(
        type: 'transfer',
        date: DateTime(2026, 7, 20),
        amount: 6500,
        source: 'Personal',
        destination: 'Common',
      );

      expect(signedAmountForAccount(tx, 'Personal'), -6500);
      expect(signedAmountForAccount(tx, 'Common'), 6500);
      expect(signedAmountForAccount(tx, 'Unrelated'), 0);
    });

    test('negative transfer amount reverses source and destination signs', () {
      final tx = _tx(
        type: 'transfer',
        date: DateTime(2026, 7, 20),
        amount: -6500,
        source: 'Personal',
        destination: 'Common',
      );

      expect(signedAmountForAccount(tx, 'Personal'), 6500);
      expect(signedAmountForAccount(tx, 'Common'), -6500);
    });
  });

  group('signedAmountForSplit', () {
    test('transfer leg signs match the viewed account', () {
      final split = _tx(
        type: 'transfer',
        date: DateTime(2026, 7, 20),
        amount: 100,
        source: 'A',
        destination: 'B',
      );

      expect(signedAmountForSplit(split, 'A'), -100);
      expect(signedAmountForSplit(split, 'B'), 100);
    });
  });

  group('computeCategorySums', () {
    test('counts each split category separately', () {
      final totals = computeCategorySums([
        _tx(
          type: 'withdrawal',
          date: DateTime(2026, 7, 1),
          amount: 30,
          splits: [
            _tx(
              type: 'withdrawal',
              date: DateTime(2026, 7, 1),
              amount: 30,
              category: 'Food',
            ),
            _tx(
              type: 'withdrawal',
              date: DateTime(2026, 7, 1),
              amount: 20,
              category: 'Health',
            ),
          ],
        ),
      ]);

      expect(totals['Food'], 30);
      expect(totals['Health'], 20);
    });
  });

  group('sumBudgetSpentInRange', () {
    test('sums only splits assigned to the budget', () {
      final spent = sumBudgetSpentInRange(
        [
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 7, 5),
            amount: 30,
            budgetId: 'b1',
            splits: [
              _tx(
                type: 'withdrawal',
                date: DateTime(2026, 7, 5),
                amount: 30,
                budgetId: 'b1',
              ),
              _tx(
                type: 'withdrawal',
                date: DateTime(2026, 7, 5),
                amount: 20,
                budgetId: 'b2',
              ),
            ],
          ),
        ],
        DateRangeBounds(start: DateTime(2026, 7, 1), end: DateTime(2026, 8, 1)),
        budgetId: 'b1',
      );

      expect(spent, 30);
    });
  });

  group('transactionAffectsAccount', () {
    test('true when any split moves the account', () {
      final tx = _tx(
        type: 'transfer',
        date: DateTime(2026, 7, 1),
        amount: 30,
        source: 'Checking',
        destination: 'Savings',
        splits: [
          _tx(
            type: 'transfer',
            date: DateTime(2026, 7, 1),
            amount: 30,
            source: 'Checking',
            destination: 'Savings',
          ),
        ],
      );

      expect(transactionAffectsAccount(tx, 'Checking'), isTrue);
      expect(transactionAffectsAccount(tx, 'Other'), isFalse);
    });
  });

  group('applySplitBalanceDelta', () {
    test('applies signed deltas for each split', () {
      final tx = _tx(
        type: 'withdrawal',
        date: DateTime(2026, 7, 1),
        amount: 30,
        splits: [
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 7, 1),
            amount: 30,
            destination: 'Market',
          ),
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 7, 1),
            amount: 20,
            destination: 'Pharmacy',
          ),
        ],
      );
      final applied = <double>[];

      applySplitBalanceDelta(
        transaction: tx,
        accountName: 'Checking',
        apply: applied.add,
      );

      expect(applied, [-30, -20]);
    });
  });

  group('reverseSplitBalanceDelta', () {
    test('reverses signed deltas for each split', () {
      final tx = _tx(
        type: 'transfer',
        date: DateTime(2026, 7, 1),
        amount: 50,
        source: 'Checking',
        destination: 'Savings',
      );
      final applied = <double>[];

      reverseSplitBalanceDelta(
        transaction: tx,
        accountName: 'Checking',
        apply: applied.add,
      );

      expect(applied, [50]);
    });
  });

  group('signedAmountForSplit edge cases', () {
    test('same source and destination nets to zero', () {
      final split = _tx(
        type: 'transfer',
        date: DateTime(2026, 7, 1),
        amount: 50,
        source: 'Checking',
        destination: 'Checking',
      );

      expect(signedAmountForSplit(split, 'Checking'), 0);
    });

    test('deposit without account match uses type-based sign', () {
      final split = _tx(
        type: 'deposit',
        date: DateTime(2026, 7, 1),
        amount: 75,
        source: 'Employer',
        destination: 'Checking',
      );

      expect(signedAmountForSplit(split, 'Unknown'), 75);
    });
  });
}
