import 'package:intl/intl.dart';

import '../models/account.dart';
import '../models/transaction.dart';
import 'date_range.dart';
import 'transaction_filters.dart';
import 'transaction_splits.dart';

class DashboardKpis {
  final double totalBalance;
  final double periodIncome;
  final double periodSpending;
  final double periodSaved;
  final DeltaResult incomeDelta;
  final DeltaResult spendingDelta;
  final DeltaResult savedDelta;
  final String currency;
  final String periodLabel;

  const DashboardKpis({
    required this.totalBalance,
    required this.periodIncome,
    required this.periodSpending,
    required this.periodSaved,
    required this.incomeDelta,
    required this.spendingDelta,
    required this.savedDelta,
    required this.currency,
    required this.periodLabel,
  });
}

class CashFlowBucket {
  final String label;
  final double income;
  final double spending;

  const CashFlowBucket({
    required this.label,
    required this.income,
    required this.spending,
  });

  bool get hasActivity => income > 0 || spending > 0;
}

class CategoryBreakdown {
  final String name;
  final double amount;
  final double share;

  const CategoryBreakdown({
    required this.name,
    required this.amount,
    required this.share,
  });
}

enum DeltaKind { noChange, newActivity, percent }

class DeltaResult {
  final DeltaKind kind;
  final double? percent;
  final bool isPositive;

  const DeltaResult({
    required this.kind,
    this.percent,
    required this.isPositive,
  });
}

class EndOfMonthOutlook {
  final double projectedSavings;
  final bool savedSoFarPositive;
  final bool showWarning;

  const EndOfMonthOutlook({
    required this.projectedSavings,
    required this.savedSoFarPositive,
    required this.showWarning,
  });
}

/// Single source of truth for assets, liabilities, and net worth.
class NetWorthBreakdown {
  final double assets;
  final double liabilities;
  final double netWorth;

  const NetWorthBreakdown({
    required this.assets,
    required this.liabilities,
    required this.netWorth,
  });
}

String resolveCurrency(
  String? primaryCurrencySymbol,
  List<Transaction> transactions,
) {
  if (primaryCurrencySymbol != null && primaryCurrencySymbol.isNotEmpty) {
    return primaryCurrencySymbol;
  }
  if (transactions.isNotEmpty) return transactions.first.currencySymbol;
  return '€';
}

NetWorthBreakdown computeNetWorthBreakdown(List<Account> accounts) {
  var assets = 0.0;
  var liabilities = 0.0;

  for (final account in accounts) {
    // Match Firefly's dashboard: inactive/closed accounts are excluded from
    // net worth (they remain visible when the Accounts "show inactive" toggle
    // is on, but must not inflate totals).
    if (!account.active) continue;
    switch (account.type) {
      case 'asset':
        assets += account.currentBalance;
      case 'liability':
        liabilities += account.currentBalance.abs();
    }
  }

  return NetWorthBreakdown(
    assets: assets,
    liabilities: liabilities,
    netWorth: assets - liabilities,
  );
}

double computeAssetsTotal(List<Account> accounts) {
  return computeNetWorthBreakdown(accounts).assets;
}

double computeLiabilitiesTotal(List<Account> accounts) {
  return computeNetWorthBreakdown(accounts).liabilities;
}

double computeNetWorth(List<Account> accounts) {
  return computeNetWorthBreakdown(accounts).netWorth;
}

List<Account> assetAccounts(List<Account> accounts) {
  return accounts.where((account) => account.type == 'asset').toList();
}

List<Transaction> _transactionsInRange(
  List<Transaction> transactions,
  DateRangeBounds range,
) {
  return filterByDateRange(
    transactions,
    range,
    (transaction) => transaction.date,
  );
}

double _sumByType(List<Transaction> transactions, String type) {
  return transactions
      .where((transaction) => transaction.type == type)
      .fold(0.0, (sum, transaction) => sum + transaction.totalAmount);
}

DeltaResult _delta(
  double current,
  double previous, {
  bool lowerIsBetter = false,
}) {
  if (previous == 0 && current == 0) {
    return const DeltaResult(kind: DeltaKind.noChange, isPositive: true);
  }
  if (previous == 0) {
    return DeltaResult(kind: DeltaKind.newActivity, isPositive: !lowerIsBetter);
  }

  final change = ((current - previous) / previous) * 100;
  final isPositive = lowerIsBetter ? change <= 0 : change >= 0;
  return DeltaResult(
    kind: DeltaKind.percent,
    percent: change,
    isPositive: isPositive,
  );
}

DashboardKpis computeDashboardKpis({
  required List<Account> accounts,
  required List<Transaction> transactions,
  required DateRangeBounds periodRange,
  DateRangeBounds? comparisonRange,
  String? primaryCurrencySymbol,
  required String periodLabel,
  double? netWorth,
}) {
  final periodTxs = _transactionsInRange(transactions, periodRange);
  final previousTxs = comparisonRange == null
      ? const <Transaction>[]
      : _transactionsInRange(transactions, comparisonRange);

  final periodIncome = _sumByType(periodTxs, 'deposit');
  final periodSpending = _sumByType(periodTxs, 'withdrawal');
  final periodSaved = periodIncome - periodSpending;

  final previousIncome = _sumByType(previousTxs, 'deposit');
  final previousSpending = _sumByType(previousTxs, 'withdrawal');
  final previousSaved = previousIncome - previousSpending;

  final incomeDelta = comparisonRange == null
      ? const DeltaResult(kind: DeltaKind.noChange, isPositive: true)
      : _delta(periodIncome, previousIncome);
  final spendingDelta = comparisonRange == null
      ? const DeltaResult(kind: DeltaKind.noChange, isPositive: true)
      : _delta(periodSpending, previousSpending, lowerIsBetter: true);
  final savedDelta = comparisonRange == null
      ? const DeltaResult(kind: DeltaKind.noChange, isPositive: true)
      : _delta(periodSaved, previousSaved);

  return DashboardKpis(
    totalBalance: netWorth ?? computeNetWorthBreakdown(accounts).netWorth,
    periodIncome: periodIncome,
    periodSpending: periodSpending,
    periodSaved: periodSaved,
    incomeDelta: incomeDelta,
    spendingDelta: spendingDelta,
    savedDelta: savedDelta,
    currency: resolveCurrency(primaryCurrencySymbol, transactions),
    periodLabel: periodLabel,
  );
}

String _formatMonthLabel(DateTime date, String languageCode) {
  return languageCode == 'en'
      ? DateFormat.MMM().format(date)
      : DateFormat.MMM(languageCode).format(date);
}

String _formatDayLabel(DateTime date, String languageCode) {
  return languageCode == 'en'
      ? DateFormat.E().format(date)
      : DateFormat.E(languageCode).format(date);
}

String _formatShortDateLabel(DateTime date, String languageCode) {
  return languageCode == 'en'
      ? DateFormat.MMMd().format(date)
      : DateFormat.MMMd(languageCode).format(date);
}

String _formatYearLabel(DateTime date, String languageCode) {
  return languageCode == 'en'
      ? DateFormat.y().format(date)
      : DateFormat.y(languageCode).format(date);
}

List<CashFlowBucket> trimEmptyCashFlowEdges(List<CashFlowBucket> buckets) {
  if (buckets.isEmpty) return buckets;

  var first = -1;
  var last = -1;
  for (var i = 0; i < buckets.length; i++) {
    if (buckets[i].hasActivity) {
      first = i;
      break;
    }
  }
  if (first == -1) return const [];

  for (var i = buckets.length - 1; i >= 0; i--) {
    if (buckets[i].hasActivity) {
      last = i;
      break;
    }
  }

  return buckets.sublist(first, last + 1);
}

List<CashFlowBucket> computeCashFlowBuckets(
  List<Transaction> transactions,
  DateRangeBounds range, {
  String languageCode = 'en',
  DateTime? reference,
}) {
  if (range.start == null && range.end == null) {
    return _bucketByYear(transactions, languageCode: languageCode);
  }

  final start = range.start!;
  final end =
      range.end ??
      _startOfDay(reference ?? DateTime.now()).add(const Duration(days: 1));
  final days = end.difference(start).inDays;

  if (days <= 14) {
    return _bucketByDay(
      transactions,
      start: start,
      end: end,
      languageCode: languageCode,
    );
  }
  if (days <= 120) {
    return _bucketByWeek(
      transactions,
      start: start,
      end: end,
      languageCode: languageCode,
    );
  }
  if (days <= 730) {
    return _bucketByMonth(
      transactions,
      start: start,
      end: end,
      languageCode: languageCode,
    );
  }
  return _bucketByQuarter(
    transactions,
    start: start,
    end: end,
    languageCode: languageCode,
  );
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

typedef _BucketBounds = ({DateTime start, DateTime end, String label});

/// Bins [transactions] into [bounds] with one pass over the list instead of
/// re-filtering the whole list per bucket. Bounds must be sorted by start;
/// gaps are allowed (rows falling in a gap are skipped).
List<CashFlowBucket> _accumulateBuckets(
  List<Transaction> transactions,
  List<_BucketBounds> bounds,
) {
  if (bounds.isEmpty) return const [];
  final income = List<double>.filled(bounds.length, 0);
  final spending = List<double>.filled(bounds.length, 0);
  final overallStart = bounds.first.start;
  final overallEnd = bounds.last.end;

  for (final transaction in transactions) {
    final isDeposit = transaction.type == 'deposit';
    if (!isDeposit && transaction.type != 'withdrawal') continue;
    final date = transaction.date;
    if (date.isBefore(overallStart) || !date.isBefore(overallEnd)) continue;

    // Binary search: last bucket whose start <= date.
    var low = 0;
    var high = bounds.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (date.isBefore(bounds[mid].start)) {
        high = mid - 1;
      } else {
        low = mid;
      }
    }
    if (!date.isBefore(bounds[low].end)) continue;
    if (isDeposit) {
      income[low] += transaction.totalAmount;
    } else {
      spending[low] += transaction.totalAmount;
    }
  }

  return [
    for (var i = 0; i < bounds.length; i++)
      CashFlowBucket(
        label: bounds[i].label,
        income: income[i],
        spending: spending[i],
      ),
  ];
}

List<CashFlowBucket> _bucketByDay(
  List<Transaction> transactions, {
  required DateTime start,
  required DateTime end,
  required String languageCode,
}) {
  final bounds = <_BucketBounds>[];
  var cursor = _startOfDay(start);
  final last = _startOfDay(end.subtract(const Duration(days: 1)));

  while (!cursor.isAfter(last)) {
    final next = cursor.add(const Duration(days: 1));
    bounds.add((
      start: cursor,
      end: next,
      label: _formatDayLabel(cursor, languageCode),
    ));
    cursor = next;
  }

  final kept = bounds.length > 12 ? bounds.sublist(bounds.length - 12) : bounds;
  return trimEmptyCashFlowEdges(_accumulateBuckets(transactions, kept));
}

List<CashFlowBucket> _bucketByWeek(
  List<Transaction> transactions, {
  required DateTime start,
  required DateTime end,
  required String languageCode,
}) {
  final bounds = <_BucketBounds>[];
  var cursor = _startOfDay(start);
  final limit = _startOfDay(end);

  while (cursor.isBefore(limit)) {
    final next = cursor.add(const Duration(days: 7));
    bounds.add((
      start: cursor,
      end: next.isAfter(limit) ? limit : next,
      label: _formatShortDateLabel(cursor, languageCode),
    ));
    cursor = next;
  }

  final kept = bounds.length > 12 ? bounds.sublist(bounds.length - 12) : bounds;
  return trimEmptyCashFlowEdges(_accumulateBuckets(transactions, kept));
}

List<CashFlowBucket> _bucketByMonth(
  List<Transaction> transactions, {
  required DateTime start,
  required DateTime end,
  required String languageCode,
}) {
  final bounds = <_BucketBounds>[];
  var cursor = DateTime(start.year, start.month, 1);
  final limit = DateTime(end.year, end.month, 1);

  while (!cursor.isAfter(limit)) {
    final next = DateTime(cursor.year, cursor.month + 1, 1);
    bounds.add((
      start: cursor,
      end: next,
      label: _formatMonthLabel(cursor, languageCode),
    ));
    cursor = next;
  }

  final kept = bounds.length > 12 ? bounds.sublist(bounds.length - 12) : bounds;
  return trimEmptyCashFlowEdges(_accumulateBuckets(transactions, kept));
}

List<CashFlowBucket> _bucketByQuarter(
  List<Transaction> transactions, {
  required DateTime start,
  required DateTime end,
  required String languageCode,
}) {
  final bounds = <_BucketBounds>[];
  var cursor = DateTime(start.year, ((start.month - 1) ~/ 3) * 3 + 1, 1);
  final limit = DateTime(end.year, end.month, 1);

  while (!cursor.isAfter(limit)) {
    final next = DateTime(cursor.year, cursor.month + 3, 1);
    bounds.add((
      start: cursor,
      end: next,
      label: 'Q${((cursor.month - 1) ~/ 3) + 1} ${cursor.year}',
    ));
    cursor = next;
  }

  return trimEmptyCashFlowEdges(_accumulateBuckets(transactions, bounds));
}

List<CashFlowBucket> _bucketByYear(
  List<Transaction> transactions, {
  required String languageCode,
}) {
  if (transactions.isEmpty) return const [];

  final years =
      transactions.map((transaction) => transaction.date.year).toSet().toList()
        ..sort();
  final bounds = <_BucketBounds>[
    for (final year in years)
      (
        start: DateTime(year, 1, 1),
        end: DateTime(year + 1, 1, 1),
        label: _formatYearLabel(DateTime(year), languageCode),
      ),
  ];
  return _accumulateBuckets(transactions, bounds);
}

List<CategoryBreakdown> computeCategoryBreakdown(
  List<Transaction> transactions,
  DateRangeBounds range, {
  int limit = 4,
}) {
  final periodTxs = _transactionsInRange(transactions, range);
  final expenses = periodTxs.where(
    (transaction) => transaction.type == 'withdrawal',
  );
  final totals = computeCategorySums(expenses);
  final sorted = sortedCategorySumEntries(totals);
  final grandTotal = sorted.fold(0.0, (sum, entry) => sum + entry.value);
  if (grandTotal == 0) return const [];

  return sorted.take(limit).map((entry) {
    return CategoryBreakdown(
      name: entry.key,
      amount: entry.value,
      share: entry.value / grandTotal,
    );
  }).toList();
}

List<Transaction> recentTransactions(
  List<Transaction> transactions,
  DateRangeBounds range, {
  int limit = 6,
}) {
  final periodTxs = _transactionsInRange(transactions, range);
  final sorted = [...periodTxs]..sort((a, b) => b.date.compareTo(a.date));
  return sorted.take(limit).toList();
}

List<Transaction> transactionsInRange(
  List<Transaction> transactions,
  DateRangeBounds range,
) {
  final periodTxs = _transactionsInRange(transactions, range);
  return periodTxs..sort((a, b) => b.date.compareTo(a.date));
}

EndOfMonthOutlook computeEndOfMonthOutlook({
  required List<Transaction> transactions,
  DateTime? reference,
}) {
  final now = reference ?? DateTime.now();
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final daysElapsed = now.day.clamp(1, daysInMonth);
  final monthRange = DateRangeBounds(
    start: DateTime(now.year, now.month, 1),
    end: DateTime(now.year, now.month + 1, 1),
  );
  final monthTxs = _transactionsInRange(transactions, monthRange);

  final income = _sumByType(monthTxs, 'deposit');
  final spending = _sumByType(monthTxs, 'withdrawal');
  final savedSoFar = income - spending;

  final projectedIncome = income / daysElapsed * daysInMonth;
  final projectedSpending = spending / daysElapsed * daysInMonth;
  final projectedSavings = projectedIncome - projectedSpending;
  final dailyPace = savedSoFar / daysElapsed;

  return EndOfMonthOutlook(
    projectedSavings: projectedSavings,
    savedSoFarPositive: savedSoFar >= 0,
    showWarning: projectedSavings < 0 || dailyPace < 0,
  );
}

List<double> reconstructAccountBalance(
  String accountName,
  double currentBalance,
  List<Transaction> transactions,
) {
  final accountTransactions =
      transactions
          .where(
            (transaction) =>
                transaction.sourceName == accountName ||
                transaction.destinationName == accountName,
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  final history = <double>[currentBalance];
  var balance = currentBalance;

  for (final transaction in accountTransactions) {
    reverseSplitBalanceDelta(
      transaction: transaction,
      accountName: accountName,
      apply: (delta) => balance += delta,
    );
    history.insert(0, balance);
  }

  if (history.length < 2) {
    history.insert(0, currentBalance);
  }

  return history;
}

List<double> reconstructAccountBalanceInRange({
  required String accountName,
  required double openingBalance,
  required List<Transaction> transactions,
  required DateTime start,
  required DateTime end,
}) {
  final accountTransactions =
      transactions
          .where(
            (transaction) =>
                !transaction.date.isBefore(start) &&
                !transaction.date.isAfter(end) &&
                (transaction.sourceName == accountName ||
                    transaction.destinationName == accountName),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final history = <double>[openingBalance];
  var balance = openingBalance;

  for (final transaction in accountTransactions) {
    applySplitBalanceDelta(
      transaction: transaction,
      accountName: accountName,
      apply: (delta) => balance += delta,
    );
    history.add(balance);
  }

  if (history.length < 2) {
    history.add(openingBalance);
  }

  return history;
}

List<double> netWorthSparklineFromBuckets({
  required double netWorth,
  required List<CashFlowBucket> buckets,
}) {
  if (buckets.isEmpty) return [netWorth, netWorth];

  final values = <double>[];
  var running = netWorth;
  for (final bucket in buckets.reversed) {
    running -= bucket.income - bucket.spending;
    values.insert(0, running);
  }
  values.add(netWorth);
  return values;
}

List<double> netWorthSparkline({
  required List<Account> accounts,
  required List<Transaction> transactions,
  required DateRangeBounds range,
  String languageCode = 'en',
  double? netWorth,
  List<CashFlowBucket>? buckets,
}) {
  final resolvedNetWorth = netWorth ?? computeNetWorth(accounts);
  final resolvedBuckets =
      buckets ??
      computeCashFlowBuckets(transactions, range, languageCode: languageCode);
  return netWorthSparklineFromBuckets(
    netWorth: resolvedNetWorth,
    buckets: resolvedBuckets,
  );
}

List<double> projectionOutlook(
  double currentNetWorth,
  List<Transaction> transactions,
  DateRangeBounds range, {
  int days = 30,
}) {
  final recent = _transactionsInRange(transactions, range);
  final income = recent
      .where((t) => t.type == 'deposit')
      .fold(0.0, (s, t) => s + t.totalAmount);
  final spending = recent
      .where((t) => t.type == 'withdrawal')
      .fold(0.0, (s, t) => s + t.totalAmount);
  final spanDays = range.start == null
      ? days
      : (range.end ?? DateTime.now().add(const Duration(days: 1)))
            .difference(range.start!)
            .inDays
            .clamp(1, 365);
  final dailyNet = (income - spending) / spanDays;

  return List.generate(days + 1, (index) {
    final value = currentNetWorth + dailyNet * index;
    return value < 0 ? 0 : value;
  });
}
