import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/models/transaction.dart';
import 'package:fireracoon/utils/transaction_filters.dart';

Transaction _tx({
  required String type,
  required DateTime date,
  String category = 'Food',
  String source = 'Checking',
  String destination = 'Groceries',
}) {
  return Transaction(
    id: '1',
    type: type,
    date: date,
    amount: 10,
    description: 'Test',
    sourceName: source,
    destinationName: destination,
    categoryName: category,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

void main() {
  group('isFutureTransaction', () {
    final reference = DateTime(2026, 7, 9);

    test('returns true for dates after reference day', () {
      expect(
        isFutureTransaction(DateTime(2026, 7, 10), reference: reference),
        isTrue,
      );
    });

    test('returns false for today and past dates', () {
      expect(
        isFutureTransaction(DateTime(2026, 7, 9), reference: reference),
        isFalse,
      );
      expect(
        isFutureTransaction(DateTime(2026, 7, 8), reference: reference),
        isFalse,
      );
    });
  });

  group('matchesReconciledFilter', () {
    test('filters reconciled and unreconciled transactions', () {
      final reconciled = _tx(
        type: 'withdrawal',
        date: DateTime(2026, 1, 1),
      ).copyWith(reconciled: true);
      final unreconciled = _tx(type: 'withdrawal', date: DateTime(2026, 1, 2));

      expect(matchesReconciledFilter(reconciled, ReconciledFilter.all), isTrue);
      expect(
        matchesReconciledFilter(reconciled, ReconciledFilter.reconciled),
        isTrue,
      );
      expect(
        matchesReconciledFilter(unreconciled, ReconciledFilter.unreconciled),
        isTrue,
      );
      expect(
        matchesReconciledFilter(unreconciled, ReconciledFilter.reconciled),
        isFalse,
      );
    });
  });

  group('resolveExpenseDateRange', () {
    final reference = DateTime(2026, 7, 6); // Monday

    test('month range starts on first day of month', () {
      final range = resolveExpenseDateRange(
        period: ExpensePeriod.month,
        reference: reference,
      );
      expect(range.start, DateTime(2026, 7, 1));
      expect(range.end, DateTime(2026, 8, 1));
    });

    test('last month range covers previous calendar month', () {
      final range = resolveExpenseDateRange(
        period: ExpensePeriod.lastMonth,
        reference: reference,
      );
      expect(range.start, DateTime(2026, 6, 1));
      expect(range.end, DateTime(2026, 7, 1));
    });

    test('last month rolls back across year boundary', () {
      final range = resolveExpenseDateRange(
        period: ExpensePeriod.lastMonth,
        reference: DateTime(2026, 1, 15),
      );
      expect(range.start, DateTime(2025, 12, 1));
      expect(range.end, DateTime(2026, 1, 1));
    });

    test('week range starts on Monday', () {
      final range = resolveExpenseDateRange(
        period: ExpensePeriod.week,
        reference: reference,
      );
      expect(range.start, DateTime(2026, 7, 6));
      expect(range.end, DateTime(2026, 7, 7));
    });

    test('custom range uses from and to dates', () {
      final range = resolveExpenseDateRange(
        period: ExpensePeriod.month,
        customFrom: DateTime(2026, 1, 1),
        customTo: DateTime(2026, 1, 31),
      );
      expect(range.start, DateTime(2026, 1, 1));
      expect(range.end, DateTime(2026, 2, 1));
    });
  });

  group('filterTransactions', () {
    final transactions = [
      _tx(type: 'withdrawal', date: DateTime(2026, 7, 1), category: 'Food'),
      _tx(type: 'deposit', date: DateTime(2026, 7, 2), category: 'Salary'),
      _tx(type: 'transfer', date: DateTime(2026, 6, 1), category: 'Savings'),
    ];

    test('filters by transaction type', () {
      final income = filterTransactions(
        transactions,
        type: TransactionTypeFilter.income,
      );
      expect(income, hasLength(1));
      expect(income.first.type, 'deposit');
    });

    test('filters by category and account', () {
      final filtered = filterTransactions(
        transactions,
        type: TransactionTypeFilter.all,
        category: 'Food',
        account: 'Checking',
      );
      expect(filtered, hasLength(1));
      expect(filtered.first.categoryName, 'Food');
    });

    test('filters by date range', () {
      final filtered = filterTransactions(
        transactions,
        type: TransactionTypeFilter.all,
        dateRange: DateRangeBounds(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 8, 1),
        ),
      );
      expect(filtered, hasLength(2));
    });
  });

  group('computeCategorySums', () {
    test('groups amounts by normalized category key', () {
      final totals = computeCategorySums([
        _tx(type: 'withdrawal', date: DateTime(2026, 7, 1), category: ' Food '),
        _tx(type: 'withdrawal', date: DateTime(2026, 7, 2), category: 'Travel'),
        _tx(type: 'withdrawal', date: DateTime(2026, 7, 3), category: 'Food'),
      ]);

      expect(totals['Food'], 20);
      expect(totals['Travel'], 10);
    });

    test('counts each split line separately', () {
      final totals = computeCategorySums([
        Transaction(
          id: '1',
          type: 'withdrawal',
          date: DateTime(2026, 7, 1),
          amount: 30,
          description: 'Groceries',
          sourceName: 'Checking',
          destinationName: 'Market',
          categoryName: 'Food',
          currencySymbol: '€',
          currencyCode: 'EUR',
          splits: [
            Transaction(
              id: '1',
              type: 'withdrawal',
              date: DateTime(2026, 7, 1),
              amount: 30,
              description: 'Groceries',
              sourceName: 'Checking',
              destinationName: 'Market',
              categoryName: 'Food',
              currencySymbol: '€',
              currencyCode: 'EUR',
            ),
            Transaction(
              id: '1',
              type: 'withdrawal',
              date: DateTime(2026, 7, 1),
              amount: 20,
              description: 'Groceries',
              sourceName: 'Checking',
              destinationName: 'Pharmacy',
              categoryName: 'Health',
              currencySymbol: '€',
              currencyCode: 'EUR',
            ),
          ],
        ),
      ]);

      expect(totals['Food'], 30);
      expect(totals['Health'], 20);
    });

    test('sortedCategorySumEntries orders by amount descending', () {
      final sorted = sortedCategorySumEntries({'Travel': 20, 'Food': 80});

      expect(sorted.first.key, 'Food');
      expect(sorted.last.key, 'Travel');
    });
  });
}
