import 'package:flutter/material.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../theme/app_theme.dart';
import '../utils/display_labels.dart';
import '../utils/locale_formatting.dart';
import 'selection_check_control.dart';

/// Compact selectable transaction row shared by reconciliation and similar views.
class SelectableTransactionRow extends StatelessWidget {
  const SelectableTransactionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    required this.amountColor,
    required this.selectionState,
    required this.selectionEnabled,
    required this.onSelectionToggle,
    this.surfaceColor,
    this.borderColor,
    this.checkColors,
  });

  final String title;
  final String subtitle;
  final String amountLabel;
  final Color amountColor;
  final SelectionState selectionState;
  final bool selectionEnabled;
  final VoidCallback? onSelectionToggle;
  final Color? surfaceColor;
  final Color? borderColor;
  final SelectionCheckColors? checkColors;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: surfaceColor ?? colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: selectionEnabled ? onSelectionToggle : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor ?? colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.text3, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                amountLabel,
                style: TextStyle(
                  fontFamily: 'Roboto Slab',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: amountColor,
                ),
              ),
              const SizedBox(width: 8),
              SelectionCheckControl(
                state: selectionState,
                enabled: selectionEnabled,
                onTap: selectionEnabled ? onSelectionToggle : null,
                colors: checkColors,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds subtitle + colors for reconciliation transaction rows.
class ReconciliationTransactionRow extends StatelessWidget {
  const ReconciliationTransactionRow({
    super.key,
    required this.transaction,
    required this.inRange,
    required this.isFuture,
    required this.signedAmount,
    required this.format,
    required this.reconciledLabel,
    required this.unreconciledLabel,
    required this.futureLabel,
    required this.onToggleReconciled,
  });

  final Transaction transaction;
  final bool inRange;
  final bool isFuture;
  final double signedAmount;
  final LocaleFormatting format;
  final String reconciledLabel;
  final String unreconciledLabel;
  final String futureLabel;
  final VoidCallback? onToggleReconciled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final partial = transaction.isPartiallyReconciled;
    final reconciled = transaction.isReconciled;

    return SelectableTransactionRow(
      title: transaction.displayTitle(),
      subtitle: isFuture
          ? '${format.formatMediumDate(transaction.date)} · $futureLabel'
          : '${format.formatMediumDate(transaction.date)} · '
                '${reconciled ? reconciledLabel : unreconciledLabel}',
      amountLabel: format.formatSignedMoney(
        signedAmount,
        transaction.currencySymbol,
      ),
      amountColor: signedAmount >= 0 ? colors.success : colors.text,
      selectionState: reconciledSelectionState(transaction),
      selectionEnabled: !isFuture && !partial,
      onSelectionToggle: onToggleReconciled,
      checkColors: SelectionCheckColors.reconciled(colors),
      surfaceColor: inRange
          ? colors.surface
          : colors.surface.withValues(alpha: 0.6),
      borderColor: reconciled
          ? colors.success.withValues(alpha: 0.45)
          : isFuture
          ? colors.border.withValues(alpha: 0.5)
          : colors.border,
    );
  }
}
