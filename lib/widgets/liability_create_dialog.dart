import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../providers/suggestion_providers.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/autocomplete_suggestions.dart';
import '../utils/locale_formatting.dart';
import 'autocomplete_text_field.dart';
import 'tooltip_helpers.dart';

Future<bool?> showLiabilityCreateDialog({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => const _LiabilityCreateDialog(),
  ).then((created) {
    if (created == true) {
      ref.invalidate(accountsProvider);
    }
    return created;
  });
}

class _LiabilityCreateDialog extends ConsumerStatefulWidget {
  const _LiabilityCreateDialog();

  @override
  ConsumerState<_LiabilityCreateDialog> createState() =>
      _LiabilityCreateDialogState();
}

class _LiabilityCreateDialogState
    extends ConsumerState<_LiabilityCreateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _interestController;
  late final TextEditingController _ibanController;
  late final TextEditingController _bicController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _notesController;

  String _currencyCode = 'EUR';
  LiabilityType _liabilityType = LiabilityType.debt;
  LiabilityDirection _liabilityDirection = LiabilityDirection.credit;
  InterestPeriod? _interestPeriod;
  DateTime? _startDate;
  bool _includeNetWorth = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController();
    _interestController = TextEditingController();
    _ibanController = TextEditingController();
    _bicController = TextEditingController();
    _accountNumberController = TextEditingController();
    _notesController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final currency = await ref.read(primaryCurrencyProvider.future);
        if (mounted) setState(() => _currencyCode = currency.code);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _interestController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    _accountNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _validate() => _nameController.text.trim().isNotEmpty;

  LiabilityInput _buildInput() {
    final amount = double.tryParse(_amountController.text.trim());
    final interest = double.tryParse(_interestController.text.trim());

    return LiabilityInput(
      name: _nameController.text.trim(),
      currencyCode: _currencyCode,
      liabilityType: _liabilityType,
      liabilityDirection: _liabilityDirection,
      amountOwed: amount,
      startDate: _startDate,
      interest: interest,
      interestPeriod: _interestPeriod,
      includeNetWorth: _includeNetWorth,
      iban: _ibanController.text,
      bic: _bicController.text,
      accountNumber: _accountNumberController.text,
      notes: _notesController.text,
    );
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _saving = true);
    try {
      final service = ref.read(apiServiceProvider);
      final input = _buildInput();
      final created = await service?.createLiability(input);
      if (created != null) {
        ref
            .read(undoHistoryProvider.notifier)
            .record(
              title: 'Liability created',
              details: 'Created liability "${created.name}"',
              type: UndoActionType.liabilityCreate,
              undoPayload: {'accountId': created.id},
              redoPayload: {
                'name': input.name,
                'currencyCode': input.currencyCode,
                'liabilityType': input.liabilityType.name,
                'liabilityDirection': input.liabilityDirection.name,
                'amountOwed': input.amountOwed,
                'startDate': input.startDate?.toIso8601String(),
                'interest': input.interest,
                'interestPeriod': input.interestPeriod?.name,
                'includeNetWorth': input.includeNetWorth,
                'iban': input.iban,
                'bic': input.bic,
                'accountNumber': input.accountNumber,
                'notes': input.notes,
              },
            );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.failedToCreateLiability(e.toString())),
          ),
        );
      }
    }
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() => _startDate = date);
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

  String _liabilityTypeLabel(LiabilityType type) {
    final l10n = context.l10n;
    return switch (type) {
      LiabilityType.debt => l10n.liabilityTypeDebt,
      LiabilityType.loan => l10n.liabilityTypeLoan,
      LiabilityType.mortgage => l10n.liabilityTypeMortgage,
    };
  }

  String _liabilityDirectionLabel(LiabilityDirection direction) {
    final l10n = context.l10n;
    return switch (direction) {
      LiabilityDirection.credit => l10n.liabilityDirectionOwe,
      LiabilityDirection.debit => l10n.liabilityDirectionOwed,
    };
  }

  String _interestPeriodLabel(InterestPeriod period) {
    final l10n = context.l10n;
    return switch (period) {
      InterestPeriod.daily => l10n.interestPeriodDaily,
      InterestPeriod.weekly => l10n.repeatWeekly,
      InterestPeriod.monthly => l10n.repeatMonthly,
      InterestPeriod.quarterly => l10n.repeatQuarterly,
      InterestPeriod.halfYear => l10n.repeatHalfYear,
      InterestPeriod.yearly => l10n.repeatYearly,
    };
  }

  Widget _buildMandatoryFields(
    AppLocalizations l10n,
    AsyncValue<List<FireflyCurrency>> currenciesAsync,
    List<String> accountNameSuggestions,
    List<String> decimalSuggestions,
  ) {
    final format = ref.watch(localeFormattingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.mandatoryFields),
        withTooltip(
          l10n.tooltipAccountName,
          AutocompleteTextField(
            controller: _nameController,
            autofocus: true,
            suggestions: accountNameSuggestions,
            decoration: _fieldDecoration(l10n.accountName),
          ),
        ),
        const SizedBox(height: 16),
        currenciesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(e.toString()),
          data: (currencies) => DropdownButtonFormField<String>(
            initialValue: currencies.any((c) => c.code == _currencyCode)
                ? _currencyCode
                : currencies.firstOrNull?.code,
            decoration: _fieldDecoration(
              l10n.defaultCurrency,
              helper: l10n.liabilityCurrencyHelp,
            ),
            items: currencies
                .map(
                  (c) => DropdownMenuItem(
                    value: c.code,
                    child: Text(l10n.currencyPair(c.name, c.symbol)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _currencyCode = value);
            },
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<LiabilityType>(
          initialValue: _liabilityType,
          decoration: _fieldDecoration(l10n.liabilityType),
          items: LiabilityType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(_liabilityTypeLabel(type)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _liabilityType = value);
          },
        ),
        const SizedBox(height: 16),
        AutocompleteTextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suggestions: const [],
          decoration: _fieldDecoration(l10n.amountOwed),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<LiabilityDirection>(
          initialValue: _liabilityDirection,
          decoration: _fieldDecoration(l10n.liabilityDirection),
          items: LiabilityDirection.values
              .map(
                (direction) => DropdownMenuItem(
                  value: direction,
                  child: Text(_liabilityDirectionLabel(direction)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _liabilityDirection = value);
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickStartDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _fieldDecoration(l10n.debtStartDate),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _startDate != null
                        ? format.formatMediumDate(_startDate!)
                        : '—',
                  ),
                ),
                const Icon(LucideIcons.calendar, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AutocompleteTextField(
          controller: _interestController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suggestions: const [],
          decoration: _fieldDecoration(l10n.interestRate),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<InterestPeriod?>(
          initialValue: _interestPeriod,
          decoration: _fieldDecoration(
            l10n.interestPeriod,
            helper: l10n.interestPeriodHelp,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('—')),
            ...InterestPeriod.values.map(
              (period) => DropdownMenuItem(
                value: period,
                child: Text(_interestPeriodLabel(period)),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _interestPeriod = value),
        ),
      ],
    );
  }

  Widget _buildOptionalFields(
    AppLocalizations l10n,
    List<String> noteSuggestions,
    ({List<String> ibans, List<String> bics, List<String> accountNumbers})
    bankingSuggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(l10n.optionalFields),
        AutocompleteTextField(
          controller: _ibanController,
          suggestions: bankingSuggestions.ibans,
          decoration: _fieldDecoration(l10n.iban),
        ),
        const SizedBox(height: 16),
        AutocompleteTextField(
          controller: _bicController,
          suggestions: bankingSuggestions.bics,
          decoration: _fieldDecoration(l10n.bic),
        ),
        const SizedBox(height: 16),
        AutocompleteTextField(
          controller: _accountNumberController,
          suggestions: bankingSuggestions.accountNumbers,
          decoration: _fieldDecoration(l10n.accountNumber),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.includeInNetWorth),
          value: _includeNetWorth,
          onChanged: (value) {
            if (value != null) setState(() => _includeNetWorth = value);
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        AutocompleteTextField(
          controller: _notesController,
          maxLines: 4,
          suggestions: noteSuggestions,
          decoration: _fieldDecoration(l10n.notes),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final currenciesAsync = ref.watch(currenciesProvider);
    final accounts = ref.watch(accountsProvider).value ?? [];
    final accountNameSuggestions = AutocompleteSuggestions.accountNames(
      accounts,
    );
    final noteSuggestions = ref.watch(notesSuggestionsProvider);
    final bankingSuggestions = (
      ibans: AutocompleteSuggestions.liabilityIbans(accounts),
      bics: AutocompleteSuggestions.liabilityBics(accounts),
      accountNumbers: AutocompleteSuggestions.liabilityAccountNumbers(accounts),
    );
    final decimalSuggestions = ref.watch(decimalSuggestionsProvider);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
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
                      LucideIcons.plus,
                      color: colors.accent.acc,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.newLiability,
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
                      final wide = constraints.maxWidth > 620;
                      final mandatory = _buildMandatoryFields(
                        l10n,
                        currenciesAsync,
                        accountNameSuggestions,
                        decimalSuggestions,
                      );
                      final optional = _buildOptionalFields(
                        l10n,
                        noteSuggestions,
                        bankingSuggestions,
                      );

                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  withTooltip(
                    l10n.tooltipCreate,
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
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
                          : Text(l10n.create),
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
