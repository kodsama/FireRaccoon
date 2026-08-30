import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import 'data_providers.dart';

final _log = AppLogger.scoped('providers.transaction_search');

/// Server-side search results for the transactions screen.
///
/// The paginated list only holds the pages scrolled into view, so a purely
/// local search silently misses older rows. This augments the local window
/// with matches from GET /api/v1/search/transactions. Best-effort: failures
/// fall back to local-only filtering.
final serverSearchResultsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const [];
      final service = ref.watch(apiServiceProvider);
      if (service == null) return const [];
      try {
        final page = await service.searchTransactionsPage(
          trimmed,
          page: 1,
          limit: 200,
        );
        return page.transactions;
      } catch (error) {
        _log.warning('Server search failed for "$trimmed": $error');
        return const [];
      }
    });
