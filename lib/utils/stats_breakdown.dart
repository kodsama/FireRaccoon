import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../router/stats_route.dart';
import 'search_filter.dart';

/// The key stacked bars put what is left after the top [kStatsTopSplits].
const kStatsOtherSplit = '\u0000other';

/// How many parts a stacked bar shows by name before the rest goes to
/// [kStatsOtherSplit].
const kStatsTopSplits = 6;

/// One kind of movement on the Stats page, summed by the page's grouping.
class StatsTypeTotals {
  final TransactionTypeFilter type;

  /// Keyed by category, tag, budget, account or payee name, whichever the
  /// page groups by; the empty key holds legs with none.
  final Map<String, double> groupSums;

  const StatsTypeTotals({required this.type, required this.groupSums});

  double get total => groupSums.values.fold(0.0, (sum, amount) => sum + amount);

  List<MapEntry<String, double>> get sortedGroups =>
      sortedCategorySumEntries(groupSums);
}

/// One stretch of a series over time and what each type came to in it.
class StatsBucket {
  final DateRangeBounds bounds;
  final Map<TransactionTypeFilter, double> totals;

  /// Each type's total cut by the split, keyed by the names in
  /// [StatsBreakdown.splitKeys]; empty unless a split was asked for.
  final Map<TransactionTypeFilter, Map<String, double>> parts;

  const StatsBucket({
    required this.bounds,
    required this.totals,
    this.parts = const {},
  });

  DateTime get start => bounds.start!;

  double totalFor(TransactionTypeFilter type) => totals[type] ?? 0;

  double partFor(TransactionTypeFilter type, String key) =>
      parts[type]?[key] ?? 0;

  double get net =>
      totalFor(TransactionTypeFilter.income) -
      totalFor(TransactionTypeFilter.expense);
}

class StatsBreakdown {
  /// One entry per selected type, in page order, each summed with every
  /// filter but the one on the grouping's own dimension, so the list keeps
  /// showing what that filter could be switched to.
  final List<StatsTypeTotals> types;

  /// Groups with at least one leg that passes every filter.
  final List<Transaction> transactions;

  /// What the category, tag and budget pickers offer: everything the
  /// period holds for the selected types, before any of them narrows it.
  final List<String> categories;
  final List<String> tags;
  final List<String> budgets;

  /// Every bucket of the period in order, empty ones included, summed with
  /// every filter applied. Empty when no interval was asked for.
  final List<StatsBucket> series;

  /// The parts stacked bars show, largest first, with [kStatsOtherSplit]
  /// last when anything was folded into it.
  final List<String> splitKeys;

  const StatsBreakdown({
    required this.types,
    required this.transactions,
    required this.categories,
    required this.tags,
    required this.budgets,
    this.series = const [],
    this.splitKeys = const [],
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

/// The names [leg] counts under when grouped by [grouping], each with the
/// share of its amount it takes. A leg with two tags gives each half, so a
/// donut or a stack of tags still adds up to what was actually spent.
List<MapEntry<String, double>> statsGroupShares(
  TransactionTypeFilter type,
  Transaction leg,
  StatsGrouping grouping,
) {
  switch (grouping) {
    case StatsGrouping.tag:
      final tags = leg.tags.toSet();
      if (tags.isEmpty) return [MapEntry('', leg.amount)];
      return [for (final tag in tags) MapEntry(tag, leg.amount / tags.length)];
    case StatsGrouping.budget:
      return [MapEntry(leg.budgetName?.trim() ?? '', leg.amount)];
    // The account is the side the money is the ledger's own, the payee the
    // other; a transfer runs between two of the ledger's accounts, and is
    // counted from the one it leaves.
    case StatsGrouping.account:
      final own = type == TransactionTypeFilter.income
          ? leg.destinationName
          : leg.sourceName;
      return [MapEntry(own.trim(), leg.amount)];
    case StatsGrouping.payee:
      final other = type == TransactionTypeFilter.income
          ? leg.sourceName
          : leg.destinationName;
      return [MapEntry(other.trim(), leg.amount)];
    case StatsGrouping.category:
    case StatsGrouping.time:
      return [MapEntry(categoryGroupKey(leg.categoryName), leg.amount)];
  }
}

StatsGrouping _groupingOf(StatsSplit split) => switch (split) {
  StatsSplit.category => StatsGrouping.category,
  StatsSplit.tag => StatsGrouping.tag,
  StatsSplit.budget => StatsGrouping.budget,
};

/// Sums [periodTransactions] leg by leg, so a split that puts one leg on a
/// tag or budget counts only that leg rather than the whole group. Each set
/// keeps what matches any one of its names, and an empty set keeps all.
///
/// [grouping] picks what the totals are keyed by. The filter on that same
/// dimension narrows [StatsBreakdown.transactions] and the series but not
/// the totals, the way picking a category leaves the others listed.
StatsBreakdown buildStatsBreakdown(
  List<Transaction> periodTransactions, {
  required List<TransactionTypeFilter> types,
  StatsGrouping grouping = StatsGrouping.category,
  Set<String> categories = const {},
  Set<String> tags = const {},
  Set<String> budgets = const {},
  Set<String> accounts = const {},
  String? words,
  StatsInterval? interval,
  StatsSplit? split,
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
  final partsByBucket =
      <DateTime, Map<TransactionTypeFilter, Map<String, double>>>{};
  final splitTotals = <String, double>{};
  final splitGrouping = split == null ? null : _groupingOf(split);

  for (final transaction in periodTransactions) {
    final type = _statsTypeOf(transaction.type);
    final typeSums = sums[type];
    if (type == null || typeSums == null) continue;
    final accountOk =
        accounts.isEmpty ||
        transaction.resolvedSplits().any(
          (leg) =>
              accounts.contains(leg.sourceName) ||
              accounts.contains(leg.destinationName),
        );
    if (!accountOk && grouping != StatsGrouping.account) continue;
    var countsTransaction = false;
    for (final leg in transaction.resolvedSplits()) {
      final key = categoryGroupKey(leg.categoryName);
      final budgetName = leg.budgetName?.trim() ?? '';
      categoryOptions.add(key);
      tagOptions.addAll(leg.tags);
      if (budgetName.isNotEmpty) budgetOptions.add(budgetName);

      if (!_matchesEveryWord(transaction, leg, wordList)) continue;
      final passes = {
        StatsGrouping.category:
            categoryKeys.isEmpty || categoryKeys.contains(key),
        StatsGrouping.tag: tags.isEmpty || leg.tags.any(tags.contains),
        StatsGrouping.budget: budgets.isEmpty || budgets.contains(budgetName),
        StatsGrouping.account: accountOk,
      };
      final passesAll = passes.values.every((ok) => ok);
      final passesOthers = passes.entries
          .where((entry) => entry.key != grouping)
          .every((entry) => entry.value);

      if (passesOthers) {
        for (final share in statsGroupShares(type, leg, grouping)) {
          typeSums[share.key] = (typeSums[share.key] ?? 0) + share.value;
        }
      }
      if (!passesAll) continue;
      countsTransaction = true;
      if (interval != null) {
        final start = statsBucketStart(transaction.date, interval);
        final bucket = byBucket.putIfAbsent(start, () => {});
        bucket[type] = (bucket[type] ?? 0) + leg.amount;
        if (splitGrouping != null) {
          final parts = partsByBucket
              .putIfAbsent(start, () => {})
              .putIfAbsent(type, () => {});
          for (final share in statsGroupShares(type, leg, splitGrouping)) {
            parts[share.key] = (parts[share.key] ?? 0) + share.value;
            splitTotals[share.key] =
                (splitTotals[share.key] ?? 0) + share.value;
          }
        }
      }
    }
    if (countsTransaction) counted.add(transaction);
  }

  final ranked = sortedCategorySumEntries(splitTotals).map((e) => e.key);
  final top = ranked.take(kStatsTopSplits).toSet();
  final folded = ranked.length > top.length;

  return StatsBreakdown(
    types: [
      for (final type in types)
        StatsTypeTotals(type: type, groupSums: sums[type]!),
    ],
    transactions: counted,
    categories: categoryOptions.toList()..sort(),
    tags: _sortedIgnoringCase(tagOptions),
    budgets: _sortedIgnoringCase(budgetOptions),
    series: interval == null
        ? const []
        : _series(
            byBucket,
            {
              for (final entry in partsByBucket.entries)
                entry.key: _fold(entry.value, top),
            },
            interval,
            range,
            counted,
            today ?? DateTime.now(),
          ),
    splitKeys: [...top, if (folded) kStatsOtherSplit],
  );
}

/// [parts] with every name outside [top] summed into [kStatsOtherSplit].
Map<TransactionTypeFilter, Map<String, double>> _fold(
  Map<TransactionTypeFilter, Map<String, double>> parts,
  Set<String> top,
) => {
  for (final entry in parts.entries)
    entry.key: entry.value.entries.fold<Map<String, double>>({}, (kept, part) {
      final key = top.contains(part.key) ? part.key : kStatsOtherSplit;
      kept[key] = (kept[key] ?? 0) + part.value;
      return kept;
    }),
};

List<StatsBucket> _series(
  Map<DateTime, Map<TransactionTypeFilter, double>> byBucket,
  Map<DateTime, Map<TransactionTypeFilter, Map<String, double>>> parts,
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
      StatsBucket(
        bounds: bounds,
        totals: byBucket[bounds.start] ?? const {},
        parts: parts[bounds.start] ?? const {},
      ),
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
