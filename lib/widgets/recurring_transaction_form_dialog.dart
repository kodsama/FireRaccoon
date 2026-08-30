import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../providers/suggestion_providers.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_feedback.dart';
import '../utils/autocomplete_suggestions.dart';
import '../utils/locale_formatting.dart';
import 'autocomplete_text_field.dart';
import 'tooltip_helpers.dart';

Future<bool?> showRecurringTransactionFormDialog({
  required BuildContext context,
  required WidgetRef ref,
  Recurrence? recurrence,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _RecurringTransactionFormDialog(recurrence: recurrence),
  ).then((saved) {
    if (saved == true) {
      ref.invalidate(recurrencesProvider);
    }
    return saved;
  });
}

class _RecurringTransactionFormDialog extends ConsumerStatefulWidget {
  final Recurrence? recurrence;

  const _RecurringTransactionFormDialog({this.recurrence});

  bool get isEditing => recurrence != null;

  @override
  ConsumerState<_RecurringTransactionFormDialog> createState() =>
      _RecurringTransactionFormDialogState();
}

class _RecurringTransactionFormDialogState
    extends ConsumerState<_RecurringTransactionFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _recurrenceDescriptionController;
  late final TextEditingController _transactionDescriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _foreignAmountController;
  late int _intervalEvery;
  late final TextEditingController _repetitionCountController;
  late final TextEditingController _tagsController;
  late final TextEditingController _notesController;

  late DateTime _firstDate;
  DateTime? _repeatUntil;
  RecurrenceTransactionType _type = RecurrenceTransactionType.withdrawal;
  RecurrenceRepetitionType _repetitionType = RecurrenceRepetitionType.monthly;
  RecurrenceWeekendMode _weekendMode = RecurrenceWeekendMode.createAnyway;
  RecurrenceEndMode _endMode = RecurrenceEndMode.forever;
  String _currencyCode = 'EUR';
  String? _foreignCurrencyCode;
  String? _sourceId;
  String? _destinationId;
  String? _budgetId;
  String? _categoryId;
  String? _billId;
  String? _transactionLineId;
  bool _active = true;
  bool _applyRules = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final recurrence = widget.recurrence;
    final tx = recurrence?.primaryTransaction;
    final repetition = recurrence?.primaryRepetition;

    _titleController = TextEditingController(text: recurrence?.title ?? '');
    _recurrenceDescriptionController = TextEditingController(
      text: recurrence?.description ?? '',
    );
    _transactionDescriptionController = TextEditingController(
      text: tx?.description ?? '',
    );
    _amountController = TextEditingController(
      text: tx != null && tx.amount > 0 ? tx.amount.toStringAsFixed(2) : '',
    );
    _foreignAmountController = TextEditingController(
      text: tx?.foreignAmount?.toStringAsFixed(2) ?? '',
    );
    _intervalEvery = (repetition?.skip ?? 0) + 1;
    _repetitionCountController = TextEditingController(
      text: recurrence?.nrOfRepetitions?.toString() ?? '',
    );
    _tagsController = TextEditingController(text: tx?.tags.join(', ') ?? '');
    _notesController = TextEditingController(text: recurrence?.notes ?? '');

    _firstDate =
        recurrence?.firstDate ?? DateTime.now().add(const Duration(days: 1));
    _repeatUntil = recurrence?.repeatUntil;
    _type = recurrence?.type ?? RecurrenceTransactionType.withdrawal;
    _repetitionType = repetition?.type ?? RecurrenceRepetitionType.monthly;
    _weekendMode = repetition?.weekend ?? RecurrenceWeekendMode.createAnyway;
    _endMode = recurrence?.nrOfRepetitions != null
        ? RecurrenceEndMode.repetitionCount
        : recurrence?.repeatUntil != null
        ? RecurrenceEndMode.untilDate
        : RecurrenceEndMode.forever;
    _currencyCode = tx?.currencyCode ?? 'EUR';
    _foreignCurrencyCode = tx?.foreignCurrencyCode;
    _sourceId = tx?.sourceId;
    _destinationId = tx?.destinationId;
    _budgetId = tx?.budgetId;
    _categoryId = tx?.categoryId;
    _billId = tx?.billId;
    _transactionLineId = tx?.id;
    _active = recurrence?.active ?? true;
    _applyRules = recurrence?.applyRules ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _recurrenceDescriptionController.dispose();
    _transactionDescriptionController.dispose();
    _amountController.dispose();
    _foreignAmountController.dispose();
    _repetitionCountController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<Account> _accountsForField(List<Account> accounts, bool isSource) {
    bool isAssetLike(Account a) => a.type == 'asset' || a.type == 'cash';
    return switch (_type) {
      RecurrenceTransactionType.withdrawal =>
        isSource
            ? accounts.where(isAssetLike).toList()
            : accounts.where((a) => a.type == 'expense').toList(),
      RecurrenceTransactionType.deposit =>
        isSource
            ? accounts.where((a) => a.type == 'revenue').toList()
            : accounts.where(isAssetLike).toList(),
      RecurrenceTransactionType.transfer =>
        accounts.where(isAssetLike).toList(),
    };
  }

  String _sourceAccountLabel(dynamic l10n) => switch (_type) {
    RecurrenceTransactionType.deposit => l10n.revenueAccount,
    RecurrenceTransactionType.withdrawal => l10n.assetAccount,
    RecurrenceTransactionType.transfer => l10n.sourceAccount,
  };

  String _destinationAccountLabel(dynamic l10n) => switch (_type) {
    RecurrenceTransactionType.deposit => l10n.assetAccount,
    RecurrenceTransactionType.withdrawal => l10n.expenseAccount,
    RecurrenceTransactionType.transfer => l10n.destinationAccount,
  };

  /// Human interval label: 'Monthly', 'Every 2 months', … The Firefly
  /// payload keeps its skip semantics (skip = every - 1).
  String _intervalLabel(dynamic l10n, int every) {
    if (every == 1) {
      return switch (_repetitionType) {
        RecurrenceRepetitionType.daily => l10n.repeatDaily,
        RecurrenceRepetitionType.weekly => l10n.repeatWeekly,
        RecurrenceRepetitionType.ndom ||
        RecurrenceRepetitionType.monthly => l10n.repeatMonthly,
        RecurrenceRepetitionType.yearly => l10n.repeatYearly,
      };
    }
    return switch (_repetitionType) {
      RecurrenceRepetitionType.daily => l10n.repeatEveryNDays(every),
      RecurrenceRepetitionType.weekly => l10n.repeatEveryNWeeks(every),
      RecurrenceRepetitionType.ndom ||
      RecurrenceRepetitionType.monthly => l10n.repeatEveryNMonths(every),
      RecurrenceRepetitionType.yearly => l10n.repeatEveryNYears(every),
    };
  }

  String _repetitionLabel(RecurrenceRepetitionType type) {
    final l10n = context.l10n;
    return switch (type) {
      RecurrenceRepetitionType.daily => l10n.repeatDaily,
      RecurrenceRepetitionType.weekly => l10n.repeatWeekly,
      RecurrenceRepetitionType.ndom => l10n.repeatNdom,
      RecurrenceRepetitionType.monthly => l10n.repeatMonthly,
      RecurrenceRepetitionType.yearly => l10n.repeatYearly,
    };
  }

  String _weekendLabel(RecurrenceWeekendMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      RecurrenceWeekendMode.createAnyway => l10n.weekendCreateAnyway,
      RecurrenceWeekendMode.skipWeekend => l10n.weekendSkip,
      RecurrenceWeekendMode.previousFriday => l10n.weekendPreviousFriday,
      RecurrenceWeekendMode.nextMonday => l10n.weekendNextMonday,
    };
  }

  String _endModeLabel(RecurrenceEndMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      RecurrenceEndMode.forever => l10n.repeatForever,
      RecurrenceEndMode.untilDate => l10n.repeatUntilDate,
      RecurrenceEndMode.repetitionCount => l10n.repeatCount,
    };
  }

  String _typeLabel(RecurrenceTransactionType type) {
    final l10n = context.l10n;
    return switch (type) {
      RecurrenceTransactionType.withdrawal => l10n.transactionTypeWithdrawal,
      RecurrenceTransactionType.deposit => l10n.transactionTypeDeposit,
      RecurrenceTransactionType.transfer => l10n.transactionTypeTransfer,
    };
  }

  RecurrenceInput _buildInput() {
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final foreignAmount = double.tryParse(_foreignAmountController.text.trim());

    return RecurrenceInput(
      type: _type,
      title: _titleController.text.trim(),
      description: _recurrenceDescriptionController.text,
      firstDate: _firstDate,
      repeatUntil: _endMode == RecurrenceEndMode.untilDate
          ? _repeatUntil
          : null,
      nrOfRepetitions: _endMode == RecurrenceEndMode.repetitionCount
          ? int.tryParse(_repetitionCountController.text.trim())
          : null,
      applyRules: _applyRules,
      active: _active,
      notes: _notesController.text,
      repetitions: [
        RecurrenceRepetitionInput(
          type: _repetitionType,
          moment: RecurrenceRepetitionInput.momentForDate(
            _repetitionType,
            _firstDate,
          ),
          skip: _intervalEvery - 1,
          weekend: _weekendMode,
        ),
      ],
      transactions: [
        RecurrenceTransactionInput(
          id: _transactionLineId,
          description: _transactionDescriptionController.text.trim(),
          amount: double.tryParse(_amountController.text.trim()) ?? 0,
          currencyCode: _currencyCode,
          foreignAmount: foreignAmount,
          foreignCurrencyCode: foreignAmount != null
              ? _foreignCurrencyCode
              : null,
          sourceId: _sourceId!,
          destinationId: _destinationId!,
          budgetId: _budgetId,
          categoryId: _categoryId,
          billId: _billId,
          tags: tags,
        ),
      ],
    );
  }

  Map<String, Object?> _recurrenceInputPayload(RecurrenceInput input) {
    final repetition = input.repetitions.first;
    final tx = input.transactions.first;
    return {
      'title': input.title,
      'type': input.type.name,
      'description': input.description,
      'firstDate': input.firstDate.toIso8601String(),
      'repeatUntil': input.repeatUntil?.toIso8601String(),
      'nrOfRepetitions': input.nrOfRepetitions,
      'applyRules': input.applyRules,
      'active': input.active,
      'notes': input.notes,
      'repetitionType': repetition.type.name,
      'moment': repetition.moment,
      'skip': repetition.skip,
      'weekendMode': repetition.weekend.name,
      'transactionLineId': tx.id,
      'transactionDescription': tx.description,
      'amount': tx.amount,
      'currencyCode': tx.currencyCode,
      'foreignAmount': tx.foreignAmount,
      'foreignCurrencyCode': tx.foreignCurrencyCode,
      'sourceId': tx.sourceId,
      'destinationId': tx.destinationId,
      'budgetId': tx.budgetId,
      'categoryId': tx.categoryId,
      'billId': tx.billId,
      'tags': tx.tags,
    };
  }

  bool _validate() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final hasAccounts = _sourceId != null && _destinationId != null;
    final endValid = switch (_endMode) {
      RecurrenceEndMode.forever => true,
      RecurrenceEndMode.untilDate => _repeatUntil != null,
      RecurrenceEndMode.repetitionCount =>
        (int.tryParse(_repetitionCountController.text.trim()) ?? 0) > 0,
    };
    return title.isNotEmpty &&
        amount > 0 &&
        hasAccounts &&
        endValid &&
        _transactionDescriptionController.text.trim().isNotEmpty;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _saving = true);
    try {
      final service = ref.read(apiServiceProvider);
      final input = _buildInput();
      if (widget.isEditing) {
        await service?.updateRecurrence(
          widget.recurrence!.id,
          input,
          current: widget.recurrence,
        );
        final old = widget.recurrence!;
        final oldRep = old.primaryRepetition;
        final oldTx = old.primaryTransaction;
        if (oldRep != null && oldTx != null) {
          final previous = RecurrenceInput(
            type: old.type,
            title: old.title,
            description: old.description,
            firstDate: old.firstDate,
            repeatUntil: old.repeatUntil,
            nrOfRepetitions: old.nrOfRepetitions,
            applyRules: old.applyRules,
            active: old.active,
            notes: old.notes,
            repetitions: [
              RecurrenceRepetitionInput(
                type: oldRep.type,
                moment: oldRep.moment,
                skip: oldRep.skip,
                weekend: oldRep.weekend,
              ),
            ],
            transactions: [
              RecurrenceTransactionInput(
                id: oldTx.id,
                description: oldTx.description,
                amount: oldTx.amount,
                currencyCode: oldTx.currencyCode,
                foreignAmount: oldTx.foreignAmount,
                foreignCurrencyCode: oldTx.foreignCurrencyCode,
                sourceId: oldTx.sourceId ?? '',
                destinationId: oldTx.destinationId ?? '',
                budgetId: oldTx.budgetId,
                categoryId: oldTx.categoryId,
                billId: oldTx.billId,
                tags: oldTx.tags,
              ),
            ],
          );
          ref
              .read(undoHistoryProvider.notifier)
              .record(
                title: 'Recurring transaction updated',
                details: 'Updated recurring transaction "${old.title}"',
                type: UndoActionType.recurrenceUpdate,
                undoPayload: {
                  'recurrenceId': old.id,
                  ..._recurrenceInputPayload(previous),
                },
                redoPayload: {
                  'recurrenceId': old.id,
                  ..._recurrenceInputPayload(input),
                },
              );
        }
      } else {
        final created = await service?.createRecurrence(input);
        if (created != null) {
          ref
              .read(undoHistoryProvider.notifier)
              .record(
                title: 'Recurring transaction created',
                details: 'Created recurring transaction "${created.title}"',
                type: UndoActionType.recurrenceCreate,
                undoPayload: {'recurrenceId': created.id},
                redoPayload: _recurrenceInputPayload(input),
              );
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // A failed write usually means this session's recurrence data is
      // stale (e.g. the recurrence was replaced server-side); resync so the
      // next attempt works against fresh ids.
      ref.invalidate(recurrencesProvider);
      if (mounted) {
        setState(() => _saving = false);
        final l10n = context.l10n;
        // A SnackBar raised from a dialog renders inside the Scaffold below it,
        // so the one thing worth reading here was drawn under the form that
        // caused it. Firefly's own words go in: it names the field it refused.
        final reason = e is FireflyApiException ? e.message : '$e';
        showErrorToast(
          context,
          widget.isEditing
              ? l10n.failedToUpdateRecurringTransaction(reason)
              : l10n.failedToCreateRecurringTransaction(reason),
        );
      }
    }
  }

  Future<void> _pickDate({
    required DateTime initial,
    required void Function(DateTime?) onSelected,
    bool allowClear = false,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (date == null && allowClear) {
      onSelected(null);
      setState(() {});
      return;
    }
    if (date != null) {
      onSelected(date);
      setState(() {});
    }
  }

  InputDecoration _fieldDecoration(String label, {String? helper}) {
    final colors = context.colors;
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      filled: true,
      fillColor: colors.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.accent.acc, width: 2),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 2, color: colors.accent.acc),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required DateTime fallback,
    required void Function(DateTime?) onChanged,
    required String tooltip,
    String? helper,
    bool allowClear = false,
  }) {
    final format = ref.watch(localeFormattingProvider);
    final display = value != null ? format.formatMediumDate(value) : '—';
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        withTooltip(
          tooltip,
          InkWell(
            onTap: () => _pickDate(
              initial: value ?? fallback,
              onSelected: onChanged,
              allowClear: allowClear,
            ),
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _fieldDecoration(label, helper: helper),
              child: Row(
                children: [
                  Expanded(child: Text(display)),
                  const Icon(LucideIcons.calendar, size: 18),
                ],
              ),
            ),
          ),
        ),
        if (allowClear && value != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: withTooltip(
              l10n.tooltipClearDate,
              IconButton(
                onPressed: () => onChanged(null),
                icon: const Icon(LucideIcons.x, size: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _accountDropdown({
    required String label,
    required String? value,
    required List<Account> accounts,
    required ValueChanged<String?> onChanged,
  }) {
    final items = accounts
        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
        .toList();
    final selected = accounts.any((a) => a.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: _fieldDecoration(label),
      items: items,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final accountsAsync = ref.watch(accountsProvider);
    final counterpartiesAsync = ref.watch(counterpartyAccountsProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final billsAsync = ref.watch(billsProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final recurrences = ref.watch(recurrencesProvider).value ?? const [];
    final bills = billsAsync.value ?? const [];
    final tags = AutocompleteSuggestions.tagNames(
      ref.watch(tagsProvider).value ?? const [],
    );
    final titleSuggestions = AutocompleteSuggestions.recurrenceTitles(
      recurrences,
      excludeTitle: widget.isEditing ? widget.recurrence?.title : null,
    );
    final descriptionSuggestions = ref.watch(
      transactionDescriptionSuggestionsProvider,
    );
    final recurrenceDescriptionSuggestions =
        AutocompleteSuggestions.distinctNonEmpty(
          recurrences.map((recurrence) => recurrence.description),
        );
    final noteSuggestions = AutocompleteSuggestions.distinctNonEmpty([
      ...ref.watch(notesSuggestionsProvider),
      ...recurrences.map((recurrence) => recurrence.notes),
      ...recurrences.map((recurrence) => recurrence.description),
    ]);
    final decimalSuggestions = ref.watch(decimalSuggestionsProvider);
    final integerSuggestions =
        AutocompleteSuggestions.combinedIntegerSuggestions(
          bills: bills,
          recurrences: recurrences,
        );

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      widget.isEditing ? LucideIcons.wrench : LucideIcons.plus,
                      color: colors.accent.acc,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.isEditing
                          ? l10n.editRecurringTransaction
                          : l10n.createRecurringTransaction,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: accountsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text(l10n.errorGeneric(e.toString())),
                    data: (assetAccounts) {
                      // Withdrawals need expense destinations and deposits
                      // revenue sources; those live in a separate fetch.
                      final accounts = [
                        ...assetAccounts,
                        ...counterpartiesAsync.value ?? const <Account>[],
                      ];
                      if (_sourceId == null) {
                        final sources = _accountsForField(accounts, true);
                        _sourceId = sources.firstOrNull?.id;
                      }
                      if (_destinationId == null) {
                        final destinations = _accountsForField(accounts, false);
                        _destinationId = destinations.firstOrNull?.id;
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 720;
                          final recurrenceMandatory = _buildRecurrenceMandatory(
                            l10n,
                            titleSuggestions,
                            integerSuggestions,
                          );
                          final recurrenceOptional = _buildRecurrenceOptional(
                            l10n,
                            recurrenceDescriptionSuggestions,
                          );
                          final transactionMandatory =
                              _buildTransactionMandatory(
                                l10n,
                                accounts,
                                currenciesAsync,
                                descriptionSuggestions,
                                decimalSuggestions,
                              );
                          final transactionOptional = _buildTransactionOptional(
                            l10n,
                            budgetsAsync,
                            categoriesAsync,
                            billsAsync,
                            currenciesAsync,
                            tags,
                            noteSuggestions,
                            decimalSuggestions,
                            integerSuggestions,
                          );

                          if (!wide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                recurrenceMandatory,
                                const SizedBox(height: 24),
                                recurrenceOptional,
                                const SizedBox(height: 24),
                                transactionMandatory,
                                const SizedBox(height: 24),
                                transactionOptional,
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: recurrenceMandatory),
                                  const SizedBox(width: 24),
                                  Expanded(child: recurrenceOptional),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: transactionMandatory),
                                  const SizedBox(width: 24),
                                  Expanded(child: transactionOptional),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  withTooltip(
                    l10n.tooltipCancel,
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  withTooltip(
                    widget.isEditing ? l10n.tooltipSave : l10n.tooltipCreate,
                    ElevatedButton(
                      onPressed: _saving || !_validate() ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent.acc,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(widget.isEditing ? l10n.save : l10n.create),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecurrenceMandatory(
    dynamic l10n,
    List<String> titleSuggestions,
    List<String> integerSuggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l10n.mandatoryRecurrenceFields),
        AutocompleteTextField(
          controller: _titleController,
          autofocus: !widget.isEditing,
          suggestions: titleSuggestions,
          decoration: _fieldDecoration(l10n.recurrenceTitle),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _dateField(
          label: l10n.firstDate,
          value: _firstDate,
          fallback: DateTime.now().add(const Duration(days: 1)),
          helper: l10n.firstDateHelp,
          tooltip: l10n.tooltipSubscriptionStartDate,
          onChanged: (date) {
            if (date != null) _firstDate = date;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<RecurrenceRepetitionType>(
          initialValue: _repetitionType,
          decoration: _fieldDecoration(
            l10n.typeOfRepetition,
            helper: l10n.typeOfRepetitionHelp,
          ),
          items: RecurrenceRepetitionType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(_repetitionLabel(t)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _repetitionType = value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _intervalEvery.clamp(1, 12),
          decoration: _fieldDecoration(
            l10n.repeatIntervalLabel,
            helper: l10n.repeatIntervalHelp,
          ),
          items: [
            for (var every = 1; every <= 12; every++)
              DropdownMenuItem(
                value: every,
                child: Text(_intervalLabel(l10n, every)),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _intervalEvery = value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<RecurrenceWeekendMode>(
          initialValue: _weekendMode,
          decoration: _fieldDecoration(
            l10n.weekendHandling,
            helper: l10n.weekendHelp,
          ),
          items: RecurrenceWeekendMode.values
              .map(
                (m) =>
                    DropdownMenuItem(value: m, child: Text(_weekendLabel(m))),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _weekendMode = value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<RecurrenceEndMode>(
          initialValue: _endMode,
          decoration: _fieldDecoration(l10n.repetitionEnds),
          items: RecurrenceEndMode.values
              .map(
                (m) =>
                    DropdownMenuItem(value: m, child: Text(_endModeLabel(m))),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _endMode = value);
          },
        ),
        if (_endMode == RecurrenceEndMode.untilDate) ...[
          const SizedBox(height: 16),
          _dateField(
            label: l10n.endDate,
            value: _repeatUntil,
            fallback: _firstDate,
            tooltip: l10n.tooltipSubscriptionEndDate,
            onChanged: (date) => _repeatUntil = date,
          ),
        ],
        if (_endMode == RecurrenceEndMode.repetitionCount) ...[
          const SizedBox(height: 16),
          AutocompleteTextField(
            controller: _repetitionCountController,
            keyboardType: TextInputType.number,
            suggestions: integerSuggestions,
            decoration: _fieldDecoration(l10n.numberOfRepetitions),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  Widget _buildRecurrenceOptional(
    dynamic l10n,
    List<String> recurrenceDescriptionSuggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l10n.optionalRecurrenceFields),
        AutocompleteTextField(
          controller: _recurrenceDescriptionController,
          maxLines: 3,
          suggestions: recurrenceDescriptionSuggestions,
          decoration: _fieldDecoration(l10n.recurrenceDescription),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.subscriptionActive),
          value: _active,
          onChanged: (value) {
            if (value != null) setState(() => _active = value);
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.applyRules),
          subtitle: Text(
            l10n.applyRulesHelp,
            style: TextStyle(color: context.colors.text3, fontSize: 12),
          ),
          value: _applyRules,
          onChanged: (value) {
            if (value != null) setState(() => _applyRules = value);
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _buildTransactionMandatory(
    dynamic l10n,
    List<Account> accounts,
    AsyncValue<List<FireflyCurrency>> currenciesAsync,
    List<String> descriptionSuggestions,
    List<String> decimalSuggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l10n.mandatoryTransactionFields),
        SegmentedButton<RecurrenceTransactionType>(
          segments: RecurrenceTransactionType.values
              .map((t) => ButtonSegment(value: t, label: Text(_typeLabel(t))))
              .toList(),
          selected: {_type},
          onSelectionChanged: (selection) {
            setState(() {
              _type = selection.first;
              _sourceId = _accountsForField(accounts, true).firstOrNull?.id;
              _destinationId = _accountsForField(
                accounts,
                false,
              ).firstOrNull?.id;
            });
          },
        ),
        const SizedBox(height: 16),
        AutocompleteTextField(
          controller: _transactionDescriptionController,
          suggestions: descriptionSuggestions,
          decoration: _fieldDecoration(l10n.description),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        currenciesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => AutocompleteTextField(
            readOnly: true,
            suggestions: [_currencyCode],
            decoration: _fieldDecoration(l10n.defaultCurrency),
            controller: TextEditingController(text: _currencyCode),
          ),
          data: (currencies) {
            final items = currencies.isEmpty
                ? [
                    DropdownMenuItem(
                      value: _currencyCode,
                      child: Text(_currencyCode),
                    ),
                  ]
                : currencies
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text('${c.name} (${c.symbol})'),
                        ),
                      )
                      .toList();
            if (!items.any((i) => i.value == _currencyCode)) {
              _currencyCode = items.first.value!;
            }
            return DropdownButtonFormField<String>(
              initialValue: _currencyCode,
              decoration: _fieldDecoration(l10n.defaultCurrency),
              items: items,
              onChanged: (value) {
                if (value != null) setState(() => _currencyCode = value);
              },
            );
          },
        ),
        const SizedBox(height: 16),
        AutocompleteTextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suggestions: const [],
          decoration: _fieldDecoration(l10n.amount),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _accountDropdown(
          label: _sourceAccountLabel(l10n),
          value: _sourceId,
          accounts: _accountsForField(accounts, true),
          onChanged: (value) => setState(() => _sourceId = value),
        ),
        const SizedBox(height: 16),
        _accountDropdown(
          label: _destinationAccountLabel(l10n),
          value: _destinationId,
          accounts: _accountsForField(accounts, false),
          onChanged: (value) => setState(() => _destinationId = value),
        ),
      ],
    );
  }

  Widget _buildTransactionOptional(
    dynamic l10n,
    AsyncValue<List<Budget>> budgetsAsync,
    AsyncValue<List<Category>> categoriesAsync,
    AsyncValue<List<Bill>> billsAsync,
    AsyncValue<List<FireflyCurrency>> currenciesAsync,
    List<String> tags,
    List<String> noteSuggestions,
    List<String> decimalSuggestions,
    List<String> integerSuggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l10n.optionalTransactionFields),
        currenciesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (currencies) {
            final items = [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('(none)'),
              ),
              ...currencies.map(
                (c) => DropdownMenuItem(
                  value: c.code,
                  child: Text('${c.name} (${c.symbol})'),
                ),
              ),
            ];
            return DropdownButtonFormField<String?>(
              initialValue: _foreignCurrencyCode,
              decoration: _fieldDecoration(l10n.foreignCurrency),
              items: items,
              onChanged: (value) {
                setState(() => _foreignCurrencyCode = value);
              },
            );
          },
        ),
        const SizedBox(height: 16),
        AutocompleteTextField(
          controller: _foreignAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suggestions: const [],
          decoration: _fieldDecoration(l10n.foreignAmountLabel),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        budgetsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (budgets) {
            final items = [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('(none)'),
              ),
              ...budgets.map(
                (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
              ),
            ];
            return DropdownButtonFormField<String?>(
              initialValue: _budgetId,
              decoration: _fieldDecoration(l10n.budgetLabel),
              items: items,
              onChanged: (value) => setState(() => _budgetId = value),
            );
          },
        ),
        const SizedBox(height: 16),
        categoriesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (categories) {
            final items = [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('(none)'),
              ),
              ...categories.map(
                (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
              ),
            ];
            return DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: _fieldDecoration(l10n.category),
              items: items,
              onChanged: (value) => setState(() => _categoryId = value),
            );
          },
        ),
        const SizedBox(height: 16),
        billsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (bills) {
            final items = [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('(none)'),
              ),
              ...bills.map(
                (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
              ),
            ];
            return DropdownButtonFormField<String?>(
              initialValue: _billId,
              decoration: _fieldDecoration(l10n.subscription),
              items: items,
              onChanged: (value) => setState(() => _billId = value),
            );
          },
        ),
        const SizedBox(height: 16),
        AutocompleteTextField(
          controller: _tagsController,
          tagMode: true,
          suggestions: tags,
          decoration: _fieldDecoration(l10n.tags),
        ),
        const SizedBox(height: 16),
        AutocompleteTextField(
          controller: _notesController,
          maxLines: 3,
          suggestions: noteSuggestions,
          decoration: _fieldDecoration(
            l10n.notes,
            helper: l10n.notesMarkdownHint,
          ),
        ),
      ],
    );
  }
}
