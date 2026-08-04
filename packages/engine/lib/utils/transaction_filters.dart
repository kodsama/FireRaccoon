import '../models/transaction.dart';
import 'date_range.dart';

String categoryGroupKey(String? name) => (name ?? '').trim();

enum ExpensePeriod { week, month, lastMonth, quarter, semester, year, all }

enum TransactionTypeFilter { all, expense, income, transfer }

enum ReconciledFilter { all, reconciled, unreconciled }

/// Whether [date] falls after [reference] (calendar day comparison).
bool isFutureTransaction(DateTime date, {DateTime? reference}) {
  final ref = reference ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(ref.year, ref.month, ref.day);
  return day.isAfter(today);
}

bool matchesReconciledFilter(Transaction transaction, ReconciledFilter filter) {
  return switch (filter) {
    ReconciledFilter.all => true,
    ReconciledFilter.reconciled => transaction.isReconciled,
    ReconciledFilter.unreconciled => transaction.hasUnreconciledSplits,
  };
}

DateRangeBounds resolveExpenseDateRange({
  required ExpensePeriod period,
  DateTime? customFrom,
  DateTime? customTo,
  DateTime? reference,
}) {
  if (customFrom != null || customTo != null) {
    final end = customTo != null
        ? DateTime(
            customTo.year,
            customTo.month,
            customTo.day,
          ).add(const Duration(days: 1))
        : null;
    final start = customFrom != null
        ? DateTime(customFrom.year, customFrom.month, customFrom.day)
        : null;
    return DateRangeBounds(start: start, end: end);
  }

  if (period == ExpensePeriod.all) {
    return const DateRangeBounds();
  }

  final now = reference ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (period) {
    case ExpensePeriod.week:
      final start = today.subtract(Duration(days: today.weekday - 1));
      return DateRangeBounds(
        start: start,
        end: today.add(const Duration(days: 1)),
      );
    case ExpensePeriod.month:
      return DateRangeBounds(
        start: DateTime(today.year, today.month, 1),
        end: DateTime(today.year, today.month + 1, 1),
      );
    case ExpensePeriod.lastMonth:
      return DateRangeBounds(
        start: DateTime(today.year, today.month - 1, 1),
        end: DateTime(today.year, today.month, 1),
      );
    case ExpensePeriod.quarter:
      final quarterStartMonth = ((today.month - 1) ~/ 3) * 3 + 1;
      return DateRangeBounds(
        start: DateTime(today.year, quarterStartMonth, 1),
        end: DateTime(today.year, quarterStartMonth + 3, 1),
      );
    case ExpensePeriod.semester:
      final semesterStartMonth = today.month <= 6 ? 1 : 7;
      return DateRangeBounds(
        start: DateTime(today.year, semesterStartMonth, 1),
        end: DateTime(today.year, semesterStartMonth + 6, 1),
      );
    case ExpensePeriod.year:
      return DateRangeBounds(
        start: DateTime(today.year, 1, 1),
        end: DateTime(today.year + 1, 1, 1),
      );
    case ExpensePeriod.all:
      return const DateRangeBounds();
  }
}

String? transactionTypeForFilter(TransactionTypeFilter filter) {
  return switch (filter) {
    TransactionTypeFilter.all => null,
    TransactionTypeFilter.expense => 'withdrawal',
    TransactionTypeFilter.income => 'deposit',
    TransactionTypeFilter.transfer => 'transfer',
  };
}

List<Transaction> filterTransactions(
  List<Transaction> transactions, {
  TransactionTypeFilter type = TransactionTypeFilter.expense,
  String? category,
  String? account,
  DateRangeBounds? dateRange,
}) {
  final typeValue = transactionTypeForFilter(type);

  return transactions.where((transaction) {
    if (typeValue != null && transaction.type != typeValue) return false;
    if (category != null) {
      final matchesCategory = transaction.resolvedSplits().any(
        (split) =>
            categoryGroupKey(split.categoryName) == categoryGroupKey(category),
      );
      if (!matchesCategory) return false;
    }
    if (account != null) {
      final matchesAccount = transaction.resolvedSplits().any(
        (split) =>
            split.sourceName == account || split.destinationName == account,
      );
      if (!matchesAccount) return false;
    }
    if (dateRange != null && !dateRange.contains(transaction.date)) {
      return false;
    }
    return true;
  }).toList();
}

Map<String, double> computeCategorySums(Iterable<Transaction> transactions) {
  final totals = <String, double>{};
  for (final transaction in transactions) {
    for (final split in transaction.resolvedSplits()) {
      final key = categoryGroupKey(split.categoryName);
      totals[key] = (totals[key] ?? 0) + split.amount;
    }
  }
  return totals;
}

List<MapEntry<String, double>> sortedCategorySumEntries(
  Map<String, double> categorySums,
) {
  return categorySums.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
}

String totalLabelForType(TransactionTypeFilter type) {
  return switch (type) {
    TransactionTypeFilter.expense => 'Total spent this period',
    TransactionTypeFilter.income => 'Total income this period',
    TransactionTypeFilter.transfer => 'Total transferred this period',
    TransactionTypeFilter.all => 'Total this period',
  };
}
