import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/column_config_provider.dart';
import '../providers/data_providers.dart';
import '../providers/paginated_transactions_provider.dart';
import '../providers/view_mode_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/tight_rows_columns_provider.dart';
import '../providers/transaction_list_refresh.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/balance_check_selection.dart';
import '../utils/display_labels.dart';
import '../utils/locale_formatting.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/entity_header_actions.dart';
import '../widgets/expandable_entity_shell.dart';
import '../widgets/fun_decorated_surface.dart';
import '../widgets/resize_handle.dart';
import '../widgets/selection_check_control.dart';
import '../widgets/split_transaction_rows.dart';
import '../widgets/transaction_edit_panel.dart';

export '../providers/transaction_list_refresh.dart'
    show refreshTransactionLists;

/// Builds a create payload identical to [source] but dated today.
Transaction transactionForDuplicate(Transaction source) {
  final today = DateTime.now();

  Transaction withToday(Transaction transaction) {
    return transaction.copyWith(
      date: today,
      splits: const [],
      reconciled: false,
    );
  }

  final splits = source.resolvedSplits();
  if (splits.length > 1) {
    final duplicated = splits.map(withToday).toList();
    return duplicated.first.copyWith(
      splits: duplicated,
      groupTitle: source.groupTitle,
    );
  }

  return source.copyWith(date: today, splits: const [], reconciled: false);
}

Map<String, Object?> transactionUndoPayload(Transaction transaction) {
  return {
    'id': transaction.id,
    'type': transaction.type,
    'date': transaction.date.toIso8601String(),
    'amount': transaction.totalAmount,
    'description': transaction.description,
    'sourceName': transaction.sourceName,
    'destinationName': transaction.destinationName,
    'categoryName': transaction.categoryName,
    'currencySymbol': transaction.currencySymbol,
    'currencyCode': transaction.currencyCode,
    'foreignAmount': transaction.foreignAmount,
    'foreignCurrencySymbol': transaction.foreignCurrencySymbol,
    'foreignCurrencyCode': transaction.foreignCurrencyCode,
    'sourceId': transaction.sourceId,
    'destinationId': transaction.destinationId,
    'categoryId': transaction.categoryId,
    'budgetId': transaction.budgetId,
    'budgetName': transaction.budgetName,
    'notes': transaction.notes,
    'tags': transaction.tags,
    'billId': transaction.billId,
    'billName': transaction.billName,
    'piggyBankId': transaction.piggyBankId,
    'piggyBankName': transaction.piggyBankName,
    'interestDate': transaction.interestDate?.toIso8601String(),
    'groupTitle': transaction.groupTitle,
    'reconciled': transaction.reconciled,
  };
}

Future<void> duplicateTransactionEntity(
  BuildContext context,
  WidgetRef ref,
  String? filterAccount,
  Transaction transaction, {
  Future<void> Function()? onMutated,
}) async {
  final l10n = context.l10n;
  try {
    final service = ref.read(apiServiceProvider);
    final duplicated = await service?.createTransaction(
      transactionForDuplicate(transaction),
    );
    if (duplicated != null) {
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Transaction duplicated',
            details: 'Duplicated transaction "${transaction.description}"',
            type: UndoActionType.transactionCreate,
            undoPayload: {'transactionId': duplicated.id},
            redoPayload: transactionUndoPayload(duplicated),
          );
    }
    await refreshTransactionLists(ref, filterAccount, upsert: duplicated);
    await onMutated?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.transactionDuplicated)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failedToDuplicateTransaction(e.toString())),
        ),
      );
    }
  }
}

Future<void> toggleTransactionReconciled(
  BuildContext context,
  WidgetRef ref,
  String? filterAccount,
  Transaction transaction, {
  required bool reconciled,
  void Function(Transaction updated)? onPatched,
}) async {
  final l10n = context.l10n;
  final service = ref.read(apiServiceProvider);
  if (service == null) return;

  final updated = transaction.withReconciled(reconciled);
  final paginated = ref.read(
    paginatedTransactionsProvider(filterAccount).notifier,
  );
  paginated.patchTransaction(updated);
  onPatched?.call(updated);

  try {
    final saved = await service.updateTransaction(updated);
    await refreshTransactionLists(ref, filterAccount, upsert: saved);
    ref
        .read(undoHistoryProvider.notifier)
        .record(
          title: reconciled
              ? 'Transaction reconciled'
              : 'Transaction unreconciled',
          details:
              '${reconciled ? 'Reconciled' : 'Unreconciled'} "${transaction.description}"',
          type: UndoActionType.transactionUpdate,
          undoPayload: transactionUndoPayload(transaction),
          redoPayload: transactionUndoPayload(updated),
        );
  } catch (e) {
    paginated.patchTransaction(transaction);
    onPatched?.call(transaction);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failedToUpdateReconciliation(e.toString())),
        ),
      );
    }
  }
}

Future<void> saveTransactionEntity(
  BuildContext context,
  WidgetRef ref,
  String? filterAccount,
  Transaction previous,
  Transaction updated,
) async {
  final l10n = context.l10n;
  try {
    final service = ref.read(apiServiceProvider);
    final saved = await service?.updateTransaction(updated);
    ref
        .read(undoHistoryProvider.notifier)
        .record(
          title: 'Transaction updated',
          details: 'Updated transaction "${updated.description}"',
          type: UndoActionType.transactionUpdate,
          undoPayload: transactionUndoPayload(previous),
          redoPayload: transactionUndoPayload(saved ?? updated),
        );
    await refreshTransactionLists(ref, filterAccount, upsert: saved);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.transactionSaved)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToSaveTransaction(e.toString()))),
      );
    }
    rethrow;
  }
}

Future<void> deleteTransactionEntity(
  BuildContext context,
  WidgetRef ref,
  String? filterAccount,
  Transaction transaction, {
  Future<void> Function()? onMutated,
}) async {
  final l10n = context.l10n;
  final confirmed = await showConfirmationDialog(
    context: context,
    title: l10n.deleteTransaction,
    message: l10n.deleteTransactionConfirmBody(transaction.description),
    confirmLabel: l10n.delete,
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final service = ref.read(apiServiceProvider);
    if (service != null) {
      await service.deleteTransaction(transaction.id);
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Transaction deleted',
            details: 'Deleted transaction "${transaction.description}"',
            type: UndoActionType.transactionDelete,
            undoPayload: transactionUndoPayload(transaction),
            redoPayload: {'transactionId': transaction.id},
          );
    }
    await refreshTransactionLists(
      ref,
      filterAccount,
      remove: service != null ? transaction : null,
    );
    await onMutated?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.transactionDeleted)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToDeleteTransaction(e.toString()))),
      );
    }
  }
}

/// Renders transactions in grid or compact list layout using shared entity shells.
class TransactionEntityList extends ConsumerWidget {
  final List<Transaction> transactions;
  final String? filterAccount;
  final Future<void> Function()? onTransactionMutated;
  final void Function(Transaction updated)? onTransactionPatched;
  final BalanceCheckSelection? balanceCheckSelection;

  const TransactionEntityList({
    super.key,
    required this.transactions,
    this.filterAccount,
    this.onTransactionMutated,
    this.onTransactionPatched,
    this.balanceCheckSelection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final viewMode = ref.watch(viewModeProvider);

    if (viewMode == ViewMode.compact) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          separatorBuilder: (context, index) =>
              Divider(color: colors.border, height: 1),
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return TransactionEntityCompactRow(
              key: ValueKey(transaction.id),
              transaction: transaction,
              filterAccount: filterAccount,
              onTransactionMutated: onTransactionMutated,
              onTransactionPatched: onTransactionPatched,
              balanceCheckSelection: balanceCheckSelection,
            );
          },
        ),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final transaction in transactions)
          TransactionEntityCard(
            key: ValueKey(transaction.id),
            transaction: transaction,
            filterAccount: filterAccount,
            onTransactionMutated: onTransactionMutated,
            onTransactionPatched: onTransactionPatched,
            balanceCheckSelection: balanceCheckSelection,
          ),
      ],
    );
  }
}

class TransactionEntityCard extends ConsumerStatefulWidget {
  final Transaction transaction;
  final String? filterAccount;
  final Future<void> Function()? onTransactionMutated;
  final void Function(Transaction updated)? onTransactionPatched;
  final BalanceCheckSelection? balanceCheckSelection;

  const TransactionEntityCard({
    super.key,
    required this.transaction,
    this.filterAccount,
    this.onTransactionMutated,
    this.onTransactionPatched,
    this.balanceCheckSelection,
  });

  @override
  ConsumerState<TransactionEntityCard> createState() =>
      _TransactionEntityCardState();
}

class _TransactionEntityCardState extends ConsumerState<TransactionEntityCard> {
  bool _expanded = false;
  bool _splitsExpanded = false;

  @override
  void didUpdateWidget(covariant TransactionEntityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.id != widget.transaction.id) {
      if (_expanded) _expanded = false;
      if (_splitsExpanded) _splitsExpanded = false;
    }
  }

  void _toggleExpand() {
    setState(() {
      if (widget.transaction.isSplitGroup) {
        _splitsExpanded = !_splitsExpanded;
      } else {
        _expanded = !_expanded;
      }
    });
  }

  void _openEdit() => setState(() => _expanded = true);

  Future<void> _delete() async {
    await deleteTransactionEntity(
      context,
      ref,
      widget.filterAccount,
      widget.transaction,
      onMutated: widget.onTransactionMutated,
    );
    if (mounted) {
      setState(() {
        _expanded = false;
        _splitsExpanded = false;
      });
    }
  }

  Future<void> _duplicate() async {
    await duplicateTransactionEntity(
      context,
      ref,
      widget.filterAccount,
      widget.transaction,
      onMutated: widget.onTransactionMutated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final format = context.format;
    final t = widget.transaction;
    final signedAmount = signedListAmount(t, accountName: widget.filterAccount);
    final isIncome = signedAmount >= 0;
    final displayAmount = signedAmount.abs();

    return FunDecoratedSurface(
      decorationKey: 'txn-${t.id}',
      child: ExpandableEntityCard(
        expanded: _splitsExpanded || _expanded,
        onToggleExpand: _toggleExpand,
        expandedChild: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (t.isSplitGroup && _splitsExpanded)
              SplitTransactionChildList(transaction: t),
            if (_expanded)
              TransactionEditPanel(
                key: ValueKey('edit-${t.id}'),
                transaction: t,
                onCancel: () => setState(() => _expanded = false),
                onSave: (updated) async {
                  await saveTransactionEntity(
                    context,
                    ref,
                    widget.filterAccount,
                    t,
                    updated,
                  );
                  if (mounted) setState(() => _expanded = false);
                },
              ),
          ],
        ),
        header: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TransactionTypeIcon(
                    isIncome: isIncome,
                    size: 28,
                    iconSize: 14,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.displayTitle(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (t.isSplitGroup) ...[
                    const SizedBox(width: 8),
                    SplitCountBadge(count: t.splits.length),
                  ],
                  const SizedBox(width: 8),
                  _TransactionTypeBadge(isIncome: isIncome),
                  EntityHeaderActions(
                    onEdit: _openEdit,
                    onDuplicate: _duplicate,
                    onDelete: _delete,
                  ),
                  const SizedBox(width: 4),
                  _TransactionReconciledToggle(
                    transaction: t,
                    filterAccount: widget.filterAccount,
                    onPatched: widget.onTransactionPatched,
                    balanceCheckSelection: widget.balanceCheckSelection,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.transactionDateCategory(
                  t.displayCategorySummary(l10n),
                  format.formatMediumDate(t.date),
                ),
                style: TextStyle(color: colors.text3, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.amount,
                          style: TextStyle(color: colors.text3, fontSize: 12),
                        ),
                        Text(
                          format.formatSignedMoney(
                            isIncome ? displayAmount : -displayAmount,
                            t.currencySymbol,
                          ),
                          style: TextStyle(
                            fontFamily: 'Roboto Slab',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isIncome ? colors.success : colors.text,
                          ),
                        ),
                        if (t.foreignAmount != null &&
                            t.foreignCurrencySymbol != null)
                          Text(
                            l10n.foreignAmount(
                              format.formatSignedMoney(
                                isIncome ? t.foreignAmount! : -t.foreignAmount!,
                                t.foreignCurrencySymbol!,
                              ),
                            ),
                            style: TextStyle(
                              color: colors.text3,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fun.accounts,
                          style: TextStyle(color: colors.text3, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${t.sourceName} → ${t.destinationName}',
                          style: TextStyle(
                            color: colors.text2,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        ExpandChevron(
                          expanded: t.isSplitGroup
                              ? _splitsExpanded
                              : _expanded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionEntityCompactRow extends ConsumerStatefulWidget {
  final Transaction transaction;
  final String? filterAccount;
  final Future<void> Function()? onTransactionMutated;
  final void Function(Transaction updated)? onTransactionPatched;
  final BalanceCheckSelection? balanceCheckSelection;

  const TransactionEntityCompactRow({
    super.key,
    required this.transaction,
    this.filterAccount,
    this.onTransactionMutated,
    this.onTransactionPatched,
    this.balanceCheckSelection,
  });

  @override
  ConsumerState<TransactionEntityCompactRow> createState() =>
      _TransactionEntityCompactRowState();
}

class _TransactionEntityCompactRowState
    extends ConsumerState<TransactionEntityCompactRow> {
  bool _expanded = false;
  bool _splitsExpanded = false;

  @override
  void didUpdateWidget(covariant TransactionEntityCompactRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.id != widget.transaction.id) {
      if (_expanded) _expanded = false;
      if (_splitsExpanded) _splitsExpanded = false;
    }
  }

  void _toggleExpand() {
    setState(() {
      if (widget.transaction.isSplitGroup) {
        _splitsExpanded = !_splitsExpanded;
      } else {
        _expanded = !_expanded;
      }
    });
  }

  void _openEdit() => setState(() => _expanded = true);

  Future<void> _delete() async {
    await deleteTransactionEntity(
      context,
      ref,
      widget.filterAccount,
      widget.transaction,
      onMutated: widget.onTransactionMutated,
    );
    if (mounted) {
      setState(() {
        _expanded = false;
        _splitsExpanded = false;
      });
    }
  }

  Future<void> _duplicate() async {
    await duplicateTransactionEntity(
      context,
      ref,
      widget.filterAccount,
      widget.transaction,
      onMutated: widget.onTransactionMutated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = context.format;
    final t = widget.transaction;
    final signedAmount = signedListAmount(t, accountName: widget.filterAccount);
    final isIncome = signedAmount >= 0;
    final displayAmount = signedAmount.abs();

    return FunDecoratedSurface(
      decorationKey: 'txn-row-${t.id}',
      borderRadius: BorderRadius.zero,
      compact: true,
      child: ExpandableEntityCompactRow(
        expanded: _splitsExpanded || _expanded,
        onToggleExpand: _toggleExpand,
        expandedChild: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (t.isSplitGroup && _splitsExpanded)
              SplitTransactionChildList(transaction: t, compact: true),
            if (_expanded)
              TransactionEditPanel(
                key: ValueKey('edit-${t.id}'),
                transaction: t,
                onCancel: () => setState(() => _expanded = false),
                onSave: (updated) async {
                  await saveTransactionEntity(
                    context,
                    ref,
                    widget.filterAccount,
                    t,
                    updated,
                  );
                  if (mounted) setState(() => _expanded = false);
                },
              ),
          ],
        ),
        header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  _TransactionTypeIcon(
                    isIncome: isIncome,
                    size: 24,
                    iconSize: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.displayTitle(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (t.isSplitGroup) ...[
                    const SizedBox(width: 6),
                    SplitCountBadge(count: t.splits.length),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    format.formatSignedMoney(
                      isIncome ? displayAmount : -displayAmount,
                      t.currencySymbol,
                    ),
                    style: TextStyle(
                      fontFamily: 'Roboto Slab',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isIncome ? colors.success : colors.text,
                    ),
                  ),
                  const SizedBox(width: 4),
                  EntityHeaderActions(
                    iconSize: 16,
                    onEdit: _openEdit,
                    onDuplicate: _duplicate,
                    onDelete: _delete,
                  ),
                  const SizedBox(width: 4),
                  // Selection only via this control — row tap keeps expand/collapse
                  // so browsing does not accidentally exclude reconciled journals.
                  _TransactionReconciledToggle(
                    transaction: t,
                    filterAccount: widget.filterAccount,
                    onPatched: widget.onTransactionPatched,
                    balanceCheckSelection: widget.balanceCheckSelection,
                  ),
                  const SizedBox(width: 4),
                  ExpandChevron(
                    expanded: t.isSplitGroup ? _splitsExpanded : _expanded,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 36),
                  Expanded(
                    child: Text(
                      l10n.transactionDateCategory(
                        t.displayCategorySummary(l10n),
                        format.formatMediumDate(t.date),
                      ),
                      style: TextStyle(color: colors.text3, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionReconciledToggle extends ConsumerWidget {
  final Transaction transaction;
  final String? filterAccount;
  final void Function(Transaction updated)? onPatched;
  final BalanceCheckSelection? balanceCheckSelection;

  const _TransactionReconciledToggle({
    required this.transaction,
    this.filterAccount,
    this.onPatched,
    this.balanceCheckSelection,
  });

  SelectionState get _state {
    final selection = balanceCheckSelection;
    if (selection != null) return selection.stateFor(transaction);
    if (transaction.isPartiallyReconciled) return SelectionState.partial;
    if (transaction.isReconciled) return SelectionState.all;
    return SelectionState.none;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final partial = transaction.isPartiallyReconciled;
    final selection = balanceCheckSelection;
    final canToggle = selection != null
        ? selection.canToggle(transaction)
        : !partial;

    final visual = selection?.visualFor(transaction);
    final palette = visual != null
        ? balanceCheckTogglePalette(colors, visual: visual)
        : reconciledTogglePalette(
            colors,
            inSelectionMode: false,
            actuallyReconciled:
                transaction.isReconciled || transaction.isPartiallyReconciled,
          );

    return Tooltip(
      message: switch (visual) {
        BalanceCheckVisual.reconciledIncluded =>
          l10n.tooltipTransactionReconciled,
        BalanceCheckVisual.reconciledExcluded =>
          l10n.tooltipBalanceCheckExcludeReconciled,
        BalanceCheckVisual.pendingInclude =>
          l10n.tooltipBalanceCheckIncludePending,
        BalanceCheckVisual.unselected => l10n.tooltipBalanceCheckIncludePending,
        null => l10n.tooltipTransactionReconciled,
      },
      // Absorb the parent row InkWell so check taps never expand/collapse
      // the row or get lost in the gesture arena.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !canToggle
            ? null
            : () async {
                if (selection != null) {
                  selection.onToggle(transaction);
                  return;
                }
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      transaction.isReconciled
                          ? l10n.reconciledFilterUnreconciled
                          : l10n.reconcile,
                    ),
                    content: Text(
                      transaction.isReconciled
                          ? 'Are you sure you want to mark this transaction as unreconciled?'
                          : 'Are you sure you want to mark this transaction as reconciled?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(
                          transaction.isReconciled
                              ? l10n.reconciledFilterUnreconciled
                              : l10n.reconcile,
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                if (!context.mounted) return;
                toggleTransactionReconciled(
                  context,
                  ref,
                  filterAccount,
                  transaction,
                  reconciled: !transaction.isReconciled,
                  onPatched: onPatched,
                );
              },
        child: SelectionCheckControl(
          state: _state,
          enabled: true,
          colors: palette,
          size: 18,
          excluded: visual == BalanceCheckVisual.reconciledExcluded,
          iconOverride: visual == BalanceCheckVisual.pendingInclude
              ? LucideIcons.circleDot
              : null,
          onTap: null,
        ),
      ),
    );
  }
}

class _TransactionTypeIcon extends StatelessWidget {
  final bool isIncome;
  final double size;
  final double iconSize;

  const _TransactionTypeIcon({
    required this.isIncome,
    this.size = 28,
    this.iconSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isIncome
            ? colors.success.withValues(alpha: 0.12)
            : colors.accent.acc.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isIncome ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
        size: iconSize,
        color: isIncome ? colors.success : colors.text2,
      ),
    );
  }
}

class _TransactionTypeBadge extends ConsumerWidget {
  final bool isIncome;
  const _TransactionTypeBadge({required this.isIncome});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isIncome
            ? colors.success.withValues(alpha: 0.1)
            : colors.accent.acc.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isIncome ? fun.income : fun.expenseLabel,
        style: TextStyle(
          color: isIncome ? colors.success : colors.accent.acc,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Map<String, double>? computeRunningBalances({
  required String? filterAccount,
  required List<Transaction> transactions,
  required List<Account>? accounts,
  required AccountPrognosisResult? prognosis,
}) {
  if (filterAccount == null || accounts == null) return null;
  final account = accounts.firstWhere(
    (a) => a.name == filterAccount,
    orElse: () => Account(
      id: '',
      name: '',
      type: '',
      role: '',
      currencyCode: '',
      currencySymbol: '',
      currentBalance: 0,
    ),
  );
  if (account.id.isEmpty) return null;

  double currentBalance = account.currentBalance;

  final sorted = List<Transaction>.from(transactions)
    ..sort((a, b) => b.date.compareTo(a.date));

  final Map<String, double> result = {};
  for (final t in sorted) {
    result[t.id] = currentBalance;
    final delta = signedListAmount(t, accountName: filterAccount);
    currentBalance -= delta;
  }
  return result;
}

class TightRowsColumnSelectionDialog extends ConsumerWidget {
  const TightRowsColumnSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final activeColumns = ref.watch(tightRowsColumnsProvider);
    final notifier = ref.read(tightRowsColumnsProvider.notifier);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.columnSelection,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TightRowColumn.values.map((col) {
                final isSelected = activeColumns.contains(col);
                return FilterChip(
                  label: Text(col.label(l10n)),
                  selected: isSelected,
                  onSelected: (selected) {
                    notifier.toggleColumn(col);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TightRowsHeaderRow extends ConsumerStatefulWidget {
  const TightRowsHeaderRow({super.key});

  static Alignment columnAlignment(TightRowColumn col) {
    return switch (col) {
      TightRowColumn.amount || TightRowColumn.balance => Alignment.centerRight,
      TightRowColumn.reconciled => Alignment.center,
      _ => Alignment.centerLeft,
    };
  }

  @override
  ConsumerState<TightRowsHeaderRow> createState() => _TightRowsHeaderRowState();
}

class _TightRowsHeaderRowState extends ConsumerState<TightRowsHeaderRow> {
  int? _draggingIndex;

  static IconData columnIcon(TightRowColumn col) {
    return switch (col) {
      TightRowColumn.date => LucideIcons.calendar,
      TightRowColumn.account => LucideIcons.landmark,
      TightRowColumn.type => LucideIcons.arrowLeftRight,
      TightRowColumn.payee => LucideIcons.user,
      TightRowColumn.description => LucideIcons.fileText,
      TightRowColumn.category => LucideIcons.shapes,
      TightRowColumn.budget => LucideIcons.target,
      TightRowColumn.amount => LucideIcons.banknote,
      TightRowColumn.reconciled => LucideIcons.checkSquare,
      TightRowColumn.balance => LucideIcons.scale,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final activeColumns = ref.watch(tightRowsColumnsProvider);
    final config = ref.watch(transactionColumnConfigProvider);
    final notifier = ref.read(transactionColumnConfigProvider.notifier);

    final visibleColumns = config.order
        .where((c) => activeColumns.contains(c))
        .toList();

    Widget columnLabel(TightRowColumn col) {
      final isRight =
          TightRowsHeaderRow.columnAlignment(col) == Alignment.centerRight;
      final isCenter =
          TightRowsHeaderRow.columnAlignment(col) == Alignment.center;
      return Row(
        mainAxisAlignment: isRight
            ? MainAxisAlignment.end
            : (isCenter ? MainAxisAlignment.center : MainAxisAlignment.start),
        children: [
          Icon(columnIcon(col), size: 12, color: colors.text3),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              col.label(l10n),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.text3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fitted = config.fittedWidths(
              constraints.maxWidth,
              visibleColumns,
            );
            return Row(
              children: [
                for (int i = 0; i < visibleColumns.length; i++) ...[
                  DragTarget<int>(
                    onWillAcceptWithDetails: (details) => details.data != i,
                    onAcceptWithDetails: (details) {
                      notifier.reorderColumn(details.data, i);
                      setState(() => _draggingIndex = null);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isDropTarget =
                          candidateData.isNotEmpty && candidateData.first != i;
                      final col = visibleColumns[i];
                      final width = fitted[col]!;
                      return SizedBox(
                        width: width,
                        height: 36,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              right: tightRowResizeGutter,
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
                                alignment: TightRowsHeaderRow.columnAlignment(
                                  col,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: Draggable<int>(
                                    data: i,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surface,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          col.label(l10n),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: colors.text,
                                          ),
                                        ),
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
                            Positioned(
                              right: 0,
                              top: 4,
                              bottom: 4,
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
                SizedBox(
                  width: TransactionColumnConfig.actionWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Tooltip(
                      message: l10n.columnSelection,
                      child: InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) =>
                              const TightRowsColumnSelectionDialog(),
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            LucideIcons.slidersHorizontal,
                            size: 14,
                            color: colors.text3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TransactionEntityTightRow extends ConsumerStatefulWidget {
  final Transaction transaction;
  final String? filterAccount;
  final Future<void> Function()? onTransactionMutated;
  final void Function(Transaction updated)? onTransactionPatched;
  final BalanceCheckSelection? balanceCheckSelection;
  final double? runningBalance;

  const TransactionEntityTightRow({
    super.key,
    required this.transaction,
    this.filterAccount,
    this.onTransactionMutated,
    this.onTransactionPatched,
    this.balanceCheckSelection,
    this.runningBalance,
  });

  @override
  ConsumerState<TransactionEntityTightRow> createState() =>
      _TransactionEntityTightRowState();
}

class _TransactionEntityTightRowState
    extends ConsumerState<TransactionEntityTightRow> {
  bool _expanded = false;
  bool _splitsExpanded = false;

  @override
  void didUpdateWidget(covariant TransactionEntityTightRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.id != widget.transaction.id) {
      if (_expanded) _expanded = false;
      if (_splitsExpanded) _splitsExpanded = false;
    }
  }

  void _toggleExpand() {
    setState(() {
      if (widget.transaction.isSplitGroup) {
        _splitsExpanded = !_splitsExpanded;
      } else {
        _expanded = !_expanded;
      }
    });
  }

  void _openEdit() => setState(() => _expanded = true);

  Future<void> _delete() async {
    await deleteTransactionEntity(
      context,
      ref,
      widget.filterAccount,
      widget.transaction,
      onMutated: widget.onTransactionMutated,
    );
    if (mounted) {
      setState(() {
        _expanded = false;
        _splitsExpanded = false;
      });
    }
  }

  Future<void> _duplicate() async {
    await duplicateTransactionEntity(
      context,
      ref,
      widget.filterAccount,
      widget.transaction,
      onMutated: widget.onTransactionMutated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final format = context.format;
    final t = widget.transaction;
    final signedAmount = signedListAmount(t, accountName: widget.filterAccount);
    final isIncoming = signedAmount >= 0;

    final dateStr = format.formatIsoDate(t.date);
    final accountStr = widget.filterAccount != null
        ? (t.sourceName == widget.filterAccount
              ? t.destinationName
              : t.sourceName)
        : (t.sourceName != 'Unknown' && t.sourceName.isNotEmpty
              ? t.sourceName
              : t.destinationName);
    final payeeStr = t.type == 'withdrawal'
        ? t.destinationName
        : (t.type == 'deposit'
              ? t.sourceName
              : '${t.sourceName} → ${t.destinationName}');

    return FunDecoratedSurface(
      decorationKey: 'txn-tight-${t.id}',
      borderRadius: BorderRadius.zero,
      compact: true,
      child: ExpandableEntityCompactRow(
        expanded: _splitsExpanded || _expanded,
        onToggleExpand: _toggleExpand,
        expandedChild: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (t.isSplitGroup && _splitsExpanded)
              SplitTransactionChildList(
                transaction: t,
                compact: true,
                filterAccount: widget.filterAccount,
              ),
            if (_expanded)
              TransactionEditPanel(
                key: ValueKey('edit-${t.id}'),
                transaction: t,
                onCancel: () => setState(() => _expanded = false),
                onSave: (updated) async {
                  await saveTransactionEntity(
                    context,
                    ref,
                    widget.filterAccount,
                    t,
                    updated,
                  );
                  if (mounted) setState(() => _expanded = false);
                },
              ),
          ],
        ),
        header: Consumer(
          builder: (context, ref, _) {
            final activeColumns = ref.watch(tightRowsColumnsProvider);
            final config = ref.watch(transactionColumnConfigProvider);
            final visibleColumns = config.order
                .where((c) => activeColumns.contains(c))
                .toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fitted = config.fittedWidths(
                    constraints.maxWidth,
                    visibleColumns,
                  );
                  return Row(
                    children: [
                      for (final col in visibleColumns)
                        SizedBox(
                          width: fitted[col],
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: tightRowResizeGutter,
                            ),
                            child: _buildCell(
                              col: col,
                              t: t,
                              dateStr: dateStr,
                              accountStr: accountStr,
                              payeeStr: payeeStr,
                              signedAmount: signedAmount,
                              isIncoming: isIncoming,
                              format: format,
                              colors: colors,
                            ),
                          ),
                        ),
                      const Spacer(),
                      SizedBox(
                        width: TransactionColumnConfig.actionWidth,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: EntityHeaderActions(
                            iconSize: 14,
                            onEdit: _openEdit,
                            onDuplicate: _duplicate,
                            onDelete: _delete,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCell({
    required TightRowColumn col,
    required Transaction t,
    required String dateStr,
    required String accountStr,
    required String payeeStr,
    required double signedAmount,
    required bool isIncoming,
    required LocaleFormatting format,
    required dynamic colors,
  }) {
    switch (col) {
      case TightRowColumn.date:
        return Text(
          dateStr,
          style: TextStyle(fontSize: 12, color: colors.text2),
          overflow: TextOverflow.ellipsis,
        );
      case TightRowColumn.account:
        return Text(
          accountStr,
          style: TextStyle(fontSize: 12, color: colors.text2),
          overflow: TextOverflow.ellipsis,
        );
      case TightRowColumn.type:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TransactionTypeIcon(isIncome: isIncoming, size: 16, iconSize: 10),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                t.type,
                style: TextStyle(fontSize: 11, color: colors.text3),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case TightRowColumn.payee:
        return Text(
          payeeStr,
          style: TextStyle(fontSize: 12, color: colors.text),
          overflow: TextOverflow.ellipsis,
        );
      case TightRowColumn.description:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                t.displayTitle(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (t.isSplitGroup) ...[
              const SizedBox(width: 4),
              SplitCountBadge(count: t.splits.length),
            ],
          ],
        );
      case TightRowColumn.category:
        return Text(
          t.categoryName.isNotEmpty ? t.categoryName : '-',
          style: TextStyle(fontSize: 12, color: colors.text3),
          overflow: TextOverflow.ellipsis,
        );
      case TightRowColumn.budget:
        return Text(
          t.budgetName ?? '-',
          style: TextStyle(fontSize: 12, color: colors.text3),
          overflow: TextOverflow.ellipsis,
        );
      case TightRowColumn.amount:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                format.formatSignedMoney(signedAmount, t.currencySymbol),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Roboto Slab',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isIncoming ? colors.success : colors.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case TightRowColumn.reconciled:
        return Align(
          alignment: Alignment.center,
          child: _TransactionReconciledToggle(
            transaction: t,
            filterAccount: widget.filterAccount,
            balanceCheckSelection: widget.balanceCheckSelection,
            onPatched: widget.onTransactionPatched,
          ),
        );
      case TightRowColumn.balance:
        final bal = widget.runningBalance;
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                bal != null ? format.formatMoney(bal, t.currencySymbol) : '-',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Roboto Slab',
                  fontSize: 12,
                  color: bal != null && bal < 0 ? colors.danger : colors.text2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    }
  }
}
