import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon/providers/paginated_transactions_provider.dart';

Future<PaginatedTransactionsState> waitForPaginatedLoad(
  ProviderContainer container,
  String? accountName, {
  int attempts = 100,
  Set<int>? loadedPages,
}) async {
  // Hold a subscription for the container's lifetime so autoDispose
  // account-filtered instances survive between polling reads.
  container.listen(paginatedTransactionsProvider(accountName), (_, _) {});
  for (var i = 0; i < attempts; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final state = container.read(paginatedTransactionsProvider(accountName));
    final pagesReady =
        loadedPages == null || loadedPages.every(state.loadedPages.contains);
    if (!state.isInitialLoading && pagesReady) return state;
  }
  throw StateError('Timed out waiting for paginated transactions to load');
}
