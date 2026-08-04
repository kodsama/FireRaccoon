import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'paginated_transactions_provider.dart';

/// Prefetches the default paginated transaction list once auth is ready so the
/// Transactions screen can render from cache instead of waiting on first visit.
///
/// The warmup is deferred past first paint so it does not compete with the
/// visible screen's requests for the browser's per-host connection pool.
final transactionsWarmupProvider = Provider<void>((ref) {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  var scheduled = false;

  ref.listen(authProvider, (_, next) {
    if (!next.isHydrated || !next.isValid || scheduled) return;
    scheduled = true;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (disposed) return;
      final auth = ref.read(authProvider);
      if (auth.isHydrated && auth.isValid) {
        ref.read(paginatedTransactionsProvider(null));
      }
    });
  }, fireImmediately: true);
});
