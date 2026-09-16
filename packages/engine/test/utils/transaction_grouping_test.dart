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
  _mergeGroupTests();

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

Transaction _leg({
  required String groupId,
  required String journalId,
  required double amount,
}) => Transaction(
  id: groupId,
  journalId: journalId,
  type: 'withdrawal',
  date: DateTime(2026, 3, 1),
  amount: amount,
  description: 'Insurance',
  sourceName: 'Checking',
  destinationName: 'Insurer',
  categoryName: '',
  currencySymbol: '€',
  currencyCode: 'EUR',
);

Transaction _group({
  required String groupId,
  required List<Transaction> legs,
}) => legs.first.copyWith(splits: legs, groupTitle: 'Insurance');

void _mergeGroupTests() {
  group('mergeTransactionGroups', () {
    test('a group split across the walk comes back whole', () {
      // Firefly paginates journals, not groups, and answered these two
      // interleaved: three legs of 94513, then two of 94512, then the last of
      // 94512, then the last three of 94513. Concatenating what came back
      // left four entries for two groups, each with its fragment's total, so
      // a six-leg bill read as two three-leg ones.
      final fragments = [
        _group(
          groupId: '94513',
          legs: [
            _leg(groupId: '94513', journalId: '108427', amount: 100.00),
            _leg(groupId: '94513', journalId: '108428', amount: 50.00),
            _leg(groupId: '94513', journalId: '108429', amount: 20.00),
          ],
        ),
        _group(
          groupId: '94512',
          legs: [
            _leg(groupId: '94512', journalId: '108424', amount: 120.00),
            _leg(groupId: '94512', journalId: '108425', amount: 58.00),
          ],
        ),
        _group(
          groupId: '94512',
          legs: [_leg(groupId: '94512', journalId: '108426', amount: 40.00)],
        ),
        _group(
          groupId: '94513',
          legs: [
            _leg(groupId: '94513', journalId: '108430', amount: 30.00),
            _leg(groupId: '94513', journalId: '108431', amount: 28.00),
            _leg(groupId: '94513', journalId: '108432', amount: 20.00),
          ],
        ),
      ];

      final merged = mergeTransactionGroups(fragments);

      expect(merged.map((t) => t.id), ['94513', '94512']);
      final byId = {for (final t in merged) t.id: t};
      expect(byId['94513']!.resolvedSplits(), hasLength(6));
      expect(byId['94512']!.resolvedSplits(), hasLength(3));
      expect(byId['94513']!.totalAmount, 248.00);
      expect(byId['94512']!.totalAmount, 218.00);
      expect(byId['94513']!.resolvedSplits().map((s) => s.journalId), [
        '108427',
        '108428',
        '108429',
        '108430',
        '108431',
        '108432',
      ]);
    });

    test('a walk with no fragmented group is handed back as it is', () {
      final whole = [
        _group(
          groupId: '1',
          legs: [_leg(groupId: '1', journalId: '10', amount: 5)],
        ),
        _group(
          groupId: '2',
          legs: [
            _leg(groupId: '2', journalId: '20', amount: 7),
            _leg(groupId: '2', journalId: '21', amount: 3),
          ],
        ),
      ];

      final merged = mergeTransactionGroups(whole);

      expect(merged, hasLength(2));
      expect(identical(merged[0], whole[0]), isTrue);
      expect(identical(merged[1], whole[1]), isTrue);
    });
  });
}
