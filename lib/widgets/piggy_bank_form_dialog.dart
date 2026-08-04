import 'package:fireracoon_engine/fireracoon_engine.dart';
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

Future<bool?> showPiggyBankFormDialog({
  required BuildContext context,
  required WidgetRef ref,
  PiggyBank? piggyBank,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _PiggyBankFormDialog(piggyBank: piggyBank),
  ).then((saved) {
    if (saved == true) {
      ref.invalidate(piggyBanksProvider);
    }
    return saved;
  });
}

class _PiggyBankFormDialog extends ConsumerStatefulWidget {
  final PiggyBank? piggyBank;

  const _PiggyBankFormDialog({this.piggyBank});

  bool get isEditing => piggyBank != null;

  @override
  ConsumerState<_PiggyBankFormDialog> createState() =>
      _PiggyBankFormDialogState();
}

class _PiggyBankFormDialogState extends ConsumerState<_PiggyBankFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late final TextEditingController _notesController;
  late final TextEditingController _groupController;

  late DateTime _startDate;
  DateTime? _targetDate;
  String _currencyCode = 'EUR';
  final Set<String> _selectedAccountIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final piggy = widget.piggyBank;
    _nameController = TextEditingController(text: piggy?.name ?? '');
    _targetController = TextEditingController(
      text: piggy != null ? piggy.targetAmount.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: piggy?.notes ?? '');
    _groupController = TextEditingController(
      text: piggy?.objectGroupTitle ?? '',
    );
    _startDate = piggy?.startDate ?? DateTime.now();
    _targetDate = piggy?.targetDate;
    _currencyCode = piggy?.currencyCode ?? 'EUR';
    if (piggy != null) {
      _selectedAccountIds.addAll(piggy.accounts.map((a) => a.accountId));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _notesController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text.trim()) ?? 0;
    return name.isNotEmpty && target > 0 && _selectedAccountIds.isNotEmpty;
  }

  PiggyBankInput _buildInput() {
    return PiggyBankInput(
      name: _nameController.text.trim(),
      targetAmount: double.tryParse(_targetController.text.trim()) ?? 0,
      currencyCode: _currencyCode,
      accountIds: _selectedAccountIds.toList(),
      startDate: _startDate,
      targetDate: _targetDate,
      notes: _notesController.text,
      objectGroupTitle: _groupController.text,
    );
  }

  Map<String, Object?> _piggyPayload(PiggyBankInput input) {
    return {
      'name': input.name,
      'targetAmount': input.targetAmount,
      'currencyCode': input.currencyCode,
      'accountIds': input.accountIds,
      'startDate': input.startDate.toIso8601String(),
      'targetDate': input.targetDate?.toIso8601String(),
      'notes': input.notes,
      'objectGroupTitle': input.objectGroupTitle,
    };
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _saving = true);
    try {
      final service = ref.read(apiServiceProvider);
      final input = _buildInput();
      if (widget.isEditing) {
        await service?.updatePiggyBank(widget.piggyBank!.id, input);
        final previous = widget.piggyBank!;
        ref
            .read(undoHistoryProvider.notifier)
            .record(
              title: 'Piggy bank updated',
              details: 'Updated piggy bank "${previous.name}"',
              type: UndoActionType.piggyBankUpdate,
              undoPayload: {
                'piggyBankId': previous.id,
                'name': previous.name,
                'targetAmount': previous.targetAmount,
                'currencyCode': previous.currencyCode,
                'accountIds': previous.accounts
                    .map((a) => a.accountId)
                    .toList(),
                'startDate': previous.startDate.toIso8601String(),
                'targetDate': previous.targetDate?.toIso8601String(),
                'notes': previous.notes,
                'objectGroupTitle': previous.objectGroupTitle,
              },
              redoPayload: {
                'piggyBankId': previous.id,
                ..._piggyPayload(input),
              },
            );
      } else {
        final created = await service?.createPiggyBank(input);
        if (created != null) {
          ref
              .read(undoHistoryProvider.notifier)
              .record(
                title: 'Piggy bank created',
                details: 'Created piggy bank "${created.name}"',
                type: UndoActionType.piggyBankCreate,
                undoPayload: {'piggyBankId': created.id},
                redoPayload: _piggyPayload(input),
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
                  ? l10n.failedToUpdatePiggyBank(e.toString())
                  : l10n.failedToCreatePiggyBank(e.toString()),
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
              TextButton(
                onPressed: () => onChanged(null),
                child: Text(l10n.none),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _accountGroupLabel(Account account) {
    final l10n = context.l10n;
    if (account.type == 'liability') return l10n.accountGroupLiabilities;
    if (account.type == 'cash') return l10n.accountGroupCash;
    if (account.role == 'savingAsset') return l10n.accountGroupSavings;
    return l10n.accountGroupDefaultAssets;
  }

  Map<String, List<Account>> _groupAccounts(List<Account> accounts) {
    final grouped = <String, List<Account>>{};
    for (final account in accounts) {
      if (account.type != 'asset' &&
          account.type != 'cash' &&
          account.type != 'liability') {
        continue;
      }
      final label = _accountGroupLabel(account);
      grouped.putIfAbsent(label, () => []).add(account);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return grouped;
  }

  void _onCurrencyChanged(String? value, List<Account> allAccounts) {
    if (value == null) return;
    final matchingIds = allAccounts
        .where((a) => a.currencyCode == value)
        .map((a) => a.id)
        .toSet();
    setState(() {
      _currencyCode = value;
      _selectedAccountIds.removeWhere((id) => !matchingIds.contains(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currenciesAsync = ref.watch(currenciesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final piggyBanks = ref.watch(piggyBanksProvider).value ?? const [];
    final groupSuggestions = ref.watch(groupTitleSuggestionsProvider);
    final noteSuggestions = ref.watch(notesSuggestionsProvider);
    final piggyNameSuggestions = AutocompleteSuggestions.piggyBankNames(
      piggyBanks,
      excludeName: widget.isEditing ? widget.piggyBank?.name : null,
    );
    final decimalSuggestions = ref.watch(decimalSuggestionsProvider);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
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
                          ? l10n.editPiggyBank
                          : l10n.createPiggyBank,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: accountsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (allAccounts) {
                    final eligible = allAccounts
                        .where((a) => a.currencyCode == _currencyCode)
                        .where(
                          (a) =>
                              a.type == 'asset' ||
                              a.type == 'cash' ||
                              a.type == 'liability',
                        )
                        .toList();
                    final grouped = _groupAccounts(eligible);

                    return SingleChildScrollView(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 560;
                          final mandatory = _buildMandatoryFields(
                            l10n: l10n,
                            currenciesAsync: currenciesAsync,
                            allAccounts: allAccounts,
                            groupedAccounts: grouped,
                            piggyNameSuggestions: piggyNameSuggestions,
                            decimalSuggestions: decimalSuggestions,
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
                    );
                  },
                ),
              ),
              if (_selectedAccountIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.selectAtLeastOneAccount,
                    style: TextStyle(color: colors.danger, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
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

  Widget _buildMandatoryFields({
    required dynamic l10n,
    required AsyncValue<List<FireflyCurrency>> currenciesAsync,
    required List<Account> allAccounts,
    required Map<String, List<Account>> groupedAccounts,
    required List<String> piggyNameSuggestions,
    required List<String> decimalSuggestions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l10n.mandatoryFields),
        withTooltip(
          l10n.tooltipPiggyBankName,
          AutocompleteTextField(
            controller: _nameController,
            autofocus: !widget.isEditing,
            suggestions: piggyNameSuggestions,
            decoration: _fieldDecoration(l10n.name),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        withTooltip(
          l10n.tooltipPiggyBankTargetAmount,
          AutocompleteTextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suggestions: const [],
            decoration: _fieldDecoration(l10n.targetAmount),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        currenciesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => withTooltip(
            l10n.tooltipPiggyBankCurrency,
            AutocompleteTextField(
              readOnly: true,
              suggestions: [_currencyCode],
              decoration: _fieldDecoration(l10n.defaultCurrency),
              controller: TextEditingController(text: _currencyCode),
            ),
          ),
          data: (currencies) {
            final canChangeCurrency = !widget.isEditing;
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
              l10n.tooltipPiggyBankCurrency,
              DropdownButtonFormField<String>(
                initialValue: _currencyCode,
                decoration: _fieldDecoration(
                  l10n.defaultCurrency,
                  helper: l10n.piggyBankCurrencyHelp,
                ),
                items: items,
                onChanged: canChangeCurrency
                    ? (value) => _onCurrencyChanged(value, allAccounts)
                    : null,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        withTooltip(
          l10n.tooltipPiggyBankAccounts,
          Text(
            l10n.saveOnAccounts,
            style: TextStyle(
              color: context.colors.text2,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...groupedAccounts.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  color: context.colors.text3,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ...entry.value.map((account) {
                return withTooltip(
                  l10n.tooltipPiggyBankAccount(account.name),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(account.name),
                    value: _selectedAccountIds.contains(account.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedAccountIds.add(account.id);
                        } else {
                          _selectedAccountIds.remove(account.id);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          );
        }),
        Text(
          l10n.piggyBankAccountsHelp,
          style: TextStyle(color: context.colors.text3, fontSize: 12),
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
          label: l10n.startDate,
          value: _startDate,
          fallback: DateTime.now(),
          tooltip: l10n.tooltipPiggyBankStartDate,
          onChanged: (date) {
            if (date != null) _startDate = date;
          },
        ),
        const SizedBox(height: 16),
        _dateField(
          label: l10n.targetDate,
          value: _targetDate,
          fallback: DateTime.now(),
          helper: l10n.targetDateHelp,
          tooltip: l10n.tooltipPiggyBankTargetDate,
          allowClear: true,
          onChanged: (date) => _targetDate = date,
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
          l10n.tooltipPiggyBankGroup,
          AutocompleteTextField(
            controller: _groupController,
            suggestions: groupSuggestions,
            decoration: _fieldDecoration(l10n.group),
          ),
        ),
      ],
    );
  }
}
