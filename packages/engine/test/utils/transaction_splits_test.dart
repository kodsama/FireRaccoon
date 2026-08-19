import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:test/test.dart';

Transaction _tx({
  String id = '1',
  required String type,
  required DateTime date,
  required double amount,
  String source = 'Checking',
  String destination = 'Store',
  String? sourceId,
  String? destinationId,
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
    sourceId: sourceId,
    destinationId: destinationId,
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

  group('signedAmountForAccountById', () {
    test('sums split effects on the account holding that id', () {
      final tx = _tx(
        type: 'withdrawal',
        date: DateTime(2026, 7, 1),
        amount: 30,
        splits: [
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 7, 1),
            amount: 30,
            sourceId: '4',
            destinationId: '19',
          ),
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 7, 1),
            amount: 20,
            sourceId: '4',
            destinationId: '21',
          ),
        ],
      );

      expect(signedAmountForAccountById(tx, '4'), -50);
      expect(signedAmountForAccountById(tx, '19'), 30);
      expect(signedAmountForAccountById(tx, '7'), 0);
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

  group('signedAmountForSplitById', () {
    test('recovers the sign a name shared across types nets to zero', () {
      // Firefly makes account names unique only within a type, so an asset
      // account and an expense account can both be called VA Syd. The
      // name-keyed reader sees one split as both legs and returns 0.0, which
      // leaves a statement short by this row with no error raised.
      final split = _tx(
        type: 'withdrawal',
        date: DateTime(2026, 7, 3),
        amount: 481,
        source: 'VA Syd',
        sourceId: '4',
        destination: 'VA Syd',
        destinationId: '19',
      );

      expect(signedAmountForSplit(split, 'VA Syd'), 0);
      expect(signedAmountForSplitById(split, '4'), -481);
      expect(signedAmountForSplitById(split, '19'), 481);
    });

    test('a negative amount reverses both legs', () {
      final split = _tx(
        type: 'transfer',
        date: DateTime(2026, 7, 20),
        amount: -6500,
        sourceId: '4',
        destinationId: '19',
      );

      expect(signedAmountForSplitById(split, '4'), 6500);
      expect(signedAmountForSplitById(split, '19'), -6500);
    });

    test('a split naming its legs by id contributes nothing to a third', () {
      // Falling through to the type switch once the ids are known would charge
      // every withdrawal in the ledger against whatever account was asked for.
      final sourceOnly = _tx(
        type: 'withdrawal',
        date: DateTime(2026, 7, 5),
        amount: 75,
        sourceId: '4',
      );
      final destinationOnly = _tx(
        type: 'deposit',
        date: DateTime(2026, 7, 5),
        amount: 75,
        destinationId: '4',
      );

      expect(signedAmountForSplitById(sourceOnly, '19'), 0);
      expect(signedAmountForSplitById(destinationOnly, '19'), 0);
    });

    test('the same id on both legs nets to zero', () {
      final split = _tx(
        type: 'transfer',
        date: DateTime(2026, 7, 1),
        amount: 50,
        sourceId: '4',
        destinationId: '4',
      );

      expect(signedAmountForSplitById(split, '4'), 0);
    });

    test('a split carrying no ids falls back to the type sign', () {
      // Splits built locally before a write carry names only, so the id reader
      // has to stay usable there rather than reporting every line as zero.
      Transaction untyped(String type, double amount) =>
          _tx(type: type, date: DateTime(2026, 7, 1), amount: amount);

      expect(signedAmountForSplitById(untyped('deposit', 75), '4'), 75);
      expect(signedAmountForSplitById(untyped('deposit', -75), '4'), -75);
      expect(signedAmountForSplitById(untyped('withdrawal', 75), '4'), -75);
      expect(signedAmountForSplitById(untyped('withdrawal', -75), '4'), 75);
      expect(signedAmountForSplitById(untyped('transfer', 75), '4'), 0);
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

  group('transactionAffectsAccountId', () {
    test(
      'true for a shared name the name-keyed check reports as untouched',
      () {
        final tx = _tx(
          type: 'withdrawal',
          date: DateTime(2026, 7, 3),
          amount: 481,
          source: 'VA Syd',
          sourceId: '4',
          destination: 'VA Syd',
          destinationId: '19',
        );

        expect(transactionAffectsAccount(tx, 'VA Syd'), isFalse);
        expect(transactionAffectsAccountId(tx, '4'), isTrue);
        expect(transactionAffectsAccountId(tx, '7'), isFalse);
      },
    );
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
