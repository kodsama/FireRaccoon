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
import '../l10n/l10n_extensions.dart';
import '../widgets/entity_list_layout.dart';
import '../widgets/prognosis_band_chart.dart';

/// Deep-link alias — use [ProjectionScreen] / `/projection` in the app shell.
class PrognosisScreen extends StatelessWidget {
  const PrognosisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrognosisView();
  }
}

/// Account balance projection: real cash-flow vs speculative trend forecast.
class PrognosisView extends ConsumerStatefulWidget {
  const PrognosisView({super.key});

  @override
  ConsumerState<PrognosisView> createState() => _PrognosisViewState();
}

class _PrognosisViewState extends ConsumerState<PrognosisView>
    with SingleTickerProviderStateMixin {
  String? _selectedAccountId;
  late final TabController _modeTabController;

  @override
  void initState() {
    super.initState();
    final initialMode = ref.read(prognosisSettingsProvider).mode;
    _modeTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialMode == PrognosisViewMode.expected ? 0 : 1,
    );
    _modeTabController.addListener(_syncModeFromTab);
  }

  void _syncModeFromTab() {
    if (_modeTabController.indexIsChanging) return;
    final mode = _modeTabController.index == 0
        ? PrognosisViewMode.expected
        : PrognosisViewMode.projected;
    final current = ref.read(prognosisSettingsProvider).mode;
    if (mode != current) {
      ref.read(prognosisSettingsProvider.notifier).setMode(mode);
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Projection view mode changed',
            details: 'Projection mode: ${current.name} -> ${mode.name}',
            type: UndoActionType.prognosisMode,
            undoPayload: {'mode': current.name},
            redoPayload: {'mode': mode.name},
          );
    }
  }

  @override
  void dispose() {
    _modeTabController.removeListener(_syncModeFromTab);
    _modeTabController.dispose();
    super.dispose();
  }

  List<Account> _visibleAccounts(
    List<Account> accounts,
    AccountPrognosisResult prognosis,
  ) {
    return accounts
        .where((account) => prognosis.forAccount(account.id) != null)
        .toList();
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
      error: (error, _) =>
          Center(child: Text(l10n.errorGeneric(error.toString()))),
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

        final tabIndex = settings.mode == PrognosisViewMode.expected ? 0 : 1;
        if (_modeTabController.index != tabIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _modeTabController.index == tabIndex) return;
            _modeTabController.animateTo(tabIndex);
          });
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModeTabs(controller: _modeTabController),
              const SizedBox(height: 6),
              Text(
                settings.mode == PrognosisViewMode.expected
                    ? l10n.prognosisModeExpectedHint
                    : l10n.prognosisModeProjectedHint,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.text3,
                  height: 1.35,
                ),
              ),
              if (settings.mode == PrognosisViewMode.expected) ...[
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
              ],
              const SizedBox(height: 14),
              _ChartPanel(
                prognosis: prognosis,
                selected: selected,
                selectedAccount: selectedAccount,
                visibleAccounts: visibleAccounts,
                selectedAccountId: selectedId,
                format: format,
                marginPercent: settings.marginPercent,
                mode: settings.mode,
                horizon: settings.horizon,
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
                        mode: settings.mode,
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
                        mode: settings.mode,
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

class _ModeTabs extends StatelessWidget {
  final TabController controller;

  const _ModeTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return TabBar(
      controller: controller,
      indicatorColor: colors.accent.acc,
      indicatorWeight: 2.5,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: colors.border,
      dividerHeight: 1,
      labelColor: colors.text,
      unselectedLabelColor: colors.text3,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      tabs: [
        Tab(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.calendarClock, size: 15),
              const SizedBox(width: 7),
              Text(l10n.prognosisModeExpected),
            ],
          ),
        ),
        Tab(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.trendingUp, size: 15),
              const SizedBox(width: 7),
              Text(l10n.prognosisModeProjected),
            ],
          ),
        ),
      ],
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
  final PrognosisViewMode mode;
  final PrognosisHorizon horizon;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<double> onMarginChanged;
  final ValueChanged<PrognosisHorizon> onHorizonChanged;

  const _ChartPanel({
    required this.prognosis,
    required this.selected,
    required this.selectedAccount,
    required this.visibleAccounts,
    required this.selectedAccountId,
    required this.format,
    required this.marginPercent,
    required this.mode,
    required this.horizon,
    required this.onAccountChanged,
    required this.onMarginChanged,
    required this.onHorizonChanged,
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
                  child: DropdownButtonFormField<String?>(
                    initialValue: selectedAccountId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.prognosisSelectAccount,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: visibleAccounts
                        .map(
                          (account) => DropdownMenuItem(
                            value: account.id,
                            child: Text(
                              account.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onAccountChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<PrognosisHorizon>(
                    initialValue: horizon,
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
                            child: Text(l10n.labelForPrognosisHorizon(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onHorizonChanged(value);
                    },
                  ),
                ),
              ],
            ),
            if (mode == PrognosisViewMode.expected) ...[
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
                    l10n.prognosisMarginDetail(
                      marginPercent.round().toString(),
                    ),
                    style: TextStyle(color: colors.text3, fontSize: 11),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
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
            ],
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
                mode: mode,
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
  final PrognosisViewMode mode;

  const _SelectedAccountBalances({
    required this.account,
    required this.prognosis,
    required this.format,
    required this.mode,
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
        if (mode == PrognosisViewMode.expected) ...[
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
        ],
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
  final PrognosisViewMode mode;
  final VoidCallback onTap;
  final bool selected;

  const _AccountPrognosisCard({
    required this.account,
    required this.prognosis,
    required this.format,
    required this.mode,
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
            if (mode == PrognosisViewMode.expected) ...[
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
            ],
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
  final PrognosisViewMode mode;
  final VoidCallback onTap;
  final bool selected;

  const _AccountPrognosisCompactRow({
    required this.account,
    required this.prognosis,
    required this.format,
    required this.mode,
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
                  if (mode == PrognosisViewMode.expected) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.prognosisMinBalance}: '
                      '${format.formatMoney(prognosis.endOfMonth.pessimistic, currency)} · '
                      '${l10n.prognosisMaxBalance}: '
                      '${format.formatMoney(prognosis.endOfMonth.optimistic, currency)}',
                      style: TextStyle(color: colors.text3, fontSize: 12),
                    ),
                  ],
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
