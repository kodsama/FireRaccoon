import 'package:fireraccoon/utils/balance_check_selection.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx({
  required String id,
  required DateTime date,
  bool reconciled = false,
}) {
  return Transaction(
    id: id,
    type: 'withdrawal',
    date: date,
    amount: 10,
    description: 'Test',
    sourceName: 'Checking',
    destinationName: 'Store',
    categoryName: '',
    currencySymbol: '€',
    currencyCode: 'EUR',
    reconciled: reconciled,
  );
}

void main() {
  group('balance check selection helpers', () {
    test('defaults start empty so all reconciled count automatically', () {
      final transactions = [
        _tx(id: 'past', date: DateTime(2026, 6, 1)),
        _tx(id: 'reconciled', date: DateTime(2026, 6, 2), reconciled: true),
        _tx(id: 'future-payment', date: DateTime(2026, 8, 1), reconciled: true),
      ];

      expect(defaultBalanceCheckIncludedIds(transactions), isEmpty);
      expect(defaultBalanceCheckExcludedIds(transactions), isEmpty);
      expect(
        effectiveBalanceCheckSelectedIds(
          transactions: transactions,
          includedIds: {},
          excludedIds: {},
        ),
        {'reconciled', 'future-payment'},
      );
    });

    test(
      'excluding a reconciled journal removes it from the effective set',
      () {
        final transactions = [
          _tx(id: 'a', date: DateTime(2026, 6, 1), reconciled: true),
          _tx(id: 'b', date: DateTime(2026, 6, 2), reconciled: true),
        ];

        expect(
          effectiveBalanceCheckSelectedIds(
            transactions: transactions,
            includedIds: {},
            excludedIds: {'a'},
          ),
          {'b'},
        );
      },
    );

    test('including an unreconciled journal adds it to the effective set', () {
      final transactions = [
        _tx(id: 'open', date: DateTime(2026, 6, 1)),
        _tx(id: 'done', date: DateTime(2026, 6, 2), reconciled: true),
      ];

      expect(
        effectiveBalanceCheckSelectedIds(
          transactions: transactions,
          includedIds: {'open'},
          excludedIds: {},
        ),
        {'open', 'done'},
      );
    });

    test('toggleBalanceCheckTransaction flips included and excluded sets', () {
      final included = <String>{};
      final excluded = <String>{};
      final reconciled = _tx(
        id: 'r',
        date: DateTime(2026, 6, 1),
        reconciled: true,
      );
      final open = _tx(id: 'o', date: DateTime(2026, 6, 2));

      toggleBalanceCheckTransaction(
        reconciled,
        includedIds: included,
        excludedIds: excluded,
      );
      expect(excluded, {'r'});
      expect(included, isEmpty);

      toggleBalanceCheckTransaction(
        reconciled,
        includedIds: included,
        excludedIds: excluded,
      );
      expect(excluded, isEmpty);

      toggleBalanceCheckTransaction(
        open,
        includedIds: included,
        excludedIds: excluded,
      );
      expect(included, {'o'});

      toggleBalanceCheckTransaction(
        open,
        includedIds: included,
        excludedIds: excluded,
      );
      expect(included, isEmpty);
    });

    test('partial journals stay selected unless excluded', () {
      final partial = Transaction(
        id: 'partial',
        type: 'withdrawal',
        date: DateTime(2026, 6, 1),
        amount: 30,
        description: 'Split',
        sourceName: 'Checking',
        destinationName: 'Store',
        categoryName: '',
        currencySymbol: '€',
        currencyCode: 'EUR',
        splits: [
          _tx(
            id: 'partial',
            date: DateTime(2026, 6, 1),
            reconciled: true,
          ).copyWith(amount: 10),
          _tx(id: 'partial', date: DateTime(2026, 6, 1)).copyWith(amount: 20),
        ],
      );

      final selection = BalanceCheckSelection(
        includedIds: {},
        excludedIds: {},
        onToggle: (_) {},
      );
      expect(selection.isSelected(partial), isTrue);
      expect(selection.stateFor(partial), SelectionState.partial);
      // Toggling used to be refused, which left the group with no way to be
      // finished or undone by anything.
      expect(selection.canToggle(partial), isTrue);

      final excluded = BalanceCheckSelection(
        includedIds: {},
        excludedIds: {'partial'},
        onToggle: (_) {},
      );
      expect(excluded.isSelected(partial), isFalse);
    });

    test('a part-reconciled group can be finished', () {
      final partial = _partialGroup();

      final changes = balanceCheckReconcileChanges(
        transactions: [partial],
        // Selected, because a part-reconciled row counts as included until
        // somebody opts it out.
        selectedIds: {'partial'},
      );

      expect(changes.toReconcile.single.id, 'partial');
      expect(changes.toUnreconcile, isEmpty);
      expect(changes.hasWork, isTrue);
    });

    test('a part-reconciled group can be undone', () {
      final partial = _partialGroup();

      final changes = balanceCheckReconcileChanges(
        transactions: [partial],
        selectedIds: const <String>{},
      );

      expect(changes.toUnreconcile.single.id, 'partial');
      expect(changes.toReconcile, isEmpty);
    });

    test('toggling a part-reconciled group opts it out and back in', () {
      final partial = _partialGroup();
      final included = <String>{};
      final excluded = <String>{};

      toggleBalanceCheckTransaction(
        partial,
        includedIds: included,
        excludedIds: excluded,
      );
      expect(excluded, {'partial'});

      toggleBalanceCheckTransaction(
        partial,
        includedIds: included,
        excludedIds: excluded,
      );
      expect(excluded, isEmpty);
    });

    test('deprecated selection helpers remain no-ops', () {
      final transactions = [_tx(id: 'a', date: DateTime(2026, 6, 1))];
      expect(defaultBalanceCheckSelection(transactions), isEmpty);
      final selected = <String>{'a'};
      syncBalanceCheckSelection(selected, transactions);
      expect(selected, {'a'});
    });

    test('toggleBalanceCheckMonthGroup only opts in unreconciled rows', () {
      final transactions = [
        _tx(id: 'a', date: DateTime(2026, 6, 1)),
        _tx(id: 'b', date: DateTime(2026, 6, 2), reconciled: true),
        _tx(id: 'c', date: DateTime(2026, 6, 3)),
      ];
      final included = <String>{};
      final excluded = <String>{};

      toggleBalanceCheckMonthGroup(
        transactions: transactions,
        includedIds: included,
        excludedIds: excluded,
      );
      expect(included, {'a', 'c'});
      expect(excluded, isEmpty);

      toggleBalanceCheckMonthGroup(
        transactions: transactions,
        includedIds: included,
        excludedIds: excluded,
      );
      expect(included, isEmpty);
      // Reconciled must not be mass-excluded by the month control.
      expect(excluded, isEmpty);
    });

    test('BalanceCheckSelection visuals distinguish the four states', () {
      final reconciled = _tx(
        id: 'b',
        date: DateTime(2026, 6, 2),
        reconciled: true,
      );
      final open = _tx(id: 'a', date: DateTime(2026, 6, 1));

      expect(
        BalanceCheckSelection(
          includedIds: const {},
          excludedIds: const {},
          onToggle: (_) {},
        ).visualFor(reconciled),
        BalanceCheckVisual.reconciledIncluded,
      );
      expect(
        BalanceCheckSelection(
          includedIds: const {},
          excludedIds: const {'b'},
          onToggle: (_) {},
        ).visualFor(reconciled),
        BalanceCheckVisual.reconciledExcluded,
      );
      expect(
        BalanceCheckSelection(
          includedIds: const {'a'},
          excludedIds: const {},
          onToggle: (_) {},
        ).visualFor(open),
        BalanceCheckVisual.pendingInclude,
      );
      expect(
        BalanceCheckSelection(
          includedIds: const {},
          excludedIds: const {},
          onToggle: (_) {},
        ).visualFor(open),
        BalanceCheckVisual.unselected,
      );

      final selectedOpen = BalanceCheckSelection(
        includedIds: const {'a'},
        excludedIds: const {},
        onToggle: (_) {},
      );
      expect(selectedOpen.stateFor(open), SelectionState.all);
      expect(selectedOpen.stateFor(reconciled), SelectionState.all);
      expect(
        BalanceCheckSelection(
          includedIds: const {},
          excludedIds: const {},
          onToggle: (_) {},
        ).stateFor(open),
        SelectionState.none,
      );
    });

    test('reconciled-only selection yields zero with a future repayment', () {
      final reference = DateTime(2026, 7, 9);
      final transactions = [
        Transaction(
          id: 'reconciled-charge',
          type: 'withdrawal',
          date: DateTime(2026, 7, 1),
          amount: 70,
          description: 'Test',
          sourceName: 'Platinum',
          destinationName: 'Store',
          categoryName: '',
          currencySymbol: 'kr',
          currencyCode: 'SEK',
          reconciled: true,
        ),
        Transaction(
          id: 'open-charge',
          type: 'withdrawal',
          date: DateTime(2026, 7, 5),
          amount: 30,
          description: 'Test',
          sourceName: 'Platinum',
          destinationName: 'Store',
          categoryName: '',
          currencySymbol: 'kr',
          currencyCode: 'SEK',
        ),
        Transaction(
          id: 'future-payment',
          type: 'deposit',
          date: DateTime(2026, 7, 31),
          amount: 70,
          description: 'Test',
          sourceName: 'Bank',
          destinationName: 'Platinum',
          categoryName: '',
          currencySymbol: 'kr',
          currencyCode: 'SEK',
          reconciled: true,
        ),
      ];

      final effective = effectiveBalanceCheckSelectedIds(
        transactions: transactions,
        includedIds: {},
        excludedIds: {},
      );

      expect(effective, {'reconciled-charge', 'future-payment'});
      expect(
        balanceFromSelectedTransactions(
          reportedBalance: -100,
          accountName: 'Platinum',
          transactions: transactions,
          selectedIds: effective,
          reference: reference,
        ),
        0,
      );
    });

    test(
      'newly loaded reconciled journals stay included without being opted in',
      () {
        // Simulates pagination: page 2 brings another reconciled journal that
        // was never added to includedIds. It must still count.
        final page1 = [
          _tx(id: 'r1', date: DateTime(2026, 6, 1), reconciled: true),
          _tx(id: 'open', date: DateTime(2026, 6, 2)),
        ];
        final page2 = [
          ...page1,
          _tx(id: 'r2', date: DateTime(2026, 5, 1), reconciled: true),
        ];

        expect(
          effectiveBalanceCheckSelectedIds(
            transactions: page1,
            includedIds: {},
            excludedIds: {},
          ),
          {'r1'},
        );
        expect(
          effectiveBalanceCheckSelectedIds(
            transactions: page2,
            includedIds: {},
            excludedIds: {},
          ),
          {'r1', 'r2'},
        );
      },
    );

    test(
      'default selection of already-reconciled journals has no reconcile work',
      () {
        final transactions = [
          _tx(id: 'open', date: DateTime(2026, 6, 1)),
          _tx(id: 'done', date: DateTime(2026, 6, 2), reconciled: true),
        ];
        final selectedIds = effectiveBalanceCheckSelectedIds(
          transactions: transactions,
          includedIds: {},
          excludedIds: {},
        );

        final changes = balanceCheckReconcileChanges(
          transactions: transactions,
          selectedIds: selectedIds,
        );

        expect(changes.toReconcile, isEmpty);
        expect(changes.toUnreconcile, isEmpty);
        expect(changes.hasWork, isFalse);
      },
    );

    test('opting in an unreconciled journal creates reconcile work', () {
      final transactions = [
        _tx(id: 'open', date: DateTime(2026, 6, 1)),
        _tx(id: 'done', date: DateTime(2026, 6, 2), reconciled: true),
      ];
      final selectedIds = effectiveBalanceCheckSelectedIds(
        transactions: transactions,
        includedIds: {'open'},
        excludedIds: {},
      );

      final changes = balanceCheckReconcileChanges(
        transactions: transactions,
        selectedIds: selectedIds,
      );

      expect(changes.toReconcile.map((t) => t.id), ['open']);
      expect(changes.toUnreconcile, isEmpty);
      expect(changes.hasWork, isTrue);
    });

    test('excluding a reconciled journal creates unreconcile work', () {
      final transactions = [
        _tx(id: 'done', date: DateTime(2026, 6, 2), reconciled: true),
      ];
      final selectedIds = effectiveBalanceCheckSelectedIds(
        transactions: transactions,
        includedIds: {},
        excludedIds: {'done'},
      );

      final changes = balanceCheckReconcileChanges(
        transactions: transactions,
        selectedIds: selectedIds,
      );

      expect(changes.toReconcile, isEmpty);
      expect(changes.toUnreconcile.map((t) => t.id), ['done']);
      expect(changes.hasWork, isTrue);
    });

    test('reconcile and unreconcile can both be pending', () {
      final transactions = [
        _tx(id: 'open', date: DateTime(2026, 6, 1)),
        _tx(id: 'keep', date: DateTime(2026, 6, 2), reconciled: true),
        _tx(id: 'drop', date: DateTime(2026, 6, 3), reconciled: true),
      ];

      final changes = balanceCheckReconcileChanges(
        transactions: transactions,
        selectedIds: {'open', 'keep'},
      );

      expect(changes.toReconcile.map((t) => t.id), ['open']);
      expect(changes.toUnreconcile.map((t) => t.id), ['drop']);
      expect(changes.hasWork, isTrue);
    });
  });
}

/// A group with one reconciled leg and one not, which is the state that used to
/// be impossible to leave.
Transaction _partialGroup() {
  return Transaction(
    id: 'partial',
    type: 'withdrawal',
    date: DateTime(2026, 6, 1),
    amount: 30,
    description: 'Split',
    sourceName: 'Checking',
    destinationName: 'Store',
    categoryName: '',
    currencySymbol: '\u20ac',
    currencyCode: 'EUR',
    splits: [
      _tx(
        id: 'partial',
        date: DateTime(2026, 6, 1),
        reconciled: true,
      ).copyWith(amount: 10),
      _tx(id: 'partial', date: DateTime(2026, 6, 1)).copyWith(amount: 20),
    ],
  );
}
