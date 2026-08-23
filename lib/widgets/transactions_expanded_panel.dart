import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:fireracoon_engine/fireracoon_engine.dart' show signedListAmount;

import '../l10n/l10n_extensions.dart';
import '../models/transaction.dart';
import '../utils/locale_formatting.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'transaction_entity_card.dart';
import 'transaction_month_header.dart';

/// An upcoming (not yet written) occurrence of a recurring entry.
typedef PlannedOccurrence = ({
  DateTime date,
  double amount,
  String description,
  String currencySymbol,
});

/// Shared expanded panel listing transactions (budgets, accounts, etc.).
class TransactionsExpandedPanel extends ConsumerStatefulWidget {
  final bool loading;
  final List<Transaction>? transactions;
  final String emptyLabel;
  final String? errorMessage;
  final String? filterAccount;
  final List<PlannedOccurrence> plannedOccurrences;
  final Future<void> Function()? onTransactionMutated;
  final void Function(Transaction updated)? onTransactionPatched;

  /// Rows the ledger already holds for days that have not happened yet, shown
  /// collapsed under their own heading.
  ///
  /// A ledger that materialises its recurrences carries months of them, and
  /// mixed into the list they read as history that has already happened.
  final List<Transaction>? futureTransactions;

  /// Re-reads the rows behind a button.
  ///
  /// A change made anywhere else leaves this preview stale with nothing to say
  /// so, and closing and reopening the row to force a reload is not obvious.
  final Future<void> Function()? onRefresh;

  /// Optional widget rendered at the very top of the expanded area,
  /// before the transactions count row.  Used by account cards to show
  /// the reconcile tile only when the card is open.
  final Widget? headerWidget;

  const TransactionsExpandedPanel({
    super.key,
    required this.loading,
    required this.transactions,
    required this.emptyLabel,
    this.errorMessage,
    this.filterAccount,
    this.plannedOccurrences = const [],
    this.onTransactionMutated,
    this.onTransactionPatched,
    this.headerWidget,
    this.futureTransactions,
    this.onRefresh,
  });

  @override
  ConsumerState<TransactionsExpandedPanel> createState() =>
      _TransactionsExpandedPanelState();
}

class _TransactionsExpandedPanelState
    extends ConsumerState<TransactionsExpandedPanel> {
  /// Collapsed to begin with: the reason for separating them is that they are
  /// not what you opened the row to look at.
  bool _futureExpanded = false;
  bool _refreshing = false;

  Future<void> _refresh() async {
    final onRefresh = widget.onRefresh;
    if (onRefresh == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      await onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Widget _plannedRow(BuildContext context, PlannedOccurrence planned) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = LocaleFormatting(Localizations.localeOf(context));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.accent.acc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l10n.plannedLabel,
              style: TextStyle(
                color: colors.accent.acc,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planned.description,
                  style: TextStyle(color: colors.text3, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  format.formatMediumDate(planned.date),
                  style: TextStyle(color: colors.text3, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            format.formatMoney(planned.amount, planned.currencySymbol),
            style: TextStyle(
              fontFamily: 'Roboto Slab',
              color: colors.text3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Header row carrying the count and the refresh button.
  ///
  /// Rendered whatever the body is doing, so a failed load can be retried
  /// without closing the row.
  Widget _actionsRow(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final count = widget.transactions?.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Icon(LucideIcons.arrowLeftRight, size: 14, color: colors.text3),
          const SizedBox(width: 8),
          Text(
            count == null ? '' : fun.transactionsCount(count),
            style: TextStyle(
              color: colors.text3,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (widget.onRefresh != null)
            Tooltip(
              message: l10n.refreshFromFirefly,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _refreshing ? null : _refresh,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _refreshing
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.text3,
                          ),
                        )
                      : Icon(
                          LucideIcons.refreshCw,
                          size: 14,
                          color: colors.text3,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The future block: one collapsed heading carrying its own total.
  Widget _futureBlock(BuildContext context, List<Transaction> rows) {
    final format = LocaleFormatting(Localizations.localeOf(context));
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final sum = rows.fold<double>(
      0,
      (total, row) =>
          total + signedListAmount(row, accountName: widget.filterAccount),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TransactionMonthHeader(
            dense: true,
            label: l10n.upcoming,
            subtitle: fun.transactionsCount(rows.length),
            trailingLabel: format.formatSignedMoney(
              sum,
              rows.first.currencySymbol,
            ),
            expanded: _futureExpanded,
            onTap: () => setState(() => _futureExpanded = !_futureExpanded),
          ),
          if (_futureExpanded)
            for (final row in rows)
              TransactionEntityCompactRow(
                key: ValueKey(row.id),
                transaction: row,
                filterAccount: widget.filterAccount,
                onTransactionMutated: widget.onTransactionMutated,
                onTransactionPatched: widget.onTransactionPatched,
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final future = widget.futureTransactions ?? const <Transaction>[];
    final posted = widget.transactions ?? const <Transaction>[];

    // The transactions body switches between loading / error / empty / list.
    Widget txBody;
    if (widget.loading) {
      txBody = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (widget.errorMessage != null) {
      txBody = Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            widget.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.danger, fontSize: 13),
          ),
        ),
      );
    } else if (posted.isEmpty &&
        future.isEmpty &&
        widget.plannedOccurrences.isEmpty) {
      txBody = Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            widget.emptyLabel,
            style: TextStyle(color: colors.text3, fontSize: 13),
          ),
        ),
      );
    } else {
      txBody = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            ...widget.plannedOccurrences.map(
              (planned) => _plannedRow(context, planned),
            ),
            if (future.isNotEmpty) ...[
              _futureBlock(context, future),
              const SizedBox(height: 8),
            ],
            ...posted
                .take(20)
                .map(
                  (transaction) => TransactionEntityCompactRow(
                    transaction: transaction,
                    filterAccount: widget.filterAccount,
                    onTransactionMutated: widget.onTransactionMutated,
                    onTransactionPatched: widget.onTransactionPatched,
                  ),
                ),
            if (posted.length > 20)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '…and ${posted.length - 20} more',
                  style: TextStyle(color: colors.text3, fontSize: 12),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: colors.border)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header widget (e.g. reconcile tile) shown immediately,
          // independently of the transaction-loading state.
          if (widget.headerWidget != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: widget.headerWidget!,
            ),
          _actionsRow(context),
          txBody,
        ],
      ),
    );
  }
}
