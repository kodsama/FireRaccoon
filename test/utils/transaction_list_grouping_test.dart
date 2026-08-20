import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/l10n/app_localizations_en.dart';
import 'package:fireracoon/models/transaction.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/utils/locale_formatting.dart';
import 'package:fireracoon/utils/transaction_list_grouping.dart';

Transaction _tx({
  required String id,
  required DateTime date,
  String type = 'withdrawal',
  double amount = 10,
}) {
  return Transaction(
    id: id,
    type: type,
    date: date,
    amount: amount,
    description: 'Test',
    sourceName: 'Checking',
    destinationName: 'Groceries',
    categoryName: 'Food',
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

void main() {
  final l10n = AppLocalizationsEn();
  final format = LocaleFormatting(const Locale('en'));

  group('buildTransactionListGroups', () {
    test('splits future transactions from grouped periods', () {
      final reference = DateTime(2026, 7, 9);
      final result = buildTransactionListGroups(
        transactions: [
          _tx(id: 'past', date: DateTime(2026, 6, 15)),
          _tx(id: 'future', date: DateTime(2026, 8, 1)),
        ],
        activeAccountFilters: {},
        searchQuery: '',
        groupType: TransactionGroupType.date,
        format: format,
        l10n: l10n,
        referenceDate: reference,
      );

      expect(result.filteredTransactions, hasLength(2));
      expect(result.futureTransactions.map((t) => t.id), ['future']);
      expect(result.groups, hasLength(1));
      expect(result.groups.first.transactions.map((t) => t.id), ['past']);
    });

    test('groups by month label and computes signed sum', () {
      final result = buildTransactionListGroups(
        transactions: [
          _tx(
            id: 'income',
            date: DateTime(2026, 6, 1),
            type: 'deposit',
            amount: 50,
          ),
          _tx(
            id: 'expense',
            date: DateTime(2026, 6, 2),
            type: 'withdrawal',
            amount: 20,
          ),
        ],
        activeAccountFilters: {},
        searchQuery: '',
        groupType: TransactionGroupType.date,
        format: format,
        l10n: l10n,
        referenceDate: DateTime(2026, 7, 9),
      );

      expect(result.groups, hasLength(1));
      expect(result.groups.first.sum, 30);
      expect(
        result.groups.first.key,
        format.formatMonthYear(DateTime(2026, 6, 1)),
      );
    });

    test('sumAccount signs amounts from the filtered account perspective', () {
      final incomingTransfer = Transaction(
        id: 'in',
        type: 'transfer',
        date: DateTime(2026, 6, 3),
        amount: 100,
        description: 'Top-up',
        sourceName: 'Savings',
        destinationName: 'Checking',
        categoryName: '',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );
      final result = buildTransactionListGroups(
        transactions: [
          incomingTransfer,
          _tx(id: 'expense', date: DateTime(2026, 6, 2), amount: 20),
        ],
        activeAccountFilters: {},
        searchQuery: '',
        groupType: TransactionGroupType.date,
        format: format,
        l10n: l10n,
        referenceDate: DateTime(2026, 7, 9),
        sumAccount: 'Checking',
      );

      expect(result.groups, hasLength(1));
      // Transfer into Checking counts +100, withdrawal from it -20.
      expect(result.groups.first.sum, 80);

      final generic = buildTransactionListGroups(
        transactions: [incomingTransfer],
        activeAccountFilters: {},
        searchQuery: '',
        groupType: TransactionGroupType.date,
        format: format,
        l10n: l10n,
        referenceDate: DateTime(2026, 7, 9),
      );
      expect(generic.groups.first.sum, -100);
    });

    test('orders date groups chronologically, not alphabetically', () {
      final result = buildTransactionListGroups(
        transactions: [
          _tx(id: 'apr', date: DateTime(2026, 4, 1)),
          _tx(id: 'dec', date: DateTime(2025, 12, 1)),
          _tx(id: 'feb', date: DateTime(2026, 2, 1)),
          _tx(id: 'jan', date: DateTime(2026, 1, 1)),
        ],
        activeAccountFilters: {},
        searchQuery: '',
        groupType: TransactionGroupType.date,
        format: format,
        l10n: l10n,
        referenceDate: DateTime(2026, 7, 9),
      );

      expect(result.groups.map((group) => group.key).toList(), [
        format.formatMonthYear(DateTime(2026, 4, 1)),
        format.formatMonthYear(DateTime(2026, 2, 1)),
        format.formatMonthYear(DateTime(2026, 1, 1)),
        format.formatMonthYear(DateTime(2025, 12, 1)),
      ]);
    });

    test('supports non-date grouping keys and group lookup getters', () {
      final transactions = [
        _tx(id: 'expense', date: DateTime(2026, 6, 2)),
        _tx(
          id: 'income',
          date: DateTime(2026, 6, 1),
          type: 'deposit',
          amount: 50,
        ),
      ];

      for (final groupType in [
        TransactionGroupType.account,
        TransactionGroupType.payee,
        TransactionGroupType.type,
        TransactionGroupType.category,
      ]) {
        final result = buildTransactionListGroups(
          transactions: transactions,
          activeAccountFilters: {},
          searchQuery: '',
          groupType: groupType,
          format: format,
          l10n: l10n,
          referenceDate: DateTime(2026, 7, 9),
        );

        expect(result.sortedKeys, result.groups.map((group) => group.key));
        expect(result.groupsByKey.keys, result.sortedKeys);
      }
    });

    test('filters transactions by selected account', () {
      final result = buildTransactionListGroups(
        transactions: [_tx(id: 'expense', date: DateTime(2026, 6, 2))],
        activeAccountFilters: {'Savings'},
        searchQuery: '',
        groupType: TransactionGroupType.date,
        format: format,
        l10n: l10n,
        referenceDate: DateTime(2026, 7, 9),
      );

      expect(result.filteredTransactions, isEmpty);
      expect(result.groups, isEmpty);
    });

    test(
      'all-future page produces empty groups with populated future list',
      () {
        final reference = DateTime(2026, 7, 29);
        final result = buildTransactionListGroups(
          transactions: [
            _tx(id: 'f1', date: DateTime(2027, 2, 13)),
            _tx(id: 'f2', date: DateTime(2027, 1, 10)),
            _tx(id: 'f3', date: DateTime(2026, 8, 1)),
          ],
          activeAccountFilters: {},
          searchQuery: '',
          groupType: TransactionGroupType.date,
          format: format,
          l10n: l10n,
          referenceDate: reference,
        );

        expect(result.filteredTransactions, hasLength(3));
        // Newest first, the direction the dated groups below already use.
        // Regression: the future block sorted the other way, so the list
        // reversed itself where that block began.
        expect(result.futureTransactions.map((t) => t.id), ['f1', 'f2', 'f3']);
        expect(result.groups, isEmpty);
      },
    );

    test('groups future transactions by month, newest first', () {
      final result = buildTransactionListGroups(
        transactions: [
          _tx(id: 'aug1', date: DateTime(2026, 8, 25), amount: 100),
          _tx(id: 'aug2', date: DateTime(2026, 8, 28), amount: 50),
          _tx(id: 'sep', date: DateTime(2026, 9, 10), amount: 30),
        ],
        activeAccountFilters: {},
        searchQuery: '',
        groupType: TransactionGroupType.date,
        format: format,
        l10n: l10n,
        referenceDate: DateTime(2026, 8, 21),
        sumAccount: 'Checking',
      );

      expect(result.futureGroups.map((g) => g.key), [
        'September 2026',
        'August 2026',
      ]);
      expect(result.futureGroups.first.transactions.map((t) => t.id), ['sep']);
      expect(result.futureGroups.last.transactions.map((t) => t.id), [
        'aug2',
        'aug1',
      ]);
      // Withdrawals leave the account they are summed against.
      expect(result.futureGroups.last.sum, -150);
      expect(result.futureGroups.first.sum, -30);
    });

    test('groups the future by month whatever the grouping in use', () {
      // The block answers what the balance will be as each month closes, which
      // grouping by payee would not.
      final result = buildTransactionListGroups(
        transactions: [_tx(id: 'f', date: DateTime(2026, 9, 10))],
        activeAccountFilters: {},
        searchQuery: '',
        groupType: TransactionGroupType.payee,
        format: format,
        l10n: l10n,
        referenceDate: DateTime(2026, 8, 21),
      );

      expect(result.futureGroups.single.key, 'September 2026');
    });
  });

  group('expectedBalanceByFutureMonth', () {
    test('carries each month forward from the opening balance', () {
      final groups = buildTransactionListGroups(
        transactions: [
          _tx(id: 'aug', date: DateTime(2026, 8, 25), amount: 100),
          _tx(id: 'sep', date: DateTime(2026, 9, 10), amount: 30),
          _tx(id: 'oct', date: DateTime(2026, 10, 5), amount: 20),
        ],
        activeAccountFilters: {},
        searchQuery: '',
        groupType: TransactionGroupType.date,
        format: format,
        l10n: l10n,
        referenceDate: DateTime(2026, 8, 21),
        sumAccount: 'Checking',
      ).futureGroups;

      final expected = expectedBalanceByFutureMonth(
        openingBalance: 1000,
        futureGroups: groups,
      );

      // Walked in calendar order even though the groups arrive newest first,
      // so each month carries everything before it.
      expect(expected['August 2026'], 900);
      expect(expected['September 2026'], 870);
      expect(expected['October 2026'], 850);
    });

    test('has nothing to report without future months', () {
      expect(
        expectedBalanceByFutureMonth(
          openingBalance: 10,
          futureGroups: const [],
        ),
        isEmpty,
      );
    });
  });
}
