import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import '../utils/web_backend_proxy.dart';
import 'auth_provider.dart';

final _log = AppLogger.scoped('providers.data');

FireflyService _requireService(Ref ref, String providerName) {
  final service = ref.watch(apiServiceProvider);
  if (service == null) {
    _log.warning('$providerName requested while Firefly is disconnected');
    throw Exception(
      'Not connected to Firefly III. Open Settings and connect your server.',
    );
  }
  return service;
}

// Build-time tuning knobs (pass via --dart-define when needed).
const _envReadMaxAttempts = String.fromEnvironment('FIREFLY_READ_MAX_ATTEMPTS');
const _envReadRetryBaseDelayMs = String.fromEnvironment(
  'FIREFLY_READ_RETRY_BASE_DELAY_MS',
);
const _envReadRetryJitterMs = String.fromEnvironment(
  'FIREFLY_READ_RETRY_JITTER_MS',
);

final apiServiceProvider = Provider<FireflyService?>((ref) {
  final authSettings = ref.watch(authProvider);
  if (authSettings.isValid) {
    final readMaxAttempts = int.tryParse(_envReadMaxAttempts);
    final readRetryBaseDelayMs = int.tryParse(_envReadRetryBaseDelayMs);
    final readRetryJitterMs = int.tryParse(_envReadRetryJitterMs);
    _log.fine('Creating API service from authenticated settings');
    _log.fine(
      'Configured Firefly retry policy: '
      'readMaxAttempts=${readMaxAttempts ?? 3}, '
      'readRetryBaseDelayMs=${readRetryBaseDelayMs ?? 200}, '
      'readRetryJitterMs=${readRetryJitterMs ?? 0}',
    );
    return FireflyApiService(
      serverUrl: resolveBackendUrlForHttp(authSettings.serverUrl),
      apiToken: authSettings.apiToken,
      readMaxAttempts: readMaxAttempts ?? 3,
      readRetryBaseDelayMs: readRetryBaseDelayMs ?? 200,
      readRetryJitterMs: readRetryJitterMs ?? 0,
    );
  } else {
    _log.finer('API service unavailable because auth settings are invalid');
    return null;
  }
});

final primaryCurrencyProvider = FutureProvider<FireflyCurrency>((ref) async {
  final service = _requireService(ref, 'primaryCurrencyProvider');
  _log.fine('Loading primary currency');
  return service.getPrimaryCurrency();
});

final currentUserProvider = FutureProvider<FireflyUser>((ref) async {
  final service = _requireService(ref, 'currentUserProvider');
  _log.fine('Loading current user');
  return service.getCurrentUser();
});

class AccountsNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    final service = _requireService(ref, 'accountsProvider');
    _log.fine('Loading accounts');
    return service.getAccounts();
  }

  Future<void> refresh() async {
    final service = _requireService(ref, 'accountsProvider');
    state = const AsyncLoading<List<Account>>();
    state = await AsyncValue.guard(() => service.getAccounts());
  }

  void applyTransactionDelta({Transaction? upsert, Transaction? remove}) {
    if (!state.hasValue) return;
    final currentAccounts = state.value!;
    if (currentAccounts.isEmpty) return;

    final updated = currentAccounts.map((account) {
      var balance = account.currentBalance;
      if (upsert != null) {
        final existing = ref
            .read(transactionsProvider)
            .asData
            ?.value
            .where((t) => t.id == upsert.id)
            .firstOrNull;
        if (existing != null) {
          balance -= signedAmountForAccount(existing, account.name);
        }
        balance += signedAmountForAccount(upsert, account.name);
      } else if (remove != null) {
        balance -= signedAmountForAccount(remove, account.name);
      }
      if (balance == account.currentBalance) return account;
      return account.copyWith(currentBalance: balance);
    }).toList();

    state = AsyncData(updated);
  }
}

final accountsProvider = AsyncNotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
);

/// Expense and revenue accounts, used as transaction counterparties in forms
/// that need real account ids (e.g. recurring transactions). Kept separate
/// from [accountsProvider] so account screens keep listing asset/liability
/// accounts only.
final counterpartyAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final service = _requireService(ref, 'counterpartyAccountsProvider');
  _log.fine('Loading counterparty accounts');
  return service.getAccounts(types: const ['expense', 'revenue']);
});

final payeesProvider = FutureProvider<List<Account>>((ref) async {
  final service = _requireService(ref, 'payeesProvider');
  _log.fine('Loading payees (expense accounts)');
  return service.getAccounts(types: const ['expense']);
});

enum TransactionGroupType { date, account, payee, type, category }

/// Full transaction cache with in-place patching so mutations do not trigger
/// a full refetch of the lookback window.
class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() async {
    final service = _requireService(ref, 'transactionsProvider');
    _log.fine('Loading transactions');
    final transactions = await service.getTransactions(
      onFirstPage: (firstPage) {
        // Progressive cold-start paint: the newest page renders immediately
        // while the rest of the window downloads. Never downgrade an
        // existing cache during a refresh.
        if (state.hasValue) return;
        final partial = List<Transaction>.from(firstPage)
          ..sort((a, b) => b.date.compareTo(a.date));
        _log.finer('Emitting first transaction page early (${partial.length})');
        state = AsyncData(partial);
      },
    );
    transactions.sort((a, b) => b.date.compareTo(a.date));
    _log.finer('Transactions loaded and sorted (${transactions.length})');
    return transactions;
  }

  /// Inserts or replaces [transaction] in the cached list without refetching.
  void upsert(Transaction transaction) {
    final current = state.value;
    if (current == null) {
      // No cached data to patch (still loading or errored): refetch instead
      // so the mutation is not lost.
      ref.invalidateSelf();
      return;
    }
    final next = [
      for (final t in current)
        if (t.id != transaction.id) t,
      transaction,
    ]..sort((a, b) => b.date.compareTo(a.date));
    state = AsyncData(next);
  }

  /// Removes the transaction with [id] from the cached list without refetching.
  void remove(String id) {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final next = [
      for (final t in current)
        if (t.id != id) t,
    ];
    if (next.length == current.length) return;
    state = AsyncData(next);
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
      TransactionsNotifier.new,
    );

typedef DateWindowKey = ({DateTime start, DateTime? end});

/// Transactions for an explicit date window, used when a view needs data
/// older than the default lookback of [transactionsProvider].
final rangedTransactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, DateWindowKey>((ref, key) async {
      // Long windows ('all', multi-year) are large; release them when the
      // dashboard stops watching, with a grace period so quick period
      // toggles do not refetch.
      final link = ref.keepAlive();
      final graceTimer = Timer(const Duration(minutes: 3), link.close);
      ref.onDispose(graceTimer.cancel);

      final service = _requireService(ref, 'rangedTransactionsProvider');
      _log.fine('Loading ranged transactions (${key.start} .. ${key.end})');
      final transactions = await service.getTransactions(
        start: key.start,
        end: key.end,
      );
      transactions.sort((a, b) => b.date.compareTo(a.date));
      return transactions;
    });

final accountTransactionsProvider =
    FutureProvider.family<List<Transaction>, String>((ref, accountName) async {
      final service = _requireService(ref, 'accountTransactionsProvider');
      _log.fine('Loading transactions for account name="$accountName"');
      final accounts = await ref.watch(accountsProvider.future);
      final account = accounts.where((a) => a.name == accountName).firstOrNull;
      if (account == null) {
        _log.warning('Account lookup failed for "$accountName"');
        throw Exception('Account "$accountName" not found.');
      }
      return service.getAccountTransactions(account.id);
    });

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final service = _requireService(ref, 'budgetsProvider');
  _log.fine('Loading budgets');
  return service.getBudgets();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final service = _requireService(ref, 'categoriesProvider');
  _log.fine('Loading categories');
  return service.getCategories();
});

final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final service = _requireService(ref, 'tagsProvider');
  _log.fine('Loading tags');
  return service.getTags();
});

final billsProvider = FutureProvider<List<Bill>>((ref) async {
  final service = _requireService(ref, 'billsProvider');
  _log.fine('Loading bills');
  return service.getBills();
});

final recurrencesProvider = FutureProvider<List<Recurrence>>((ref) async {
  final service = _requireService(ref, 'recurrencesProvider');
  _log.fine('Loading recurrences');
  return service.getRecurrences();
});

final currenciesProvider = FutureProvider<List<FireflyCurrency>>((ref) async {
  final service = _requireService(ref, 'currenciesProvider');
  _log.fine('Loading currencies');
  return service.getCurrencies();
});

final piggyBanksProvider = FutureProvider<List<PiggyBank>>((ref) async {
  final service = _requireService(ref, 'piggyBanksProvider');
  _log.fine('Loading piggy banks');
  return service.getPiggyBanks();
});
