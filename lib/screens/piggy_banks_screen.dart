import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../providers/undo_history_provider.dart';
import '../providers/theme_provider.dart';
import '../router/route_query.dart';
import '../router/transactions_route.dart';
import '../theme/app_theme.dart';
import '../utils/create_flows.dart';
import '../utils/locale_formatting.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/entity_header_actions.dart';
import '../widgets/entity_list_layout.dart';
import '../widgets/entity_screen_header.dart';
import '../widgets/piggy_bank_form_dialog.dart';

class PiggyBanksScreen extends ConsumerWidget {
  const PiggyBanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final piggyBanksAsync = ref.watch(piggyBanksProvider);

    final searchQuery =
        RouteQuery.searchFrom(GoRouterState.of(context).uri) ?? '';

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: piggyBanksAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.errorGeneric(e.toString()))),
        data: (piggyBanks) {
          final filtered = piggyBanks
              .where(
                (p) =>
                    searchQuery.isEmpty ||
                    p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    p.currencyCode.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ),
              )
              .toList();

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntityScreenHeader(
                  title: fun.piggyBanksTitle,
                  createLabel: fun.newPiggyBank,
                  onCreate: () => openCreatePiggyBankDialog(context, ref),
                  trailing: [
                    _PiggyBankSearchBox(
                      searchQuery: searchQuery,
                      uri: GoRouterState.of(context).uri,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (filtered.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        searchQuery.isEmpty
                            ? l10n.noPiggyBanksFound
                            : 'No piggy banks matching "$searchQuery".',
                        style: TextStyle(color: colors.text3, fontSize: 14),
                      ),
                    ),
                  )
                else
                  EntityListLayout(
                    gridItems: filtered
                        .map((p) => _PiggyBankCard(piggyBank: p))
                        .toList(),
                    compactItems: filtered
                        .map((p) => _PiggyBankCompactRow(piggyBank: p))
                        .toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PiggyBankCard extends ConsumerWidget {
  final PiggyBank piggyBank;

  const _PiggyBankCard({required this.piggyBank});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmationDialog(
      context: context,
      title: l10n.deletePiggyBank,
      message: l10n.deletePiggyBankConfirmBody(piggyBank.name),
      confirmLabel: l10n.delete,
    );
    if (confirmed != true) return;

    try {
      final service = ref.read(apiServiceProvider);
      await service?.deletePiggyBank(piggyBank.id);
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Piggy bank deleted',
            details: 'Deleted piggy bank "${piggyBank.name}"',
            type: UndoActionType.piggyBankDelete,
            undoPayload: {
              'name': piggyBank.name,
              'targetAmount': piggyBank.targetAmount,
              'currencyCode': piggyBank.currencyCode,
              'accountIds': piggyBank.accounts.map((a) => a.accountId).toList(),
              'startDate': piggyBank.startDate.toIso8601String(),
              'targetDate': piggyBank.targetDate?.toIso8601String(),
              'notes': piggyBank.notes,
              'objectGroupTitle': piggyBank.objectGroupTitle,
            },
            redoPayload: {'piggyBankId': piggyBank.id},
          );
      ref.invalidate(piggyBanksProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.piggyBankDeleted(piggyBank.name))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToDeletePiggyBank(e.toString()))),
        );
      }
    }
  }

  void _edit(BuildContext context, WidgetRef ref) {
    showPiggyBankFormDialog(context: context, ref: ref, piggyBank: piggyBank);
  }

  void _openTransactions(BuildContext context) {
    final linkedAccountNames = piggyBank.accounts.map((a) => a.name).toList();
    if (linkedAccountNames.isEmpty) {
      context.go(TransactionsRoute.location());
      return;
    }
    context.go(TransactionsRoute.location(accounts: linkedAccountNames));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);
    final progress = piggyBank.targetAmount > 0
        ? piggyBank.currentAmount / piggyBank.targetAmount
        : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTransactions(context),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.piggyBank,
                      size: 18,
                      color: colors.accent.acc,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        piggyBank.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    EntityHeaderActions(
                      onEdit: () => _edit(context, ref),
                      onDelete: () => _delete(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.piggyBankProgress(
                    format.formatMoney(
                      piggyBank.currentAmount,
                      piggyBank.currencySymbol,
                    ),
                    format.formatMoney(
                      piggyBank.targetAmount,
                      piggyBank.currencySymbol,
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'Roboto Slab',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: colors.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colors.accent.acc,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (piggyBank.percentage != null)
                  Text(
                    '${piggyBank.percentage}%',
                    style: TextStyle(color: colors.text2, fontSize: 12),
                  ),
                if (piggyBank.accounts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    piggyBank.accounts.map((a) => a.name).join(', '),
                    style: TextStyle(color: colors.text3, fontSize: 12),
                  ),
                ],
                if (piggyBank.targetDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.targetDate}: ${format.formatMediumDate(piggyBank.targetDate!)}',
                    style: TextStyle(color: colors.text3, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PiggyBankCompactRow extends _PiggyBankCard {
  const _PiggyBankCompactRow({required super.piggyBank});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTransactions(context),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(LucideIcons.piggyBank, size: 16, color: colors.accent.acc),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      piggyBank.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.piggyBankProgress(
                        format.formatMoney(
                          piggyBank.currentAmount,
                          piggyBank.currencySymbol,
                        ),
                        format.formatMoney(
                          piggyBank.targetAmount,
                          piggyBank.currencySymbol,
                        ),
                      ),
                      style: TextStyle(color: colors.text2, fontSize: 12),
                    ),
                  ],
                ),
              ),
              EntityHeaderActions(
                onEdit: () => _edit(context, ref),
                onDelete: () => _delete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PiggyBankSearchBox extends ConsumerStatefulWidget {
  final String searchQuery;
  final Uri uri;

  const _PiggyBankSearchBox({required this.searchQuery, required this.uri});

  @override
  ConsumerState<_PiggyBankSearchBox> createState() =>
      _PiggyBankSearchBoxState();
}

class _PiggyBankSearchBoxState extends ConsumerState<_PiggyBankSearchBox> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _PiggyBankSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text &&
        widget.searchQuery != oldWidget.searchQuery) {
      _controller.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    context.go(RouteQuery.withSearch(widget.uri, val));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);

    return SizedBox(
      width: 220,
      height: 36,
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        style: TextStyle(color: colors.text, fontSize: 13),
        decoration: InputDecoration(
          hintText: fun.search,
          hintStyle: TextStyle(color: colors.text3, fontSize: 13),
          prefixIcon: Icon(LucideIcons.search, size: 15, color: colors.text3),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x, size: 14, color: colors.text3),
                  onPressed: () {
                    _controller.clear();
                    _onSearchChanged('');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          filled: true,
          fillColor: colors.surface2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.accent.acc, width: 1.5),
          ),
        ),
      ),
    );
  }
}
