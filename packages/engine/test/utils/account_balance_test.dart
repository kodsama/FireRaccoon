import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Account _account({double balance = 1000}) {
  return Account(
    id: '1',
    name: 'Checking',
    type: 'asset',
    role: 'defaultAsset',
    currentBalance: balance,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

Transaction _tx({
  required String id,
  required DateTime date,
  required double amount,
  String type = 'withdrawal',
  String source = 'Checking',
  String destination = 'Store',
}) {
  return Transaction(
    id: id,
    type: type,
    date: date,
    amount: amount,
    description: 'Test',
    sourceName: source,
    destinationName: destination,
    categoryName: '',
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

void main() {
  final reference = DateTime(2026, 7, 9);

  group('accountBalanceExcludingFuture', () {
    // Firefly's reported balance is already as-of-today (future-dated
    // transactions excluded server-side), so no client-side adjustment
    // may be applied on top of it.
    test('returns the reported balance unchanged', () {
      final balance = accountBalanceExcludingFuture(
        reportedBalance: 2000,
        accountName: 'Checking',
        transactions: [
          _tx(id: 'future', date: DateTime(2026, 7, 15), amount: 500),
          _tx(id: 'past', date: DateTime(2026, 7, 5), amount: 100),
        ],
        reference: reference,
      );

      expect(balance, 2000);
    });

    test('is unaffected by future transactions regardless of account', () {
      final balance = accountBalanceExcludingFuture(
        reportedBalance: 2000,
        accountName: 'Checking',
        transactions: [
          _tx(
            id: 'future-transfer',
            date: DateTime(2026, 7, 20),
            amount: 300,
            type: 'transfer',
            source: 'Savings',
            destination: 'Checking',
          ),
        ],
        reference: reference,
      );

      expect(balance, 2000);
    });
  });

  group('balanceFromSelectedTransactions', () {
    test('returns today balance when only non-future rows are selected', () {
      final transactions = [
        _tx(id: 'future', date: DateTime(2026, 7, 15), amount: 500),
        _tx(id: 'past', date: DateTime(2026, 7, 5), amount: 100),
      ];

      final balance = balanceFromSelectedTransactions(
        reportedBalance: 2000,
        accountName: 'Checking',
        transactions: transactions,
        selectedIds: {'past'},
        reference: reference,
      );

      expect(balance, 2000);
    });

    test('excludes unselected non-future transactions from the balance', () {
      final balance = balanceFromSelectedTransactions(
        reportedBalance: 2000,
        accountName: 'Checking',
        transactions: [
          _tx(id: 'included', date: DateTime(2026, 7, 5), amount: 100),
          _tx(id: 'excluded', date: DateTime(2026, 7, 4), amount: 250),
        ],
        selectedIds: {'included'},
        reference: reference,
      );

      expect(balance, 2250);
    });

    test('includes selected future transactions in the balance', () {
      // Credit-card style: today still owes 100, but a future reconciled
      // repayment is selected, so the reconciled/selected balance is 0.
      final balance = balanceFromSelectedTransactions(
        reportedBalance: -100,
        accountName: 'Platinum',
        transactions: [
          _tx(
            id: 'charge',
            date: DateTime(2026, 7, 5),
            amount: 100,
            source: 'Platinum',
            destination: 'Store',
          ),
          _tx(
            id: 'future-payment',
            date: DateTime(2026, 7, 31),
            amount: 100,
            type: 'deposit',
            source: 'Bank',
            destination: 'Platinum',
          ),
        ],
        selectedIds: {'charge', 'future-payment'},
        reference: reference,
      );

      expect(balance, 0);
    });

    test('ignores unselected future transactions', () {
      final balance = balanceFromSelectedTransactions(
        reportedBalance: -100,
        accountName: 'Platinum',
        transactions: [
          _tx(
            id: 'charge',
            date: DateTime(2026, 7, 5),
            amount: 100,
            source: 'Platinum',
            destination: 'Store',
          ),
          _tx(
            id: 'future-payment',
            date: DateTime(2026, 7, 31),
            amount: 100,
            type: 'deposit',
            source: 'Bank',
            destination: 'Platinum',
          ),
        ],
        selectedIds: {'charge'},
        reference: reference,
      );

      expect(balance, -100);
    });

    test(
      'reconciled-only selection reaches 0 when a future repayment is included',
      () {
        // Today still shows the card debt; unreconciled charges are left out of
        // the selection while a future reconciled repayment is included — the
        // reconciled amounts then net to 0.
        final transactions = [
          _tx(
            id: 'reconciled-charge',
            date: DateTime(2026, 7, 1),
            amount: 70,
            source: 'Platinum',
            destination: 'Store',
          ),
          _tx(
            id: 'open-charge',
            date: DateTime(2026, 7, 5),
            amount: 30,
            source: 'Platinum',
            destination: 'Store',
          ),
          _tx(
            id: 'future-payment',
            date: DateTime(2026, 7, 31),
            amount: 70,
            type: 'deposit',
            source: 'Bank',
            destination: 'Platinum',
          ),
        ];

        expect(
          balanceFromSelectedTransactions(
            reportedBalance: -100,
            accountName: 'Platinum',
            transactions: transactions,
            selectedIds: {'reconciled-charge', 'open-charge', 'future-payment'},
            reference: reference,
          ),
          -30,
        );
        expect(
          balanceFromSelectedTransactions(
            reportedBalance: -100,
            accountName: 'Platinum',
            transactions: transactions,
            selectedIds: {'reconciled-charge', 'future-payment'},
            reference: reference,
          ),
          0,
        );
      },
    );
  });

  group('resolvedAccountBalance', () {
    test('returns the reported balance for every account type', () {
      final asset = _account(balance: 2000);
      final expense = Account(
        id: '2',
        name: 'Groceries',
        type: 'expense',
        role: 'expenseAccount',
        currentBalance: 0,
        currencySymbol: '€',
        currencyCode: 'EUR',
      );

      final transactions = [
        _tx(id: 'future', date: DateTime(2026, 7, 12), amount: 200),
      ];

      expect(
        resolvedAccountBalance(asset, transactions, reference: reference),
        2000,
      );
      expect(
        resolvedAccountBalance(expense, transactions, reference: reference),
        0,
      );
    });
  });
}
