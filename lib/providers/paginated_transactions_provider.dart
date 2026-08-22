import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import 'auth_provider.dart';
import 'data_providers.dart';
import 'transaction_page_size_provider.dart';

/// How far from the scroll edge (px) before the next page is requested.
const kTransactionPrefetchThreshold = 800.0;
final _log = AppLogger.scoped('providers.paginated_transactions');

class PaginatedTransactionsState {
  final List<Transaction> transactions;
  final Set<int> loadedPages;
  final Set<int> loadingPages;
  final int totalPages;
  final int totalCount;
  final bool isInitialLoading;
  final String? error;
  final String? accountName;

  const PaginatedTransactionsState({
    this.transactions = const [],
    this.loadedPages = const {},
    this.loadingPages = const {},
    this.totalPages = 0,
    this.totalCount = 0,
    this.isInitialLoading = true,
    this.error,
    this.accountName,
  });

  bool get hasMore {
    if (totalPages == 0) return false;
    if (loadedPages.isEmpty) return true;
    return loadedPages.length < totalPages;
  }

  bool get isLoadingMore => loadingPages.isNotEmpty;

  PaginatedTransactionsState copyWith({
    List<Transaction>? transactions,
    Set<int>? loadedPages,
    Set<int>? loadingPages,
    int? totalPages,
    int? totalCount,
    bool? isInitialLoading,
    String? error,
    String? accountName,
    bool clearError = false,
  }) {
    return PaginatedTransactionsState(
      transactions: transactions ?? this.transactions,
      loadedPages: loadedPages ?? this.loadedPages,
      loadingPages: loadingPages ?? this.loadingPages,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      error: clearError ? null : (error ?? this.error),
      accountName: accountName ?? this.accountName,
    );
  }
}

class PaginatedTransactionsNotifier
    extends Notifier<PaginatedTransactionsState> {
  PaginatedTransactionsNotifier(this._accountName);

  final String? _accountName;
  int _loadGeneration = 0;
  String? _cachedAccountId;
  String? _cachedAccountName;
  bool _initialLoadInFlight = false;
  bool _pendingReload = false;

  int get _pageSize => ref.read(transactionPageSizeProvider);

  @override
  PaginatedTransactionsState build() {
    // The all-accounts instance backs the main list and is warmed at startup;
    // keep it for the session. Per-account instances are released when their
    // screen stops watching so loaded pages do not accumulate per account.
    if (_accountName == null) {
      ref.keepAlive();
    }
    ref.listen(transactionPageSizeProvider, (previous, next) {
      if (previous != null && previous != next) {
        Future.microtask(() => _scheduleLoad());
      }
    });
    ref.listen(authProvider, (_, _) => _scheduleLoad(), fireImmediately: true);
    return PaginatedTransactionsState(accountName: _accountName);
  }

  void _scheduleLoad() {
    final auth = ref.read(authProvider);
    if (!auth.isHydrated) {
      _log.finer('Skipping paginated load schedule while auth is hydrating');
      return;
    }
    if (_initialLoadInFlight) {
      _log.finer('Queueing paginated reload; initial load in flight');
      _pendingReload = true;
      return;
    }
    _log.fine('Scheduling paginated transaction initial load');
    Future.microtask(() => _loadInitial(_accountName));
  }

  /// True while this load is still the one wanted and the provider is still
  /// alive.
  ///
  /// The generation counter alone only catches a load that has been superseded.
  /// It lives on the notifier, which outlives disposal, so it still matched
  /// after the provider was gone and the state write threw out of a future
  /// nobody awaits. That surfaced as a page load failing for no visible reason,
  /// and as an uncaught error landing on whatever was running at the time.
  bool _stillWanted(int generation) =>
      ref.mounted && generation == _loadGeneration;

  Future<void> _loadInitial(String? accountName, {bool force = false}) async {
    // Kicked off from a microtask, so the provider can already be gone by the
    // time this runs.
    if (!ref.mounted) return;
    if (_initialLoadInFlight) return;
    _initialLoadInFlight = true;
    final generation = ++_loadGeneration;
    _cachedAccountId = null;
    _cachedAccountName = null;
    // Existing rows are kept only as a visual placeholder; page bookkeeping is
    // always reset so page 1 is genuinely refetched (page size or auth may
    // have changed since the pages were loaded).
    final preserveExisting = !force && state.transactions.isNotEmpty;
    _log.info(
      'Loading paginated transactions (generation=$generation, account=$accountName, pageSize=$_pageSize, preserveExisting=$preserveExisting)',
    );
    state = state.copyWith(
      isInitialLoading: !preserveExisting,
      transactions: preserveExisting ? state.transactions : const [],
      loadedPages: const {},
      loadingPages: const {},
      totalPages: 0,
      totalCount: 0,
      clearError: true,
    );
    try {
      await _fetchPage(1, accountName: accountName, generation: generation);
      if (!_stillWanted(generation)) return;
      // Page 1 success/error already clears isInitialLoading inside _fetchPage.
      // Do not clear it here: an early return (auth still hydrating, duplicate
      // in-flight page) would leave an empty list with no loading affordance.
      if (state.totalPages > 1) {
        _log.finer('Prefetching second page in background');
        unawaited(
          _fetchPage(
            2,
            accountName: accountName,
            isPrefetch: true,
            generation: generation,
          ),
        );
      }
      _log.info(
        'Paginated initial load completed (pagesLoaded=${state.loadedPages.length}, totalPages=${state.totalPages}, totalCount=${state.totalCount})',
      );
    } finally {
      if (generation == _loadGeneration) {
        _initialLoadInFlight = false;
        if (_pendingReload) {
          _pendingReload = false;
          _log.fine('Running queued paginated reload');
          Future.microtask(() => _loadInitial(_accountName));
        }
      }
    }
  }

  Future<void> refresh() async {
    _initialLoadInFlight = false;
    await _loadInitial(_accountName, force: true);
  }

  void patchTransaction(Transaction updated) {
    final index = state.transactions.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;
    final next = List<Transaction>.from(state.transactions);
    next[index] = updated;
    state = state.copyWith(transactions: next);
  }

  bool _involvesAccount(Transaction transaction, String accountName) {
    if (transaction.sourceName == accountName ||
        transaction.destinationName == accountName) {
      return true;
    }
    return transaction.resolvedSplits().any(
      (split) =>
          split.sourceName == accountName ||
          split.destinationName == accountName,
    );
  }

  /// Inserts, replaces, or evicts [transaction] locally, avoiding a refetch.
  void upsertTransaction(Transaction transaction) {
    final accountName = state.accountName;
    final belongs =
        accountName == null || _involvesAccount(transaction, accountName);
    final index = state.transactions.indexWhere((t) => t.id == transaction.id);

    if (index == -1) {
      if (!belongs) return;
      // If the row is older than our oldest loaded transaction, omit it to avoid
      // rendering a visual gap before older pages are loaded.
      if (state.transactions.isNotEmpty &&
          transaction.date.isBefore(state.transactions.last.date)) {
        return;
      }
      final next = [...state.transactions, transaction]
        ..sort((a, b) => b.date.compareTo(a.date));
      state = state.copyWith(
        transactions: next,
        totalCount: state.totalCount + 1,
      );
      return;
    }

    if (!belongs) {
      // The edit moved the row off this instance's account.
      removeTransaction(transaction.id);
      return;
    }
    final next = List<Transaction>.from(state.transactions);
    next[index] = transaction;
    next.sort((a, b) => b.date.compareTo(a.date));
    state = state.copyWith(transactions: next);
  }

  /// Removes the transaction with [id] locally, avoiding a refetch.
  void removeTransaction(String id) {
    final index = state.transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final next = List<Transaction>.from(state.transactions)..removeAt(index);
    state = state.copyWith(
      transactions: next,
      totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
    );
  }

  void onScroll(double pixels, double maxScrollExtent) {
    if (state.isInitialLoading) return;
    if (!state.hasMore) return;

    // Content shorter than the viewport — keep loading until scrollable or
    // exhausted; otherwise load when nearing the bottom edge.
    if (maxScrollExtent <= kTransactionPrefetchThreshold ||
        maxScrollExtent - pixels < kTransactionPrefetchThreshold) {
      _loadMorePages();
    }
  }

  /// Loads up to two not-yet-loaded pages, retrying earlier failed pages
  /// before extending past the highest loaded page.
  Future<void> _loadMorePages() async {
    if (state.loadedPages.isEmpty || state.totalPages == 0) return;
    final generation = _loadGeneration;
    final missing = <int>[];
    for (var page = 1; page <= state.totalPages && missing.length < 2; page++) {
      if (!state.loadedPages.contains(page) &&
          !state.loadingPages.contains(page)) {
        missing.add(page);
      }
    }
    if (missing.isEmpty) return;
    await Future.wait(
      missing.map(
        (page) => _fetchPage(
          page,
          accountName: state.accountName,
          isPrefetch: true,
          generation: generation,
        ),
      ),
    );
  }

  Future<void> _fetchPage(
    int page, {
    required String? accountName,
    required int generation,
    bool isPrefetch = false,
  }) async {
    if (state.loadedPages.contains(page) || state.loadingPages.contains(page)) {
      _log.finer('Skipping page $page fetch; already loaded/loading');
      return;
    }
    if (state.totalPages > 0 && page > state.totalPages) {
      _log.finer(
        'Skipping page $page fetch; beyond totalPages=${state.totalPages}',
      );
      return;
    }

    state = state.copyWith(loadingPages: {...state.loadingPages, page});
    _log.fine(
      'Fetching transaction page $page (prefetch=$isPrefetch, account=$accountName)',
    );

    var pageLoaded = false;
    try {
      final service = ref.read(apiServiceProvider);
      if (service == null) {
        if (!ref.read(authProvider).isHydrated) return;
        _log.warning('Paginated fetch failed: api service unavailable');
        throw Exception(
          'Not connected to Firefly III. Open Settings and connect your server.',
        );
      }

      final TransactionPageResult result;
      if (accountName != null) {
        final accountId = await _resolveAccountId(accountName);
        if (!_stillWanted(generation)) return;
        result = await service.getAccountTransactionsPage(
          accountId,
          page: page,
          limit: _pageSize,
        );
      } else {
        result = await service.getTransactionsPage(
          page: page,
          limit: _pageSize,
        );
      }

      if (!_stillWanted(generation)) return;

      final merged = _mergePage(
        state.transactions,
        result.transactions,
        page,
        state.loadedPages,
      );
      final loaded = {...state.loadedPages, page};
      final loading = Set<int>.from(state.loadingPages)..remove(page);
      pageLoaded = true;

      state = state.copyWith(
        transactions: merged,
        loadedPages: loaded,
        loadingPages: loading,
        totalPages: result.totalPages,
        totalCount: result.total,
        isInitialLoading: page == 1 && !isPrefetch
            ? false
            : state.isInitialLoading,
        clearError: true,
      );
      _log.fine(
        'Fetched page $page successfully (received=${result.transactions.length}, loadedPages=${state.loadedPages.length}, totalPages=${state.totalPages})',
      );
    } catch (e) {
      if (!_stillWanted(generation)) return;
      _log.warning(
        'Failed to fetch page $page (prefetch=$isPrefetch, account=$accountName): $e',
      );
      if (!isPrefetch) {
        state = state.copyWith(error: e.toString(), isInitialLoading: false);
      }
    } finally {
      // Any exit that did not mark the page loaded (early return, stale
      // generation, error) must release the loading slot for this generation.
      if (!pageLoaded &&
          _stillWanted(generation) &&
          state.loadingPages.contains(page)) {
        state = state.copyWith(
          loadingPages: Set<int>.from(state.loadingPages)..remove(page),
        );
      }
    }
  }

  Future<String> _resolveAccountId(String accountName) async {
    if (_cachedAccountName == accountName && _cachedAccountId != null) {
      return _cachedAccountId!;
    }

    final accounts = await ref.read(accountsProvider.future);
    var account = accounts.where((a) => a.name == accountName).firstOrNull;
    if (account == null) {
      final counterparties = await ref.read(
        counterpartyAccountsProvider.future,
      );
      account = counterparties.where((a) => a.name == accountName).firstOrNull;
    }
    if (account == null) {
      _log.warning('Paginated fetch account not found: "$accountName"');
      throw Exception('Account "$accountName" not found.');
    }

    _cachedAccountId = account.id;
    _cachedAccountName = accountName;
    return account.id;
  }

  List<Transaction> _mergePage(
    List<Transaction> current,
    List<Transaction> incoming,
    int page,
    Set<int> loadedPages,
  ) {
    // First page of a (re)load replaces any placeholder rows outright, even
    // when the server now returns nothing.
    if (current.isEmpty || loadedPages.isEmpty) {
      return List<Transaction>.from(incoming)
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    if (incoming.isEmpty) return current;

    // Fast path for the common scroll case: the next page is disjoint and
    // strictly older than everything loaded, so append without a full
    // map rebuild + O(n log n) sort.
    final currentIds = {for (final t in current) t.id};
    final disjoint = incoming.every((t) => !currentIds.contains(t.id));
    if (disjoint && !incoming.first.date.isAfter(current.last.date)) {
      var ordered = true;
      for (var i = 1; i < incoming.length; i++) {
        if (incoming[i].date.isAfter(incoming[i - 1].date)) {
          ordered = false;
          break;
        }
      }
      if (ordered) return [...current, ...incoming];
    }

    final byId = {for (final t in current) t.id: t};
    for (final t in incoming) {
      byId[t.id] = t;
    }

    return byId.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}

final paginatedTransactionsProvider = NotifierProvider.autoDispose
    .family<PaginatedTransactionsNotifier, PaginatedTransactionsState, String?>(
      PaginatedTransactionsNotifier.new,
    );
