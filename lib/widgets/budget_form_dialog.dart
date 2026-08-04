import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../providers/budget_period_providers.dart';
import '../providers/data_providers.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/autocomplete_suggestions.dart';
import '../utils/locale_formatting.dart';
import 'autocomplete_text_field.dart';
import 'tooltip_helpers.dart';

enum BudgetAmountMode { autoBudget, dateRange, none }

Future<bool?> showBudgetFormDialog({
  required BuildContext context,
  required WidgetRef ref,
  Budget? budget,
  String? initialName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) =>
        _BudgetFormDialog(budget: budget, initialName: initialName),
  ).then((saved) {
    if (saved == true) {
      ref.invalidate(budgetsProvider);
      ref.invalidate(budgetPeriodMetricsProvider);
    }
    return saved;
  });
}

class _BudgetFormDialog extends ConsumerStatefulWidget {
  final Budget? budget;
  final String? initialName;

  const _BudgetFormDialog({this.budget, this.initialName});

  bool get isEditing => budget != null;

  @override
  ConsumerState<_BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends ConsumerState<_BudgetFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late bool _active;
  late String _currencyCode;
  late BudgetAmountMode _amountMode;
  late AutoBudgetType _autoBudgetType;
  late AutoBudgetPeriod _autoBudgetPeriod;
  late DateTime _limitStart;
  late DateTime _limitEnd;
  String? _existingLimitId;
  bool _loadingLimits = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final budget = widget.budget;
    _nameController = TextEditingController(
      text: budget?.name ?? widget.initialName ?? '',
    );
    _amountController = TextEditingController(
      text: budget != null && budget.autoBudgetAmount > 0
          ? budget.autoBudgetAmount.toStringAsFixed(2)
          : '',
    );
    _notesController = TextEditingController(text: budget?.notes ?? '');
    _active = budget?.active ?? true;
    _currencyCode = budget?.currencyCode ?? 'EUR';
    _autoBudgetType = budget?.autoBudgetType ?? AutoBudgetType.reset;
    _autoBudgetPeriod = budget?.autoBudgetPeriod ?? AutoBudgetPeriod.monthly;
    final now = DateTime.now();
    _limitStart = DateTime(now.year, now.month, 1);
    _limitEnd = DateTime(now.year, now.month + 1, 0);

    if (budget == null) {
      _amountMode = BudgetAmountMode.autoBudget;
    } else if (budget.autoBudgetType != AutoBudgetType.none ||
        budget.autoBudgetPeriod != null) {
      _amountMode = BudgetAmountMode.autoBudget;
      _autoBudgetType = budget.autoBudgetType == AutoBudgetType.none
          ? AutoBudgetType.reset
          : budget.autoBudgetType;
      if (budget.autoBudgetPeriod != null) {
        _autoBudgetPeriod = budget.autoBudgetPeriod!;
      }
    } else if (budget.autoBudgetAmount > 0) {
      _amountMode = BudgetAmountMode.autoBudget;
      _autoBudgetType = AutoBudgetType.reset;
    } else {
      _amountMode = BudgetAmountMode.none;
      _loadExistingLimit(budget);
    }
  }

  Future<void> _loadExistingLimit(Budget budget) async {
    setState(() => _loadingLimits = true);
    try {
      final service = ref.read(apiServiceProvider);
      final limits = await service?.getBudgetLimits(budget.id) ?? [];
      if (!mounted || limits.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selected = limits.firstWhere(
        (limit) =>
            !today.isBefore(limit.start) &&
            !today.isAfter(
              DateTime(limit.end.year, limit.end.month, limit.end.day),
            ),
        orElse: () => limits.last,
      );

      setState(() {
        _amountMode = BudgetAmountMode.dateRange;
        _existingLimitId = selected.id;
        _limitStart = selected.start;
        _limitEnd = selected.end;
        _amountController.text = selected.amount.toStringAsFixed(2);
        _currencyCode = selected.currencyCode;
      });
    } catch (_) {
      // Keep default mode when limits cannot be loaded.
    } finally {
      if (mounted) setState(() => _loadingLimits = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;
    if (_amountMode == BudgetAmountMode.none) return true;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return amount > 0;
  }

  BudgetInput _buildBudgetInput() {
    final amount = double.tryParse(_amountController.text.trim());
    return BudgetInput(
      name: _nameController.text.trim(),
      active: _active,
      notes: _notesController.text,
      autoBudgetType: _amountMode == BudgetAmountMode.autoBudget
          ? _autoBudgetType
          : AutoBudgetType.none,
      autoBudgetAmount: _amountMode == BudgetAmountMode.autoBudget
          ? amount
          : null,
      autoBudgetPeriod: _amountMode == BudgetAmountMode.autoBudget
          ? _autoBudgetPeriod
          : null,
      currencyCode: _currencyCode,
    );
  }

  BudgetLimitInput? _buildLimitInput() {
    if (_amountMode != BudgetAmountMode.dateRange) return null;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return BudgetLimitInput(
      start: _limitStart,
      end: _limitEnd,
      amount: amount,
      currencyCode: _currencyCode,
    );
  }

  Map<String, Object?> _budgetPayload(BudgetInput input) {
    return {
      'name': input.name,
      'active': input.active,
      'notes': input.notes,
      'autoBudgetType': input.autoBudgetType.apiValue,
      'autoBudgetAmount': input.autoBudgetAmount,
      'autoBudgetPeriod': input.autoBudgetPeriod?.apiValue,
      'currencyCode': input.currencyCode,
    };
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _saving = true);
    try {
      final service = ref.read(apiServiceProvider);
      final input = _buildBudgetInput();
      final limitInput = _buildLimitInput();

      if (widget.isEditing) {
        final budget = widget.budget!;
        await service?.updateBudget(budget.id, input);
        if (limitInput != null) {
          if (_existingLimitId != null) {
            await service?.updateBudgetLimit(
              budget.id,
              _existingLimitId!,
              limitInput,
            );
          } else {
            await service?.createBudgetLimit(budget.id, limitInput);
          }
        }

        ref
            .read(undoHistoryProvider.notifier)
            .record(
              title: 'Budget updated',
              details: 'Updated budget "${budget.name}"',
              type: UndoActionType.budgetUpdate,
              undoPayload: {
                'budgetId': budget.id,
                'name': budget.name,
                'amount': budget.autoBudgetAmount,
                ..._budgetPayload(
                  BudgetInput(
                    name: budget.name,
                    active: budget.active,
                    notes: budget.notes,
                    autoBudgetType: budget.autoBudgetType,
                    autoBudgetAmount: budget.autoBudgetAmount,
                    autoBudgetPeriod: budget.autoBudgetPeriod,
                    currencyCode: budget.currencyCode,
                  ),
                ),
              },
              redoPayload: {'budgetId': budget.id, ..._budgetPayload(input)},
            );
      } else {
        final created = await service?.createBudget(input);
        if (created != null && limitInput != null) {
          await service?.createBudgetLimit(created.id, limitInput);
        }
        if (created != null) {
          ref
              .read(undoHistoryProvider.notifier)
              .record(
                title: 'Budget created',
                details: 'Created budget "${created.name}"',
                type: UndoActionType.budgetCreate,
                undoPayload: {'budgetId': created.id},
                redoPayload: _budgetPayload(input),
              );
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? context.l10n.failedToUpdate(e.toString())
                  : context.l10n.failedToCreateBudget(e.toString()),
            ),
          ),
        );
      }
    }
  }

  InputDecoration _fieldDecoration(String label, {String? helper}) {
    final colors = context.colors;
    return InputDecoration(
      labelText: label,
      helperText: helper,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.accent.acc, width: 2),
      ),
      filled: true,
      fillColor: colors.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _pickDate({
    required DateTime initial,
    required void Function(DateTime) onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onSelected(picked);
  }

  Widget _dateField({
    required String label,
    required DateTime value,
    required void Function(DateTime) onChanged,
    required String tooltip,
  }) {
    final format = ref.watch(localeFormattingProvider);
    return withTooltip(
      tooltip,
      InkWell(
        onTap: () => _pickDate(initial: value, onSelected: onChanged),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: _fieldDecoration(label),
          child: Row(
            children: [
              Expanded(child: Text(format.formatMediumDate(value))),
              const Icon(LucideIcons.calendar, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final budgets = ref.watch(budgetsProvider).value ?? [];
    final currenciesAsync = ref.watch(currenciesProvider);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                      widget.isEditing ? l10n.editBudget : l10n.createBudget,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_loadingLimits) const LinearProgressIndicator(minHeight: 2),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      withTooltip(
                        l10n.tooltipBudgetName,
                        AutocompleteTextField(
                          controller: _nameController,
                          autofocus: !widget.isEditing,
                          suggestions: AutocompleteSuggestions.budgetNames(
                            budgets,
                            excludeName: widget.budget?.name,
                          ),
                          decoration: _fieldDecoration(l10n.budgetNameHint),
                        ),
                      ),
                      const SizedBox(height: 16),
                      withTooltip(
                        l10n.tooltipBudgetActive,
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.budgetActive),
                          value: _active,
                          onChanged: (value) {
                            if (value != null) setState(() => _active = value);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      const SizedBox(height: 8),
                      withTooltip(
                        l10n.tooltipBudgetNotes,
                        AutocompleteTextField(
                          controller: _notesController,
                          maxLines: 2,
                          suggestions: const [],
                          decoration: _fieldDecoration(l10n.notes),
                        ),
                      ),
                      const SizedBox(height: 16),
                      withTooltip(
                        l10n.tooltipBudgetAmountMode,
                        DropdownButtonFormField<BudgetAmountMode>(
                          initialValue: _amountMode,
                          decoration: _fieldDecoration(l10n.budgetAmountMode),
                          items: BudgetAmountMode.values
                              .map(
                                (mode) => DropdownMenuItem(
                                  value: mode,
                                  child: Text(mode.localizedLabel(l10n)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _amountMode = value);
                            }
                          },
                        ),
                      ),
                      if (_amountMode != BudgetAmountMode.none) ...[
                        const SizedBox(height: 16),
                        currenciesAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => withTooltip(
                            l10n.tooltipBudgetCurrency,
                            AutocompleteTextField(
                              readOnly: true,
                              suggestions: [_currencyCode],
                              decoration: _fieldDecoration(
                                l10n.defaultCurrency,
                              ),
                              controller: TextEditingController(
                                text: _currencyCode,
                              ),
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
                                          child: Text(
                                            '${c.name} (${c.symbol})',
                                          ),
                                        ),
                                      )
                                      .toList();
                            if (!items.any((i) => i.value == _currencyCode)) {
                              _currencyCode = items.first.value!;
                            }
                            return withTooltip(
                              l10n.tooltipBudgetCurrency,
                              DropdownButtonFormField<String>(
                                initialValue: _currencyCode,
                                decoration: _fieldDecoration(
                                  l10n.defaultCurrency,
                                ),
                                items: items,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _currencyCode = value);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        withTooltip(
                          l10n.tooltipBudgetAmount,
                          AutocompleteTextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            suggestions: const [],
                            decoration: _fieldDecoration(l10n.budgetAmount),
                          ),
                        ),
                      ],
                      if (_amountMode == BudgetAmountMode.autoBudget) ...[
                        const SizedBox(height: 16),
                        withTooltip(
                          l10n.tooltipBudgetAutoType,
                          DropdownButtonFormField<AutoBudgetType>(
                            initialValue: _autoBudgetType,
                            decoration: _fieldDecoration(l10n.budgetAutoType),
                            items:
                                [
                                      AutoBudgetType.reset,
                                      AutoBudgetType.rollover,
                                      AutoBudgetType.adjusted,
                                    ]
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type.localizedLabel(l10n)),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _autoBudgetType = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        withTooltip(
                          l10n.tooltipBudgetRepeatPeriod,
                          DropdownButtonFormField<AutoBudgetPeriod>(
                            initialValue: _autoBudgetPeriod,
                            decoration: _fieldDecoration(
                              l10n.budgetRepeatPeriod,
                            ),
                            items: AutoBudgetPeriod.values
                                .map(
                                  (period) => DropdownMenuItem(
                                    value: period,
                                    child: Text(
                                      period.localizedPeriodLabel(l10n),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _autoBudgetPeriod = value);
                              }
                            },
                          ),
                        ),
                      ],
                      if (_amountMode == BudgetAmountMode.dateRange) ...[
                        const SizedBox(height: 16),
                        _dateField(
                          label: l10n.startDate,
                          value: _limitStart,
                          tooltip: l10n.tooltipBudgetStartDate,
                          onChanged: (date) =>
                              setState(() => _limitStart = date),
                        ),
                        const SizedBox(height: 16),
                        _dateField(
                          label: l10n.endDate,
                          value: _limitEnd,
                          tooltip: l10n.tooltipBudgetEndDate,
                          onChanged: (date) => setState(() => _limitEnd = date),
                        ),
                      ],
                    ],
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
                      onPressed: _saving || _loadingLimits ? null : _save,
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
}

extension BudgetAmountModeL10n on BudgetAmountMode {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    BudgetAmountMode.autoBudget => l10n.budgetAmountModeAuto,
    BudgetAmountMode.dateRange => l10n.budgetAmountModeDateRange,
    BudgetAmountMode.none => l10n.budgetAmountModeNone,
  };
}
