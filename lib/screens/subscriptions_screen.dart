import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:go_router/go_router.dart';
import '../l10n/l10n_extensions.dart';
import '../router/route_query.dart';
import '../providers/data_providers.dart';
import '../providers/undo_history_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/create_flows.dart';
import '../utils/locale_formatting.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/entity_header_actions.dart';
import '../widgets/entity_list_layout.dart';
import '../widgets/entity_screen_header.dart';
import '../widgets/expandable_entity_shell.dart';
import '../widgets/transactions_expanded_panel.dart';
import '../widgets/recurring_transaction_form_dialog.dart';
import '../widgets/subscription_form_dialog.dart';

enum _RecurringEntryKind { subscription, recurringTransaction }

class _RecurringEntry {
  final _RecurringEntryKind kind;
  final Bill? bill;
  final Recurrence? recurrence;

  const _RecurringEntry._({required this.kind, this.bill, this.recurrence});

  factory _RecurringEntry.subscription(Bill bill) =>
      _RecurringEntry._(kind: _RecurringEntryKind.subscription, bill: bill);

  factory _RecurringEntry.recurringTransaction(Recurrence recurrence) =>
      _RecurringEntry._(
        kind: _RecurringEntryKind.recurringTransaction,
        recurrence: recurrence,
      );

  String get sortKey => switch (kind) {
    _RecurringEntryKind.subscription => bill!.name.toLowerCase(),
    _RecurringEntryKind.recurringTransaction => recurrence!.title.toLowerCase(),
  };
}

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final billsAsync = ref.watch(billsProvider);
    final recurrencesAsync = ref.watch(recurrencesProvider);

    final searchQuery =
        RouteQuery.searchFrom(GoRouterState.of(context).uri) ?? '';

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntityScreenHeader(
              title: fun.subscriptionsTitle,
              trailing: [
                _SubscriptionSearchBox(
                  searchQuery: searchQuery,
                  uri: GoRouterState.of(context).uri,
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: fun.newSubscription,
                  child: ElevatedButton.icon(
                    onPressed: () => openCreateSubscriptionDialog(context, ref),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: Text(l10n.addSubscription),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent.acc,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.newRecurringTransaction,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        openCreateRecurringTransactionDialog(context, ref),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: Text(l10n.addRecurringTransaction),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.surface2,
                      foregroundColor: colors.text,
                      side: BorderSide(color: colors.border),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _CombinedList(
                billsAsync: billsAsync,
                recurrencesAsync: recurrencesAsync,
                searchQuery: searchQuery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CombinedList extends StatelessWidget {
  final AsyncValue<List<Bill>> billsAsync;
  final AsyncValue<List<Recurrence>> recurrencesAsync;
  final String searchQuery;

  const _CombinedList({
    required this.billsAsync,
    required this.recurrencesAsync,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    if (billsAsync.isLoading || recurrencesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = billsAsync.error ?? recurrencesAsync.error;
    if (error != null) {
      return Center(child: Text(l10n.errorGeneric(error.toString())));
    }

    final bills = billsAsync.value ?? const [];
    final recurrences = recurrencesAsync.value ?? const [];
    final allEntries = [
      ...bills.map(_RecurringEntry.subscription),
      ...recurrences.map(_RecurringEntry.recurringTransaction),
    ]..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    final entries = allEntries.where((e) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return e.sortKey.contains(q);
    }).toList();

    if (entries.isEmpty) {
      return Center(
        child: Text(
          l10n.noSubscriptionsOrRecurrencesFound,
          style: TextStyle(color: colors.text3),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: EntityListLayout(
        gridItems: entries
            .map(
              (entry) => switch (entry.kind) {
                _RecurringEntryKind.subscription => _SubscriptionCard(
                  bill: entry.bill!,
                ),
                _RecurringEntryKind.recurringTransaction =>
                  _RecurringTransactionCard(recurrence: entry.recurrence!),
              },
            )
            .toList(),
        compactItems: entries
            .map(
              (entry) => switch (entry.kind) {
                _RecurringEntryKind.subscription => _SubscriptionCompactRow(
                  bill: entry.bill!,
                ),
                _RecurringEntryKind.recurringTransaction =>
                  _RecurringTransactionCompactRow(
                    recurrence: entry.recurrence!,
                  ),
              },
            )
            .toList(),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  final _RecurringEntryKind kind;

  const _KindBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isSubscription = kind == _RecurringEntryKind.subscription;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSubscription
            ? colors.accent.acc.withValues(alpha: 0.12)
            : colors.text3.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isSubscription
            ? l10n.badgeSubscription
            : l10n.badgeRecurringTransaction,
        style: TextStyle(
          color: isSubscription ? colors.accent.acc : colors.text2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Expand-to-load state shared by subscription and recurring cards: fetches
/// the entry's linked transactions (one page of 20) on first expansion.
mixin _LinkedTransactionsState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool _expanded = false;
  bool _loadingTx = false;
  List<Transaction>? _transactions;
  String? _loadError;

  Future<TransactionPageResult> fetchLinkedTransactions(FireflyService service);

  /// Free-text query used to find historical matches when the entry has no
  /// server-linked transactions (e.g. history imported before the recurring
  /// definition existed).
  String get searchFallbackQuery;

  /// Upcoming occurrences shown as planned rows in the expanded panel.
  List<PlannedOccurrence> plannedOccurrences() => const [];

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      if (_transactions == null && !_loadingTx) _loadTransactions();
    } else {
      _transactions = null;
      _loadingTx = false;
      _loadError = null;
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loadingTx = true;
      _loadError = null;
    });
    try {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        var rows = (await fetchLinkedTransactions(service)).transactions;
        if (rows.isEmpty && searchFallbackQuery.trim().isNotEmpty) {
          rows = (await service.searchTransactionsPage(
            searchFallbackQuery,
            page: 1,
            limit: 20,
          )).transactions;
        }
        if (mounted) {
          setState(() {
            _transactions = rows;
            _loadingTx = false;
            _loadError = null;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingTx = false;
          _transactions = null;
          _loadError = context.l10n.errorLoadingData('$error');
        });
      }
    }
  }

  Widget _transactionsPanel(BuildContext context) {
    return TransactionsExpandedPanel(
      loading: _loadingTx,
      transactions: _transactions,
      errorMessage: _loadError,
      emptyLabel: context.l10n.noTransactionsYet,
      plannedOccurrences: plannedOccurrences(),
      onTransactionMutated: _loadTransactions,
    );
  }
}

const _plannedHorizonDays = 90;
const _maxPlannedRows = 4;

Future<void> _deleteBill(BuildContext context, WidgetRef ref, Bill bill) async {
  final l10n = context.l10n;
  final confirmed = await showConfirmationDialog(
    context: context,
    title: l10n.deleteSubscription,
    message: l10n.deleteSubscriptionConfirmBody(bill.name),
    confirmLabel: l10n.delete,
  );
  if (confirmed != true) return;

  try {
    final service = ref.read(apiServiceProvider);
    await service?.deleteBill(bill.id);
    ref
        .read(undoHistoryProvider.notifier)
        .record(
          title: 'Subscription deleted',
          details: 'Deleted subscription "${bill.name}"',
          type: UndoActionType.billDelete,
          undoPayload: {
            'name': bill.name,
            'amountMin': bill.amountMin,
            'amountMax': bill.amountMax,
            'currencyCode': bill.currencyCode,
            'date': bill.date.toIso8601String(),
            'repeatFrequency': bill.repeatFrequency.name,
            'skip': bill.skip,
            'active': bill.active,
            'endDate': bill.endDate?.toIso8601String(),
            'extensionDate': bill.extensionDate?.toIso8601String(),
            'notes': bill.notes,
            'objectGroupTitle': bill.objectGroupTitle,
          },
          redoPayload: {'billId': bill.id},
        );
    ref.invalidate(billsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.subscriptionDeleted(bill.name))),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToDeleteSubscription(e.toString()))),
      );
    }
  }
}

void _editBill(BuildContext context, WidgetRef ref, Bill bill) {
  showSubscriptionFormDialog(context: context, ref: ref, bill: bill);
}

String _billRepeatLabel(BuildContext context, BillRepeatFrequency frequency) {
  final l10n = context.l10n;
  return switch (frequency) {
    BillRepeatFrequency.weekly => l10n.repeatWeekly,
    BillRepeatFrequency.monthly => l10n.repeatMonthly,
    BillRepeatFrequency.quarterly => l10n.repeatQuarterly,
    BillRepeatFrequency.halfYear => l10n.repeatHalfYear,
    BillRepeatFrequency.yearly => l10n.repeatYearly,
  };
}

class _SubscriptionCard extends ConsumerStatefulWidget {
  final Bill bill;

  const _SubscriptionCard({required this.bill});

  @override
  ConsumerState<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends ConsumerState<_SubscriptionCard>
    with _LinkedTransactionsState {
  @override
  Future<TransactionPageResult> fetchLinkedTransactions(
    FireflyService service,
  ) {
    return service.getBillTransactionsPage(widget.bill.id, page: 1, limit: 20);
  }

  @override
  String get searchFallbackQuery => widget.bill.name;

  @override
  List<PlannedOccurrence> plannedOccurrences() {
    final now = DateTime.now();
    final dates = expandBillOccurrences(
      bill: widget.bill,
      rangeStart: now,
      rangeEnd: now.add(const Duration(days: _plannedHorizonDays)),
    );
    return [
      for (final date in dates.take(_maxPlannedRows))
        (
          date: date,
          amount: widget.bill.amountAvg,
          description: widget.bill.name,
          currencySymbol: widget.bill.currencySymbol,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);
    final bill = widget.bill;

    return ExpandableEntityCard(
      expanded: _expanded,
      onToggleExpand: _toggleExpand,
      expandedChild: _transactionsPanel(context),
      header: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _KindBadge(kind: _RecurringEntryKind.subscription),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bill.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                EntityHeaderActions(
                  leading: [
                    if (!bill.active)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.text3.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.subscriptionInactive,
                          style: TextStyle(
                            color: colors.text3,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                  onEdit: () => _editBill(context, ref, bill),
                  onDelete: () => _deleteBill(context, ref, bill),
                ),
                ExpandChevron(expanded: _expanded),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(LucideIcons.repeat, size: 16, color: colors.text3),
                const SizedBox(width: 8),
                Text(
                  _billRepeatLabel(context, bill.repeatFrequency),
                  style: TextStyle(color: colors.text2, fontSize: 13),
                ),
                if (bill.skip > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· ${l10n.skip}: ${bill.skip}',
                    style: TextStyle(color: colors.text3, fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.subscriptionAmountRange(
                format.formatMoney(bill.amountMin, bill.currencySymbol),
                format.formatMoney(bill.amountMax, bill.currencySymbol),
              ),
              style: const TextStyle(
                fontFamily: 'Roboto Slab',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.startDate}: ${format.formatMediumDate(bill.date)}',
              style: TextStyle(color: colors.text3, fontSize: 12),
            ),
            if (bill.objectGroupTitle != null &&
                bill.objectGroupTitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.group}: ${bill.objectGroupTitle}',
                style: TextStyle(color: colors.text3, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCompactRow extends ConsumerStatefulWidget {
  final Bill bill;

  const _SubscriptionCompactRow({required this.bill});

  @override
  ConsumerState<_SubscriptionCompactRow> createState() =>
      _SubscriptionCompactRowState();
}

class _SubscriptionCompactRowState
    extends ConsumerState<_SubscriptionCompactRow>
    with _LinkedTransactionsState {
  @override
  Future<TransactionPageResult> fetchLinkedTransactions(
    FireflyService service,
  ) {
    return service.getBillTransactionsPage(widget.bill.id, page: 1, limit: 20);
  }

  @override
  String get searchFallbackQuery => widget.bill.name;

  @override
  List<PlannedOccurrence> plannedOccurrences() {
    final now = DateTime.now();
    final dates = expandBillOccurrences(
      bill: widget.bill,
      rangeStart: now,
      rangeEnd: now.add(const Duration(days: _plannedHorizonDays)),
    );
    return [
      for (final date in dates.take(_maxPlannedRows))
        (
          date: date,
          amount: widget.bill.amountAvg,
          description: widget.bill.name,
          currencySymbol: widget.bill.currencySymbol,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);
    final bill = widget.bill;

    return ExpandableEntityCompactRow(
      expanded: _expanded,
      onToggleExpand: _toggleExpand,
      expandedChild: _transactionsPanel(context),
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const _KindBadge(kind: _RecurringEntryKind.subscription),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.subscriptionAmountRange(
                      format.formatMoney(bill.amountMin, bill.currencySymbol),
                      format.formatMoney(bill.amountMax, bill.currencySymbol),
                    ),
                    style: TextStyle(color: colors.text2, fontSize: 12),
                  ),
                ],
              ),
            ),
            EntityHeaderActions(
              onEdit: () => _editBill(context, ref, bill),
              onDelete: () => _deleteBill(context, ref, bill),
            ),
            ExpandChevron(expanded: _expanded),
          ],
        ),
      ),
    );
  }
}

Future<void> _deleteRecurrence(
  BuildContext context,
  WidgetRef ref,
  Recurrence recurrence,
) async {
  final l10n = context.l10n;
  final confirmed = await showConfirmationDialog(
    context: context,
    title: l10n.deleteRecurringTransaction,
    message: l10n.deleteRecurringTransactionConfirmBody(recurrence.title),
    confirmLabel: l10n.delete,
  );
  if (confirmed != true) return;

  try {
    final service = ref.read(apiServiceProvider);
    await service?.deleteRecurrence(recurrence.id);
    final rep = recurrence.primaryRepetition;
    final tx = recurrence.primaryTransaction;
    if (rep != null && tx != null) {
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Recurring transaction deleted',
            details: 'Deleted recurring transaction "${recurrence.title}"',
            type: UndoActionType.recurrenceDelete,
            undoPayload: {
              'title': recurrence.title,
              'firstDate': recurrence.firstDate.toIso8601String(),
              'repetitionType': rep.type.name,
              'repetitionMoment': rep.moment,
              'transactionType': recurrence.type.name,
              'description': tx.description,
              'amount': tx.amount,
              'sourceId': tx.sourceId ?? '',
              'destinationId': tx.destinationId ?? '',
            },
            redoPayload: {'recurrenceId': recurrence.id},
          );
    }
    ref.invalidate(recurrencesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.recurringTransactionDeleted(recurrence.title)),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failedToDeleteRecurringTransaction(e.toString())),
        ),
      );
    }
  }
}

void _editRecurrence(
  BuildContext context,
  WidgetRef ref,
  Recurrence recurrence,
) {
  showRecurringTransactionFormDialog(
    context: context,
    ref: ref,
    recurrence: recurrence,
  );
}

String _recurrenceTypeLabel(BuildContext context, Recurrence recurrence) {
  final l10n = context.l10n;
  return switch (recurrence.type) {
    RecurrenceTransactionType.withdrawal => l10n.transactionTypeWithdrawal,
    RecurrenceTransactionType.deposit => l10n.transactionTypeDeposit,
    RecurrenceTransactionType.transfer => l10n.transactionTypeTransfer,
  };
}

String _recurrenceRepetitionLabel(BuildContext context, Recurrence recurrence) {
  final l10n = context.l10n;
  final repetition = recurrence.primaryRepetition;
  if (repetition?.description != null && repetition!.description!.isNotEmpty) {
    return repetition.description!;
  }
  // Translate Firefly's skip semantics (skip = every - 1) into a human
  // interval: 'Monthly', 'Every 3 months', …
  final every = (repetition?.skip ?? 0) + 1;
  if (every > 1) {
    return switch (repetition?.type) {
      RecurrenceRepetitionType.daily => l10n.repeatEveryNDays(every),
      RecurrenceRepetitionType.weekly => l10n.repeatEveryNWeeks(every),
      RecurrenceRepetitionType.yearly => l10n.repeatEveryNYears(every),
      _ => l10n.repeatEveryNMonths(every),
    };
  }
  return switch (repetition?.type) {
    RecurrenceRepetitionType.daily => l10n.repeatDaily,
    RecurrenceRepetitionType.weekly => l10n.repeatWeekly,
    RecurrenceRepetitionType.ndom => l10n.repeatNdom,
    RecurrenceRepetitionType.monthly => l10n.repeatMonthly,
    RecurrenceRepetitionType.yearly => l10n.repeatYearly,
    null => l10n.repeatMonthly,
  };
}

class _RecurringTransactionCard extends ConsumerStatefulWidget {
  final Recurrence recurrence;

  const _RecurringTransactionCard({required this.recurrence});

  @override
  ConsumerState<_RecurringTransactionCard> createState() =>
      _RecurringTransactionCardState();
}

class _RecurringTransactionCardState
    extends ConsumerState<_RecurringTransactionCard>
    with _LinkedTransactionsState {
  @override
  Future<TransactionPageResult> fetchLinkedTransactions(
    FireflyService service,
  ) {
    return service.getRecurrenceTransactionsPage(
      widget.recurrence.id,
      page: 1,
      limit: 20,
    );
  }

  @override
  String get searchFallbackQuery =>
      widget.recurrence.primaryTransaction?.description ??
      widget.recurrence.title;

  @override
  List<PlannedOccurrence> plannedOccurrences() {
    final line = widget.recurrence.primaryTransaction;
    if (line == null) return const [];
    final now = DateTime.now();
    final dates = expandRecurrenceOccurrences(
      recurrence: widget.recurrence,
      rangeStart: now,
      rangeEnd: now.add(const Duration(days: _plannedHorizonDays)),
    );
    return [
      for (final date in dates.take(_maxPlannedRows))
        (
          date: date,
          amount: line.amount,
          description: line.description,
          currencySymbol: line.currencySymbol ?? line.currencyCode,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);
    final recurrence = widget.recurrence;
    final tx = recurrence.primaryTransaction;

    return ExpandableEntityCard(
      expanded: _expanded,
      onToggleExpand: _toggleExpand,
      expandedChild: _transactionsPanel(context),
      header: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _KindBadge(
                  kind: _RecurringEntryKind.recurringTransaction,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recurrence.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                EntityHeaderActions(
                  leading: [
                    if (!recurrence.active)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.text3.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.recurringTransactionInactive,
                          style: TextStyle(
                            color: colors.text3,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                  onEdit: () => _editRecurrence(context, ref, recurrence),
                  onDelete: () => _deleteRecurrence(context, ref, recurrence),
                ),
                ExpandChevron(expanded: _expanded),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _recurrenceTypeLabel(context, recurrence),
              style: TextStyle(color: colors.text2, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(LucideIcons.calendarClock, size: 16, color: colors.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _recurrenceRepetitionLabel(context, recurrence),
                    style: TextStyle(color: colors.text2, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (tx != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.recurrenceAmount(
                  format.formatMoney(
                    tx.amount,
                    tx.currencySymbol ?? tx.currencyCode,
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'Roboto Slab',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (tx.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  tx.description,
                  style: TextStyle(color: colors.text3, fontSize: 12),
                ),
              ],
            ],
            const SizedBox(height: 8),
            Text(
              '${l10n.firstDate}: ${format.formatMediumDate(recurrence.firstDate)}',
              style: TextStyle(color: colors.text3, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTransactionCompactRow extends ConsumerStatefulWidget {
  final Recurrence recurrence;

  const _RecurringTransactionCompactRow({required this.recurrence});

  @override
  ConsumerState<_RecurringTransactionCompactRow> createState() =>
      _RecurringTransactionCompactRowState();
}

class _RecurringTransactionCompactRowState
    extends ConsumerState<_RecurringTransactionCompactRow>
    with _LinkedTransactionsState {
  @override
  Future<TransactionPageResult> fetchLinkedTransactions(
    FireflyService service,
  ) {
    return service.getRecurrenceTransactionsPage(
      widget.recurrence.id,
      page: 1,
      limit: 20,
    );
  }

  @override
  String get searchFallbackQuery =>
      widget.recurrence.primaryTransaction?.description ??
      widget.recurrence.title;

  @override
  List<PlannedOccurrence> plannedOccurrences() {
    final line = widget.recurrence.primaryTransaction;
    if (line == null) return const [];
    final now = DateTime.now();
    final dates = expandRecurrenceOccurrences(
      recurrence: widget.recurrence,
      rangeStart: now,
      rangeEnd: now.add(const Duration(days: _plannedHorizonDays)),
    );
    return [
      for (final date in dates.take(_maxPlannedRows))
        (
          date: date,
          amount: line.amount,
          description: line.description,
          currencySymbol: line.currencySymbol ?? line.currencyCode,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);
    final recurrence = widget.recurrence;
    final tx = recurrence.primaryTransaction;

    return ExpandableEntityCompactRow(
      expanded: _expanded,
      onToggleExpand: _toggleExpand,
      expandedChild: _transactionsPanel(context),
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const _KindBadge(kind: _RecurringEntryKind.recurringTransaction),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recurrence.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  if (tx != null)
                    Text(
                      l10n.recurrenceAmount(
                        format.formatMoney(
                          tx.amount,
                          tx.currencySymbol ?? tx.currencyCode,
                        ),
                      ),
                      style: TextStyle(color: colors.text2, fontSize: 12),
                    ),
                ],
              ),
            ),
            EntityHeaderActions(
              onEdit: () => _editRecurrence(context, ref, recurrence),
              onDelete: () => _deleteRecurrence(context, ref, recurrence),
            ),
            ExpandChevron(expanded: _expanded),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionSearchBox extends ConsumerStatefulWidget {
  final String searchQuery;
  final Uri uri;

  const _SubscriptionSearchBox({required this.searchQuery, required this.uri});

  @override
  ConsumerState<_SubscriptionSearchBox> createState() =>
      _SubscriptionSearchBoxState();
}

class _SubscriptionSearchBoxState
    extends ConsumerState<_SubscriptionSearchBox> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _SubscriptionSearchBox oldWidget) {
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
