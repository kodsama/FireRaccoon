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
  });
}
