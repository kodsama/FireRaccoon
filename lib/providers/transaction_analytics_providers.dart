import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../router/stats_route.dart';
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
  String? tag,
  String? budget,
});

/// What Stats fetches: the period, account and types, and none of the
/// filters that only narrow what was fetched.
class StatsScope {
  final ExpensePeriod period;
  final DateTime? from;
  final DateTime? to;
  final Set<TransactionTypeFilter> types;
  final String? account;

  const StatsScope({
    required this.period,
    required this.from,
    required this.to,
    required this.types,
    required this.account,
  });

  TransactionAnalyticsKey keyFor(TransactionTypeFilter type) =>
      (period: period, from: from, to: to, type: type, account: account);

  @override
  bool operator ==(Object other) =>
      other is StatsScope &&
      other.period == period &&
      other.from == from &&
      other.to == to &&
      other.account == account &&
      other.types.length == types.length &&
      other.types.containsAll(types);

  @override
  int get hashCode =>
      Object.hash(period, from, to, account, Object.hashAllUnordered(types));
}

extension StatsRouteFiltersScope on StatsRouteFilters {
  StatsScope get scope => StatsScope(
    period: period,
    from: from,
    to: to,
    types: types,
    account: account,
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

/// Every transaction of the scope's types, newest first. Each type is
/// fetched on its own so switching one on or off reuses what the others
/// already loaded.
final statsTransactionsProvider =
    FutureProvider.family<List<Transaction>, StatsScope>((ref, scope) async {
      final perType = [
        for (final type in statsTypes.where(scope.types.contains))
          ref.watch(scopedTransactionsProvider(scope.keyFor(type)).future),
      ];
      final lists = await Future.wait(perType);
      return [for (final list in lists) ...list]
        ..sort((a, b) => b.date.compareTo(a.date));
    });

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
      return filterTransactions(
        transactions,
        type: TransactionTypeFilter.all,
        category: key.category,
        tag: key.tag,
        budget: key.budget,
      );
    });
