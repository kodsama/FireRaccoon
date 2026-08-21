import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../utils/locale_formatting.dart';
import '../theme/app_theme.dart';
import '../providers/data_providers.dart';
import '../providers/people_providers.dart';
import '../providers/default_period_provider.dart';
import '../providers/paginated_transactions_provider.dart';
import '../providers/transaction_analytics_providers.dart';
import '../providers/transaction_search_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/undo_history_provider.dart';
import '../router/route_navigation.dart';
import '../router/route_query.dart';
import '../router/transaction_analytics_route.dart';
import '../router/transactions_route.dart';
import '../utils/balance_check_selection.dart';
import '../utils/transaction_list_grouping.dart';
import '../widgets/account_balance_check_panel.dart';
import '../widgets/account_filter_dialog.dart';
import '../widgets/entity_screen_header.dart';
import '../widgets/small_loading_indicator.dart';
import '../providers/firefly_data_refresh.dart';
import '../widgets/selection_check_control.dart';
import '../widgets/transaction_edit_panel.dart';
import '../widgets/transaction_entity_card.dart';
import '../widgets/transaction_list_collapse.dart';
import '../widgets/transaction_month_header.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with TransactionListCollapseMixin {
  final _scrollController = ScrollController();
  bool _scrollCheckQueued = false;
  bool _balanceCheckMode = false;
  String? _balanceCheckAccount;
  Set<String> _balanceCheckIncludedIds = {};
  Set<String> _balanceCheckExcludedIds = {};
  bool _balanceCheckReconciling = false;
  bool _refreshingFromFirefly = false;
  String? _paybackPaymentAccountId;
  DateTime _paybackDate = DateTime.now();
  bool _reconcileRouteApplied = false;

  /// Day the balance chip is reading, or null for today.
  DateTime? _balanceAsOfDate;
  _CachedTransactionListGroups? _cachedGroups;
  List<Transaction>? _cachedMergeLocal;
  List<Transaction>? _cachedMergeSearch;
  List<Transaction>? _cachedMerged;

  /// Asks which day the balance chip should read.
  ///
  /// The range reaches a decade either way: the ledger holds scheduled payments
  /// well past today, and answering "what will I have when the loan is paid" is
  /// the point of allowing a future date at all.
  Future<void> _pickBalanceDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _balanceAsOfDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: context.l10n.balance,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _balanceAsOfDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  /// Combines the locally paginated window with server search results,
  /// memoized by input identity so downstream group caching stays effective.
  List<Transaction> _mergeWithSearchResults(
    List<Transaction> local,
    List<Transaction> searchResults,
  ) {
    if (searchResults.isEmpty) return local;
    if (identical(_cachedMergeLocal, local) &&
        identical(_cachedMergeSearch, searchResults)) {
      return _cachedMerged!;
    }
    final byId = {for (final t in local) t.id: t};
    for (final t in searchResults) {
      byId.putIfAbsent(t.id, () => t);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _cachedMergeLocal = local;
    _cachedMergeSearch = searchResults;
    _cachedMerged = merged;
    return merged;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Account filter resolved once per build; read by the per-frame scroll
  /// listener so it does not re-parse the route on every scroll tick.
  String? _scrollFilterAccount;

  /// False while a scoped-filter view is showing: those lists are fully
  /// loaded, so scrolling must not drive (or instantiate) the paginated
  /// provider.
  bool _scrollDrivesPagination = false;

  void _onScroll() {
    if (!_scrollDrivesPagination) return;
    if (!_scrollController.hasClients) return;
    ref
        .read(paginatedTransactionsProvider(_scrollFilterAccount).notifier)
        .onScroll(
          _scrollController.position.pixels,
          _scrollController.position.maxScrollExtent,
        );
  }

  void _scheduleScrollCheck() {
    if (_scrollCheckQueued) return;
    _scrollCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCheckQueued = false;
      if (mounted) _onScroll();
    });
  }

  TransactionListGroups _computeTransactionListGroups(
    List<Transaction> allTransactions, {
    required Set<String> activeAccountFilters,
    required String searchQuery,
    required TransactionGroupType type,
    required LocaleFormatting format,
    required AppLocalizations l10n,
    bool isRacoon = false,
    ReconciledFilter reconciledFilter = ReconciledFilter.all,
    Set<TransactionField> missingFields = const {},
    String? sumAccount,
  }) {
    final cached = _cachedGroups;
    if (cached != null &&
        identical(cached.allTransactions, allTransactions) &&
        cached.searchQuery == searchQuery &&
        cached.groupType == type &&
        cached.isRacoon == isRacoon &&
        cached.reconciledFilter == reconciledFilter &&
        _sameFieldSet(cached.missingFields, missingFields) &&
        cached.sumAccount == sumAccount &&
        identical(cached.format, format) &&
        identical(cached.l10n, l10n) &&
        _sameStringSet(cached.activeAccountFilters, activeAccountFilters)) {
      return cached.groups;
    }

    final groups = buildTransactionListGroups(
      transactions: allTransactions,
      activeAccountFilters: activeAccountFilters,
      searchQuery: searchQuery,
      groupType: type,
      format: format,
      l10n: l10n,
      isRacoon: isRacoon,
      reconciledFilter: reconciledFilter,
      missingFields: missingFields,
      sumAccount: sumAccount,
    );
    _cachedGroups = _CachedTransactionListGroups(
      allTransactions: allTransactions,
      activeAccountFilters: activeAccountFilters,
      searchQuery: searchQuery,
      groupType: type,
      isRacoon: isRacoon,
      reconciledFilter: reconciledFilter,
      missingFields: missingFields,
      sumAccount: sumAccount,
      format: format,
      l10n: l10n,
      groups: groups,
    );
    return groups;
  }

  bool _sameFieldSet(Set<TransactionField> left, Set<TransactionField> right) {
    if (left.length != right.length) return false;
    for (final value in left) {
      if (!right.contains(value)) return false;
    }
    return true;
  }

  bool _sameStringSet(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    for (final value in left) {
      if (!right.contains(value)) return false;
    }
    return true;
  }

  void _setBalanceCheckMode(bool enabled, List<Transaction> transactions) {
    setState(() {
      _balanceCheckMode = enabled;
      if (enabled) {
        _balanceCheckIncludedIds = defaultBalanceCheckIncludedIds(transactions);
        _balanceCheckExcludedIds = defaultBalanceCheckExcludedIds(transactions);
        _paybackDate = DateTime.now();
      } else {
        _balanceCheckIncludedIds = {};
        _balanceCheckExcludedIds = {};
        _paybackPaymentAccountId = null;
      }
    });
  }

  void _syncBalanceCheckSelection(List<Transaction> transactions) {
    // Reconciled journals count automatically; nothing to sync.
  }

  void _toggleBalanceCheckTransaction(Transaction transaction) {
    setState(() {
      toggleBalanceCheckTransaction(
        transaction,
        includedIds: _balanceCheckIncludedIds,
        excludedIds: _balanceCheckExcludedIds,
      );
    });
  }

  void _toggleBalanceCheckMonthGroup(List<Transaction> transactions) {
    setState(() {
      toggleBalanceCheckMonthGroup(
        transactions: transactions,
        includedIds: _balanceCheckIncludedIds,
        excludedIds: _balanceCheckExcludedIds,
      );
    });
  }

  Future<void> _reconcileSelectedTransactions({
    required List<Transaction> transactions,
    required String? filterAccount,
    Account? creditCard,
    List<Account> paymentAccounts = const [],
  }) async {
    if (_balanceCheckReconciling) return;
    final selectedIds = effectiveBalanceCheckSelectedIds(
      transactions: transactions,
      includedIds: _balanceCheckIncludedIds,
      excludedIds: _balanceCheckExcludedIds,
    );
    final changes = balanceCheckReconcileChanges(
      transactions: transactions,
      selectedIds: selectedIds,
    );
    final toReconcile = changes.toReconcile;
    final toUnreconcile = changes.toUnreconcile;
    if (!changes.hasWork) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.balanceCheckNothingToReconcile)),
        );
      }
      return;
    }

    final service = ref.read(apiServiceProvider);
    if (service == null) return;

    final isCreditCard = creditCard != null && isCreditCardAccount(creditCard);
    Account? paymentAccount;
    final creatingPayback = isCreditCard && toReconcile.isNotEmpty;
    if (creatingPayback) {
      final paymentAccountId =
          _paybackPaymentAccountId ??
          (paymentAccounts.length == 1 ? paymentAccounts.single.id : null);
      paymentAccount = paymentAccounts
          .where((account) => account.id == paymentAccountId)
          .firstOrNull;
      final eligible = toReconcile
          .where(
            (transaction) => isCreditCardPurchase(transaction, creditCard.name),
          )
          .toList();
      if (paymentAccount == null || eligible.isEmpty) return;
    }

    setState(() => _balanceCheckReconciling = true);
    final notifier = ref.read(
      paginatedTransactionsProvider(filterAccount).notifier,
    );
    for (final transaction in toReconcile) {
      notifier.patchTransaction(transaction.withReconciled(true));
    }
    for (final transaction in toUnreconcile) {
      notifier.patchTransaction(transaction.withReconciled(false));
    }
    try {
      if (creatingPayback && paymentAccount != null) {
        await _reconcileCreditCardPayback(
          service: service,
          notifier: notifier,
          filterAccount: filterAccount,
          creditCard: creditCard,
          paymentAccount: paymentAccount,
          toReconcile: toReconcile,
          toUnreconcile: toUnreconcile,
        );
      } else {
        await _reconcileMarkOnly(
          service: service,
          notifier: notifier,
          filterAccount: filterAccount,
          toReconcile: toReconcile,
          toUnreconcile: toUnreconcile,
        );
      }
    } finally {
      if (mounted) setState(() => _balanceCheckReconciling = false);
    }
  }

  Future<void> _reconcileMarkOnly({
    required FireflyService service,
    required PaginatedTransactionsNotifier notifier,
    required String? filterAccount,
    required List<Transaction> toReconcile,
    required List<Transaction> toUnreconcile,
  }) async {
    final saved = <Transaction>[];
    final failedOriginals = <Transaction>[];
    const concurrency = 4;

    Future<void> applyChunk(
      List<Transaction> originals,
      bool reconciled,
    ) async {
      for (var i = 0; i < originals.length; i += concurrency) {
        final chunkEnd = i + concurrency < originals.length
            ? i + concurrency
            : originals.length;
        await Future.wait(
          originals.sublist(i, chunkEnd).map((original) async {
            try {
              saved.add(
                await service.updateTransaction(
                  original.withReconciled(reconciled),
                ),
              );
            } catch (_) {
              failedOriginals.add(original);
            }
          }),
        );
      }
    }

    await applyChunk(toReconcile, true);
    await applyChunk(toUnreconcile, false);

    for (final original in failedOriginals) {
      notifier.patchTransaction(original);
    }
    for (final transaction in saved) {
      await refreshTransactionLists(ref, filterAccount, upsert: transaction);
      final wasReconciled = transaction.isReconciled;
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: wasReconciled
                ? 'Transaction reconciled'
                : 'Transaction unreconciled',
            details:
                '${wasReconciled ? 'Reconciled' : 'Unreconciled'} "${transaction.description}"',
            type: UndoActionType.transactionUpdate,
            undoPayload: transactionUndoPayload(
              transaction.withReconciled(!wasReconciled),
            ),
            redoPayload: transactionUndoPayload(transaction),
          );
    }

    if (mounted) {
      final attempted = toReconcile.length + toUnreconcile.length;
      final message = failedOriginals.isEmpty
          ? context.l10n.balanceCheckReconciled
          : context.l10n.failedToUpdateReconciliation(
              '${failedOriginals.length}/$attempted',
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _reconcileCreditCardPayback({
    required FireflyService service,
    required PaginatedTransactionsNotifier notifier,
    required String? filterAccount,
    required Account creditCard,
    required Account paymentAccount,
    required List<Transaction> toReconcile,
    required List<Transaction> toUnreconcile,
  }) async {
    try {
      for (final original in toUnreconcile) {
        final updated = await service.updateTransaction(
          original.withReconciled(false),
        );
        await refreshTransactionLists(ref, filterAccount, upsert: updated);
      }

      final result = await ReconciliationService(service)
          .storeCreditCardPayback(
            journalsToReconcile: toReconcile,
            creditCard: creditCard,
            paymentAccount: paymentAccount,
            paybackDate: _paybackDate,
          );

      for (final transaction in result.reconciled) {
        await refreshTransactionLists(ref, filterAccount, upsert: transaction);
      }
      if (result.payback != null) {
        await refreshTransactionLists(
          ref,
          filterAccount,
          upsert: result.payback,
        );
      }
      // Always re-fetch after creating a payback: patch-only can miss the new
      // multi-split journal or leave sibling account lists stale.
      await refreshTransactionLists(
        ref,
        filterAccount,
        alsoRefreshAccounts: {
          paymentAccount.name,
          if (result.payback != null)
            ...transactionAccountNames(result.payback!),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.balanceCheckPaybackReconciled)),
        );
      }
    } catch (error) {
      for (final original in [...toReconcile, ...toUnreconcile]) {
        notifier.patchTransaction(original);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.failedToUpdateReconciliation('$error')),
          ),
        );
      }
    }
  }

  BalanceCheckSelection? _balanceCheckSelection(
    List<Transaction> transactions,
    String? filterAccount,
  ) {
    if (!_balanceCheckMode || filterAccount == null) return null;
    return BalanceCheckSelection(
      includedIds: _balanceCheckIncludedIds,
      excludedIds: _balanceCheckExcludedIds,
      onToggle: _toggleBalanceCheckTransaction,
    );
  }

  Future<void> _openNewTransaction(String? filterAccount) async {
    final l10n = context.l10n;
    try {
      final currency = await ref.read(primaryCurrencyProvider.future);
      final accounts = await ref.read(accountsProvider.future);
      final filtered = filterAccount != null
          ? accounts.where((a) => a.name == filterAccount).firstOrNull
          : null;

      final initial = newTransactionTemplate(
        currencySymbol: filtered?.currencySymbol ?? currency.symbol,
        currencyCode: filtered?.currencyCode ?? currency.code,
        sourceName: filtered?.name,
        sourceId: filtered?.id,
      );

      if (!mounted) return;

      final created = await showNewTransactionDialog(
        context: context,
        ref: ref,
        initial: initial,
        onCreate: (transaction) async {
          final service = ref.read(apiServiceProvider);
          final created = await service?.createTransaction(transaction);
          if (created != null) {
            ref
                .read(undoHistoryProvider.notifier)
                .record(
                  title: 'Transaction created',
                  details: 'Created transaction "${created.description}"',
                  type: UndoActionType.transactionCreate,
                  undoPayload: {'transactionId': created.id},
                  redoPayload: transactionUndoPayload(created),
                );
          }
          await refreshTransactionLists(ref, filterAccount, upsert: created);
        },
      );

      if (created == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.transactionCreated)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToCreateTransaction(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final format = ref.watch(localeFormattingProvider);
    final routeState = GoRouterState.of(context);
    final defaultPeriod = ref.watch(defaultDashboardPeriodProvider);
    final routeFilters = TransactionsRoute.filtersFrom(
      routeState,
      defaultDashboardPeriod: defaultPeriod,
    );
    final filterAccounts = routeFilters.accounts;
    final filterAccount = filterAccounts.isEmpty ? routeFilters.account : null;
    _scrollFilterAccount = filterAccount;
    final searchQuery = RouteQuery.searchFrom(routeState.uri) ?? '';
    final groupType = routeFilters.group;

    _scrollDrivesPagination = !routeFilters.hasScopedFilters;

    if (routeFilters.hasScopedFilters) {
      final listKey = (
        period: routeFilters.period,
        from: routeFilters.from,
        to: routeFilters.to,
        type: routeFilters.type,
        account: routeFilters.account,
        category: routeFilters.category,
      );
      final scopedAsync = ref.watch(filteredTransactionListProvider(listKey));
      return scopedAsync.when(
        skipLoadingOnReload: true,
        loading: () => _buildTransactionsScaffold(
          allTransactions: const [],
          filterAccount: filterAccount,
          filterAccounts: filterAccounts,
          routeFilters: routeFilters,
          searchQuery: searchQuery,
          groupType: groupType,
          format: format,
          l10n: l10n,
          fun: fun,
          colors: colors,
          totalCount: 0,
          hasMore: false,
          isLoadingMore: false,
          showInitialLoader: true,
        ),
        error: (error, stackTrace) => Scaffold(
          backgroundColor: colors.pageBg,
          body: Center(child: Text(l10n.errorGeneric(error.toString()))),
        ),
        data: (transactions) => _buildTransactionsScaffold(
          allTransactions: transactions,
          filterAccount: filterAccount,
          filterAccounts: filterAccounts,
          routeFilters: routeFilters,
          searchQuery: searchQuery,
          groupType: groupType,
          format: format,
          l10n: l10n,
          fun: fun,
          colors: colors,
          totalCount: transactions.length,
          hasMore: false,
          isLoadingMore: false,
        ),
      );
    }

    final paginatedState = ref.watch(
      paginatedTransactionsProvider(filterAccount),
    );
    final accountsAsync = filterAccount != null
        ? ref.watch(accountsProvider)
        : null;
    final currencyAsync = filterAccount != null
        ? ref.watch(primaryCurrencyProvider)
        : null;

    if (paginatedState.error != null && paginatedState.transactions.isEmpty) {
      return Scaffold(
        backgroundColor: colors.pageBg,
        body: Center(
          child: Text(l10n.errorGeneric(paginatedState.error.toString())),
        ),
      );
    }

    // Treat an in-flight first page as loading even if isInitialLoading was
    // cleared by a raced early return from _fetchPage.
    final showInitialLoader =
        paginatedState.transactions.isEmpty &&
        (paginatedState.isInitialLoading || paginatedState.isLoadingMore);

    var serverSearchResults = searchQuery.trim().isEmpty
        ? const <Transaction>[]
        : ref.watch(serverSearchResultsProvider(searchQuery)).value ??
              const <Transaction>[];
    if (filterAccount != null && serverSearchResults.isNotEmpty) {
      // Single-account view: only merge search hits touching that account.
      serverSearchResults = serverSearchResults
          .where(
            (transaction) =>
                transactionAccountNames(transaction).contains(filterAccount),
          )
          .toList();
    }

    var mergedTransactions = _mergeWithSearchResults(
      paginatedState.transactions,
      serverSearchResults,
    );

    final activePersonId = ref.watch(activePersonFilterProvider);
    if (activePersonId != null) {
      final peopleConfig = ref.watch(peopleSettingsProvider);
      mergedTransactions = mergedTransactions.where((tx) {
        final srcId = tx.sourceId;
        final dstId = tx.destinationId;
        final srcRatio = srcId != null
            ? peopleConfig.getOwnershipRatio(srcId, activePersonId)
            : 0.0;
        final dstRatio = dstId != null
            ? peopleConfig.getOwnershipRatio(dstId, activePersonId)
            : 0.0;
        return srcRatio > 0.0 || dstRatio > 0.0;
      }).toList();
    }

    return _buildTransactionsScaffold(
      allTransactions: mergedTransactions,
      filterAccount: filterAccount,
      filterAccounts: filterAccounts,
      routeFilters: routeFilters,
      searchQuery: searchQuery,
      groupType: groupType,
      format: format,
      l10n: l10n,
      fun: fun,
      colors: colors,
      totalCount: paginatedState.totalCount,
      hasMore: paginatedState.hasMore,
      isLoadingMore: paginatedState.isLoadingMore,
      showInitialLoader: showInitialLoader,
      accountsAsync: accountsAsync,
      currencyAsync: currencyAsync,
      onScheduleScrollCheck: _scheduleScrollCheck,
    );
  }

  Widget _buildTransactionsScaffold({
    required List<Transaction> allTransactions,
    required String? filterAccount,
    required List<String> filterAccounts,
    required TransactionsRouteFilters routeFilters,
    required String searchQuery,
    required TransactionGroupType groupType,
    required LocaleFormatting format,
    required AppLocalizations l10n,
    required dynamic fun,
    required dynamic colors,
    required int totalCount,
    required bool hasMore,
    required bool isLoadingMore,
    bool showInitialLoader = false,
    AsyncValue<List<Account>>? accountsAsync,
    AsyncValue<FireflyCurrency>? currencyAsync,
    VoidCallback? onScheduleScrollCheck,
  }) {
    final activeAccountFilters = filterAccounts.toSet();
    final listGroups = _computeTransactionListGroups(
      allTransactions,
      activeAccountFilters: activeAccountFilters,
      searchQuery: searchQuery,
      type: groupType,
      format: format,
      l10n: l10n,
      isRacoon: fun.isRacoon,
      reconciledFilter: routeFilters.reconciledFilter,
      missingFields: routeFilters.missingFields,
      // Sums are signed from the filtered account's perspective so incoming
      // transfers count positive.
      sumAccount: filterAccount,
    );
    final filteredTxs = listGroups.filteredTransactions;

    double? balance;
    double? reportedBalance;
    String? currencySymbol = currencyAsync?.value?.symbol ?? '€';
    if (filterAccount != null) {
      final accs = accountsAsync?.value ?? [];
      final acc = accs.where((a) => a.name == filterAccount).firstOrNull;
      if (acc != null) {
        currencySymbol = acc.currencySymbol;
        if (acc.type == 'asset' || acc.type == 'liability') {
          reportedBalance = acc.currentBalance;
          balance = accountBalanceExcludingFuture(
            reportedBalance: acc.currentBalance,
            accountName: filterAccount,
            transactions: filteredTxs,
          );
        } else {
          balance = _sumNonFutureTransactionBalance(filteredTxs);
        }
      } else if (filteredTxs.isNotEmpty) {
        currencySymbol = filteredTxs.first.currencySymbol;
        balance = _sumNonFutureTransactionBalance(filteredTxs);
      }
    }

    _syncBalanceCheckSelection(filteredTxs);

    // Arriving via a "Reconcile" action (from an account) auto-enters balance
    // check mode once, so the user lands ready to review and tick off
    // operations for that account.
    if (routeFilters.reconcile &&
        !_reconcileRouteApplied &&
        !_balanceCheckMode &&
        filterAccount != null) {
      _reconcileRouteApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setBalanceCheckMode(true, filteredTxs);
      });
    }

    // Balance-from-selected must see every account journal (including
    // unreconciled and future reconciled), even when the list is filtered to
    // reconciled-only — otherwise unreconciled amounts stay stuck in the
    // reported balance and a future card repayment cannot bring the
    // reconciled total to 0.
    final balanceCheckTxs =
        routeFilters.reconciledFilter == ReconciledFilter.all
        ? filteredTxs
        : _computeTransactionListGroups(
            allTransactions,
            activeAccountFilters: activeAccountFilters,
            searchQuery: searchQuery,
            type: groupType,
            format: format,
            l10n: l10n,
            isRacoon: fun.isRacoon,
            reconciledFilter: ReconciledFilter.all,
            sumAccount: filterAccount,
          ).filteredTransactions;

    final balanceCheckSelection = _balanceCheckSelection(
      filteredTxs,
      filterAccount,
    );
    final showBalanceCheckSelection =
        _balanceCheckMode &&
        filterAccount != null &&
        balance != null &&
        reportedBalance != null;
    final selectedBalance = showBalanceCheckSelection
        ? balanceFromSelectedTransactions(
            reportedBalance: reportedBalance,
            accountName: filterAccount,
            transactions: balanceCheckTxs,
            selectedIds: effectiveBalanceCheckSelectedIds(
              transactions: balanceCheckTxs,
              includedIds: _balanceCheckIncludedIds,
              excludedIds: _balanceCheckExcludedIds,
            ),
          )
        : balance;

    final sortedKeys = listGroups.sortedKeys;
    ensureDefaultGroupExpansion(sortedKeys);
    final futureTxs = listGroups.futureTransactions;
    // A running balance only means something for one account at a time, so
    // without one the months show their own total and nothing more.
    final expectedFutureBalances = balance == null
        ? const <String, double>{}
        : expectedBalanceByFutureMonth(
            openingBalance: balance,
            futureGroups: listGroups.futureGroups,
          );
    final loadedCount = filteredTxs.length;

    final subtitleParts = <String>[
      if (routeFilters.hasScopedFilters)
        routeFilters.localizedSummary(l10n, format, isRacoon: fun.isRacoon),
      if (filterAccount != null) l10n.filteredBy(filterAccount),
      if (activeAccountFilters.isNotEmpty)
        l10n.filteredBy(activeAccountFilters.map((name) => name).join(', ')),
      if (totalCount > 0 && hasMore && loadedCount < totalCount)
        l10n.showingTransactionsOfTotal(loadedCount, totalCount)
      else if (loadedCount == 1)
        fun.oneTransaction
      else
        fun.transactionsCount(loadedCount),
    ];

    if (hasMore && !isLoadingMore) {
      onScheduleScrollCheck?.call();
    }

    if (filterAccount != _balanceCheckAccount) {
      _balanceCheckAccount = filterAccount;
      _balanceCheckMode = false;
      _balanceCheckIncludedIds = {};
      _balanceCheckExcludedIds = {};
      _paybackPaymentAccountId = null;
    }

    final accounts = accountsAsync?.value ?? const <Account>[];
    final filteredAccount = filterAccount == null
        ? null
        : accounts
              .where((account) => account.name == filterAccount)
              .firstOrNull;
    final isCreditCard =
        filteredAccount != null && isCreditCardAccount(filteredAccount);
    final paymentAccounts = isCreditCard
        ? paymentAccountsForCreditCard(filteredAccount, accounts)
        : const <Account>[];
    final effectivePaybackPaymentAccountId =
        _paybackPaymentAccountId ??
        (paymentAccounts.length == 1 ? paymentAccounts.single.id : null);
    final selectedIdsForPayback = showBalanceCheckSelection
        ? effectiveBalanceCheckSelectedIds(
            transactions: balanceCheckTxs,
            includedIds: _balanceCheckIncludedIds,
            excludedIds: _balanceCheckExcludedIds,
          )
        : <String>{};
    final pendingReconcileChanges = showBalanceCheckSelection
        ? balanceCheckReconcileChanges(
            transactions: balanceCheckTxs,
            selectedIds: selectedIdsForPayback,
          )
        : const BalanceCheckReconcileChanges(
            toReconcile: [],
            toUnreconcile: [],
          );
    final eligiblePaybackPurchases = isCreditCard
        ? balanceCheckTxs
              .where(
                (transaction) =>
                    selectedIdsForPayback.contains(transaction.id) &&
                    !transaction.isReconciled &&
                    !transaction.isPartiallyReconciled &&
                    isCreditCardPurchase(transaction, filterAccount!),
              )
              .toList()
        : const <Transaction>[];
    final paybackTotal = eligiblePaybackPurchases.fold<double>(
      0,
      (sum, transaction) =>
          sum + creditCardPaybackAmount(transaction, filterAccount!),
    );

    final showBalanceCheck =
        filterAccount != null && balance != null && _balanceCheckMode;

    final hasAnyActiveFilter =
        filterAccount != null ||
        filterAccounts.isNotEmpty ||
        (routeFilters.category != null && routeFilters.category!.isNotEmpty) ||
        searchQuery.isNotEmpty ||
        routeFilters.type != TransactionTypeFilter.all ||
        routeFilters.hasCustomDateRange ||
        routeFilters.reconciledFilter != ReconciledFilter.all ||
        routeFilters.missingFields.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
            sliver: SliverToBoxAdapter(
              child: EntityScreenHeader(
                title: fun.transactionsTitle,
                subtitle: subtitleParts.join(' · '),
                createLabel: fun.newTransaction,
                onCreate: () => _openNewTransaction(filterAccount),
                trailing: [
                  if (hasAnyActiveFilter)
                    TextButton(
                      onPressed: () => context.go(
                        TransactionsRoute.location(group: routeFilters.group),
                      ),
                      child: Text(l10n.clearFilters),
                    ),
                  _AccountBalanceChip(
                    accountId: filteredAccount?.id,
                    todayBalance: balance,
                    currencySymbol: currencySymbol,
                    format: format,
                    asOf: _balanceAsOfDate,
                    onPickDate: filteredAccount == null
                        ? null
                        : () => _pickBalanceDate(context),
                    onClearDate: () => setState(() => _balanceAsOfDate = null),
                  ),
                  if (filterAccount != null && balance != null) ...[
                    AccountBalanceCheckToggle(
                      enabled: _balanceCheckMode,
                      onToggle: () {
                        if (_balanceCheckMode) {
                          _setBalanceCheckMode(false, filteredTxs);
                        } else {
                          _setBalanceCheckMode(true, filteredTxs);
                        }
                      },
                    ),
                  ],
                  _PeriodFilterButton(
                    routeFilters: routeFilters,
                    l10n: l10n,
                    format: format,
                  ),
                  _AccountFilterButton(
                    routeFilters: routeFilters,
                    currentFilter: filterAccount,
                    currentGroupType: groupType,
                    l10n: l10n,
                  ),
                  _GroupingButton(
                    routeFilters: routeFilters,
                    currentGroupType: groupType,
                    currentFilter: filterAccount,
                    l10n: l10n,
                  ),
                  _MissingFieldsFilterButton(
                    selected: routeFilters.missingFields,
                    l10n: l10n,
                    onChanged: (fields) {
                      context.goPreservingSearch(
                        TransactionsRoute.location(
                          account: routeFilters.account,
                          accounts: routeFilters.accounts,
                          group: routeFilters.group,
                          category: routeFilters.category,
                          period: routeFilters.period,
                          type: routeFilters.type,
                          from: routeFilters.from != null
                              ? ExpenseRouteFilters.formatDate(
                                  routeFilters.from!,
                                )
                              : null,
                          to: routeFilters.to != null
                              ? ExpenseRouteFilters.formatDate(routeFilters.to!)
                              : null,
                          reconcile: routeFilters.reconcile,
                          reconciledFilter: routeFilters.reconciledFilter,
                          missingFields: fields,
                        ),
                      );
                    },
                  ),
                  _ReconciledFilterButton(
                    currentFilter: routeFilters.reconciledFilter,
                    l10n: l10n,
                    onSelected: (value) {
                      context.goPreservingSearch(
                        TransactionsRoute.location(
                          account: routeFilters.account,
                          accounts: routeFilters.accounts,
                          group: routeFilters.group,
                          category: routeFilters.category,
                          period: routeFilters.period,
                          type: routeFilters.type,
                          from: routeFilters.from != null
                              ? ExpenseRouteFilters.formatDate(
                                  routeFilters.from!,
                                )
                              : null,
                          to: routeFilters.to != null
                              ? ExpenseRouteFilters.formatDate(routeFilters.to!)
                              : null,
                          reconcile: routeFilters.reconcile,
                          reconciledFilter: value,
                          missingFields: routeFilters.missingFields,
                        ),
                      );
                    },
                  ),
                  _FireflyRefreshButton(
                    refreshing: _refreshingFromFirefly,
                    onPressed: _refreshingFromFirefly
                        ? null
                        : () async {
                            setState(() => _refreshingFromFirefly = true);
                            try {
                              await refreshFireflyData(
                                ref,
                                focusAccount: filterAccount,
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _refreshingFromFirefly = false);
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
          if (hasAnyActiveFilter)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(30, 16, 30, 0),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Active Filters:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.text3,
                      ),
                    ),
                    if (filterAccount != null)
                      _ActiveFilterBubble(
                        icon: LucideIcons.store,
                        label: 'Account/Payee: $filterAccount',
                        onRemove: () => context.goPreservingSearch(
                          TransactionsRoute.location(
                            group: groupType,
                            category: routeFilters.category,
                            period: routeFilters.period,
                            type: routeFilters.type,
                            from: routeFilters.from != null
                                ? ExpenseRouteFilters.formatDate(
                                    routeFilters.from!,
                                  )
                                : null,
                            to: routeFilters.to != null
                                ? ExpenseRouteFilters.formatDate(
                                    routeFilters.to!,
                                  )
                                : null,
                            reconcile: routeFilters.reconcile,
                          ),
                        ),
                      ),
                    if (routeFilters.category != null &&
                        routeFilters.category!.isNotEmpty)
                      _ActiveFilterBubble(
                        icon: LucideIcons.folder,
                        label: 'Category: ${routeFilters.category}',
                        onRemove: () => context.goPreservingSearch(
                          TransactionsRoute.location(
                            account: filterAccount,
                            accounts: filterAccounts,
                            group: groupType,
                            period: routeFilters.period,
                            type: routeFilters.type,
                            from: routeFilters.from != null
                                ? ExpenseRouteFilters.formatDate(
                                    routeFilters.from!,
                                  )
                                : null,
                            to: routeFilters.to != null
                                ? ExpenseRouteFilters.formatDate(
                                    routeFilters.to!,
                                  )
                                : null,
                            reconcile: routeFilters.reconcile,
                          ),
                        ),
                      ),
                    if (searchQuery.isNotEmpty)
                      _ActiveFilterBubble(
                        icon: LucideIcons.search,
                        label: 'Search: "$searchQuery"',
                        onRemove: () => context.go(
                          RouteQuery.withSearch(
                            GoRouterState.of(context).uri,
                            null,
                          ),
                        ),
                      ),
                    if (routeFilters.type != TransactionTypeFilter.all)
                      _ActiveFilterBubble(
                        icon: LucideIcons.arrowUpRight,
                        label: 'Type: ${routeFilters.type.name}',
                        onRemove: () => context.goPreservingSearch(
                          TransactionsRoute.location(
                            account: filterAccount,
                            accounts: filterAccounts,
                            group: groupType,
                            category: routeFilters.category,
                            period: routeFilters.period,
                            type: TransactionTypeFilter.all,
                            from: routeFilters.from != null
                                ? ExpenseRouteFilters.formatDate(
                                    routeFilters.from!,
                                  )
                                : null,
                            to: routeFilters.to != null
                                ? ExpenseRouteFilters.formatDate(
                                    routeFilters.to!,
                                  )
                                : null,
                            reconcile: routeFilters.reconcile,
                          ),
                        ),
                      ),
                    if (routeFilters.hasCustomDateRange)
                      _ActiveFilterBubble(
                        icon: LucideIcons.calendar,
                        label:
                            'Date: ${format.formatDateRange(routeFilters.from, routeFilters.to, ellipsis: l10n.dateEllipsis, separator: l10n.dateRangeSeparator)}',
                        onRemove: () => context.goPreservingSearch(
                          TransactionsRoute.location(
                            account: filterAccount,
                            accounts: filterAccounts,
                            group: groupType,
                            category: routeFilters.category,
                            period: ExpensePeriod.all,
                            type: routeFilters.type,
                            reconcile: routeFilters.reconcile,
                            reconciledFilter: routeFilters.reconciledFilter,
                          ),
                        ),
                      ),
                    if (routeFilters.reconciledFilter != ReconciledFilter.all)
                      _ActiveFilterBubble(
                        icon: LucideIcons.circleCheck,
                        label:
                            'Reconciled: ${routeFilters.reconciledFilter.name}',
                        onRemove: () => context.goPreservingSearch(
                          TransactionsRoute.location(
                            account: filterAccount,
                            accounts: filterAccounts,
                            group: groupType,
                            category: routeFilters.category,
                            period: routeFilters.period,
                            type: routeFilters.type,
                            from: routeFilters.from != null
                                ? ExpenseRouteFilters.formatDate(
                                    routeFilters.from!,
                                  )
                                : null,
                            to: routeFilters.to != null
                                ? ExpenseRouteFilters.formatDate(
                                    routeFilters.to!,
                                  )
                                : null,
                            reconcile: routeFilters.reconcile,
                            reconciledFilter: ReconciledFilter.all,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (showBalanceCheck)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(30, 16, 30, 0),
              sliver: SliverToBoxAdapter(
                child: AccountBalanceCheckPanel(
                  expectedBalance: selectedBalance ?? balance,
                  currencySymbol: currencySymbol,
                  format: format,
                  expectedBalanceLabel: showBalanceCheckSelection
                      ? l10n.balanceCheckSelectedBalance
                      : null,
                  onReconcile: showBalanceCheckSelection
                      ? () => _reconcileSelectedTransactions(
                          transactions: balanceCheckTxs,
                          filterAccount: filterAccount,
                          creditCard: isCreditCard ? filteredAccount : null,
                          paymentAccounts: paymentAccounts,
                        )
                      : null,
                  isReconciling: _balanceCheckReconciling,
                  hasPendingReconcileWork: pendingReconcileChanges.hasWork,
                  creditCardPayback: isCreditCard
                      ? CreditCardPaybackFields(
                          paymentAccounts: paymentAccounts,
                          selectedPaymentAccountId:
                              effectivePaybackPaymentAccountId,
                          onPaymentAccountChanged: (id) {
                            setState(() => _paybackPaymentAccountId = id);
                          },
                          paybackDate: _paybackDate,
                          onPaybackDateChanged: (date) {
                            setState(() => _paybackDate = date);
                          },
                          paybackTotal: paybackTotal,
                          hasEligiblePurchases:
                              eligiblePaybackPurchases.isNotEmpty,
                        )
                      : null,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: showBalanceCheck ? 16 : 24),
          ),
          if (showInitialLoader)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: PageLoadingIndicator(),
            )
          else if (filteredTxs.isEmpty && futureTxs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  hasAnyActiveFilter
                      ? l10n.noTransactionsMatchFilters
                      : fun.noTransactionsYet,
                  style: TextStyle(color: colors.text3, fontSize: 14),
                ),
              ),
            )
          else ...[
            if (futureTxs.isNotEmpty)
              Builder(
                builder: (context) {
                  final futureShown =
                      futureExpanded || listGroups.groups.isEmpty;
                  final futureSum = sumTransactionAmounts(
                    futureTxs,
                    accountName: filterAccount,
                  );
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Tooltip(
                            message: futureShown
                                ? l10n.tooltipCollapseDetails
                                : l10n.tooltipExpandDetails,
                            child: InkWell(
                              onTap: toggleFutureCollapse,
                              child: TransactionMonthHeader(
                                label: l10n.futureTransactions,
                                subtitle: l10n.transactionsCount(
                                  futureTxs.length,
                                ),
                                trailingLabel: format.formatSignedMoney(
                                  futureSum,
                                  futureTxs.first.currencySymbol,
                                ),
                                trailingColor: futureSum >= 0
                                    ? colors.success
                                    : colors.text,
                                expanded: futureShown,
                                interactive: false,
                              ),
                            ),
                          ),
                        ),
                        if (futureShown)
                          for (final group in listGroups.futureGroups)
                            SliverCollapsibleTransactionGroup(
                              label: group.key,
                              // What the balance will be once this month has
                              // closed, which is the reason for the months.
                              subtitle:
                                  expectedFutureBalances[group.key] == null
                                  ? null
                                  : l10n.reconcileExpectedBalance(
                                      format.formatMoney(
                                        expectedFutureBalances[group.key]!,
                                        group.currencySymbol,
                                      ),
                                    ),
                              sum: group.sum,
                              currencySymbol: group.currencySymbol,
                              transactions: group.transactions,
                              filterAccount: filterAccount,
                              // Namespaced: a future month and a posted month
                              // can carry the same label, and they collapse
                              // independently.
                              expanded: isGroupExpanded('future:${group.key}'),
                              onToggle: () =>
                                  toggleGroupCollapse('future:${group.key}'),
                              format: format,
                              balanceCheckSelection: balanceCheckSelection,
                            ),
                      ],
                    ),
                  );
                },
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              sliver: SliverMainAxisGroup(
                slivers: [
                  for (final group in listGroups.groups)
                    Builder(
                      builder: (context) {
                        final key = group.key;
                        final showMonthSelection =
                            showBalanceCheckSelection &&
                            groupType == TransactionGroupType.date;
                        final monthSelectionState = showMonthSelection
                            ? balanceCheckGroupSelectionState(
                                transactions: group.transactions,
                                includedIds: _balanceCheckIncludedIds,
                                excludedIds: _balanceCheckExcludedIds,
                              )
                            : null;
                        final monthToggleable = showMonthSelection
                            ? group.transactions.where(
                                (transaction) =>
                                    !transaction.isReconciled &&
                                    !transaction.isPartiallyReconciled,
                              )
                            : const Iterable<Transaction>.empty();
                        return SliverCollapsibleTransactionGroup(
                          label: group.key,
                          sum: group.sum,
                          currencySymbol: group.currencySymbol,
                          transactions: group.transactions,
                          filterAccount: filterAccount,
                          expanded: isGroupExpanded(key),
                          onToggle: () => toggleGroupCollapse(key),
                          format: format,
                          selectionState: monthSelectionState,
                          selectionEnabled: monthToggleable.isNotEmpty,
                          onSelectionToggle: showMonthSelection
                              ? () => _toggleBalanceCheckMonthGroup(
                                  group.transactions,
                                )
                              : null,
                          // Month header uses accent for mixed pending picks;
                          // per-row icons still show green vs accent via visual.
                          checkColors: showMonthSelection
                              ? SelectionCheckColors.selection(colors)
                              : null,
                          balanceCheckSelection: balanceCheckSelection,
                        );
                      },
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              sliver: SliverToBoxAdapter(
                child: isLoadingMore
                    ? const Center(child: SmallLoadingIndicator(size: 24))
                    : hasMore
                    ? Center(
                        child: Text(
                          l10n.scrollForMore,
                          style: TextStyle(color: colors.text3, fontSize: 12),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CachedTransactionListGroups {
  final List<Transaction> allTransactions;
  final Set<String> activeAccountFilters;
  final String searchQuery;
  final TransactionGroupType groupType;
  final bool isRacoon;
  final ReconciledFilter reconciledFilter;
  final Set<TransactionField> missingFields;
  final String? sumAccount;
  final LocaleFormatting format;
  final AppLocalizations l10n;
  final TransactionListGroups groups;

  const _CachedTransactionListGroups({
    required this.allTransactions,
    required this.activeAccountFilters,
    required this.searchQuery,
    required this.groupType,
    required this.isRacoon,
    required this.reconciledFilter,
    required this.missingFields,
    required this.sumAccount,
    required this.format,
    required this.l10n,
    required this.groups,
  });
}

class _GroupingButton extends StatelessWidget {
  final TransactionsRouteFilters routeFilters;
  final TransactionGroupType currentGroupType;
  final String? currentFilter;
  final AppLocalizations l10n;

  const _GroupingButton({
    required this.routeFilters,
    required this.currentGroupType,
    required this.currentFilter,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopupMenuButton<TransactionGroupType>(
      initialValue: currentGroupType,
      onSelected: (value) {
        context.goPreservingSearch(
          TransactionsRoute.locationPreservingScope(
            routeFilters,
            account: currentFilter,
            group: value,
          ),
        );
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: TransactionGroupType.date,
            child: Text(l10n.groupByDate),
          ),
          PopupMenuItem(
            value: TransactionGroupType.account,
            child: Text(l10n.groupByAccount),
          ),
          PopupMenuItem(
            value: TransactionGroupType.payee,
            child: Text(l10n.groupByPayee),
          ),
          PopupMenuItem(
            value: TransactionGroupType.type,
            child: Text(l10n.groupByType),
          ),
          PopupMenuItem(
            value: TransactionGroupType.category,
            child: Text(l10n.groupByCategory),
          ),
        ];
      },
      child: Tooltip(
        message: l10n.groupBy,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.listOrdered, size: 16, color: colors.text),
              const SizedBox(width: 8),
              Text(
                l10n.groupBy,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReconciledFilterButton extends StatelessWidget {
  final ReconciledFilter currentFilter;
  final AppLocalizations l10n;
  final ValueChanged<ReconciledFilter> onSelected;

  const _ReconciledFilterButton({
    required this.currentFilter,
    required this.l10n,
    required this.onSelected,
  });

  String _label(ReconciledFilter filter) {
    return switch (filter) {
      ReconciledFilter.all => l10n.reconciledFilterAll,
      ReconciledFilter.reconciled => l10n.reconciledFilterReconciled,
      ReconciledFilter.unreconciled => l10n.reconciledFilterUnreconciled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopupMenuButton<ReconciledFilter>(
      initialValue: currentFilter,
      onSelected: onSelected,
      itemBuilder: (context) => ReconciledFilter.values
          .map(
            (filter) =>
                PopupMenuItem(value: filter, child: Text(_label(filter))),
          )
          .toList(),
      child: Tooltip(
        message: l10n.reconciledFilter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: currentFilter == ReconciledFilter.all
                ? colors.surface
                : colors.accent.acc.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentFilter == ReconciledFilter.all
                  ? colors.border
                  : colors.accent.acc.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.circleCheck, size: 16, color: colors.text),
              const SizedBox(width: 8),
              Text(
                _label(currentFilter),
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Narrows the list to rows missing bookkeeping, one gap at a time.
///
/// Each gap is picked separately because incomplete is not a single standard:
/// a ledger that never uses piggy banks is not missing one on every row.
class _MissingFieldsFilterButton extends StatelessWidget {
  final Set<TransactionField> selected;
  final AppLocalizations l10n;
  final ValueChanged<Set<TransactionField>> onChanged;

  const _MissingFieldsFilterButton({
    required this.selected,
    required this.l10n,
    required this.onChanged,
  });

  String _label(TransactionField field) {
    return switch (field) {
      TransactionField.description => l10n.description,
      TransactionField.category => l10n.category,
      TransactionField.budget => l10n.budgetLabel,
      TransactionField.tags => l10n.tags,
      TransactionField.payee => l10n.payee,
      TransactionField.notes => l10n.notes,
      TransactionField.piggyBank => l10n.piggyBank,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = selected.isNotEmpty;

    return PopupMenuButton<TransactionField>(
      onSelected: (field) {
        final next = {...selected};
        if (!next.remove(field)) next.add(field);
        onChanged(next);
      },
      itemBuilder: (context) => [
        for (final field in TransactionField.values)
          CheckedPopupMenuItem(
            value: field,
            checked: selected.contains(field),
            child: Text(_label(field)),
          ),
      ],
      child: Tooltip(
        message: l10n.missingInformation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? colors.accent.acc.withValues(alpha: 0.08)
                : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? colors.accent.acc.withValues(alpha: 0.35)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.circleHelp, size: 16, color: colors.text),
              const SizedBox(width: 8),
              Text(
                active
                    ? '${l10n.missingInformation} (${selected.length})'
                    : l10n.missingInformation,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountFilterButton extends ConsumerWidget {
  final TransactionsRouteFilters routeFilters;
  final String? currentFilter;
  final TransactionGroupType currentGroupType;
  final AppLocalizations l10n;

  const _AccountFilterButton({
    required this.routeFilters,
    required this.currentFilter,
    required this.currentGroupType,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final accountsAsync = ref.watch(accountsProvider);

    const allAccountsSentinel = '__all__';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final accounts = accountsAsync.value ?? [];
        final selected = await showAccountFilterDialog(
          context: context,
          ref: ref,
          accounts: accounts,
          currentFilter: currentFilter,
        );
        if (selected != null && context.mounted) {
          context.goPreservingSearch(
            TransactionsRoute.locationPreservingScope(
              routeFilters,
              account: selected == allAccountsSentinel ? null : selected,
              group: currentGroupType,
            ),
          );
        }
      },
      child: Tooltip(
        message: l10n.filterAccount,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.filter, size: 16, color: colors.text),
              const SizedBox(width: 8),
              Text(
                currentFilter == null ? fun.filterAccount : currentFilter!,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodFilterButton extends StatelessWidget {
  final TransactionsRouteFilters routeFilters;
  final AppLocalizations l10n;
  final LocaleFormatting format;

  const _PeriodFilterButton({
    required this.routeFilters,
    required this.l10n,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final periodLabel = routeFilters.hasCustomDateRange
        ? format.formatDateRange(
            routeFilters.from,
            routeFilters.to,
            ellipsis: l10n.dateEllipsis,
            separator: l10n.dateRangeSeparator,
          )
        : routeFilters.period.localizedLabel(l10n);

    final isExplicit =
        routeFilters.period != ExpensePeriod.all ||
        routeFilters.hasCustomDateRange;

    return PopupMenuButton<ExpensePeriod>(
      tooltip: l10n.viewPeriod,
      onSelected: (period) {
        context.goPreservingSearch(
          TransactionsRoute.location(
            account: routeFilters.account,
            accounts: routeFilters.accounts,
            group: routeFilters.group,
            category: routeFilters.category,
            period: period,
            type: routeFilters.type,
            reconcile: routeFilters.reconcile,
            defaultDashboardPeriod: routeFilters.defaultDashboardPeriod,
          ),
        );
      },
      itemBuilder: (context) => ExpensePeriod.values
          .map(
            (period) => PopupMenuItem(
              value: period,
              child: Text(period.localizedLabel(l10n)),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isExplicit
              ? colors.accent.acc.withValues(alpha: 0.1)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExplicit
                ? colors.accent.acc.withValues(alpha: 0.4)
                : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 16,
              color: isExplicit ? colors.accent.acc : colors.text,
            ),
            const SizedBox(width: 8),
            Text(
              periodLabel,
              style: TextStyle(
                color: isExplicit ? colors.accent.acc : colors.text,
                fontWeight: isExplicit ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _sumNonFutureTransactionBalance(List<Transaction> transactions) {
  return transactions
      .where((transaction) => !isFutureTransaction(transaction.date))
      .fold<double>(0.0, (sum, transaction) {
        return transaction.type == 'deposit'
            ? sum + transaction.totalAmount
            : sum - transaction.totalAmount;
      });
}

class _FireflyRefreshButton extends StatelessWidget {
  const _FireflyRefreshButton({
    required this.refreshing,
    required this.onPressed,
  });

  final bool refreshing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Tooltip(
      message: l10n.tooltipRefreshFromFirefly,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (refreshing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.text,
                    ),
                  )
                else
                  Icon(LucideIcons.refreshCw, size: 16, color: colors.text),
                const SizedBox(width: 8),
                Text(
                  l10n.refreshFromFirefly,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterBubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterBubble({
    required this.icon,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.accent.acc.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.acc.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.accent.acc),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(LucideIcons.x, size: 14, color: colors.accent.acc),
            ),
          ),
        ],
      ),
    );
  }
}

/// The balance chip in the header, which reads today by default and any other
/// day on request.
///
/// A day other than today is asked of the ledger rather than derived here:
/// Firefly counts everything dated up to it, future-dated rows included, so a
/// date ahead of today gives the balance already expected rather than a
/// forecast of it.
class _AccountBalanceChip extends ConsumerWidget {
  const _AccountBalanceChip({
    required this.accountId,
    required this.todayBalance,
    required this.currencySymbol,
    required this.format,
    required this.asOf,
    required this.onPickDate,
    required this.onClearDate,
  });

  final String? accountId;
  final double? todayBalance;
  final String? currencySymbol;
  final LocaleFormatting format;
  final DateTime? asOf;
  final VoidCallback? onPickDate;
  final VoidCallback onClearDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final symbol = currencySymbol ?? '';

    final dated = asOf == null || accountId == null
        ? null
        : ref.watch(
            accountBalanceAtDateProvider(
              AccountBalanceDateKey(accountId: accountId!, date: asOf!),
            ),
          );

    final String amountLabel;
    double? shownBalance;
    if (dated == null) {
      shownBalance = todayBalance;
      amountLabel = todayBalance != null
          ? format.formatMoney(todayBalance!, symbol)
          : l10n.notAvailable;
    } else {
      shownBalance = dated.hasValue ? dated.value : null;
      amountLabel = switch (dated) {
        AsyncData(:final value) => format.formatMoney(value, symbol),
        AsyncError() => l10n.notAvailable,
        _ => '…',
      };
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPickDate,
            child: Row(
              children: [
                Text(
                  l10n.balance,
                  style: TextStyle(color: colors.text3, fontSize: 13),
                ),
                if (asOf != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    format.formatMediumDate(asOf!),
                    style: TextStyle(color: colors.accent.acc, fontSize: 13),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  amountLabel,
                  style: TextStyle(
                    fontFamily: 'Roboto Slab',
                    fontWeight: FontWeight.w700,
                    color: shownBalance != null && shownBalance < 0
                        ? colors.danger
                        : colors.text,
                  ),
                ),
                if (onPickDate != null && asOf == null) ...[
                  const SizedBox(width: 6),
                  Icon(LucideIcons.calendar, size: 14, color: colors.text3),
                ],
              ],
            ),
          ),
          if (asOf != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: l10n.today,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onClearDate,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    LucideIcons.x,
                    size: 14,
                    color: colors.accent.acc,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
