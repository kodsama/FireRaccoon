import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../router/transaction_analytics_route.dart';
import 'data_providers.dart';

typedef TransactionAnalyticsKey = ({
  ExpensePeriod period,
  DateTime? from,
  DateTime? to,
  TransactionTypeFilter type,
  String? account,
});

typedef TransactionListFilterKey = ({
  ExpensePeriod period,
  DateTime? from,
  DateTime? to,
  TransactionTypeFilter type,
  String? account,
  String? category,
});

extension ExpenseRouteFiltersAnalytics on ExpenseRouteFilters {
  TransactionAnalyticsKey get analyticsKey =>
      (period: period, from: from, to: to, type: type, account: account);
}

class TransactionAnalyticsSummary {
  final DateRangeBounds dateRange;
  final List<Transaction> periodTransactions;
  final Map<String, double> categorySums;

  const TransactionAnalyticsSummary({
    required this.dateRange,
    required this.periodTransactions,
    required this.categorySums,
  });

  List<MapEntry<String, double>> get sortedCategoryEntries =>
      sortedCategorySumEntries(categorySums);

  List<String> get categoryNames => categorySums.keys.toList()..sort();

  double get periodTotal => periodTransactions.fold(
    0.0,
    (sum, transaction) => sum + transaction.totalAmount,
  );
}

DateRangeBounds _dateRangeForKey(TransactionAnalyticsKey key) =>
    resolveExpenseDateRange(
      period: key.period,
      customFrom: key.from,
      customTo: key.to,
    );

/// Fetches only the transactions needed for the active analytics filters.
final scopedTransactionsProvider =
    FutureProvider.family<List<Transaction>, TransactionAnalyticsKey>((
      ref,
      key,
    ) async {
      final service = await requireFireflyService(
        ref,
        'scopedTransactionsProvider',
      );

      final dateRange = _dateRangeForKey(key);
      // Let the server filter by type so expense/income screens do not
      // download deposits/transfers they immediately discard.
      final transactions = await service.getTransactions(
        start: dateRange.start,
        end: dateRange.end,
        type: transactionTypeForFilter(key.type),
      );
      final filtered = filterTransactions(
        transactions,
        type: key.type,
        account: key.account,
        dateRange: dateRange,
      )..sort((a, b) => b.date.compareTo(a.date));
      return filtered;
    });

/// Filtered transactions and category totals for analytics screens.
final transactionAnalyticsSummaryProvider =
    FutureProvider.family<TransactionAnalyticsSummary, TransactionAnalyticsKey>(
      (ref, key) async {
        final periodTransactions = await ref.watch(
          scopedTransactionsProvider(key).future,
        );
        final dateRange = _dateRangeForKey(key);

        return TransactionAnalyticsSummary(
          dateRange: dateRange,
          periodTransactions: periodTransactions,
          categorySums: computeCategorySums(periodTransactions),
        );
      },
    );

/// Scoped transaction list for analytics drill-down and filtered list routes.
final filteredTransactionListProvider =
    FutureProvider.family<List<Transaction>, TransactionListFilterKey>((
      ref,
      key,
    ) async {
      final analyticsKey = (
        period: key.period,
        from: key.from,
        to: key.to,
        type: key.type,
        account: key.account,
      );
      final transactions = await ref.watch(
        scopedTransactionsProvider(analyticsKey).future,
      );
      if (key.category == null) return transactions;
      final categoryKey = categoryGroupKey(key.category);
      return transactions
          .where(
            (transaction) =>
                categoryGroupKey(transaction.categoryName) == categoryKey,
          )
          .toList();
    });
