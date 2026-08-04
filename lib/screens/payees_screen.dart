import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../providers/theme_provider.dart';
import '../router/route_query.dart';
import '../router/transactions_route.dart';
import '../theme/app_theme.dart';
import '../widgets/payee_form_dialog.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/entity_header_actions.dart';
import '../widgets/entity_linking_dialog.dart';
import '../widgets/entity_list_layout.dart';
import '../widgets/entity_screen_header.dart';

class PayeesScreen extends ConsumerWidget {
  const PayeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final searchQuery =
        RouteQuery.searchFrom(GoRouterState.of(context).uri) ?? '';

    final payeesAsync = ref.watch(payeesProvider);

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: payeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.errorGeneric(e.toString()))),
        data: (payees) {
          final filtered = payees
              .where(
                (p) =>
                    searchQuery.isEmpty ||
                    p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    (p.iban != null &&
                        p.iban!.toLowerCase().contains(
                          searchQuery.toLowerCase(),
                        )),
              )
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntityScreenHeader(
                  title: 'Payees',
                  subtitle:
                      'Manage merchants, stores, and payees (destination accounts).',
                  createLabel: 'New Payee',
                  onCreate: () =>
                      showPayeeFormDialog(context: context, ref: ref),
                  trailing: [
                    _PayeeSearchBox(
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
                            ? 'No payees found. Create your first payee!'
                            : 'No payees matching "$searchQuery".',
                        style: TextStyle(color: colors.text3, fontSize: 14),
                      ),
                    ),
                  )
                else
                  EntityListLayout(
                    gridItems: filtered
                        .map((p) => _PayeeCard(payee: p))
                        .toList(),
                    compactItems: filtered
                        .map((p) => _PayeeRow(payee: p))
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

class _PayeeCard extends ConsumerWidget {
  final Account payee;
  const _PayeeCard({required this.payee});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Payee',
      message:
          'Are you sure you want to delete the payee "${payee.name}"? It will be deleted from all associated transactions.',
      confirmLabel: 'Delete Payee',
    );
    if (confirmed == true) {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        try {
          await service.deleteAccount(payee.id);
          ref.invalidate(payeesProvider);
          ref.invalidate(counterpartyAccountsProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete payee: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Card(
      color: colors.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: () =>
            context.go(TransactionsRoute.location(account: payee.name)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.accent.acc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.store,
                      color: colors.accent.acc,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payee.name,
                          style: TextStyle(
                            fontFamily: 'Comfortaa',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: colors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (payee.iban != null && payee.iban!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            payee.iban!,
                            style: TextStyle(color: colors.text3, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  EntityHeaderActions(
                    onLink: () => showEntityLinkingDialog(
                      context: context,
                      ref: ref,
                      sourceType: EntityLinkingSourceType.payee,
                      sourceName: payee.name,
                    ),
                    onEdit: () => showPayeeFormDialog(
                      context: context,
                      ref: ref,
                      payee: payee,
                    ),
                    onDelete: () => _delete(context, ref),
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

class _PayeeRow extends ConsumerWidget {
  final Account payee;
  const _PayeeRow({required this.payee});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Payee',
      message:
          'Are you sure you want to delete the payee "${payee.name}"? It will be deleted from all associated transactions.',
      confirmLabel: 'Delete Payee',
    );
    if (confirmed == true) {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        try {
          await service.deleteAccount(payee.id);
          ref.invalidate(payeesProvider);
          ref.invalidate(counterpartyAccountsProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete payee: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.go(TransactionsRoute.location(account: payee.name)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.store, color: colors.accent.acc, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payee.name,
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colors.text,
                      ),
                    ),
                    if (payee.iban != null && payee.iban!.isNotEmpty)
                      Text(
                        payee.iban!,
                        style: TextStyle(color: colors.text3, fontSize: 11),
                      ),
                  ],
                ),
              ),
              EntityHeaderActions(
                onLink: () => showEntityLinkingDialog(
                  context: context,
                  ref: ref,
                  sourceType: EntityLinkingSourceType.payee,
                  sourceName: payee.name,
                ),
                onEdit: () => showPayeeFormDialog(
                  context: context,
                  ref: ref,
                  payee: payee,
                ),
                onDelete: () => _delete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayeeSearchBox extends ConsumerStatefulWidget {
  final String searchQuery;
  final Uri uri;

  const _PayeeSearchBox({required this.searchQuery, required this.uri});

  @override
  ConsumerState<_PayeeSearchBox> createState() => _PayeeSearchBoxState();
}

class _PayeeSearchBoxState extends ConsumerState<_PayeeSearchBox> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _PayeeSearchBox oldWidget) {
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
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);

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
