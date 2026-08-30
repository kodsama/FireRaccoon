import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Transaction _tx({String id = '1', required DateTime date}) {
  return Transaction(
    id: id,
    type: 'deposit',
    date: date,
    amount: 1,
    description: id,
    sourceName: 'Employer',
    destinationName: 'Checking',
    categoryName: '',
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

void main() {
  test('groupTransactionsByMonth sorts groups and transactions', () {
    final groups = groupTransactionsByMonth([
      _tx(id: 'jan', date: DateTime(2026, 1, 5)),
      _tx(id: 'feb', date: DateTime(2026, 2, 2)),
      _tx(id: 'jan-2', date: DateTime(2026, 1, 20)),
    ]);

    expect(groups, hasLength(2));
    expect(groups.first.month, 2);
    expect(groups.last.transactions.map((t) => t.id), ['jan-2', 'jan']);
  });

  test('sumTransactionAmounts signs deposits positive without an account', () {
    final total = sumTransactionAmounts([
      _tx(id: 'in', date: DateTime(2026, 3, 1)), // deposit, +1
    ]);
    expect(total, 1);
  });

  test('signedListAmount is account-relative when an account is given', () {
    final incoming = Transaction(
      id: 'xfer',
      type: 'transfer',
      date: DateTime(2026, 3, 2),
      amount: 100,
      description: 'Top-up',
      sourceName: 'Savings',
      destinationName: 'Checking',
      categoryName: '',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    // Generic signing treats a transfer as negative; account-relative signing
    // counts a transfer INTO Checking as positive and OUT of Savings as negative.
    expect(signedListAmount(incoming), -100);
    expect(signedListAmount(incoming, accountName: 'Checking'), 100);
    expect(signedListAmount(incoming, accountName: 'Savings'), -100);
    expect(sumTransactionAmounts([incoming], accountName: 'Checking'), 100);
    expect(sumTransactionAmounts([incoming], accountName: 'Savings'), -100);
  });

  test('signedListAmount reverses when transfer amount is negative', () {
    final reversed = Transaction(
      id: 'xfer-neg',
      type: 'transfer',
      date: DateTime(2026, 3, 2),
      amount: -100,
      description: 'Refund transfer',
      sourceName: 'Savings',
      destinationName: 'Checking',
      categoryName: '',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    expect(signedListAmount(reversed, accountName: 'Checking'), -100);
    expect(signedListAmount(reversed, accountName: 'Savings'), 100);
  });

  test('selectionStateForIds reports partial selection', () {
    final state = selectionStateForIds(
      transactions: [
        _tx(id: 'a', date: DateTime(2026, 9, 2)),
        _tx(id: 'b', date: DateTime(2026, 9, 20)),
      ],
      selectedIds: {'a'},
      isToggleable: (_) => true,
    );

    expect(state, SelectionState.partial);
  });

  test('transactionMonthListItemCount includes headers and rows', () {
    final groups = groupTransactionsByMonth([
      _tx(id: 'a', date: DateTime(2026, 9, 2)),
      _tx(id: 'b', date: DateTime(2026, 9, 20)),
      _tx(id: 'c', date: DateTime(2026, 8, 1)),
    ]);

    expect(transactionMonthListItemCount(groups), 5);
  });

  test('shouldSelectAllForIds is false when everything selected', () {
    final transactions = [
      _tx(id: 'a', date: DateTime(2026, 9, 2)),
      _tx(id: 'b', date: DateTime(2026, 9, 20)),
    ];

    expect(
      shouldSelectAllForIds(
        transactions: transactions,
        selectedIds: {'a', 'b'},
        isToggleable: (_) => true,
      ),
      isFalse,
    );
    expect(
      selectionStateForIds(
        transactions: const [],
        selectedIds: {},
        isToggleable: (_) => true,
      ),
      SelectionState.none,
    );
  });
}
