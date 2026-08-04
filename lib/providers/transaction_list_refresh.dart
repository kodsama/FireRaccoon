import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import 'dashboard_stats_providers.dart';
import 'data_providers.dart';
import 'paginated_transactions_provider.dart';
import 'transaction_analytics_providers.dart';
import 'transaction_search_provider.dart';

/// Refreshes transaction caches after a mutation.
///
/// When the mutated transaction is known ([upsert] or [remove]), the cached
/// lists are patched in place instead of refetched, so a single edit does not
/// re-download the whole lookback window. Live account-filtered list
/// instances for every account the transaction touches are patched too.
Future<void> refreshTransactionLists(
  WidgetRef ref,
  String? filterAccount, {
  Transaction? upsert,
  Transaction? remove,
}) async {
  ref.invalidate(scopedTransactionsProvider);
  ref.invalidate(filteredTransactionListProvider);
  ref.invalidate(rangedTransactionsProvider);
  ref.invalidate(serverSearchResultsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(budgetsProvider);
  ref.invalidate(counterpartyAccountsProvider);
  ref.invalidate(tagsProvider);
  ref.invalidate(accountBalanceHistoriesProvider);

  if (ref.exists(accountsProvider)) {
    final accountsNotifier = ref.read(accountsProvider.notifier);
    accountsNotifier.applyTransactionDelta(upsert: upsert, remove: remove);
    unawaited(accountsNotifier.refresh());
  }

  final patched = upsert ?? remove;
  if (patched != null) {
    final transactionsNotifier = ref.read(transactionsProvider.notifier);
    // Patch the warmed all-accounts instance, the currently viewed instance,
    // and any live instance for an account the transaction touches — without
    // instantiating instances nobody is watching.
    final accountKeys =
        <String?>{null, filterAccount, ...transactionAccountNames(patched)}
          ..removeWhere(
            (key) =>
                key != null && !ref.exists(paginatedTransactionsProvider(key)),
          );
    final paginatedNotifiers = [
      for (final key in accountKeys)
        ref.read(paginatedTransactionsProvider(key).notifier),
    ];
    if (upsert != null) {
      transactionsNotifier.upsert(upsert);
      for (final notifier in paginatedNotifiers) {
        notifier.upsertTransaction(upsert);
      }
    } else {
      transactionsNotifier.remove(remove!.id);
      for (final notifier in paginatedNotifiers) {
        notifier.removeTransaction(remove.id);
      }
    }
    return;
  }

  ref.invalidate(transactionsProvider);
  await Future.wait([
    ref.read(paginatedTransactionsProvider(null).notifier).refresh(),
    if (filterAccount != null &&
        ref.exists(paginatedTransactionsProvider(filterAccount)))
      ref.read(paginatedTransactionsProvider(filterAccount).notifier).refresh(),
  ]);
}
