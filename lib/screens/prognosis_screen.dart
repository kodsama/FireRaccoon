import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/account.dart';
import '../models/account_prognosis.dart';
import '../providers/data_providers.dart';
import '../providers/prognosis_settings_provider.dart';
import '../providers/dashboard_stats_providers.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/locale_formatting.dart';
import '../widgets/autocomplete_text_field.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../widgets/entity_list_layout.dart';
import '../widgets/loading_body.dart';
import '../widgets/not_connected_view.dart';
import '../widgets/prognosis_band_chart.dart';

/// Deep-link alias — use [ProjectionScreen] / `/projection` in the app shell.
class PrognosisScreen extends StatelessWidget {
  const PrognosisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrognosisView();
  }
}

/// Account balance projection from scheduled and recurring cash flow.
class PrognosisView extends ConsumerStatefulWidget {
  const PrognosisView({super.key});

  @override
  ConsumerState<PrognosisView> createState() => _PrognosisViewState();
}

class _PrognosisViewState extends ConsumerState<PrognosisView> {
  String? _selectedAccountId;

  /// Accounts worth forecasting: open, and with a forecast to show.
  ///
  /// A closed account has nothing ahead of it, so offering one is offering a
  /// projection of nothing.
  List<Account> _visibleAccounts(
    List<Account> accounts,
    AccountPrognosisResult prognosis,
  ) {
    return accounts
        .where(
          (account) =>
              account.active && prognosis.forAccount(account.id) != null,
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);
    final settings = ref.watch(prognosisSettingsProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return accountsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => accountsAsync.isLoading
          ? const LoadingBody()
          : LoadFailureView(
              error: error,
              message: l10n.errorGeneric(error.toString()),
            ),
      data: (accounts) {
        final prognosis = ref.watch(accountPrognosisProvider);
        final visibleAccounts = _visibleAccounts(accounts, prognosis);
        final selectedId =
            _selectedAccountId ?? visibleAccounts.firstOrNull?.id;
        final selected = selectedId == null
            ? null
            : prognosis.forAccount(selectedId);
        final selectedAccount = selectedId == null
            ? null
            : accounts.where((a) => a.id == selectedId).firstOrNull;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.prognosisSummaryHint,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.text3,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _InclusionPanel(
                inclusion: settings.inclusion,
                onChanged: (inclusion) {
                  final previous = settings.inclusion;
                  ref
                      .read(prognosisSettingsProvider.notifier)
                      .setInclusion(inclusion);
                  ref
                      .read(undoHistoryProvider.notifier)
                      .record(
                        title: 'Projection inclusion changed',
                        details: 'Projection inclusion options updated',
                        type: UndoActionType.prognosisInclusion,
                        undoPayload: {
                          'includeScheduledTransactions':
                              previous.includeScheduledTransactions,
                          'includeRecurringTransactions':
                              previous.includeRecurringTransactions,
                          'includeBills': previous.includeBills,
                          'includeIncome': previous.includeIncome,
                          'includeExpenses': previous.includeExpenses,
                          'includeTransfers': previous.includeTransfers,
                          'includeCreditCards': previous.includeCreditCards,
                          'includeLiabilities': previous.includeLiabilities,
                        },
                        redoPayload: {
                          'includeScheduledTransactions':
                              inclusion.includeScheduledTransactions,
                          'includeRecurringTransactions':
                              inclusion.includeRecurringTransactions,
                          'includeBills': inclusion.includeBills,
                          'includeIncome': inclusion.includeIncome,
                          'includeExpenses': inclusion.includeExpenses,
                          'includeTransfers': inclusion.includeTransfers,
                          'includeCreditCards': inclusion.includeCreditCards,
                          'includeLiabilities': inclusion.includeLiabilities,
                        },
                      );
                },
              ),
              const SizedBox(height: 14),
              _ChartPanel(
                prognosis: prognosis,
                selected: selected,
                selectedAccount: selectedAccount,
                visibleAccounts: visibleAccounts,
                selectedAccountId: selectedId,
                format: format,
                marginPercent: settings.marginPercent,
                horizon: settings.horizon,
                customHorizonDate: settings.customHorizonDate,
                onAccountChanged: (id) =>
                    setState(() => _selectedAccountId = id),
                onMarginChanged: (value) {
                  final previous = settings.marginPercent;
                  final next = value.clamp(0, 50).toDouble();
                  ref
                      .read(prognosisSettingsProvider.notifier)
                      .setMarginPercent(next);
                  if (previous == next) return;
                  ref
                      .read(undoHistoryProvider.notifier)
                      .record(
                        title: 'Projection margin changed',
                        details:
                            'Projection margin: ${previous.toStringAsFixed(1)} -> ${next.toStringAsFixed(1)}',
                        type: UndoActionType.prognosisMarginPercent,
                        undoPayload: {'marginPercent': previous},
                        redoPayload: {'marginPercent': next},
                      );
                },
                onHorizonChanged: (horizon) {
                  final previous = settings.horizon;
                  ref
                      .read(prognosisSettingsProvider.notifier)
                      .setHorizon(horizon);
                  ref
                      .read(undoHistoryProvider.notifier)
                      .record(
                        title: 'Projection horizon changed',
                        details:
                            'Projection horizon: ${previous.name} -> ${horizon.name}',
                        type: UndoActionType.prognosisHorizon,
                        undoPayload: {'horizon': previous.name},
                        redoPayload: {'horizon': horizon.name},
                      );
                },
                onCustomDateChanged: (date) {
                  final previous = settings.horizon;
                  final previousDate = settings.customHorizonDate;
                  final notifier = ref.read(prognosisSettingsProvider.notifier);
                  notifier.setCustomHorizonDate(date);
                  notifier.setHorizon(PrognosisHorizon.customDate);
                  ref
                      .read(undoHistoryProvider.notifier)
                      .record(
                        title: 'Projection horizon changed',
                        details:
                            'Projection horizon: ${previous.name} -> '
                            '${format.formatIsoDate(date)}',
                        type: UndoActionType.prognosisHorizon,
                        undoPayload: {
                          'horizon': previous.name,
                          if (previousDate != null)
                            'customHorizonDate': previousDate.toIso8601String(),
                        },
                        redoPayload: {
                          'horizon': PrognosisHorizon.customDate.name,
                          'customHorizonDate': date.toIso8601String(),
                        },
                      );
                },
              ),
              const SizedBox(height: 20),
              Text(l10n.yourAccounts, style: context.textTheme.titleLarge),
              const SizedBox(height: 16),
              EntityListLayout(
                gridItems: visibleAccounts
                    .map(
                      (account) => _AccountPrognosisCard(
                        account: account,
                        prognosis: prognosis.forAccount(account.id)!,
                        format: format,
                        onTap: () =>
                            setState(() => _selectedAccountId = account.id),
                        selected: account.id == selectedId,
                      ),
                    )
                    .toList(),
                compactItems: visibleAccounts
                    .map(
                      (account) => _AccountPrognosisCompactRow(
                        account: account,
                        prognosis: prognosis.forAccount(account.id)!,
                        format: format,
                        onTap: () =>
                            setState(() => _selectedAccountId = account.id),
                        selected: account.id == selectedId,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChartPanel extends StatelessWidget {
  final AccountPrognosisResult prognosis;
  final AccountPrognosis? selected;
  final Account? selectedAccount;
  final List<Account> visibleAccounts;
  final String? selectedAccountId;
  final LocaleFormatting format;
  final double marginPercent;
  final PrognosisHorizon horizon;
  final DateTime? customHorizonDate;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<double> onMarginChanged;
  final ValueChanged<PrognosisHorizon> onHorizonChanged;
  final ValueChanged<DateTime> onCustomDateChanged;

  const _ChartPanel({
    required this.prognosis,
    required this.selected,
    required this.selectedAccount,
    required this.visibleAccounts,
    required this.selectedAccountId,
    required this.format,
    required this.marginPercent,
    required this.horizon,
    required this.customHorizonDate,
    required this.onAccountChanged,
    required this.onMarginChanged,
    required this.onHorizonChanged,
    required this.onCustomDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.prognosisPredictedBalances,
              style: context.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AccountPicker(
                    accounts: visibleAccounts,
                    selectedAccountId: selectedAccountId,
                    label: l10n.prognosisSelectAccount,
                    onAccountChanged: onAccountChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HorizonPicker(
                    horizon: horizon,
                    customDate: customHorizonDate,
                    format: format,
                    onHorizonChanged: onHorizonChanged,
                    onCustomDateChanged: onCustomDateChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.prognosisMarginLabel,
                    style: TextStyle(color: colors.text2, fontSize: 13),
                  ),
                ),
                Text(
                  l10n.prognosisMarginDetail(marginPercent.round().toString()),
                  style: TextStyle(color: colors.text3, fontSize: 11),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: marginPercent,
                min: 0,
                max: 50,
                divisions: 10,
                label: '${marginPercent.round()}%',
                onChanged: onMarginChanged,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.prognosisBandLegend,
              style: TextStyle(fontSize: 11, color: colors.text3),
            ),
            const SizedBox(height: 10),
            if (selected != null && selectedAccount != null)
              PrognosisBandChart(
                height: 220,
                timeline: selected!.timeline,
                markerEndOfMonth: prognosis.endOfThisMonth,
                markerEndOfNextMonth: prognosis.endOfNextMonth,
                horizonEnd: prognosis.horizonEnd,
                formatValue: (value) => format.formatMoney(
                  value,
                  selectedAccount!.currencySymbol,
                  decimalDigits: 0,
                ),
              )
            else
              const SizedBox(height: 220),
            if (selected != null && selectedAccount != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _SelectedAccountBalances(
                account: selectedAccount!,
                prognosis: selected!,
                format: format,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedAccountBalances extends StatelessWidget {
  final Account account;
  final AccountPrognosis prognosis;
  final LocaleFormatting format;

  const _SelectedAccountBalances({
    required this.account,
    required this.prognosis,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currency = account.currencySymbol;
    final dateFormat = DateFormat.yMMMd();

    final milestoneRows = prognosisDisplayMilestones
        .map(
          (milestone) => _BalanceRow(
            label: l10n.labelForPrognosisMilestone(milestone),
            value: format.formatMoney(
              prognosis.milestone(milestone).expected,
              currency,
            ),
            warning:
                prognosis.hasNegativeRisk &&
                prognosis.milestone(milestone).expected <= 0,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BalanceRow(
          label: l10n.prognosisCurrentBalance,
          value: format.formatMoney(prognosis.currentBalance, currency),
          emphasized: true,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 480;
            if (!twoColumns) {
              return Column(children: milestoneRows);
            }
            return Wrap(
              spacing: 16,
              runSpacing: 0,
              children: milestoneRows
                  .map(
                    (row) => SizedBox(
                      width: (constraints.maxWidth - 16) / 2,
                      child: row,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _BalanceRow(
                label: l10n.prognosisMinBalance,
                value: format.formatMoney(
                  prognosis.endOfMonth.pessimistic,
                  currency,
                ),
                color: colors.danger,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _BalanceRow(
                label: l10n.prognosisMaxBalance,
                value: format.formatMoney(
                  prognosis.endOfMonth.optimistic,
                  currency,
                ),
                color: colors.success,
              ),
            ),
          ],
        ),
        if (prognosis.firstNegativeDate != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.triangleAlert, size: 16, color: colors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.prognosisNegativeOn(
                      dateFormat.format(prognosis.firstNegativeDate!),
                    ),
                    style: TextStyle(
                      color: colors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InclusionPanel extends StatelessWidget {
  final PrognosisInclusionOptions inclusion;
  final ValueChanged<PrognosisInclusionOptions> onChanged;

  const _InclusionPanel({required this.inclusion, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.prognosisIncludeSources,
              style: context.textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InclusionChip(
                  label: l10n.prognosisIncludeScheduled,
                  selected: inclusion.includeScheduledTransactions,
                  onChanged: (value) => onChanged(
                    inclusion.copyWith(includeScheduledTransactions: value),
                  ),
                ),
                _InclusionChip(
                  label: l10n.prognosisIncludeRecurring,
                  selected: inclusion.includeRecurringTransactions,
                  onChanged: (value) => onChanged(
                    inclusion.copyWith(includeRecurringTransactions: value),
                  ),
                ),
                _InclusionChip(
                  label: l10n.prognosisIncludeBills,
                  selected: inclusion.includeBills,
                  onChanged: (value) =>
                      onChanged(inclusion.copyWith(includeBills: value)),
                ),
                _InclusionChip(
                  label: l10n.prognosisIncludeIncome,
                  selected: inclusion.includeIncome,
                  onChanged: (value) =>
                      onChanged(inclusion.copyWith(includeIncome: value)),
                ),
                _InclusionChip(
                  label: l10n.prognosisIncludeExpenses,
                  selected: inclusion.includeExpenses,
                  onChanged: (value) =>
                      onChanged(inclusion.copyWith(includeExpenses: value)),
                ),
                _InclusionChip(
                  label: l10n.prognosisIncludeTransfers,
                  selected: inclusion.includeTransfers,
                  onChanged: (value) =>
                      onChanged(inclusion.copyWith(includeTransfers: value)),
                ),
                _InclusionChip(
                  label: l10n.prognosisIncludeCreditCards,
                  selected: inclusion.includeCreditCards,
                  onChanged: (value) =>
                      onChanged(inclusion.copyWith(includeCreditCards: value)),
                ),
                _InclusionChip(
                  label: l10n.prognosisIncludeLiabilities,
                  selected: inclusion.includeLiabilities,
                  onChanged: (value) =>
                      onChanged(inclusion.copyWith(includeLiabilities: value)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InclusionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _InclusionChip({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? colors.accent.acc : colors.text2,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide(
        color: selected
            ? colors.accent.acc.withValues(alpha: 0.6)
            : colors.border,
      ),
      backgroundColor: colors.surface2,
      selectedColor: colors.accent.acc.withValues(alpha: 0.14),
      onSelected: onChanged,
    );
  }
}

class _AccountPrognosisCard extends StatelessWidget {
  final Account account;
  final AccountPrognosis prognosis;
  final LocaleFormatting format;
  final VoidCallback onTap;
  final bool selected;

  const _AccountPrognosisCard({
    required this.account,
    required this.prognosis,
    required this.format,
    required this.onTap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currency = account.currencySymbol;
    final dateFormat = DateFormat.yMMMd();
    final isLiability = account.type == 'liability';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? colors.surface2 : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: prognosis.hasNegativeRisk
                ? colors.danger
                : selected
                ? colors.accent.acc
                : colors.border,
            width: prognosis.hasNegativeRisk || selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLiability ? LucideIcons.creditCard : LucideIcons.landmark,
                  color: prognosis.hasNegativeRisk
                      ? colors.danger
                      : colors.accent.acc,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    account.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BalanceRow(
              label: l10n.prognosisCurrentBalance,
              value: format.formatMoney(prognosis.currentBalance, currency),
            ),
            for (final milestone in prognosisDisplayMilestones)
              _BalanceRow(
                label: l10n.labelForPrognosisMilestone(milestone),
                value: format.formatMoney(
                  prognosis.milestone(milestone).expected,
                  currency,
                ),
                emphasized: milestone == PrognosisMilestone.endOfMonth,
                warning:
                    prognosis.hasNegativeRisk &&
                    prognosis.milestone(milestone).expected <= 0,
              ),
            const Divider(height: 16),
            _BalanceRow(
              label: l10n.prognosisMinBalance,
              value: format.formatMoney(
                prognosis.endOfMonth.pessimistic,
                currency,
              ),
              color: colors.danger,
            ),
            _BalanceRow(
              label: l10n.prognosisMaxBalance,
              value: format.formatMoney(
                prognosis.endOfMonth.optimistic,
                currency,
              ),
              color: colors.success,
            ),
            if (prognosis.firstNegativeDate != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.prognosisNegativeOn(
                  dateFormat.format(prognosis.firstNegativeDate!),
                ),
                style: TextStyle(
                  color: colors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountPrognosisCompactRow extends StatelessWidget {
  final Account account;
  final AccountPrognosis prognosis;
  final LocaleFormatting format;
  final VoidCallback onTap;
  final bool selected;

  const _AccountPrognosisCompactRow({
    required this.account,
    required this.prognosis,
    required this.format,
    required this.onTap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currency = account.currencySymbol;
    final isLiability = account.type == 'liability';
    final endOfMonth = prognosis.milestone(PrognosisMilestone.endOfMonth);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? colors.surface2 : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(
              isLiability ? LucideIcons.creditCard : LucideIcons.landmark,
              color: prognosis.hasNegativeRisk ? colors.danger : colors.text2,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.labelForPrognosisMilestone(PrognosisMilestone.endOfMonth)}: '
                    '${format.formatMoney(endOfMonth.expected, currency)}',
                    style: TextStyle(color: colors.text3, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.prognosisMinBalance}: '
                    '${format.formatMoney(prognosis.endOfMonth.pessimistic, currency)} · '
                    '${l10n.prognosisMaxBalance}: '
                    '${format.formatMoney(prognosis.endOfMonth.optimistic, currency)}',
                    style: TextStyle(color: colors.text3, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  format.formatMoney(prognosis.currentBalance, currency),
                  style: TextStyle(
                    fontFamily: 'Roboto Slab',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: prognosis.currentBalance < 0
                        ? colors.danger
                        : colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.prognosisCurrentBalance,
                  style: TextStyle(color: colors.text3, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  final bool warning;
  final Color? color;

  const _BalanceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.warning = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: emphasized ? 13 : 12,
                color: colors.text3,
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Roboto Slab',
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
              fontSize: emphasized ? 18 : 14,
              color: color ?? (warning ? colors.danger : colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizon chooser. Every entry but the last stands on its own; the last is a
/// day taken from a calendar, and choosing it asks for that day before the
/// horizon moves, so the forecast never runs to a date nobody named.
class _HorizonPicker extends StatefulWidget {
  const _HorizonPicker({
    required this.horizon,
    required this.customDate,
    required this.format,
    required this.onHorizonChanged,
    required this.onCustomDateChanged,
  });

  final PrognosisHorizon horizon;
  final DateTime? customDate;
  final LocaleFormatting format;
  final ValueChanged<PrognosisHorizon> onHorizonChanged;
  final ValueChanged<DateTime> onCustomDateChanged;

  @override
  State<_HorizonPicker> createState() => _HorizonPickerState();
}

class _HorizonPickerState extends State<_HorizonPicker> {
  /// What the dropdown shows. It parts from the settings for as long as the
  /// calendar is open, since picking the date entry is only a request for one.
  late PrognosisHorizon _shown = widget.horizon;

  @override
  void didUpdateWidget(_HorizonPicker old) {
    super.didUpdateWidget(old);
    if (widget.horizon != old.horizon) _shown = widget.horizon;
  }

  String _label(AppLocalizations l10n, PrognosisHorizon value) {
    final picked = widget.customDate;
    if (value.needsDate && picked != null) {
      return l10n.prognosisHorizonUntil(widget.format.formatMediumDate(picked));
    }
    return l10n.labelForPrognosisHorizon(value);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final stored = widget.customDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: stored != null && !stored.isBefore(tomorrow)
          ? stored
          : tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(today.year + 10, today.month, today.day),
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _shown = widget.horizon);
      return;
    }
    widget.onCustomDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          // A FormField keeps the value it was last given rather than the one
          // it is handed, so the key puts a cancelled pick back.
          child: DropdownButtonFormField<PrognosisHorizon>(
            key: ValueKey(_shown),
            initialValue: _shown,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.prognosisHorizonLabel,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: PrognosisHorizon.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_label(l10n, value)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _shown = value);
              if (value.needsDate) {
                _pickDate();
                return;
              }
              widget.onHorizonChanged(value);
            },
          ),
        ),
        if (widget.horizon.needsDate)
          IconButton(
            icon: const Icon(LucideIcons.calendar, size: 18),
            tooltip: l10n.prognosisHorizonCustomDate,
            onPressed: _pickDate,
          ),
      ],
    );
  }
}

/// Account chooser that can be typed into, as the pickers elsewhere can.
///
/// A dropdown is fine for a handful of entries and unusable for a ledger with
/// dozens, which is why every other picker in the app filters as you type.
class _AccountPicker extends StatefulWidget {
  const _AccountPicker({
    required this.accounts,
    required this.selectedAccountId,
    required this.label,
    required this.onAccountChanged,
  });

  final List<Account> accounts;
  final String? selectedAccountId;
  final String label;
  final ValueChanged<String?> onAccountChanged;

  @override
  State<_AccountPicker> createState() => _AccountPickerState();
}

class _AccountPickerState extends State<_AccountPicker> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = _selectedName ?? '';
  }

  @override
  void didUpdateWidget(_AccountPicker old) {
    super.didUpdateWidget(old);
    // Follow a selection made elsewhere, such as tapping an account card, but
    // never overwrite what someone is part-way through typing.
    if (widget.selectedAccountId != old.selectedAccountId) {
      _controller.text = _selectedName ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _selectedName => widget.accounts
      .where((account) => account.id == widget.selectedAccountId)
      .firstOrNull
      ?.name;

  void _select(String name) {
    final match = widget.accounts
        .where((account) => account.name == name)
        .firstOrNull;
    if (match == null) return;
    widget.onAccountChanged(match.id);
  }

  @override
  Widget build(BuildContext context) {
    return AutocompleteTextField(
      controller: _controller,
      suggestions: widget.accounts.map((account) => account.name).toList(),
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onSelected: _select,
      // Typing a full name straight through counts as choosing it; anything
      // else leaves the current selection alone rather than clearing the chart.
      onSubmitted: _select,
    );
  }
}
