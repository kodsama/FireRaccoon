import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'budget_period_providers.dart';
import 'dashboard_stats_providers.dart';
import 'data_providers.dart';
import 'paginated_transactions_provider.dart';
import 'transaction_analytics_providers.dart';
import 'transaction_search_provider.dart';

/// Re-fetches Firefly-backed caches so the UI reflects external edits.
///
/// Providers keep session-long data; navigating between pages does not hit
/// the API again. Call this from pull-to-refresh or when re-selecting the
/// active sidebar destination.
///
/// Pass [focusAccount] when a transactions page is filtered to one account so
/// that instance is awaited too (the all-accounts list alone is not enough).
Future<void> refreshFireflyData(WidgetRef ref, {String? focusAccount}) async {
  ref.invalidate(accountsProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(counterpartyAccountsProvider);
  ref.invalidate(payeesProvider);
  ref.invalidate(budgetsProvider);
  ref.invalidate(budgetPeriodMetricsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(tagsProvider);
  ref.invalidate(billsProvider);
  ref.invalidate(recurrencesProvider);
  ref.invalidate(piggyBanksProvider);
  ref.invalidate(currenciesProvider);
  ref.invalidate(primaryCurrencyProvider);
  ref.invalidate(currentUserProvider);
  ref.invalidate(rangedTransactionsProvider);
  ref.invalidate(accountTransactionsProvider);
  ref.invalidate(scopedTransactionsProvider);
  ref.invalidate(filteredTransactionListProvider);
  ref.invalidate(serverSearchResultsProvider);
  ref.invalidate(accountBalanceHistoriesProvider);
  ref.invalidate(paginatedTransactionsProvider);

  final account = focusAccount?.trim();
  final hasFocusAccount = account != null && account.isNotEmpty;

  // Await the lists every screen depends on so RefreshIndicator dismisses
  // once fresh data is in place, not merely once invalidation is queued.
  await Future.wait([
    ref.read(accountsProvider.future),
    ref.read(transactionsProvider.future),
    ref.read(paginatedTransactionsProvider(null).notifier).refresh(),
    if (hasFocusAccount)
      ref.read(paginatedTransactionsProvider(account).notifier).refresh(),
  ]);
}
