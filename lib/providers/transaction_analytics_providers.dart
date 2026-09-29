import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../router/stats_route.dart';
import 'data_providers.dart';
import 'people_providers.dart';

typedef TransactionAnalyticsKey = ({
  ExpensePeriod period,
  DateTime? from,
  DateTime? to,
  TransactionTypeFilter type,
  String? account,
});

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

/// A fetch plus the category, tag and budget sets that narrow it. A class
/// rather than a record because a record compares sets by identity, and a
/// provider keyed on one would refetch on every rebuild.
class TransactionListFilterKey {
  final TransactionAnalyticsKey scope;
  final Set<String> categories;
  final Set<String> tags;
  final Set<String> budgets;

  const TransactionListFilterKey({
    required this.scope,
    this.categories = const {},
    this.tags = const {},
    this.budgets = const {},
  });

  @override
  bool operator ==(Object other) =>
      other is TransactionListFilterKey &&
      other.scope == scope &&
      _sameSet(other.categories, categories) &&
      _sameSet(other.tags, tags) &&
      _sameSet(other.budgets, budgets);

  @override
  int get hashCode => Object.hash(
    scope,
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(tags),
    Object.hashAllUnordered(budgets),
  );
}

/// What Stats fetches: the period and types, and none of the filters that
/// only narrow what was fetched. Accounts are one of those, since the fetch
/// narrows to an account on the device anyway.
class StatsScope {
  final ExpensePeriod period;
  final DateTime? from;
  final DateTime? to;
  final Set<TransactionTypeFilter> types;

  const StatsScope({
    required this.period,
    required this.from,
    required this.to,
    required this.types,
  });

  TransactionAnalyticsKey keyFor(TransactionTypeFilter type) =>
      (period: period, from: from, to: to, type: type, account: null);

  @override
  bool operator ==(Object other) =>
      other is StatsScope &&
      other.period == period &&
      other.from == from &&
      other.to == to &&
      _sameSet(other.types, types);

  @override
  int get hashCode =>
      Object.hash(period, from, to, Object.hashAllUnordered(types));
}

extension StatsRouteFiltersScope on StatsRouteFilters {
  StatsScope get scope =>
      StatsScope(period: period, from: from, to: to, types: types);
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

/// Every transaction of the scope's types touching the selected person's
/// accounts, newest first. Each type is fetched on its own so switching one
/// on or off reuses what the others already loaded, and switching person
/// narrows what is already here rather than fetching again.
final statsTransactionsProvider =
    FutureProvider.family<List<Transaction>, StatsScope>((ref, scope) async {
      final perType = [
        for (final type in statsTypes.where(scope.types.contains))
          ref.watch(scopedTransactionsProvider(scope.keyFor(type)).future),
      ];
      final personId = ref.watch(activePersonFilterProvider);
      final config = ref.watch(peopleSettingsProvider);
      final lists = await Future.wait(perType);
      return [
        for (final list in lists)
          for (final transaction in list)
            if (personId == null ||
                touchesPersonAccounts(transaction, config, personId))
              transaction,
      ]..sort((a, b) => b.date.compareTo(a.date));
    });

/// Scoped transaction list for analytics drill-down and filtered list routes.
final filteredTransactionListProvider =
    FutureProvider.family<List<Transaction>, TransactionListFilterKey>((
      ref,
      key,
    ) async {
      final transactions = await ref.watch(
        scopedTransactionsProvider(key.scope).future,
      );
      return filterTransactions(
        transactions,
        type: TransactionTypeFilter.all,
        categories: key.categories,
        tags: key.tags,
        budgets: key.budgets,
      );
    });
