import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Transaction _tx({
  String id = '1',
  required String type,
  required DateTime date,
  required double amount,
  String source = 'Employer',
  String destination = 'Checking',
  bool reconciled = false,
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
    reconciled: reconciled,
  );
}

void main() {
  group('signedAmountForAccount', () {
    test('handles deposits, withdrawals, and transfers', () {
      expect(
        signedAmountForAccount(
          _tx(type: 'deposit', date: DateTime(2026, 1, 1), amount: 50),
          'Checking',
        ),
        50,
      );
      expect(
        signedAmountForAccount(
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 1, 1),
            amount: 20,
            source: 'Checking',
            destination: 'Store',
          ),
          'Checking',
        ),
        -20,
      );
      expect(
        signedAmountForAccount(
          _tx(
            type: 'transfer',
            date: DateTime(2026, 1, 1),
            amount: 15,
            source: 'Checking',
            destination: 'Savings',
          ),
          'Savings',
        ),
        15,
      );
    });

    test('sums every split when reconciling an account', () {
      final splitGroup = Transaction(
        id: '99',
        type: 'withdrawal',
        date: DateTime(2026, 1, 5),
        amount: 30,
        description: 'Groceries',
        sourceName: 'Checking',
        destinationName: 'Market',
        categoryName: 'Food',
        currencySymbol: '€',
        currencyCode: 'EUR',
        splits: [
          _tx(
            id: '99',
            type: 'withdrawal',
            date: DateTime(2026, 1, 5),
            amount: 30,
            source: 'Checking',
            destination: 'Market',
          ),
          _tx(
            id: '99',
            type: 'withdrawal',
            date: DateTime(2026, 1, 5),
            amount: 20,
            source: 'Checking',
            destination: 'Pharmacy',
          ),
        ],
      );

      expect(signedAmountForAccount(splitGroup, 'Checking'), -50);
    });
  });

  group('computeReconciliationGap', () {
    test('returns zero when checked transactions match statement', () {
      final gap = computeReconciliationGap(
        startBalance: 100,
        endBalance: 130,
        selectedTransactions: [
          _tx(type: 'deposit', date: DateTime(2026, 1, 10), amount: 30),
        ],
        accountName: 'Checking',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );

      expect(gap, 0);
    });

    test('ignores checked transactions outside the period', () {
      final gap = computeReconciliationGap(
        startBalance: 100,
        endBalance: 100,
        selectedTransactions: [
          _tx(type: 'deposit', date: DateTime(2025, 12, 20), amount: 30),
        ],
        accountName: 'Checking',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );

      expect(gap, 0);
    });

    test('ignores future in-period transactions when computing gap', () {
      final gap = computeReconciliationGap(
        startBalance: 100,
        endBalance: 130,
        selectedTransactions: [
          _tx(type: 'deposit', date: DateTime(2026, 7, 5), amount: 30),
          _tx(type: 'deposit', date: DateTime(2026, 7, 20), amount: 40),
        ],
        accountName: 'Checking',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 31),
        reference: DateTime(2026, 7, 9),
      );

      expect(gap, 0);
    });
  });

  group('defaultReconciliationSelection', () {
    test('selects in-period transactions and excludes future dates', () {
      final transactions = [
        _tx(
          id: 'before',
          type: 'deposit',
          date: DateTime(2025, 12, 28),
          amount: 10,
        ),
        _tx(
          id: 'inside',
          type: 'deposit',
          date: DateTime(2026, 1, 10),
          amount: 20,
        ),
        _tx(
          id: 'future',
          type: 'deposit',
          date: DateTime(2026, 2, 3),
          amount: 30,
        ),
      ];

      final selected = defaultReconciliationSelection(
        transactions: transactions,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      ).toList();

      expect(selected, ['inside']);
    });

    test('excludes in-period transactions dated after today', () {
      final transactions = [
        _tx(
          id: 'past',
          type: 'deposit',
          date: DateTime(2026, 7, 5),
          amount: 10,
        ),
        _tx(
          id: 'future-in-period',
          type: 'deposit',
          date: DateTime(2026, 7, 20),
          amount: 20,
        ),
      ];

      final selected = defaultReconciliationSelection(
        transactions: transactions,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 31),
        reference: DateTime(2026, 7, 9),
      ).toList();

      expect(selected, ['past']);
    });

    test('unselecting an in-period transaction changes the gap', () {
      final inPeriod = _tx(
        type: 'deposit',
        date: DateTime(2026, 1, 10),
        amount: 30,
      );
      final allSelectedGap = computeReconciliationGap(
        startBalance: 100,
        endBalance: 130,
        selectedTransactions: [inPeriod],
        accountName: 'Checking',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );
      final noneSelectedGap = computeReconciliationGap(
        startBalance: 100,
        endBalance: 130,
        selectedTransactions: const [],
        accountName: 'Checking',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );

      expect(allSelectedGap, 0);
      expect(noneSelectedGap, 30);
    });
  });

  group('groupReconciliationTransactionsByMonth', () {
    test('groups transactions by calendar month in descending order', () {
      final groups = groupReconciliationTransactionsByMonth([
        _tx(id: 'jan', type: 'deposit', date: DateTime(2026, 1, 5), amount: 10),
        _tx(id: 'feb', type: 'deposit', date: DateTime(2026, 2, 2), amount: 20),
        _tx(
          id: 'jan-2',
          type: 'deposit',
          date: DateTime(2026, 1, 20),
          amount: 5,
        ),
      ]);

      expect(groups, hasLength(2));
      expect(groups.first.month, 2);
      expect(groups.first.transactions.map((t) => t.id), ['feb']);
      expect(groups.last.transactions.map((t) => t.id), ['jan-2', 'jan']);
    });

    test('reports partial selection for month groups', () {
      final transactions = [
        _tx(id: 'a', type: 'deposit', date: DateTime(2026, 6, 2), amount: 10),
        _tx(id: 'b', type: 'deposit', date: DateTime(2026, 6, 20), amount: 20),
      ];
      final reference = DateTime(2026, 7, 9);

      expect(
        reconciliationSelectionState(
          transactions: transactions,
          selectedIds: {'a'},
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 30),
          reference: reference,
        ),
        ReconciliationSelectionState.partial,
      );
      expect(
        shouldSelectAllReconciliationTransactions(
          transactions: transactions,
          selectedIds: {'a'},
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 30),
          reference: reference,
        ),
        isTrue,
      );
    });
  });

  group('reconciled state helpers', () {
    test('reconciledJournalIds collects reconciled transaction ids', () {
      final transactions = [
        _tx(
          id: 'a',
          type: 'deposit',
          date: DateTime(2026, 1, 1),
          amount: 10,
          reconciled: true,
        ),
        _tx(id: 'b', type: 'deposit', date: DateTime(2026, 1, 2), amount: 20),
      ];

      expect(reconciledJournalIds(transactions), {'a'});
    });

    test('reconciledSelectionState reports partial journals', () {
      final partial =
          _tx(
            type: 'withdrawal',
            date: DateTime(2026, 1, 1),
            amount: 10,
            reconciled: true,
          ).copyWith(
            splits: [
              _tx(
                type: 'withdrawal',
                date: DateTime(2026, 1, 1),
                amount: 10,
                reconciled: true,
              ),
              _tx(type: 'withdrawal', date: DateTime(2026, 1, 1), amount: 15),
            ],
          );

      expect(reconciledSelectionState(partial), SelectionState.partial);
      expect(
        reconciledSelectionState(
          _tx(
            type: 'deposit',
            date: DateTime(2026, 1, 1),
            amount: 10,
            reconciled: true,
          ),
        ),
        SelectionState.all,
      );
      expect(
        reconciledSelectionState(
          _tx(type: 'deposit', date: DateTime(2026, 1, 1), amount: 10),
        ),
        SelectionState.none,
      );
    });

    test('reconciledTransactionsInPeriod filters by date and flag', () {
      final transactions = [
        _tx(
          id: 'in',
          type: 'deposit',
          reconciled: true,
          date: DateTime(2026, 1, 10),
          amount: 10,
        ),
        _tx(
          id: 'out',
          type: 'deposit',
          reconciled: true,
          date: DateTime(2025, 12, 20),
          amount: 20,
        ),
        _tx(
          id: 'open',
          type: 'deposit',
          date: DateTime(2026, 1, 12),
          amount: 30,
        ),
      ];

      final reconciled = reconciledTransactionsInPeriod(
        transactions: transactions,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );

      expect(reconciled.map((transaction) => transaction.id), ['in']);
    });
  });

  group('buildReconciliationCorrection', () {
    test('routes positive gap into the asset account', () {
      final correction = buildReconciliationCorrection(
        accountId: '5',
        accountName: 'Checking',
        reconciliationAccountId: '77',
        reconciliationAccountName: 'Checking reconciliation (EUR)',
        currencyCode: 'EUR',
        currencySymbol: '€',
        gap: 12.5,
        endDate: DateTime(2026, 1, 31),
      );

      expect(correction.type, 'reconciliation');
      expect(correction.amount, 12.5);
      expect(correction.destinationId, '5');
      expect(correction.destinationName, 'Checking');
      // Both sides are named. Leaving the far one empty is how Firefly's own
      // interface asks the factory to fill it in, and the REST layer turns an
      // absent name into an empty string before the validator sees it, so the
      // request built zero journals instead.
      expect(correction.sourceId, '77');
      expect(correction.sourceName, 'Checking reconciliation (EUR)');
    });
  });

  group('date helpers', () {
    test('future reconciliation transactions are after period end', () {
      expect(
        isFutureReconciliationTransaction(
          DateTime(2026, 2, 5),
          DateTime(2026, 1, 31),
        ),
        isTrue,
      );
      expect(
        isFutureReconciliationTransaction(
          DateTime(2026, 1, 15),
          DateTime(2026, 1, 31),
        ),
        isFalse,
      );
    });
  });

  group('reconciliationToggleableTransactions', () {
    test('returns only in-period occurred transactions', () {
      final transactions = [
        _tx(
          id: 'past',
          type: 'deposit',
          date: DateTime(2026, 7, 5),
          amount: 10,
        ),
        _tx(
          id: 'future',
          type: 'deposit',
          date: DateTime(2026, 7, 20),
          amount: 20,
        ),
      ];

      final toggleable = reconciliationToggleableTransactions(
        transactions: transactions,
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 31),
        reference: DateTime(2026, 7, 9),
      );

      expect(toggleable.map((t) => t.id), ['past']);
    });
  });

  group('transactionsForReconciliationView', () {
    test('includes buffered range and sorts newest first', () {
      final visible = transactionsForReconciliationView(
        transactions: [
          _tx(
            id: 'old',
            type: 'deposit',
            date: DateTime(2025, 12, 20),
            amount: 10,
          ),
          _tx(
            id: 'new',
            type: 'deposit',
            date: DateTime(2026, 1, 20),
            amount: 20,
            source: 'Employer',
            destination: 'Checking',
          ),
        ],
        accountName: 'Checking',
        startDate: DateTime(2026, 1, 10),
        endDate: DateTime(2026, 1, 31),
      );

      expect(visible, hasLength(1));
      expect(visible.single.id, 'new');
    });
  });

  group('buildReconciliationCorrection negative gap', () {
    test('routes surplus out of the asset account', () {
      final correction = buildReconciliationCorrection(
        accountId: '5',
        accountName: 'Checking',
        reconciliationAccountId: '77',
        reconciliationAccountName: 'Checking reconciliation (EUR)',
        currencyCode: 'EUR',
        currencySymbol: '€',
        gap: -12.5,
        endDate: DateTime(2026, 1, 31),
      );

      expect(correction.sourceId, '5');
      expect(correction.sourceName, 'Checking');
      expect(correction.destinationId, '77');
      expect(correction.destinationName, 'Checking reconciliation (EUR)');
    });
  });

  group('findReconciliationAccount', () {
    Account reconciliation(String id, String name) => Account(
      id: id,
      name: name,
      type: 'reconciliation',
      role: '',
      currentBalance: 0,
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    test('takes the name this Firefly writes, currency and all', () {
      final found = findReconciliationAccount(
        [
          reconciliation('1', 'Savings reconciliation (EUR)'),
          reconciliation('2', 'Checking reconciliation (EUR)'),
        ],
        accountName: 'Checking',
        currencyCode: 'EUR',
      );

      expect(found?.id, '2');
    });

    test('takes the bare name an older Firefly wrote', () {
      // An account keeps the name it was made with, so a ledger running since
      // 2020 holds both spellings.
      final found = findReconciliationAccount(
        [reconciliation('3', 'Checking reconciliation')],
        accountName: 'Checking',
        currencyCode: 'SEK',
      );

      expect(found?.id, '3');
    });

    test('takes a suffix in another currency over nothing', () {
      // Firefly names it in the instance's primary currency when the account
      // carries none of its own.
      final found = findReconciliationAccount(
        [reconciliation('4', 'Checking reconciliation (USD)')],
        accountName: 'Checking',
        currencyCode: 'EUR',
      );

      expect(found?.id, '4');
    });

    test('does not take another account with a longer name', () {
      final found = findReconciliationAccount(
        [reconciliation('5', 'Checking 2 reconciliation (EUR)')],
        accountName: 'Checking',
        currencyCode: 'EUR',
      );

      expect(found, isNull);
    });

    test('answers nothing when Firefly has made none', () {
      expect(
        findReconciliationAccount(
          const <Account>[],
          accountName: 'Checking',
          currencyCode: 'EUR',
        ),
        isNull,
      );
    });
  });
}
