import 'package:flutter/material.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_theme.dart';
import '../utils/display_labels.dart';

/// Inline child rows for a split journal (Skrooge-style sub-operations).
class SplitTransactionChildList extends StatelessWidget {
  const SplitTransactionChildList({
    super.key,
    required this.transaction,
    this.compact = false,
    this.filterAccount,
  });

  final Transaction transaction;
  final bool compact;
  final String? filterAccount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final splits = transaction.resolvedSplits();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < splits.length; i++) ...[
          if (i > 0) Divider(color: colors.border, height: 1),
          _SplitChildRow(
            split: splits[i],
            compact: compact,
            signedAmount: filterAccount != null
                ? signedAmountForSplit(splits[i], filterAccount!)
                : signedListAmount(splits[i]),
          ),
        ],
      ],
    );
  }
}

class _SplitChildRow extends StatelessWidget {
  const _SplitChildRow({
    required this.split,
    required this.compact,
    required this.signedAmount,
  });

  final Transaction split;
  final bool compact;
  final double signedAmount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = context.format;
    final isIncoming = signedAmount >= 0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 24 : 32,
        vertical: compact ? 8 : 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.subdirectory_arrow_right,
              size: compact ? 14 : 16,
              color: colors.text3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  split.description,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: compact ? 12 : 13,
                    color: colors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${split.displayCategory(l10n)} · ${split.sourceName} → ${split.destinationName}',
                  style: TextStyle(color: colors.text3, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            format.formatSignedMoney(signedAmount, split.currencySymbol),
            style: TextStyle(
              fontFamily: 'Roboto Slab',
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13,
              color: isIncoming ? colors.success : colors.text2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge showing how many splits a journal contains.
class SplitCountBadge extends StatelessWidget {
  const SplitCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    final colors = context.colors;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.accent.acc.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.accent.acc.withValues(alpha: 0.35)),
      ),
      child: Text(
        l10n.splitCount(count),
        style: TextStyle(
          color: colors.accent.acc,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
