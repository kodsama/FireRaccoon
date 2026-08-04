import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../models/transaction.dart';
import '../utils/locale_formatting.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'transaction_entity_card.dart';

/// An upcoming (not yet written) occurrence of a recurring entry.
typedef PlannedOccurrence = ({
  DateTime date,
  double amount,
  String description,
  String currencySymbol,
});

/// Shared expanded panel listing transactions (budgets, accounts, etc.).
class TransactionsExpandedPanel extends ConsumerWidget {
  final bool loading;
  final List<Transaction>? transactions;
  final String emptyLabel;
  final String? errorMessage;
  final String? filterAccount;
  final List<PlannedOccurrence> plannedOccurrences;
  final Future<void> Function()? onTransactionMutated;
  final void Function(Transaction updated)? onTransactionPatched;

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
  });

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);

    // The transactions body switches between loading / error / empty / list.
    Widget txBody;
    if (loading) {
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
    } else if (errorMessage != null) {
      txBody = Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.danger, fontSize: 13),
          ),
        ),
      );
    } else if ((transactions == null || transactions!.isEmpty) &&
        plannedOccurrences.isEmpty) {
      txBody = Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            emptyLabel,
            style: TextStyle(color: colors.text3, fontSize: 13),
          ),
        ),
      );
    } else {
      txBody = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            ...plannedOccurrences.map(
              (planned) => _plannedRow(context, planned),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.arrowLeftRight,
                    size: 14,
                    color: colors.text3,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fun.transactionsCount(transactions?.length ?? 0),
                    style: TextStyle(
                      color: colors.text3,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...(transactions ?? const <Transaction>[])
                .take(20)
                .map(
                  (transaction) => TransactionEntityCompactRow(
                    transaction: transaction,
                    filterAccount: filterAccount,
                    onTransactionMutated: onTransactionMutated,
                    onTransactionPatched: onTransactionPatched,
                  ),
                ),
            if ((transactions?.length ?? 0) > 20)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '…and ${(transactions?.length ?? 0) - 20} more',
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
          if (headerWidget != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: headerWidget!,
            ),
          txBody,
        ],
      ),
    );
  }
}
