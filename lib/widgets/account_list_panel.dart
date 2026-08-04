import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/account_prognosis.dart';
import '../providers/column_config_provider.dart';
import '../providers/data_providers.dart';
import '../providers/dashboard_stats_providers.dart';
import '../providers/people_providers.dart';
import '../theme/app_theme.dart';
import '../utils/locale_formatting.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/entity_header_actions.dart';
import '../widgets/entity_list_layout.dart';
import '../widgets/expandable_entity_shell.dart';
import '../widgets/resize_handle.dart';
import '../widgets/simple_charts.dart';
import '../widgets/transactions_expanded_panel.dart';
import '../router/transactions_route.dart';
import 'account_edit_dialog.dart';

Widget _inactiveAccountBadge(BuildContext context) {
  final colors = context.colors;
  final l10n = context.l10n;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: colors.text3.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      l10n.accountInactive,
      style: TextStyle(
        color: colors.text3,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget _accountBalanceAmount({
  required String tooltip,
  required String text,
  required TextStyle style,
}) {
  return Tooltip(
    message: tooltip,
    child: Text(text, style: style),
  );
}

class AccountListPanel extends ConsumerWidget {
  final List<Account> accounts;
  final String? expandedAccountName;
  final LocaleFormatting format;
  final String emptyLabel;
  final String emptyTransactionsLabel;
  final void Function(Account account, bool isExpanded) onToggleExpand;
  final Future<void> Function(Account account) onDelete;

  const AccountListPanel({
    super.key,
    required this.accounts,
    required this.expandedAccountName,
    required this.format,
    required this.emptyLabel,
    required this.emptyTransactionsLabel,
    required this.onToggleExpand,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (accounts.isEmpty) {
      return Text(emptyLabel);
    }

    final prognosis = ref.watch(accountPrognosisProvider);

    return EntityListLayout(
      gridItems: accounts
          .map(
            (acc) => AccountEntityCard(
              account: acc,
              prognosis: prognosis.forAccount(acc.id),
              isExpanded: expandedAccountName == acc.name,
              format: format,
              emptyTransactionsLabel: emptyTransactionsLabel,
              onToggleExpand: () =>
                  onToggleExpand(acc, expandedAccountName == acc.name),
              onEdit: () => showAccountEditDialog(
                context: context,
                ref: ref,
                account: acc,
              ),
              onDelete: () {
                onDelete(acc);
              },
              onReconcile: _reconcileCallback(context, acc),
            ),
          )
          .toList(),
      compactItems: accounts
          .map(
            (acc) => AccountEntityCompactRow(
              account: acc,
              prognosis: prognosis.forAccount(acc.id),
              isExpanded: expandedAccountName == acc.name,
              format: format,
              emptyTransactionsLabel: emptyTransactionsLabel,
              onToggleExpand: () =>
                  onToggleExpand(acc, expandedAccountName == acc.name),
              onEdit: () => showAccountEditDialog(
                context: context,
                ref: ref,
                account: acc,
              ),
              onDelete: () {
                onDelete(acc);
              },
              onReconcile: _reconcileCallback(context, acc),
            ),
          )
          .toList(),
      tightItems: accounts
          .map(
            (acc) => AccountEntityTightRow(
              account: acc,
              prognosis: prognosis.forAccount(acc.id),
              isExpanded: expandedAccountName == acc.name,
              format: format,
              emptyTransactionsLabel: emptyTransactionsLabel,
              onToggleExpand: () =>
                  onToggleExpand(acc, expandedAccountName == acc.name),
              onEdit: () => showAccountEditDialog(
                context: context,
                ref: ref,
                account: acc,
              ),
              onDelete: () {
                onDelete(acc);
              },
              onReconcile: _reconcileCallback(context, acc),
            ),
          )
          .toList(),
      tightHeader: const AccountTightRowsHeaderRow(),
    );
  }

  /// Reconcile action for a row, or null for accounts that cannot be
  /// balance-reconciled (non-asset or inactive). Jumps to the account's
  /// transactions filtered and pre-armed for reconciliation. Shared by the
  /// grid and compact layouts.
  VoidCallback? _reconcileCallback(BuildContext context, Account acc) {
    if (acc.type != 'asset' || !acc.active) return null;
    return () => context.go(
      TransactionsRoute.location(account: acc.name, reconcile: true),
    );
  }
}

/// Tappable reconcile entry shown in an expanded asset-account row. Displays
/// today's ledger balance for context and jumps to the account's transactions
/// in reconcile mode — the amount you check against there is the balance of
/// selected (reconciled) transactions, not this figure.
class _AccountReconcileTile extends StatelessWidget {
  const _AccountReconcileTile({
    required this.account,
    required this.currentBalance,
    required this.format,
  });

  final Account account;
  final double currentBalance;
  final LocaleFormatting format;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go(
          TransactionsRoute.location(account: account.name, reconcile: true),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.listChecks, size: 18, color: colors.text2),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reconcile,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.balance} ${format.formatMoney(currentBalance, account.currencySymbol)}',
                      style: TextStyle(color: colors.text3, fontSize: 12),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l10n.reconcileClickHint,
                      style: TextStyle(color: colors.text3, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: colors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountEntityCard extends ConsumerStatefulWidget {
  final Account account;
  final AccountPrognosis? prognosis;
  final bool isExpanded;
  final LocaleFormatting format;
  final String emptyTransactionsLabel;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReconcile;

  const AccountEntityCard({
    super.key,
    required this.account,
    required this.prognosis,
    required this.isExpanded,
    required this.format,
    required this.emptyTransactionsLabel,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
    this.onReconcile,
  });

  @override
  ConsumerState<AccountEntityCard> createState() => _AccountEntityCardState();
}

class _AccountEntityCardState extends ConsumerState<AccountEntityCard> {
  List<Transaction>? _transactions;
  bool _loadingTx = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isExpanded) _loadTransactions();
  }

  @override
  void didUpdateWidget(covariant AccountEntityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && _transactions == null && !_loadingTx) {
      _loadTransactions();
    } else if (!widget.isExpanded) {
      _transactions = null;
      _loadingTx = false;
      _loadError = null;
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loadingTx = true;
      _loadError = null;
    });
    try {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        // The expanded panel previews at most 20 rows; fetch only one page
        // instead of the account's entire history.
        final page = await service.getAccountTransactionsPage(
          widget.account.id,
          page: 1,
          limit: 20,
        );
        if (mounted) {
          setState(() {
            _transactions = page.transactions;
            _loadingTx = false;
            _loadError = null;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingTx = false;
          _transactions = null;
          _loadError = context.l10n.errorLoadingData('$error');
        });
      }
    }
  }

  void _patchTransaction(Transaction updated) {
    final txs = _transactions;
    if (txs == null) return;
    final index = txs.indexWhere((transaction) => transaction.id == updated.id);
    if (index == -1) return;
    setState(() {
      _transactions = List<Transaction>.from(txs)..[index] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final acc = widget.account;
    final currentBalance =
        widget.prognosis?.currentBalance ?? acc.currentBalance;
    final isPositive = currentBalance >= 0;
    final currentBalanceText = widget.format.formatMoney(
      currentBalance,
      acc.currencySymbol,
    );
    final endOfMonthText = widget.prognosis == null
        ? null
        : widget.format.formatMoney(
            widget.prognosis!.endOfMonth.expected,
            acc.currencySymbol,
          );

    return ExpandableEntityCard(
      expanded: widget.isExpanded,
      onToggleExpand: widget.onToggleExpand,
      width: 320,
      expandedChild: TransactionsExpandedPanel(
        loading: _loadingTx,
        transactions: _transactions,
        errorMessage: _loadError,
        emptyLabel: widget.emptyTransactionsLabel,
        filterAccount: acc.name,
        onTransactionMutated: _loadTransactions,
        onTransactionPatched: _patchTransaction,
        headerWidget: (acc.type == 'asset' && acc.active)
            ? _AccountReconcileTile(
                account: acc,
                currentBalance: currentBalance,
                format: widget.format,
              )
            : null,
      ),
      header: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.landmark, color: colors.iconFg),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        localizedAccountRole(l10n, acc.role),
                        style: TextStyle(color: colors.text3, fontSize: 12),
                      ),
                      () {
                        final peopleConfig = ref.watch(peopleSettingsProvider);
                        final ownership =
                            peopleConfig.accountOwnerships[acc.id];
                        final assignedPeople = peopleConfig.getOwnersForAccount(
                          acc.id,
                        );
                        final isShared = assignedPeople.length > 1;

                        if (assignedPeople.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: assignedPeople.map((person) {
                              final share = ownership?.personShares[person.id];
                              final label = (share != null && isShared)
                                  ? '${person.name} ${(share * 100).toStringAsFixed(0)}%'
                                  : person.name;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: person.color.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: person.color.withValues(alpha: 0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: person.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: person.color,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }(),
                    ],
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: EntityHeaderActions(
                    leading: [if (!acc.active) _inactiveAccountBadge(context)],
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                    onReconcile: widget.onReconcile,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _accountBalanceAmount(
              tooltip: l10n.tooltipAccountCurrentBalance,
              text: currentBalanceText,
              style: TextStyle(
                fontFamily: 'Roboto Slab',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isPositive ? colors.text : colors.danger,
              ),
            ),
            if (endOfMonthText != null) ...[
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${l10n.projectedEndOfMonth}: ',
                    style: TextStyle(
                      color: widget.prognosis!.showWarning
                          ? colors.warning
                          : colors.text3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _accountBalanceAmount(
                    tooltip: l10n.tooltipAccountEndOfMonthBalance,
                    text: endOfMonthText,
                    style: TextStyle(
                      color: widget.prognosis!.showWarning
                          ? colors.warning
                          : colors.text3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SimpleSparkline(
              values: _balanceSparkline(acc.name, currentBalance),
              color: isPositive ? colors.success : colors.danger,
              width: 272,
              height: 40,
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [ExpandChevron(expanded: widget.isExpanded)],
            ),
          ],
        ),
      ),
    );
  }

  List<double> _balanceSparkline(String accountName, double currentBalance) {
    final histories = ref.watch(accountBalanceHistoriesProvider).value;
    final history = [
      ...(histories?[accountName] ?? [currentBalance, currentBalance]),
    ];
    final prognosis = widget.prognosis;
    if (prognosis != null) {
      history.add(prognosis.endOfMonth.expected);
    }
    return history;
  }
}

class AccountEntityCompactRow extends ConsumerStatefulWidget {
  final Account account;
  final AccountPrognosis? prognosis;
  final bool isExpanded;
  final LocaleFormatting format;
  final String emptyTransactionsLabel;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReconcile;

  const AccountEntityCompactRow({
    super.key,
    required this.account,
    required this.prognosis,
    required this.isExpanded,
    required this.format,
    required this.emptyTransactionsLabel,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
    this.onReconcile,
  });

  @override
  ConsumerState<AccountEntityCompactRow> createState() =>
      _AccountEntityCompactRowState();
}

class _AccountEntityCompactRowState
    extends ConsumerState<AccountEntityCompactRow> {
  List<Transaction>? _transactions;
  bool _loadingTx = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isExpanded) _loadTransactions();
  }

  @override
  void didUpdateWidget(covariant AccountEntityCompactRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && _transactions == null && !_loadingTx) {
      _loadTransactions();
    } else if (!widget.isExpanded) {
      _transactions = null;
      _loadingTx = false;
      _loadError = null;
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loadingTx = true;
      _loadError = null;
    });
    try {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        // The expanded panel previews at most 20 rows; fetch only one page
        // instead of the account's entire history.
        final page = await service.getAccountTransactionsPage(
          widget.account.id,
          page: 1,
          limit: 20,
        );
        if (mounted) {
          setState(() {
            _transactions = page.transactions;
            _loadingTx = false;
            _loadError = null;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingTx = false;
          _transactions = null;
          _loadError = context.l10n.errorLoadingData('$error');
        });
      }
    }
  }

  void _patchTransaction(Transaction updated) {
    final txs = _transactions;
    if (txs == null) return;
    final index = txs.indexWhere((transaction) => transaction.id == updated.id);
    if (index == -1) return;
    setState(() {
      _transactions = List<Transaction>.from(txs)..[index] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final acc = widget.account;
    final currentBalance =
        widget.prognosis?.currentBalance ?? acc.currentBalance;
    final isPositive = currentBalance >= 0;
    final currentBalanceText = widget.format.formatMoney(
      currentBalance,
      acc.currencySymbol,
    );
    final endOfMonthText = widget.prognosis == null
        ? null
        : widget.format.formatMoney(
            widget.prognosis!.endOfMonth.expected,
            acc.currencySymbol,
          );

    return ExpandableEntityCompactRow(
      expanded: widget.isExpanded,
      onToggleExpand: widget.onToggleExpand,
      expandedChild: TransactionsExpandedPanel(
        loading: _loadingTx,
        transactions: _transactions,
        errorMessage: _loadError,
        emptyLabel: widget.emptyTransactionsLabel,
        filterAccount: acc.name,
        onTransactionMutated: _loadTransactions,
        onTransactionPatched: _patchTransaction,
        headerWidget: (acc.type == 'asset' && acc.active)
            ? _AccountReconcileTile(
                account: acc,
                currentBalance: currentBalance,
                format: widget.format,
              )
            : null,
      ),
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(LucideIcons.landmark, color: colors.text2),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        localizedAccountRole(l10n, acc.role),
                        style: TextStyle(color: colors.text3),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _accountBalanceAmount(
                          tooltip: l10n.tooltipAccountCurrentBalance,
                          text: currentBalanceText,
                          style: TextStyle(
                            fontFamily: 'Roboto Slab',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isPositive ? colors.text : colors.danger,
                          ),
                        ),
                        if (endOfMonthText != null) ...[
                          const SizedBox(width: 12),
                          _accountBalanceAmount(
                            tooltip: l10n.tooltipAccountEndOfMonthBalance,
                            text: endOfMonthText,
                            style: TextStyle(
                              fontFamily: 'Roboto Slab',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.prognosis!.showWarning
                                  ? colors.warning
                                  : colors.text3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                EntityHeaderActions(
                  leading: [if (!acc.active) _inactiveAccountBadge(context)],
                  iconSize: 16,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                  onReconcile: widget.onReconcile,
                ),
                const SizedBox(width: 4),
                ExpandChevron(expanded: widget.isExpanded, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AccountTightRowsHeaderRow extends ConsumerStatefulWidget {
  const AccountTightRowsHeaderRow({super.key});

  @override
  ConsumerState<AccountTightRowsHeaderRow> createState() =>
      _AccountTightRowsHeaderRowState();
}

class _AccountTightRowsHeaderRowState
    extends ConsumerState<AccountTightRowsHeaderRow> {
  // Track which column index is currently being dragged for reorder.
  int? _draggingIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final config = ref.watch(accountColumnConfigProvider);
    final notifier = ref.read(accountColumnConfigProvider.notifier);

    Widget columnLabel(AccountColumn col) {
      return switch (col) {
        AccountColumn.account => Row(
          children: [
            Icon(LucideIcons.landmark, size: 12, color: colors.text3),
            const SizedBox(width: 4),
            Text(
              l10n.filterAccount,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.text3,
              ),
            ),
          ],
        ),
        AccountColumn.role => Row(
          children: [
            Icon(LucideIcons.shapes, size: 12, color: colors.text3),
            const SizedBox(width: 4),
            Text(
              'Role',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.text3,
              ),
            ),
          ],
        ),
        AccountColumn.balance => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(LucideIcons.wallet, size: 12, color: colors.text3),
            const SizedBox(width: 4),
            Text(
              l10n.balance,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.text3,
              ),
            ),
          ],
        ),
        AccountColumn.endOfMonth => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(LucideIcons.calendar, size: 12, color: colors.text3),
            const SizedBox(width: 4),
            Text(
              'End of Month',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.text3,
              ),
            ),
          ],
        ),
      };
    }

    final columns = config.order;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Row(
          children: [
            for (int i = 0; i < columns.length; i++) ...[
              // ── Draggable column header ──────────────────────────
              DragTarget<int>(
                onWillAcceptWithDetails: (details) => details.data != i,
                onAcceptWithDetails: (details) {
                  notifier.reorderColumn(details.data, i);
                  setState(() => _draggingIndex = null);
                },
                builder: (context, candidateData, rejectedData) {
                  final isDropTarget =
                      candidateData.isNotEmpty && candidateData.first != i;
                  final col = columns[i];
                  final width = config.widths[col]!;
                  return SizedBox(
                    width: width,
                    height: 36,
                    child: Stack(
                      children: [
                        // Column label – drag to reorder
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          right: 12, // leave room for resize handle
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              color: isDropTarget
                                  ? colors.surface2.withValues(alpha: 0.8)
                                  : Colors.transparent,
                              border: isDropTarget
                                  ? Border(
                                      left: BorderSide(
                                        color: colors.text2,
                                        width: 2,
                                      ),
                                    )
                                  : null,
                            ),
                            alignment:
                                (col == AccountColumn.balance ||
                                    col == AccountColumn.endOfMonth)
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Draggable<int>(
                                data: i,
                                feedback: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(6),
                                  color: colors.surface2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: columnLabel(col),
                                  ),
                                ),
                                onDragStarted: () =>
                                    setState(() => _draggingIndex = i),
                                onDragEnd: (_) =>
                                    setState(() => _draggingIndex = null),
                                child: Opacity(
                                  opacity: _draggingIndex == i ? 0.3 : 1.0,
                                  child: columnLabel(col),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Resize handle on the right edge
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 12,
                          child: ResizeHandle(
                            onDrag: (dx) => notifier.resizeColumn(col, dx),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const Spacer(),
            const SizedBox(width: AccountColumnConfig.actionWidth),
          ],
        ),
      ),
    );
  }
}

class AccountEntityTightRow extends ConsumerStatefulWidget {
  final Account account;
  final AccountPrognosis? prognosis;
  final bool isExpanded;
  final LocaleFormatting format;
  final String emptyTransactionsLabel;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReconcile;

  const AccountEntityTightRow({
    super.key,
    required this.account,
    required this.prognosis,
    required this.isExpanded,
    required this.format,
    required this.emptyTransactionsLabel,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
    this.onReconcile,
  });

  @override
  ConsumerState<AccountEntityTightRow> createState() =>
      _AccountEntityTightRowState();
}

class _AccountEntityTightRowState extends ConsumerState<AccountEntityTightRow> {
  List<Transaction>? _transactions;
  bool _loadingTx = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isExpanded) _loadTransactions();
  }

  @override
  void didUpdateWidget(covariant AccountEntityTightRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && _transactions == null && !_loadingTx) {
      _loadTransactions();
    } else if (!widget.isExpanded) {
      _transactions = null;
      _loadingTx = false;
      _loadError = null;
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loadingTx = true;
      _loadError = null;
    });
    try {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        final page = await service.getAccountTransactionsPage(
          widget.account.id,
          page: 1,
          limit: 20,
        );
        if (mounted) {
          setState(() {
            _transactions = page.transactions;
            _loadingTx = false;
            _loadError = null;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingTx = false;
          _transactions = null;
          _loadError = context.l10n.errorLoadingData('$error');
        });
      }
    }
  }

  void _patchTransaction(Transaction updated) {
    final txs = _transactions;
    if (txs == null) return;
    final index = txs.indexWhere((transaction) => transaction.id == updated.id);
    if (index == -1) return;
    setState(() {
      _transactions = List<Transaction>.from(txs)..[index] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final acc = widget.account;
    final currentBalance =
        widget.prognosis?.currentBalance ?? acc.currentBalance;
    final isPositive = currentBalance >= 0;
    final currentBalanceText = widget.format.formatMoney(
      currentBalance,
      acc.currencySymbol,
    );
    final endOfMonthText = widget.prognosis == null
        ? null
        : widget.format.formatMoney(
            widget.prognosis!.endOfMonth.expected,
            acc.currencySymbol,
          );

    return ExpandableEntityCompactRow(
      expanded: widget.isExpanded,
      onToggleExpand: widget.onToggleExpand,
      expandedChild: TransactionsExpandedPanel(
        loading: _loadingTx,
        transactions: _transactions,
        errorMessage: _loadError,
        emptyLabel: widget.emptyTransactionsLabel,
        filterAccount: acc.name,
        onTransactionMutated: _loadTransactions,
        onTransactionPatched: _patchTransaction,
        headerWidget: (acc.type == 'asset' && acc.active)
            ? _AccountReconcileTile(
                account: acc,
                currentBalance: currentBalance,
                format: widget.format,
              )
            : null,
      ),
      header: Consumer(
        builder: (context, ref, _) {
          final config = ref.watch(accountColumnConfigProvider);

          Widget cellForColumn(AccountColumn col) {
            switch (col) {
              case AccountColumn.account:
                return Row(
                  children: [
                    Icon(LucideIcons.landmark, size: 14, color: colors.text2),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        acc.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              case AccountColumn.role:
                return Text(
                  localizedAccountRole(l10n, acc.role),
                  style: TextStyle(color: colors.text3, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                );
              case AccountColumn.balance:
                return Align(
                  alignment: Alignment.centerRight,
                  child: _accountBalanceAmount(
                    tooltip: l10n.tooltipAccountCurrentBalance,
                    text: currentBalanceText,
                    style: TextStyle(
                      fontFamily: 'Roboto Slab',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isPositive ? colors.text : colors.danger,
                    ),
                  ),
                );
              case AccountColumn.endOfMonth:
                return Align(
                  alignment: Alignment.centerRight,
                  child: endOfMonthText != null
                      ? _accountBalanceAmount(
                          tooltip: l10n.tooltipAccountEndOfMonthBalance,
                          text: endOfMonthText,
                          style: TextStyle(
                            fontFamily: 'Roboto Slab',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.prognosis!.showWarning
                                ? colors.warning
                                : colors.text3,
                          ),
                        )
                      : const SizedBox.shrink(),
                );
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                for (final col in config.order)
                  SizedBox(
                    width: config.widths[col],
                    child: cellForColumn(col),
                  ),
                const Spacer(),
                SizedBox(
                  width: AccountColumnConfig.actionWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      EntityHeaderActions(
                        leading: [
                          if (!acc.active) _inactiveAccountBadge(context),
                        ],
                        iconSize: 14,
                        onEdit: widget.onEdit,
                        onDelete: widget.onDelete,
                        onReconcile: widget.onReconcile,
                      ),
                      const SizedBox(width: 4),
                      ExpandChevron(expanded: widget.isExpanded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<bool> confirmDeleteAccount(BuildContext context, Account account) {
  return showConfirmationDialog(
    context: context,
    title: context.l10n.deleteAccount,
    message: context.l10n.deleteAccountConfirmBody(account.name),
    confirmLabel: context.l10n.delete,
  ).then((value) => value == true);
}
