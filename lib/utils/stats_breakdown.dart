import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../router/stats_route.dart';
import 'search_filter.dart';

/// One kind of movement on the Stats page, summed by category.
class StatsTypeTotals {
  final TransactionTypeFilter type;
  final Map<String, double> categorySums;

  const StatsTypeTotals({required this.type, required this.categorySums});

  double get total =>
      categorySums.values.fold(0.0, (sum, amount) => sum + amount);

  List<MapEntry<String, double>> get sortedCategories =>
      sortedCategorySumEntries(categorySums);
}

class StatsBreakdown {
  /// One entry per selected type, in page order, each summed with the tag,
  /// budget and word filters applied but not the category one, so the
  /// category list keeps showing what the others could be switched to.
  final List<StatsTypeTotals> types;

  /// Groups with at least one leg that passes every filter, category too.
  final List<Transaction> transactions;

  /// What the category, tag and budget pickers offer: everything the
  /// period holds for the selected types, before any of them narrows it.
  final List<String> categories;
  final List<String> tags;
  final List<String> budgets;

  const StatsBreakdown({
    required this.types,
    required this.transactions,
    required this.categories,
    required this.tags,
    required this.budgets,
  });

  StatsTypeTotals? totalsFor(TransactionTypeFilter type) {
    for (final totals in types) {
      if (totals.type == type) return totals;
    }
    return null;
  }

  /// Income less expenses, when both are shown; transfers move money
  /// between accounts and change neither.
  double? get net {
    final income = totalsFor(TransactionTypeFilter.income);
    final expenses = totalsFor(TransactionTypeFilter.expense);
    if (income == null || expenses == null) return null;
    return income.total - expenses.total;
  }
}

/// Sums [periodTransactions] leg by leg, so a split that puts one leg on a
/// tag or budget counts only that leg rather than the whole group.
StatsBreakdown buildStatsBreakdown(
  List<Transaction> periodTransactions, {
  required List<TransactionTypeFilter> types,
  String? category,
  String? tag,
  String? budget,
  String? words,
}) {
  final wordList = (words ?? '')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  final categoryKey = category == null ? null : categoryGroupKey(category);
  final sums = {for (final type in types) type: <String, double>{}};
  final categories = <String>{};
  final tags = <String>{};
  final budgets = <String>{};
  final counted = <Transaction>[];

  for (final transaction in periodTransactions) {
    final typeSums = sums[_statsTypeOf(transaction.type)];
    if (typeSums == null) continue;
    var countsTransaction = false;
    for (final split in transaction.resolvedSplits()) {
      final key = categoryGroupKey(split.categoryName);
      final budgetName = split.budgetName?.trim() ?? '';
      categories.add(key);
      tags.addAll(split.tags);
      if (budgetName.isNotEmpty) budgets.add(budgetName);

      if (tag != null && !split.tags.contains(tag)) continue;
      if (budget != null && budgetName != budget) continue;
      if (!_matchesEveryWord(transaction, split, wordList)) continue;

      typeSums[key] = (typeSums[key] ?? 0) + split.amount;
      if (categoryKey == null || key == categoryKey) countsTransaction = true;
    }
    if (countsTransaction) counted.add(transaction);
  }

  return StatsBreakdown(
    types: [
      for (final type in types)
        StatsTypeTotals(type: type, categorySums: sums[type]!),
    ],
    transactions: counted,
    categories: categories.toList()..sort(),
    tags: _sortedIgnoringCase(tags),
    budgets: _sortedIgnoringCase(budgets),
  );
}

TransactionTypeFilter? _statsTypeOf(String firefly) {
  for (final type in statsTypes) {
    if (transactionTypeForFilter(type) == firefly) return type;
  }
  return null;
}

/// Each word may land in a different field, so "coffee oslo" finds
/// "Coffee" paid to "Oslo Kaffebar". The group title lives on the group,
/// not on its legs, so it is read from there.
bool _matchesEveryWord(
  Transaction transaction,
  Transaction split,
  List<String> words,
) {
  for (final word in words) {
    if (split.matchesSearch(word)) continue;
    if (matchesSearchQuery(word, [?transaction.groupTitle])) continue;
    return false;
  }
  return true;
}

List<String> _sortedIgnoringCase(Set<String> values) =>
    values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
