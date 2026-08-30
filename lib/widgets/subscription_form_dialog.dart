import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../providers/suggestion_providers.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/autocomplete_suggestions.dart';
import '../utils/locale_formatting.dart';
import 'autocomplete_text_field.dart';
import 'tooltip_helpers.dart';

Future<bool?> showSubscriptionFormDialog({
  required BuildContext context,
  required WidgetRef ref,
  Bill? bill,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _SubscriptionFormDialog(bill: bill),
  ).then((saved) {
    if (saved == true) {
      ref.invalidate(billsProvider);
    }
    return saved;
  });
}

class _SubscriptionFormDialog extends ConsumerStatefulWidget {
  final Bill? bill;

  const _SubscriptionFormDialog({this.bill});

  bool get isEditing => bill != null;

  @override
  ConsumerState<_SubscriptionFormDialog> createState() =>
      _SubscriptionFormDialogState();
}

class _SubscriptionFormDialogState
    extends ConsumerState<_SubscriptionFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountMinController;
  late final TextEditingController _amountMaxController;
  late final TextEditingController _skipController;
  late final TextEditingController _notesController;
  late final TextEditingController _groupController;

  late DateTime _startDate;
  DateTime? _endDate;
  DateTime? _extensionDate;
  BillRepeatFrequency _repeatFrequency = BillRepeatFrequency.monthly;
  String _currencyCode = 'EUR';
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    _nameController = TextEditingController(text: bill?.name ?? '');
    _amountMinController = TextEditingController(
      text: bill != null ? bill.amountMin.toStringAsFixed(2) : '',
    );
    _amountMaxController = TextEditingController(
      text: bill != null ? bill.amountMax.toStringAsFixed(2) : '',
    );
    _skipController = TextEditingController(text: '${bill?.skip ?? 0}');
    _notesController = TextEditingController(text: bill?.notes ?? '');
    _groupController = TextEditingController(
      text: bill?.objectGroupTitle ?? '',
    );
    _startDate = bill?.date ?? DateTime.now();
    _endDate = bill?.endDate;
    _extensionDate = bill?.extensionDate;
    _repeatFrequency = bill?.repeatFrequency ?? BillRepeatFrequency.monthly;
    _currencyCode = bill?.currencyCode ?? 'EUR';
    _active = bill?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountMinController.dispose();
    _amountMaxController.dispose();
    _skipController.dispose();
    _notesController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  BillInput _buildInput() {
    return BillInput(
      name: _nameController.text.trim(),
      amountMin: double.tryParse(_amountMinController.text.trim()) ?? 0,
      amountMax: double.tryParse(_amountMaxController.text.trim()) ?? 0,
      currencyCode: _currencyCode,
      date: _startDate,
      repeatFrequency: _repeatFrequency,
      skip: int.tryParse(_skipController.text.trim()) ?? 0,
      active: _active,
      endDate: _endDate,
      extensionDate: _extensionDate,
      notes: _notesController.text,
      objectGroupTitle: _groupController.text,
    );
  }

  Map<String, Object?> _billInputPayload(BillInput input) {
    return {
      'name': input.name,
      'amountMin': input.amountMin,
      'amountMax': input.amountMax,
      'currencyCode': input.currencyCode,
      'date': input.date.toIso8601String(),
      'repeatFrequency': input.repeatFrequency.name,
      'skip': input.skip,
      'active': input.active,
      'endDate': input.endDate?.toIso8601String(),
      'extensionDate': input.extensionDate?.toIso8601String(),
      'notes': input.notes,
      'objectGroupTitle': input.objectGroupTitle,
    };
  }

  bool _validate() {
    final name = _nameController.text.trim();
    final min = double.tryParse(_amountMinController.text.trim()) ?? 0;
    final max = double.tryParse(_amountMaxController.text.trim()) ?? 0;
    return name.isNotEmpty && min > 0 && max > 0 && min <= max;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _saving = true);
    try {
      final service = ref.read(apiServiceProvider);
      final input = _buildInput();
      if (widget.isEditing) {
        await service?.updateBill(widget.bill!.id, input);
        final previous = BillInput(
          name: widget.bill!.name,
          amountMin: widget.bill!.amountMin,
          amountMax: widget.bill!.amountMax,
          currencyCode: widget.bill!.currencyCode,
          date: widget.bill!.date,
          repeatFrequency: widget.bill!.repeatFrequency,
          skip: widget.bill!.skip,
          active: widget.bill!.active,
          endDate: widget.bill!.endDate,
          extensionDate: widget.bill!.extensionDate,
          notes: widget.bill!.notes,
          objectGroupTitle: widget.bill!.objectGroupTitle,
        );
        ref
            .read(undoHistoryProvider.notifier)
            .record(
              title: 'Subscription updated',
              details: 'Updated subscription "${widget.bill!.name}"',
              type: UndoActionType.billUpdate,
              undoPayload: {
                'billId': widget.bill!.id,
                ..._billInputPayload(previous),
              },
              redoPayload: {
                'billId': widget.bill!.id,
                ..._billInputPayload(input),
              },
            );
      } else {
        final created = await service?.createBill(input);
        if (created != null) {
          ref
              .read(undoHistoryProvider.notifier)
              .record(
                title: 'Subscription created',
                details: 'Created subscription "${created.name}"',
                type: UndoActionType.billCreate,
                undoPayload: {'billId': created.id},
                redoPayload: _billInputPayload(input),
              );
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? l10n.failedToUpdateSubscription(e.toString())
                  : l10n.failedToCreateSubscription(e.toString()),
            ),
          ),
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

  String _repeatLabel(BillRepeatFrequency frequency) {
    final l10n = context.l10n;
    return switch (frequency) {
      BillRepeatFrequency.weekly => l10n.repeatWeekly,
      BillRepeatFrequency.monthly => l10n.repeatMonthly,
      BillRepeatFrequency.quarterly => l10n.repeatQuarterly,
      BillRepeatFrequency.halfYear => l10n.repeatHalfYear,
      BillRepeatFrequency.yearly => l10n.repeatYearly,
    };
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currenciesAsync = ref.watch(currenciesProvider);
    final bills = ref.watch(billsProvider).value ?? const [];
    final groupSuggestions = ref.watch(groupTitleSuggestionsProvider);
    final noteSuggestions = ref.watch(notesSuggestionsProvider);
    final billNameSuggestions = AutocompleteSuggestions.billNames(
      bills,
      excludeName: widget.isEditing ? widget.bill?.name : null,
    );
    final decimalSuggestions = ref.watch(decimalSuggestionsProvider);
    final integerSuggestions =
        AutocompleteSuggestions.combinedIntegerSuggestions(bills: bills);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
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
                          ? l10n.editSubscription
                          : l10n.createSubscription,
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 560;
                      final mandatory = _buildMandatoryFields(
                        l10n,
                        currenciesAsync,
                        billNameSuggestions,
                        decimalSuggestions,
                        integerSuggestions,
                      );
                      final optional = _buildOptionalFields(
                        l10n,
                        groupSuggestions,
                        noteSuggestions,
                      );

                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            mandatory,
                            const SizedBox(height: 24),
                            optional,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: mandatory),
                          const SizedBox(width: 24),
                          Expanded(child: optional),
                        ],
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

  Widget _buildMandatoryFields(
    dynamic l10n,
    AsyncValue<List<FireflyCurrency>> currenciesAsync,
    List<String> billNameSuggestions,
    List<String> decimalSuggestions,
    List<String> integerSuggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l10n.mandatoryFields),
        withTooltip(
          l10n.tooltipSubscriptionName,
          AutocompleteTextField(
            controller: _nameController,
            autofocus: !widget.isEditing,
            suggestions: billNameSuggestions,
            decoration: _fieldDecoration(l10n.name),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        currenciesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => withTooltip(
            l10n.tooltipSubscriptionCurrency,
            AutocompleteTextField(
              readOnly: true,
              suggestions: [_currencyCode],
              decoration: _fieldDecoration(l10n.defaultCurrency),
              controller: TextEditingController(text: _currencyCode),
            ),
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
            return withTooltip(
              l10n.tooltipSubscriptionCurrency,
              DropdownButtonFormField<String>(
                initialValue: _currencyCode,
                decoration: _fieldDecoration(l10n.defaultCurrency),
                items: items,
                onChanged: (value) {
                  if (value != null) setState(() => _currencyCode = value);
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        withTooltip(
          l10n.tooltipSubscriptionAmountMin,
          AutocompleteTextField(
            controller: _amountMinController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suggestions: const [],
            decoration: _fieldDecoration(l10n.minimumAmount),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        withTooltip(
          l10n.tooltipSubscriptionAmountMax,
          AutocompleteTextField(
            controller: _amountMaxController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suggestions: const [],
            decoration: _fieldDecoration(l10n.maximumAmount),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        _dateField(
          label: l10n.startDate,
          value: _startDate,
          fallback: DateTime.now(),
          tooltip: l10n.tooltipSubscriptionStartDate,
          onChanged: (date) {
            if (date != null) _startDate = date;
          },
        ),
        const SizedBox(height: 16),
        withTooltip(
          l10n.tooltipSubscriptionRepeats,
          DropdownButtonFormField<BillRepeatFrequency>(
            initialValue: _repeatFrequency,
            decoration: _fieldDecoration(l10n.repeats),
            items: BillRepeatFrequency.values
                .map(
                  (f) =>
                      DropdownMenuItem(value: f, child: Text(_repeatLabel(f))),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _repeatFrequency = value);
            },
          ),
        ),
        const SizedBox(height: 16),
        withTooltip(
          l10n.tooltipSubscriptionSkip,
          AutocompleteTextField(
            controller: _skipController,
            keyboardType: TextInputType.number,
            suggestions: integerSuggestions,
            decoration: _fieldDecoration(l10n.skip, helper: l10n.skipHelp),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalFields(
    dynamic l10n,
    List<String> groupSuggestions,
    List<String> noteSuggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l10n.optionalFields),
        _dateField(
          label: l10n.endDate,
          value: _endDate,
          fallback: DateTime.now(),
          helper: l10n.endDateHelp,
          tooltip: l10n.tooltipSubscriptionEndDate,
          allowClear: true,
          onChanged: (date) => _endDate = date,
        ),
        const SizedBox(height: 16),
        _dateField(
          label: l10n.extensionDate,
          value: _extensionDate,
          fallback: DateTime.now(),
          helper: l10n.extensionDateHelp,
          tooltip: l10n.tooltipSubscriptionExtensionDate,
          allowClear: true,
          onChanged: (date) => _extensionDate = date,
        ),
        const SizedBox(height: 16),
        withTooltip(
          l10n.tooltipFieldNotes,
          AutocompleteTextField(
            controller: _notesController,
            maxLines: 4,
            suggestions: noteSuggestions,
            decoration: _fieldDecoration(
              l10n.notes,
              helper: l10n.notesMarkdownHint,
            ),
          ),
        ),
        const SizedBox(height: 16),
        withTooltip(
          l10n.tooltipSubscriptionGroup,
          AutocompleteTextField(
            controller: _groupController,
            suggestions: groupSuggestions,
            decoration: _fieldDecoration(l10n.group),
          ),
        ),
        const SizedBox(height: 16),
        withTooltip(
          l10n.tooltipSubscriptionActive,
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.subscriptionActive),
            value: _active,
            onChanged: (value) {
              if (value != null) setState(() => _active = value);
            },
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
    );
  }
}
