import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../providers/data_providers.dart';
import '../providers/people_providers.dart';
import '../providers/account_classification_provider.dart';
import '../models/account.dart';
import '../providers/theme_provider.dart';
import '../providers/undo_history_provider.dart';
import '../router/accounts_route.dart';
import '../router/route_navigation.dart';
import '../router/route_query.dart';
import '../utils/search_filter.dart';
import '../utils/create_flows.dart';
import '../widgets/account_list_panel.dart';
import '../widgets/entity_screen_header.dart';
import '../widgets/firefly_refresh_button.dart';
import '../widgets/view_mode_switch.dart';
import '../widgets/show_inactive_accounts_toggle.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../l10n/fun_l10n.dart';
import '../utils/locale_formatting.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final format = ref.watch(localeFormattingProvider);
    final routeState = GoRouterState.of(context);
    final typeFilter = AccountsRoute.typeFrom(routeState);
    final expandedAccount = AccountsRoute.accountFrom(routeState);
    final showInactive = AccountsRoute.showInactiveFrom(routeState);
    final searchQuery = RouteQuery.searchFrom(routeState.uri);
    final accountsAsync = ref.watch(accountsProvider);
    final effectiveAccounts = ref.watch(ownedAccountsProvider);
    final customClassifications = ref.watch(accountClassificationProvider);

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: accountsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.errorGeneric(e.toString()))),
        data: (_) {
          final accounts = effectiveAccounts;

          final assetAccounts = accounts
              .where(
                (a) =>
                    getCategoryForAccount(a, customClassifications) ==
                    AccountCategory.asset,
              )
              .where((a) => showInactive || a.active)
              .where((a) => a.matchesSearch(searchQuery))
              .toList();

          final savingsAccounts = accounts
              .where(
                (a) =>
                    getCategoryForAccount(a, customClassifications) ==
                    AccountCategory.savings,
              )
              .where((a) => showInactive || a.active)
              .where((a) => a.matchesSearch(searchQuery))
              .toList();

          final creditCards = accounts
              .where(
                (a) =>
                    getCategoryForAccount(a, customClassifications) ==
                    AccountCategory.creditCard,
              )
              .where((a) => showInactive || a.active)
              .where((a) => a.matchesSearch(searchQuery))
              .toList();

          final investmentAccounts = accounts
              .where(
                (a) =>
                    getCategoryForAccount(a, customClassifications) ==
                    AccountCategory.investment,
              )
              .where((a) => showInactive || a.active)
              .where((a) => a.matchesSearch(searchQuery))
              .toList();

          final liabilities = accounts
              .where(
                (a) =>
                    getCategoryForAccount(a, customClassifications) ==
                    AccountCategory.liability,
              )
              .where((a) => showInactive || a.active)
              .where((a) => a.matchesSearch(searchQuery))
              .toList();

          final isAll = typeFilter == AccountTypeFilter.all;

          final showAssets = isAll
              ? assetAccounts.isNotEmpty
              : typeFilter == AccountTypeFilter.asset;
          final showSavings = isAll
              ? savingsAccounts.isNotEmpty
              : typeFilter == AccountTypeFilter.savings;
          final showCreditCards = isAll
              ? creditCards.isNotEmpty
              : typeFilter == AccountTypeFilter.creditCard;
          final showInvestment = isAll
              ? investmentAccounts.isNotEmpty
              : typeFilter == AccountTypeFilter.investment;
          final showLiabilities = isAll
              ? liabilities.isNotEmpty
              : typeFilter == AccountTypeFilter.liability;

          final hasAnyCategoryToShow =
              showAssets ||
              showSavings ||
              showCreditCards ||
              showInvestment ||
              showLiabilities;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntityScreenHeader(
                  title: fun.accountsTitle,
                  createLabel: fun.newAccount,
                  onCreate: () => openCreateAccountDialog(
                    context,
                    ref,
                    accountType: 'asset',
                  ),
                  trailing: [
                    _AccountTypeFilter(
                      current: typeFilter,
                      showInactive: showInactive,
                      fun: fun,
                    ),
                    _AccountSearchBox(
                      searchQuery: searchQuery ?? '',
                      uri: routeState.uri,
                    ),
                    ShowInactiveAccountsToggle(
                      showInactive: showInactive,
                      onToggle: () => context.goPreservingSearch(
                        AccountsRoute.location(
                          type: typeFilter,
                          showInactive: !showInactive,
                          account: expandedAccount,
                        ),
                      ),
                    ),
                    const _BalanceDateChip(),
                    const FireflyRefreshButton(),
                    const ViewModeSwitcher(),
                  ],
                ),
                if (!hasAnyCategoryToShow) ...[
                  const SizedBox(height: 24),
                  Text(l10n.noAccountsFound),
                ],
                if (showAssets) ...[
                  const SizedBox(height: 24),
                  Text(fun.assetAccounts, style: context.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  if (assetAccounts.isEmpty)
                    Text(l10n.noAccountsFound)
                  else
                    AccountListPanel(
                      accounts: assetAccounts,
                      expandedAccountName: expandedAccount,
                      format: format,
                      emptyLabel: l10n.noAccountsFound,
                      emptyTransactionsLabel: l10n.noTransactionsForAccount,
                      onToggleExpand: (account, isExpanded) =>
                          _toggleAccountExpand(
                            context,
                            typeFilter,
                            showInactive,
                            account,
                            isExpanded,
                          ),
                      onDelete: (account) =>
                          _deleteAccount(context, ref, account),
                    ),
                ],
                if (showSavings) ...[
                  const SizedBox(height: 32),
                  Text(
                    fun.savingsAccounts,
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (savingsAccounts.isEmpty)
                    Text(l10n.noAccountsFound)
                  else
                    AccountListPanel(
                      accounts: savingsAccounts,
                      expandedAccountName: expandedAccount,
                      format: format,
                      emptyLabel: l10n.noAccountsFound,
                      emptyTransactionsLabel: l10n.noTransactionsForAccount,
                      onToggleExpand: (account, isExpanded) =>
                          _toggleAccountExpand(
                            context,
                            typeFilter,
                            showInactive,
                            account,
                            isExpanded,
                          ),
                      onDelete: (account) =>
                          _deleteAccount(context, ref, account),
                    ),
                ],
                if (showCreditCards) ...[
                  const SizedBox(height: 32),
                  Text(
                    fun.creditCardAccounts,
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (creditCards.isEmpty)
                    Text(l10n.noAccountsFound)
                  else
                    AccountListPanel(
                      accounts: creditCards,
                      expandedAccountName: expandedAccount,
                      format: format,
                      emptyLabel: l10n.noAccountsFound,
                      emptyTransactionsLabel: l10n.noTransactionsForAccount,
                      onToggleExpand: (account, isExpanded) =>
                          _toggleAccountExpand(
                            context,
                            typeFilter,
                            showInactive,
                            account,
                            isExpanded,
                          ),
                      onDelete: (account) =>
                          _deleteAccount(context, ref, account),
                    ),
                ],
                if (showInvestment) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Investment Accounts',
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (investmentAccounts.isEmpty)
                    Text(l10n.noAccountsFound)
                  else
                    AccountListPanel(
                      accounts: investmentAccounts,
                      expandedAccountName: expandedAccount,
                      format: format,
                      emptyLabel: l10n.noAccountsFound,
                      emptyTransactionsLabel: l10n.noTransactionsForAccount,
                      onToggleExpand: (account, isExpanded) =>
                          _toggleAccountExpand(
                            context,
                            typeFilter,
                            showInactive,
                            account,
                            isExpanded,
                          ),
                      onDelete: (account) =>
                          _deleteAccount(context, ref, account),
                    ),
                ],
                if (showLiabilities) ...[
                  const SizedBox(height: 32),
                  Text(
                    l10n.liabilityAccounts,
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (liabilities.isEmpty)
                    Text(l10n.noAccountsFound)
                  else
                    AccountListPanel(
                      accounts: liabilities,
                      expandedAccountName: expandedAccount,
                      format: format,
                      emptyLabel: l10n.noAccountsFound,
                      emptyTransactionsLabel: l10n.noTransactionsForAccount,
                      onToggleExpand: (account, isExpanded) =>
                          _toggleAccountExpand(
                            context,
                            typeFilter,
                            showInactive,
                            account,
                            isExpanded,
                          ),
                      onDelete: (account) =>
                          _deleteAccount(context, ref, account),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleAccountExpand(
    BuildContext context,
    AccountTypeFilter typeFilter,
    bool showInactive,
    Account account,
    bool isExpanded,
  ) {
    context.goPreservingSearch(
      AccountsRoute.location(
        type: typeFilter,
        showInactive: showInactive,
        account: isExpanded ? null : account.name,
      ),
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final l10n = context.l10n;
    final confirmed = await confirmDeleteAccount(context, account);
    if (!confirmed || !context.mounted) return;

    try {
      final service = ref.read(apiServiceProvider);
      await service?.deleteAccount(account.id);
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Account deleted',
            details: 'Deleted account "${account.name}"',
            type: UndoActionType.accountDelete,
            undoPayload: {
              'name': account.name,
              'type': account.type,
              'currencyCode': account.currencyCode,
            },
            redoPayload: {'accountId': account.id},
          );
      ref.invalidate(accountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountDeleted(account.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToDeleteAccount(e.toString()))),
        );
      }
    }
  }
}

class _AccountTypeFilter extends StatelessWidget {
  final AccountTypeFilter current;
  final bool showInactive;
  final FunL10n fun;

  const _AccountTypeFilter({
    required this.current,
    required this.showInactive,
    required this.fun,
  });

  IconData _iconFor(AccountTypeFilter filter) {
    return switch (filter) {
      AccountTypeFilter.all => LucideIcons.layers,
      AccountTypeFilter.asset => LucideIcons.wallet,
      AccountTypeFilter.savings => LucideIcons.piggyBank,
      AccountTypeFilter.creditCard => LucideIcons.creditCard,
      AccountTypeFilter.investment => LucideIcons.trendingUp,
      AccountTypeFilter.liability => LucideIcons.landmark,
    };
  }

  String _labelFor(AccountTypeFilter filter, AppLocalizations l10n) {
    return switch (filter) {
      AccountTypeFilter.all => l10n.filterAllShort,
      AccountTypeFilter.asset => l10n.filterAssetsShort,
      AccountTypeFilter.savings => 'Savings',
      AccountTypeFilter.creditCard => 'Credit Cards',
      AccountTypeFilter.investment => 'Investments',
      AccountTypeFilter.liability => l10n.filterLiabilitiesShort,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = fun.l10n;
    return PopupMenuButton<AccountTypeFilter>(
      initialValue: current,
      onSelected: (value) => context.goPreservingSearch(
        AccountsRoute.location(type: value, showInactive: showInactive),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AccountTypeFilter.all,
          child: Row(
            children: [
              Icon(LucideIcons.layers, size: 16, color: colors.text3),
              const SizedBox(width: 8),
              Text(fun.allAccounts),
            ],
          ),
        ),
        PopupMenuItem(
          value: AccountTypeFilter.asset,
          child: Row(
            children: [
              Icon(LucideIcons.wallet, size: 16, color: colors.text3),
              const SizedBox(width: 8),
              Text(l10n.assetsOnly),
            ],
          ),
        ),
        PopupMenuItem(
          value: AccountTypeFilter.savings,
          child: Row(
            children: [
              Icon(LucideIcons.piggyBank, size: 16, color: colors.text3),
              const SizedBox(width: 8),
              Text(fun.savingsAccounts),
            ],
          ),
        ),
        PopupMenuItem(
          value: AccountTypeFilter.creditCard,
          child: Row(
            children: [
              Icon(LucideIcons.creditCard, size: 16, color: colors.text3),
              const SizedBox(width: 8),
              Text(fun.creditCardAccounts),
            ],
          ),
        ),
        PopupMenuItem(
          value: AccountTypeFilter.investment,
          child: Row(
            children: [
              Icon(LucideIcons.trendingUp, size: 16, color: colors.text3),
              const SizedBox(width: 8),
              const Text('Investment Accounts'),
            ],
          ),
        ),
        PopupMenuItem(
          value: AccountTypeFilter.liability,
          child: Row(
            children: [
              Icon(LucideIcons.landmark, size: 16, color: colors.text3),
              const SizedBox(width: 8),
              const Text('Loans (liabilities)'),
            ],
          ),
        ),
      ],
      child: Tooltip(
        message: l10n.filterAccount,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(_iconFor(current), size: 16, color: colors.text),
              const SizedBox(width: 8),
              Text(
                _labelFor(current, l10n),
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

class _AccountSearchBox extends ConsumerStatefulWidget {
  final String searchQuery;
  final Uri uri;

  const _AccountSearchBox({required this.searchQuery, required this.uri});

  @override
  ConsumerState<_AccountSearchBox> createState() => _AccountSearchBoxState();
}

class _AccountSearchBoxState extends ConsumerState<_AccountSearchBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _AccountSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text &&
        widget.searchQuery != oldWidget.searchQuery) {
      _controller.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    context.go(RouteQuery.withSearch(widget.uri, val));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);

    return SizedBox(
      width: 200,
      height: 36,
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        style: TextStyle(color: colors.text, fontSize: 13),
        decoration: InputDecoration(
          hintText: fun.search,
          hintStyle: TextStyle(color: colors.text3, fontSize: 13),
          prefixIcon: Icon(LucideIcons.search, size: 15, color: colors.text3),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x, size: 14, color: colors.text3),
                  onPressed: () {
                    _controller.clear();
                    _onSearchChanged('');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          filled: true,
          fillColor: colors.surface2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.accent.acc, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Picks the date every account row reports its balance for.
///
/// Defaults to the end of the current month, which is the only figure the column
/// could show before it was selectable, so the view opens exactly as it did.
class _BalanceDateChip extends ConsumerWidget {
  const _BalanceDateChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);
    final picked = ref.watch(accountBalanceDateProvider);
    final showing = ref.watch(resolvedAccountBalanceDateProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: picked == null
            ? colors.surface
            : colors.accent.acc.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: picked == null
              ? colors.border
              : colors.accent.acc.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Tooltip(
            message: l10n.tooltipBalanceDatePick,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final now = DateTime.now();
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: showing,
                  firstDate: DateTime(now.year - 10),
                  lastDate: DateTime(now.year + 10, 12, 31),
                );
                if (chosen == null) return;
                ref.read(accountBalanceDateProvider.notifier).select(chosen);
              },
              child: Row(
                children: [
                  Icon(LucideIcons.calendar, size: 14, color: colors.text3),
                  const SizedBox(width: 8),
                  Text(
                    format.formatMediumDate(showing),
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (picked != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: l10n.tooltipBalanceDateReset,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () =>
                    ref.read(accountBalanceDateProvider.notifier).reset(),
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
