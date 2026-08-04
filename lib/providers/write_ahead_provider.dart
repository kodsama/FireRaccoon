import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import 'auth_provider.dart';
import 'data_providers.dart';
import 'paginated_transactions_provider.dart';
import 'theme_provider.dart';
import 'transaction_list_refresh.dart';

final _log = AppLogger.scoped('providers.write_ahead');

/// Allowed advance-write horizons, mirroring Skrooge's choices. 0 = off.
const kWriteAheadDayChoices = [0, 7, 15, 30, 60, 90];

class WriteAheadDaysNotifier extends Notifier<int> {
  static const _prefsKey = 'recurrenceWriteAheadDays';

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final value = prefs.getInt(_prefsKey) ?? 0;
    return kWriteAheadDayChoices.contains(value) ? value : 0;
  }

  Future<void> setDays(int value) async {
    if (!kWriteAheadDayChoices.contains(value) || value == state) return;
    state = value;
    await ref.read(sharedPreferencesProvider).setInt(_prefsKey, value);
    _log.info('Recurrence write-ahead horizon set to $value days');
  }
}

final writeAheadDaysProvider = NotifierProvider<WriteAheadDaysNotifier, int>(
  WriteAheadDaysNotifier.new,
);

/// Result of a write-ahead materialization pass.
class WriteAheadRunResult {
  const WriteAheadRunResult({required this.created, required this.failed});

  final int created;
  final int failed;

  bool get hasFailures => failed > 0;
}

/// Materializes upcoming recurrence occurrences as real future-dated
/// transactions, [writeAheadDaysProvider] days ahead (Skrooge-style
/// advance writing). Only runs when the horizon is > 0 (explicit opt-in).
final writeAheadRunnerProvider = FutureProvider<WriteAheadRunResult>((
  ref,
) async {
  final days = ref.watch(writeAheadDaysProvider);
  if (days <= 0) {
    return const WriteAheadRunResult(created: 0, failed: 0);
  }
  final auth = ref.watch(authProvider);
  if (!auth.isHydrated || !auth.isValid) {
    return const WriteAheadRunResult(created: 0, failed: 0);
  }
  final service = ref.watch(apiServiceProvider);
  if (service == null) {
    return const WriteAheadRunResult(created: 0, failed: 0);
  }

  final recurrences = await ref.watch(recurrencesProvider.future);
  if (recurrences.isEmpty) {
    return const WriteAheadRunResult(created: 0, failed: 0);
  }

  final now = DateTime.now();
  final existing = await service.getTransactions(
    start: DateTime(now.year, now.month, now.day),
    end: DateTime(now.year, now.month, now.day + days + 2),
  );
  final planned = planWriteAheadTransactions(
    recurrences: recurrences,
    existing: existing,
    days: days,
    reference: now,
  );
  if (planned.isEmpty) {
    _log.fine('Write-ahead: nothing to materialize (horizon=$days days)');
    return const WriteAheadRunResult(created: 0, failed: 0);
  }

  var created = 0;
  var failed = 0;
  for (final transaction in planned) {
    try {
      final saved = await service.createTransaction(transaction);
      created++;
      ref.read(transactionsProvider.notifier).upsert(saved);
      ref
          .read(paginatedTransactionsProvider(null).notifier)
          .upsertTransaction(saved);
    } catch (error) {
      failed++;
      _log.warning(
        'Write-ahead failed for "${transaction.description}" '
        'on ${transaction.date}: $error',
      );
    }
  }
  _log.info(
    'Write-ahead materialized $created transaction(s)'
    '${failed > 0 ? ', $failed failed' : ''}',
  );
  return WriteAheadRunResult(created: created, failed: failed);
});

/// Convenience used by settings/screens to trigger a fresh write-ahead pass
/// and refresh the visible lists afterwards.
Future<WriteAheadRunResult> runWriteAheadNow(WidgetRef ref) async {
  ref.invalidate(writeAheadRunnerProvider);
  final result = await ref.read(writeAheadRunnerProvider.future);
  if (result.created > 0) {
    await refreshTransactionLists(ref, null);
  }
  return result;
}
