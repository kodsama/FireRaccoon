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
///
/// Firefly matches bare words against the description and group title only
/// (`GroupCollector::setSearchWords`), so tags and notes each need their own
/// operator query to be found at all.
final serverSearchResultsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const [];
      final service = ref.watch(apiServiceProvider);
      if (service == null) return const [];
      final quoted = '"${trimmed.replaceAll('"', '')}"';
      final pages = await Future.wait(
        [trimmed, 'tag_contains:$quoted', 'notes_contains:$quoted'].map((
          firefly,
        ) async {
          try {
            final page = await service.searchTransactionsPage(
              firefly,
              page: 1,
              limit: 200,
            );
            return page.transactions;
          } catch (error) {
            _log.warning('Server search failed for "$firefly": $error');
            return const <Transaction>[];
          }
        }),
      );
      final byId = <String, Transaction>{};
      for (final transaction in pages.expand((page) => page)) {
        byId.putIfAbsent(transaction.id, () => transaction);
      }
      return byId.values.toList();
    });
