import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Transaction _tx({
  required String type,
  required DateTime date,
  String category = 'Food',
  String source = 'Checking',
  String destination = 'Groceries',
  bool reconciled = false,
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
    reconciled: reconciled,
  );
}

void main() {
  group('isFutureTransaction', () {
    final reference = DateTime(2026, 7, 9);

    test('true after reference day, false for today and past', () {
      expect(
        isFutureTransaction(DateTime(2026, 7, 10), reference: reference),
        isTrue,
      );
      expect(
        isFutureTransaction(DateTime(2026, 7, 9), reference: reference),
        isFalse,
      );
      expect(
        isFutureTransaction(DateTime(2026, 7, 8), reference: reference),
        isFalse,
      );
    });

    test('uses DateTime.now when reference omitted', () {
      final tomorrow = DateTime.now().add(const Duration(days: 2));
      expect(isFutureTransaction(tomorrow), isTrue);
    });
  });

  group('matchesReconciledFilter', () {
    test('all / reconciled / unreconciled', () {
      final reconciled = _tx(
        type: 'withdrawal',
        date: DateTime(2026, 1, 1),
        reconciled: true,
      );
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
    test('all period uses open bounds', () {
      const range = DateRangeBounds();
      expect(range.start, isNull);
      expect(range.end, isNull);
      expect(resolveExpenseDateRange(period: ExpensePeriod.all), range);
    });

    final reference = DateTime(2026, 7, 6); // Monday

    test('all preset periods', () {
      expect(
        resolveExpenseDateRange(
          period: ExpensePeriod.week,
          reference: reference,
        ).start,
        DateTime(2026, 7, 6),
      );
      expect(
        resolveExpenseDateRange(
          period: ExpensePeriod.month,
          reference: reference,
        ).start,
        DateTime(2026, 7, 1),
      );
      expect(
        resolveExpenseDateRange(
          period: ExpensePeriod.lastMonth,
          reference: reference,
        ).start,
        DateTime(2026, 6, 1),
      );
      expect(
        resolveExpenseDateRange(
          period: ExpensePeriod.lastMonth,
          reference: DateTime(2026, 1, 15),
        ).start,
        DateTime(2025, 12, 1),
      );
      expect(
        resolveExpenseDateRange(
          period: ExpensePeriod.quarter,
          reference: reference,
        ).start,
        DateTime(2026, 7, 1),
      );
      expect(
        resolveExpenseDateRange(
          period: ExpensePeriod.semester,
          reference: reference,
        ).start,
        DateTime(2026, 7, 1),
      );
      expect(
        resolveExpenseDateRange(
          period: ExpensePeriod.semester,
          reference: DateTime(2026, 3, 1),
        ).start,
        DateTime(2026, 1, 1),
      );
      expect(
        resolveExpenseDateRange(
          period: ExpensePeriod.year,
          reference: reference,
        ).start,
        DateTime(2026, 1, 1),
      );
      expect(resolveExpenseDateRange(period: ExpensePeriod.all).start, isNull);
    });

    test('custom range variants', () {
      final both = resolveExpenseDateRange(
        period: ExpensePeriod.month,
        customFrom: DateTime(2026, 1, 1),
        customTo: DateTime(2026, 1, 31),
      );
      expect(both.start, DateTime(2026, 1, 1));
      expect(both.end, DateTime(2026, 2, 1));

      final fromOnly = resolveExpenseDateRange(
        period: ExpensePeriod.month,
        customFrom: DateTime(2026, 1, 1),
      );
      expect(fromOnly.start, DateTime(2026, 1, 1));
      expect(fromOnly.end, isNull);

      final toOnly = resolveExpenseDateRange(
        period: ExpensePeriod.month,
        customTo: DateTime(2026, 1, 31),
      );
      expect(toOnly.start, isNull);
      expect(toOnly.end, DateTime(2026, 2, 1));
    });

    test('uses now when reference omitted for month', () {
      final range = resolveExpenseDateRange(period: ExpensePeriod.month);
      final now = DateTime.now();
      expect(range.start, DateTime(now.year, now.month, 1));
    });
  });

  group('transactionTypeForFilter and totalLabelForType', () {
    test('maps filters', () {
      expect(transactionTypeForFilter(TransactionTypeFilter.all), isNull);
      expect(
        transactionTypeForFilter(TransactionTypeFilter.expense),
        'withdrawal',
      );
      expect(transactionTypeForFilter(TransactionTypeFilter.income), 'deposit');
      expect(
        transactionTypeForFilter(TransactionTypeFilter.transfer),
        'transfer',
      );
      expect(
        totalLabelForType(TransactionTypeFilter.expense),
        contains('spent'),
      );
      expect(
        totalLabelForType(TransactionTypeFilter.income),
        contains('income'),
      );
      expect(
        totalLabelForType(TransactionTypeFilter.transfer),
        contains('transferred'),
      );
      expect(totalLabelForType(TransactionTypeFilter.all), contains('Total'));
    });
  });

  group('filterTransactions', () {
    final transactions = [
      _tx(type: 'withdrawal', date: DateTime(2026, 7, 1), category: 'Food'),
      _tx(type: 'deposit', date: DateTime(2026, 7, 2), category: 'Salary'),
      _tx(type: 'transfer', date: DateTime(2026, 6, 1), category: 'Savings'),
    ];

    test('filters by type, category, account, and date', () {
      expect(
        filterTransactions(
          transactions,
          type: TransactionTypeFilter.income,
        ).single.type,
        'deposit',
      );
      expect(
        filterTransactions(
          transactions,
          type: TransactionTypeFilter.all,
          category: 'Food',
          account: 'Checking',
        ),
        hasLength(1),
      );
      expect(
        filterTransactions(
          transactions,
          type: TransactionTypeFilter.all,
          dateRange: DateRangeBounds(
            start: DateTime(2026, 7, 1),
            end: DateTime(2026, 8, 1),
          ),
        ),
        hasLength(2),
      );
    });
  });

  group('computeCategorySums', () {
    test('groups and sorts', () {
      final totals = computeCategorySums([
        _tx(type: 'withdrawal', date: DateTime(2026, 7, 1), category: ' Food '),
        _tx(type: 'withdrawal', date: DateTime(2026, 7, 2), category: 'Travel'),
        _tx(type: 'withdrawal', date: DateTime(2026, 7, 3), category: 'Food'),
      ]);
      expect(totals['Food'], 20);
      expect(totals['Travel'], 10);
      final sorted = sortedCategorySumEntries(totals);
      expect(sorted.first.key, 'Food');
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
  });

  test('categoryGroupKey trims', () {
    expect(categoryGroupKey('  a  '), 'a');
    expect(categoryGroupKey(null), '');
  });

  test('resolveExpenseDateRange all preset returns open bounds', () {
    final range = resolveExpenseDateRange(period: ExpensePeriod.all);
    expect(range.start, isNull);
    expect(range.end, isNull);
  });
}
