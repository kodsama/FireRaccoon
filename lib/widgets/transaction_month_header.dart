import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/column_config_provider.dart';
import '../providers/data_providers.dart';
import '../providers/dashboard_stats_providers.dart';
import '../providers/tight_rows_columns_provider.dart';
import '../providers/view_mode_provider.dart';
import '../theme/app_theme.dart';
import '../utils/balance_check_selection.dart';
import '../utils/locale_formatting.dart';
import 'expandable_entity_shell.dart';
import 'selection_check_control.dart';
import 'tight_rows_table_shell.dart';
import 'transaction_entity_card.dart';

/// Month/period header shared by transactions and reconciliation lists.
class TransactionMonthHeader extends StatelessWidget {
  const TransactionMonthHeader({
    super.key,
    required this.label,
    this.subtitle,
    this.trailingLabel,
    this.trailingColor,
    this.selectionState,
    this.selectionEnabled = false,
    this.onSelectionToggle,
    this.checkColors,
    this.onTap,
    this.dense = false,
    this.expanded,
    this.interactive = true,
  });

  final String label;
  final String? subtitle;
  final String? trailingLabel;
  final Color? trailingColor;
  final SelectionState? selectionState;
  final bool selectionEnabled;
  final VoidCallback? onSelectionToggle;
  final SelectionCheckColors? checkColors;
  final VoidCallback? onTap;
  final bool dense;
  final bool? expanded;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showSelection = selectionState != null;
    final showChevron = expanded != null;

    if (dense) {
      return Material(
        color: colors.surface2.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: selectionEnabled ? onSelectionToggle ?? onTap : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _headerRow(context, showSelection: showSelection),
          ),
        ),
      );
    }

    final row = _headerRow(
      context,
      showSelection: showSelection,
      showChevron: showChevron,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: interactive
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: row,
            )
          : row,
    );
  }

  Widget _headerRow(
    BuildContext context, {
    required bool showSelection,
    bool showChevron = false,
  }) {
    final colors = context.colors;
    final textStyle = dense
        ? TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          )
        : context.textTheme.titleMedium?.copyWith(color: colors.text2);

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(child: Text(label, style: textStyle)),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                // Flexible because this header is also used inside an account
                // card, where the column is narrow enough for a subtitle to
                // run off the end of it.
                Flexible(
                  child: Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text3,
                      fontSize: dense ? 12 : 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailingLabel != null) ...[
          Text(
            trailingLabel!,
            style: dense
                ? TextStyle(color: colors.text3, fontSize: 12)
                : TextStyle(
                    fontFamily: 'Roboto Slab',
                    fontWeight: FontWeight.w600,
                    color: trailingColor ?? colors.text,
                  ),
          ),
          if (showSelection || showChevron) const SizedBox(width: 8),
        ],
        if (showSelection)
          SelectionCheckControl(
            state: selectionState!,
            enabled: selectionEnabled,
            onTap: selectionEnabled ? onSelectionToggle : null,
            colors: checkColors,
          ),
        if (showChevron) ExpandChevron(expanded: expanded!),
      ],
    );
  }
}

/// Sliver variant of the collapsible transaction group: the header is a box
/// sliver and the rows are a lazy sliver list, so only visible rows are ever
/// built no matter how large the group grows.
class SliverCollapsibleTransactionGroup extends ConsumerWidget {
  const SliverCollapsibleTransactionGroup({
    super.key,
    required this.label,
    this.subtitle,
    required this.sum,
    required this.currencySymbol,
    required this.transactions,
    this.filterAccount,
    required this.expanded,
    required this.onToggle,
    required this.format,
    this.selectionState,
    this.selectionEnabled = false,
    this.onSelectionToggle,
    this.checkColors,
    this.balanceCheckSelection,
  });

  final String label;
  final String? subtitle;
  final double sum;
  final String currencySymbol;
  final List<Transaction> transactions;
  final String? filterAccount;
  final bool expanded;
  final VoidCallback onToggle;
  final LocaleFormatting format;
  final SelectionState? selectionState;
  final bool selectionEnabled;
  final VoidCallback? onSelectionToggle;
  final SelectionCheckColors? checkColors;
  final BalanceCheckSelection? balanceCheckSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final colors = context.colors;
    final l10n = context.l10n;
    final viewMode = ref.watch(viewModeProvider);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Tooltip(
            message: expanded
                ? l10n.tooltipCollapseDetails
                : l10n.tooltipExpandDetails,
            child: InkWell(
              onTap: onToggle,
              child: TransactionMonthHeader(
                label: label,
                subtitle: subtitle,
                trailingLabel: format.formatSignedMoney(sum, currencySymbol),
                trailingColor: sum >= 0 ? colors.success : colors.text,
                expanded: expanded,
                interactive: false,
                selectionState: selectionState,
                selectionEnabled: selectionEnabled,
                onSelectionToggle: onSelectionToggle,
                checkColors: checkColors,
              ),
            ),
          ),
        ),
        if (expanded)
          switch (viewMode) {
            ViewMode.compact => _compactRowsSliver(context),
            ViewMode.tight => _tightRowsSliver(context, ref),
            ViewMode.standard => _gridSliver(context),
          },
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _tightRowsSliver(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accounts = ref.watch(accountsProvider).value;
    final prognosis = ref.watch(accountPrognosisProvider);
    final runningBalances = computeRunningBalances(
      filterAccount: filterAccount,
      transactions: transactions,
      accounts: accounts,
      prognosis: prognosis,
    );
    final activeColumns = ref.watch(tightRowsColumnsProvider);
    final columnConfig = ref.watch(transactionColumnConfigProvider);
    final visibleColumns = columnConfig.order
        .where(activeColumns.contains)
        .toList();
    final minContentWidth =
        columnConfig.preferredContentWidth(visibleColumns) +
        tightRowsHorizontalPadding * 2;

    return DecoratedSliver(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      sliver: SliverToBoxAdapter(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: TightRowsTableShell(
            minContentWidth: minContentWidth,
            header: const TightRowsHeaderRow(),
            rows: [
              for (final transaction in transactions)
                TransactionEntityTightRow(
                  key: ValueKey(transaction.id),
                  transaction: transaction,
                  filterAccount: filterAccount,
                  balanceCheckSelection: balanceCheckSelection,
                  runningBalance: runningBalances?[transaction.id],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lazy compact rows with the card chrome painted across the sliver,
  /// matching the app's CardThemeData (surface, border, radius 16).
  Widget _compactRowsSliver(BuildContext context) {
    final colors = context.colors;
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      sliver: SliverList.separated(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return TransactionEntityCompactRow(
            key: ValueKey(transaction.id),
            transaction: transaction,
            filterAccount: filterAccount,
            balanceCheckSelection: balanceCheckSelection,
          );
        },
        separatorBuilder: (context, index) =>
            Divider(color: colors.border, height: 1),
      ),
    );
  }

  /// Lazy card grid: fixed-width cards chunked into rows so vertical
  /// virtualization works while cards keep their inline expansion.
  Widget _gridSliver(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const cardWidth = 380.0;
        const spacing = 16.0;
        final perRow =
            ((constraints.crossAxisExtent + spacing) / (cardWidth + spacing))
                .floor()
                .clamp(1, 12);
        final rowCount = (transactions.length + perRow - 1) ~/ perRow;
        return SliverList.builder(
          itemCount: rowCount,
          itemBuilder: (context, rowIndex) {
            final start = rowIndex * perRow;
            final rowEnd = start + perRow < transactions.length
                ? start + perRow
                : transactions.length;
            return Padding(
              padding: EdgeInsets.only(
                bottom: rowIndex == rowCount - 1 ? 0 : spacing,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = start; i < rowEnd; i++) ...[
                    if (i != start) const SizedBox(width: spacing),
                    TransactionEntityCard(
                      key: ValueKey(transactions[i].id),
                      transaction: transactions[i],
                      filterAccount: filterAccount,
                      balanceCheckSelection: balanceCheckSelection,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
