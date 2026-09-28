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

/// One stretch of a series over time and what each type came to in it.
class StatsBucket {
  final DateRangeBounds bounds;
  final Map<TransactionTypeFilter, double> totals;

  const StatsBucket({required this.bounds, required this.totals});

  DateTime get start => bounds.start!;

  double totalFor(TransactionTypeFilter type) => totals[type] ?? 0;

  double get net =>
      totalFor(TransactionTypeFilter.income) -
      totalFor(TransactionTypeFilter.expense);
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

  /// Every bucket of the period in order, empty ones included, summed with
  /// every filter applied, categories too, since a series has no category
  /// list beside it to switch between. Empty when no interval was asked for.
  final List<StatsBucket> series;

  const StatsBreakdown({
    required this.types,
    required this.transactions,
    required this.categories,
    required this.tags,
    required this.budgets,
    this.series = const [],
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
/// tag or budget counts only that leg rather than the whole group. Each set
/// keeps what matches any one of its names, and an empty set keeps all.
StatsBreakdown buildStatsBreakdown(
  List<Transaction> periodTransactions, {
  required List<TransactionTypeFilter> types,
  Set<String> categories = const {},
  Set<String> tags = const {},
  Set<String> budgets = const {},
  Set<String> accounts = const {},
  String? words,
  StatsInterval? interval,
  DateRangeBounds range = const DateRangeBounds(),
  DateTime? today,
}) {
  final wordList = (words ?? '')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  final categoryKeys = categories.map(categoryGroupKey).toSet();
  final sums = {for (final type in types) type: <String, double>{}};
  final categoryOptions = <String>{};
  final tagOptions = <String>{};
  final budgetOptions = <String>{};
  final counted = <Transaction>[];
  final byBucket = <DateTime, Map<TransactionTypeFilter, double>>{};

  for (final transaction in periodTransactions) {
    final type = _statsTypeOf(transaction.type);
    final typeSums = sums[type];
    if (type == null || typeSums == null) continue;
    if (accounts.isNotEmpty &&
        !transaction.resolvedSplits().any(
          (split) =>
              accounts.contains(split.sourceName) ||
              accounts.contains(split.destinationName),
        )) {
      continue;
    }
    var countsTransaction = false;
    for (final split in transaction.resolvedSplits()) {
      final key = categoryGroupKey(split.categoryName);
      final budgetName = split.budgetName?.trim() ?? '';
      categoryOptions.add(key);
      tagOptions.addAll(split.tags);
      if (budgetName.isNotEmpty) budgetOptions.add(budgetName);

      if (tags.isNotEmpty && !split.tags.any(tags.contains)) continue;
      if (budgets.isNotEmpty && !budgets.contains(budgetName)) continue;
      if (!_matchesEveryWord(transaction, split, wordList)) continue;

      typeSums[key] = (typeSums[key] ?? 0) + split.amount;
      if (categoryKeys.isEmpty || categoryKeys.contains(key)) {
        countsTransaction = true;
        if (interval != null) {
          final bucket = byBucket.putIfAbsent(
            statsBucketStart(transaction.date, interval),
            () => {},
          );
          bucket[type] = (bucket[type] ?? 0) + split.amount;
        }
      }
    }
    if (countsTransaction) counted.add(transaction);
  }

  return StatsBreakdown(
    types: [
      for (final type in types)
        StatsTypeTotals(type: type, categorySums: sums[type]!),
    ],
    transactions: counted,
    categories: categoryOptions.toList()..sort(),
    tags: _sortedIgnoringCase(tagOptions),
    budgets: _sortedIgnoringCase(budgetOptions),
    series: interval == null
        ? const []
        : _series(byBucket, interval, range, counted, today ?? DateTime.now()),
  );
}

List<StatsBucket> _series(
  Map<DateTime, Map<TransactionTypeFilter, double>> byBucket,
  StatsInterval interval,
  DateRangeBounds range,
  List<Transaction> counted,
  DateTime today,
) {
  // An open period (all time) runs from the first row counted to the last.
  // One reaching past today stops at today or at the last row dated ahead,
  // whichever is later, so the months still to come do not plot as zeros
  // and read as a collapse.
  final dates = counted.map((t) => t.date).toList()..sort();
  final first = range.start ?? (dates.isEmpty ? null : dates.first);
  final end = range.end;
  final latest = dates.isEmpty || dates.last.isBefore(today)
      ? today
      : dates.last;
  final periodLast = end == null
      ? null
      : DateTime(end.year, end.month, end.day - 1);
  final last = periodLast == null
      ? (dates.isEmpty ? null : dates.last)
      : (periodLast.isAfter(latest) ? latest : periodLast);
  if (first == null || last == null || last.isBefore(first)) return const [];
  return [
    for (final bounds in statsBuckets(first, last, interval))
      StatsBucket(bounds: bounds, totals: byBucket[bounds.start] ?? const {}),
  ];
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
