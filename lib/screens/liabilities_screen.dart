import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/theme_provider.dart';
import '../router/liabilities_route.dart';
import '../router/route_navigation.dart';
import '../router/route_query.dart';
import '../utils/create_flows.dart';
import '../widgets/account_list_panel.dart';
import '../widgets/entity_screen_header.dart';
import '../widgets/show_inactive_accounts_toggle.dart';
import '../l10n/l10n_extensions.dart';
import '../models/account.dart';
import '../providers/account_classification_provider.dart';
import '../providers/data_providers.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/locale_formatting.dart';
import '../utils/search_filter.dart';

class LiabilitiesScreen extends ConsumerWidget {
  const LiabilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final format = ref.watch(localeFormattingProvider);
    final routeState = GoRouterState.of(context);
    final expandedAccount = LiabilitiesRoute.accountFrom(routeState);
    final showInactive = LiabilitiesRoute.showInactiveFrom(routeState);
    final searchQuery = RouteQuery.searchFrom(routeState.uri);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: accountsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.errorGeneric(e.toString()))),
        data: (accounts) {
          final customClassifications = ref.watch(
            accountClassificationProvider,
          );
          final liabilities = accounts
              .where(
                (a) =>
                    a.type == 'liability' ||
                    getCategoryForAccount(a, customClassifications) ==
                        AccountCategory.liability ||
                    getCategoryForAccount(a, customClassifications) ==
                        AccountCategory.creditCard,
              )
              .where((a) => showInactive || a.active)
              .where((a) => a.matchesSearch(searchQuery))
              .toList();

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntityScreenHeader(
                  title: fun.liabilitiesTitle,
                  createLabel: fun.newLiability,
                  onCreate: () => openCreateAccountDialog(
                    context,
                    ref,
                    accountType: 'liability',
                  ),
                  trailing: [
                    ShowInactiveAccountsToggle(
                      showInactive: showInactive,
                      onToggle: () => context.goPreservingSearch(
                        LiabilitiesRoute.location(
                          showInactive: !showInactive,
                          account: expandedAccount,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AccountListPanel(
                  accounts: liabilities,
                  expandedAccountName: expandedAccount,
                  format: format,
                  emptyLabel: l10n.noLiabilitiesFound,
                  emptyTransactionsLabel: l10n.noTransactionsForAccount,
                  onToggleExpand: (account, isExpanded) {
                    context.goPreservingSearch(
                      LiabilitiesRoute.location(
                        showInactive: showInactive,
                        account: isExpanded ? null : account.name,
                      ),
                    );
                  },
                  onDelete: (account) => _deleteAccount(context, ref, account),
                ),
              ],
            ),
          );
        },
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
            title: 'Liability deleted',
            details: 'Deleted liability "${account.name}"',
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
