import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../models/account.dart';
import '../models/bill.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/currency.dart';
import '../models/piggy_bank.dart';
import '../models/transaction.dart';
import '../providers/people_providers.dart';
import '../providers/data_providers.dart';
import '../providers/suggestion_providers.dart';
import '../theme/app_theme.dart';
import '../utils/autocomplete_suggestions.dart';
import 'autocomplete_text_field.dart';
import 'budget_create_dialog.dart';
import 'category_form_dialog.dart';
import 'payee_form_dialog.dart';

class TransactionEditPanel extends ConsumerStatefulWidget {
  final Transaction transaction;
  final VoidCallback onCancel;
  final Future<void> Function(Transaction updated) onSave;
  final bool isCreating;
  final bool embedded;
  final String? lockedType;

  const TransactionEditPanel({
    super.key,
    required this.transaction,
    required this.onCancel,
    required this.onSave,
    this.isCreating = false,
    this.embedded = true,
    this.lockedType,
  });

  @override
  ConsumerState<TransactionEditPanel> createState() =>
      _TransactionEditPanelState();
}

class _SplitDraft {
  _SplitDraft({
    required String description,
    required String amount,
    required String foreignAmount,
    required String category,
    required String budget,
    required String tags,
    required String notes,
    required String? sourceName,
    required String? destinationName,
    required this.currencyCode,
    required this.foreignCurrencyCode,
    required this.budgetId,
    required this.billId,
    required this.piggyBankId,
    required this.interestDate,
    this.reconciled = false,
  }) : descriptionController = TextEditingController(text: description),
       amountController = TextEditingController(text: amount),
       foreignAmountController = TextEditingController(text: foreignAmount),
       categoryController = TextEditingController(text: category),
       budgetController = TextEditingController(text: budget),
       tagsController = TextEditingController(text: tags),
       notesController = TextEditingController(text: notes),
       sourceController = TextEditingController(text: sourceName ?? ''),
       destinationController = TextEditingController(
         text: destinationName ?? '',
       );

  final TextEditingController descriptionController;
  final TextEditingController amountController;
  final TextEditingController foreignAmountController;
  final TextEditingController categoryController;
  final TextEditingController budgetController;
  final TextEditingController tagsController;
  final TextEditingController notesController;
  final TextEditingController sourceController;
  final TextEditingController destinationController;

  String? get sourceName {
    final text = sourceController.text.trim();
    return text.isEmpty ? null : text;
  }

  String? get destinationName {
    final text = destinationController.text.trim();
    return text.isEmpty ? null : text;
  }

  String currencyCode;
  String? foreignCurrencyCode;
  String? budgetId;
  String? billId;
  String? piggyBankId;
  DateTime? interestDate;
  bool reconciled;

  factory _SplitDraft.fromTransaction(
    Transaction t, {
    bool blankAmount = false,
  }) {
    return _SplitDraft(
      description: t.description,
      amount: blankAmount || t.amount == 0 ? '' : t.amount.toString(),
      foreignAmount: t.foreignAmount?.toString() ?? '',
      category: t.categoryName,
      budget: t.budgetName ?? '',
      tags: t.tags.join(', '),
      notes: t.notes ?? '',
      sourceName: t.sourceName.isEmpty ? null : t.sourceName,
      destinationName: t.destinationName.isEmpty ? null : t.destinationName,
      currencyCode: t.currencyCode,
      foreignCurrencyCode: t.foreignCurrencyCode,
      budgetId: t.budgetId,
      billId: t.billId,
      piggyBankId: t.piggyBankId,
      interestDate: t.interestDate,
      reconciled: t.reconciled,
    );
  }

  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    foreignAmountController.dispose();
    categoryController.dispose();
    budgetController.dispose();
    tagsController.dispose();
    notesController.dispose();
    sourceController.dispose();
    destinationController.dispose();
  }
}

class _TransactionEditPanelState extends ConsumerState<TransactionEditPanel> {
  late String _type;
  late DateTime _date;
  late List<_SplitDraft> _splits;
  late TextEditingController _groupTitleController;
  bool _saving = false;
  double? _targetTotal;
  bool _optionalFieldsExpanded = false;

  ThemeData _datePickerTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      dialogTheme: theme.dialogTheme.copyWith(
        constraints: const BoxConstraints(minWidth: 560),
      ),
    );
  }

  void _loadFromTransaction(Transaction t) {
    for (final split in _splits) {
      split.dispose();
    }
    _type = widget.lockedType ?? t.type;
    _date = t.date;
    final sourceSplits = t.resolvedSplits();
    _splits = sourceSplits
        .map((split) => _SplitDraft.fromTransaction(split))
        .toList();
    if (_splits.isEmpty) {
      _splits.add(
        _SplitDraft.fromTransaction(t, blankAmount: widget.isCreating),
      );
    }
    _groupTitleController.text = t.groupTitle ?? t.description;
    _targetTotal = _resolveTargetTotal(t, sourceSplits);
  }

  double? _resolveTargetTotal(
    Transaction transaction,
    List<Transaction> sourceSplits,
  ) {
    if (!widget.isCreating || sourceSplits.length > 1) {
      return transaction.totalAmount;
    }
    return transaction.amount > 0 ? transaction.amount : null;
  }

  double _currentSplitSum() {
    return _splits.fold(0.0, (sum, draft) {
      final amount = double.tryParse(draft.amountController.text.trim());
      return sum + (amount ?? 0);
    });
  }

  @override
  void initState() {
    super.initState();
    _splits = [];
    _groupTitleController = TextEditingController();
    _loadFromTransaction(widget.transaction);
  }

  @override
  void didUpdateWidget(covariant TransactionEditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transaction.id != widget.transaction.id ||
        oldWidget.isCreating != widget.isCreating) {
      _loadFromTransaction(widget.transaction);
    }
  }

  @override
  void dispose() {
    for (final split in _splits) {
      split.dispose();
    }
    _groupTitleController.dispose();
    super.dispose();
  }

  Account? _accountByName(List<Account> accounts, String? name) {
    if (name == null) return null;
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return accounts
        .where((a) => a.name.trim().toLowerCase() == normalized)
        .firstOrNull;
  }

  bool _requiresForeignAmount(_SplitDraft split, List<Account> accounts) {
    // Resolve both ends, including expense/revenue counterparties, so a
    // same-currency withdrawal never asks the user for a foreign amount.
    final counterparties =
        ref.watch(counterpartyAccountsProvider).value ?? const <Account>[];
    final all = [...accounts, ...counterparties];
    final source = _accountByName(all, split.sourceName);
    final destination = _accountByName(all, split.destinationName);
    final involved = [
      if (source != null) source.currencyCode,
      if (destination != null) destination.currencyCode,
    ];
    if (involved.isEmpty) return false;
    return involved.any((code) => code != split.currencyCode);
  }

  List<Account> _accountsForField(
    List<Account> accounts,
    bool isSource, {
    String? selectedName,
  }) {
    // Expense/revenue counterparties come from a separate fetch; without
    // them a withdrawal's destination (or deposit's source) list is empty
    // and the field renders blank and unselectable.
    final counterparties =
        ref.watch(counterpartyAccountsProvider).value ?? const <Account>[];
    final all = [...accounts, ...counterparties];
    bool isAssetLike(Account a) => a.type == 'asset' || a.type == 'cash';
    // Hide inactive accounts from asset/cash lists so closed accounts
    // don't clutter the dropdown.
    bool isActiveAssetLike(Account a) => isAssetLike(a) && a.active;
    final filtered = switch (_type) {
      'withdrawal' =>
        isSource
            ? all.where(isActiveAssetLike).toList()
            : all
                  .where((a) => a.type == 'expense' || a.type == 'liability')
                  .toList(),
      'deposit' =>
        isSource
            ? all.where((a) => a.type == 'revenue').toList()
            : all.where(isActiveAssetLike).toList(),
      'transfer' => all.where(isActiveAssetLike).toList(),
      _ => all,
    };

    if (selectedName == null || selectedName.isEmpty) return filtered;
    if (filtered.any((account) => account.name == selectedName)) {
      return filtered;
    }
    final selected = all
        .where((account) => account.name == selectedName)
        .firstOrNull;
    if (selected == null) return filtered;
    return [selected, ...filtered];
  }

  String _sourceAccountLabel(AppLocalizations l10n) => switch (_type) {
    'deposit' => l10n.revenueAccount,
    'withdrawal' => l10n.assetAccount,
    _ => l10n.sourceAccount,
  };

  String _destinationAccountLabel(AppLocalizations l10n) => switch (_type) {
    'deposit' => l10n.assetAccount,
    'withdrawal' => l10n.payee,
    _ => l10n.destinationAccount,
  };

  String _panelTitle(AppLocalizations l10n) {
    if (widget.isCreating) {
      return switch (_type) {
        'deposit' => l10n.newDeposit,
        'withdrawal' => l10n.newWithdrawal,
        'transfer' => l10n.newTransfer,
        _ => l10n.newTransaction,
      };
    }
    return switch (_type) {
      'deposit' => l10n.editDeposit,
      'withdrawal' => l10n.editWithdrawal,
      'transfer' => l10n.editTransfer,
      _ => l10n.editTransaction,
    };
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(data: _datePickerTheme(context), child: child!);
      },
    );
    if (date == null || !mounted) return;

    setState(() {
      _date = DateTime(
        date.year,
        date.month,
        date.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  void _addSplit() {
    setState(() {
      if (_splits.length == 1 && _targetTotal == null) {
        final amount = double.tryParse(
          _splits.first.amountController.text.trim(),
        );
        if (amount != null && amount > 0) {
          _targetTotal = amount;
        }
      }
      final template = _splits.last;
      _splits.add(
        _SplitDraft(
          description: template.descriptionController.text,
          amount: '',
          foreignAmount: '',
          category: '',
          budget: '',
          tags: '',
          notes: '',
          sourceName: template.sourceName,
          destinationName: null,
          currencyCode: template.currencyCode,
          foreignCurrencyCode: null,
          budgetId: null,
          billId: null,
          piggyBankId: null,
          interestDate: null,
          reconciled: false,
        ),
      );
    });
  }

  void _removeSplit(int index) {
    if (_splits.length <= 1) return;
    setState(() {
      _splits.removeAt(index).dispose();
    });
  }

  Transaction _buildTransaction({
    required List<Account> accounts,
    required List<Category> categories,
    required List<Budget> budgets,
    required List<Bill> bills,
    required List<PiggyBank> piggyBanks,
    required List<FireflyCurrency> currencies,
  }) {
    final splits = <Transaction>[];
    for (final draft in _splits) {
      final requiresForeign = _requiresForeignAmount(draft, accounts);
      final amount = double.tryParse(draft.amountController.text.trim()) ?? 0;
      final foreignText = draft.foreignAmountController.text.trim();
      final foreignAmount = !requiresForeign || foreignText.isEmpty
          ? null
          : double.tryParse(foreignText);
      final counterparties =
          ref.watch(counterpartyAccountsProvider).value ?? const <Account>[];
      final allAccounts = [...accounts, ...counterparties];
      final source = _accountByName(allAccounts, draft.sourceName);
      final destination = _accountByName(allAccounts, draft.destinationName);
      final categoryName = draft.categoryController.text.trim();
      final category = categories
          .where((c) => c.name.toLowerCase() == categoryName.toLowerCase())
          .firstOrNull;
      final budgetName = draft.budgetController.text.trim();
      final budget = budgets
          .where((b) => b.name.toLowerCase() == budgetName.toLowerCase())
          .firstOrNull;
      final currency = currencies
          .where((c) => c.code == draft.currencyCode)
          .firstOrNull;
      final foreignCurrency = draft.foreignCurrencyCode == null
          ? null
          : currencies
                .where((c) => c.code == draft.foreignCurrencyCode)
                .firstOrNull;
      final tags = draft.tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final bill = bills.where((b) => b.id == draft.billId).firstOrNull;
      final piggy = piggyBanks
          .where((p) => p.id == draft.piggyBankId)
          .firstOrNull;

      splits.add(
        Transaction(
          id: widget.transaction.id,
          type: _type,
          date: _date,
          amount: amount,
          description: draft.descriptionController.text.trim(),
          sourceName: draft.sourceName ?? '',
          destinationName: draft.destinationName ?? '',
          categoryName: categoryName,
          currencySymbol: currency?.symbol ?? widget.transaction.currencySymbol,
          currencyCode: draft.currencyCode,
          foreignAmount: foreignAmount,
          foreignCurrencySymbol: foreignCurrency?.symbol,
          foreignCurrencyCode: requiresForeign
              ? (draft.foreignCurrencyCode ?? draft.currencyCode)
              : null,
          sourceId: source?.id,
          destinationId: destination?.id,
          categoryId: category?.id,
          budgetId: budget?.id,
          budgetName: budgetName.isEmpty ? null : budgetName,
          notes: draft.notesController.text.trim(),
          tags: tags,
          billId: draft.billId,
          billName: bill?.name,
          piggyBankId: draft.piggyBankId,
          piggyBankName: piggy?.name,
          interestDate: draft.interestDate,
          reconciled: draft.reconciled,
          groupTitle: _splits.length > 1
              ? (_groupTitleController.text.trim().isNotEmpty
                    ? _groupTitleController.text.trim()
                    : _splits.first.descriptionController.text.trim())
              : widget.transaction.groupTitle,
        ),
      );
    }

    if (splits.length == 1) return splits.first;
    return splits.first.copyWith(splits: splits);
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final accounts = await ref.read(accountsProvider.future);
    if (!mounted) return;

    for (final split in _splits) {
      final description = split.descriptionController.text.trim();
      final amountRaw = split.amountController.text.trim();
      final amount = double.tryParse(amountRaw);
      final foreignAmountRaw = split.foreignAmountController.text.trim();
      final foreignAmount = double.tryParse(foreignAmountRaw);
      final requiresForeign = _requiresForeignAmount(split, accounts);

      if (description.isEmpty) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.missingDescription)),
        );
        return;
      }
      if (amountRaw.isEmpty) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.missingAmount)),
        );
        return;
      }
      if (amount == null || amount <= 0) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.invalidAmount)),
        );
        return;
      }
      if (split.sourceName == null || split.destinationName == null) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.missingAccounts)),
        );
        return;
      }
      if (requiresForeign) {
        if (foreignAmountRaw.isEmpty) {
          setState(() => _saving = false);
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.missingAmount)),
          );
          return;
        }
        if (foreignAmount == null || foreignAmount <= 0) {
          setState(() => _saving = false);
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.invalidForeignAmount)),
          );
          return;
        }
      }
    }

    if (_splits.length > 1 && _targetTotal != null) {
      final sum = _currentSplitSum();
      if ((sum - _targetTotal!).abs() > 0.005) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.splitsTotalMismatch(
                context.format.formatMoney(
                  _targetTotal!,
                  widget.transaction.currencySymbol,
                ),
              ),
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final categories = await ref.read(categoriesProvider.future);
      final budgets = await ref.read(budgetsProvider.future);
      final bills = await ref.read(billsProvider.future);
      final piggyBanks = await ref.read(piggyBanksProvider.future);
      final currencies = await ref.read(currenciesProvider.future);
      final updated = _buildTransaction(
        accounts: accounts,
        categories: categories,
        budgets: budgets,
        bills: bills,
        piggyBanks: piggyBanks,
        currencies: currencies,
      );
      await widget.onSave(updated);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration(AppLocalizations l10n, String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  Widget _gapBox({required bool compact}) => SizedBox(height: compact ? 6 : 10);

  Widget _withTooltip(String message, Widget child) {
    return Tooltip(message: message, child: child);
  }

  Widget _currencyDropdown({
    required String label,
    required String value,
    required List<FireflyCurrency> currencies,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    final items = currencies
        .map(
          (c) => DropdownMenuItem(
            value: c.code,
            child: Text('${c.name} (${c.symbol})'),
          ),
        )
        .toList();
    final selected = items.any((i) => i.value == value)
        ? value
        : items.firstOrNull?.value;

    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: _fieldDecoration(context.l10n, label),
      isExpanded: true,
      items: items,
      onChanged: enabled ? onChanged : null,
    );
  }

  Future<void> _pickInterestDate(_SplitDraft split) async {
    final date = await showDatePicker(
      context: context,
      initialDate: split.interestDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(data: _datePickerTheme(context), child: child!);
      },
    );
    if (date != null && mounted) {
      setState(() => split.interestDate = date);
    }
  }

  Widget _buildSplitTotalBanner(AppLocalizations l10n) {
    if (_splits.length <= 1) return const SizedBox.shrink();

    final colors = context.colors;
    final format = context.format;
    final sum = _currentSplitSum();
    final target = _targetTotal;
    final mismatch = target != null && (sum - target).abs() > 0.005;
    final remainder = target == null ? null : target - sum;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: mismatch
            ? colors.danger.withValues(alpha: 0.08)
            : colors.accent.acc.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mismatch
              ? colors.danger.withValues(alpha: 0.45)
              : colors.accent.acc.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.splitTotalLabel(
                format.formatMoney(sum, widget.transaction.currencySymbol),
              ),
              style: TextStyle(
                color: mismatch ? colors.danger : colors.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (remainder != null && remainder.abs() > 0.005)
            Text(
              l10n.splitRemainder(
                format.formatMoney(
                  remainder.abs(),
                  widget.transaction.currencySymbol,
                ),
              ),
              style: TextStyle(
                color: mismatch ? colors.danger : colors.text3,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSplitSection({
    required int index,
    required _SplitDraft split,
    required List<Account> accounts,
    required List<Budget> budgets,
    required List<Bill> bills,
    required List<PiggyBank> piggyBanks,
    required List<FireflyCurrency> currencies,
    required List<Category> categories,
    required List<String> tags,
    required List<String> descriptionSuggestions,
    required List<String> notesSuggestions,
    required List<String> decimalSuggestions,
    required bool wide,
  }) {
    final l10n = context.l10n;
    final colors = context.colors;
    final format = context.format;
    final compact = widget.embedded || _splits.length > 1;
    final requiresForeign = _requiresForeignAmount(split, accounts);
    final rowGap = compact ? 8.0 : 12.0;

    final descriptionField = _withTooltip(
      l10n.tooltipFieldDescription,
      AutocompleteTextField(
        controller: split.descriptionController,
        suggestions: descriptionSuggestions,
        decoration: _fieldDecoration(l10n, l10n.description),
      ),
    );

    final amountField = _withTooltip(
      l10n.tooltipFieldAmount,
      AutocompleteTextField(
        controller: split.amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        suggestions: const [],
        decoration: _fieldDecoration(l10n, l10n.amount),
        onChanged: (_) => setState(() {}),
      ),
    );

    final sourceAccounts = _accountsForField(
      accounts,
      true,
      selectedName: split.sourceName,
    );
    final destinationAccounts = _accountsForField(
      accounts,
      false,
      selectedName: split.destinationName,
    );

    final sourceField = _withTooltip(
      l10n.tooltipFieldSourceAccount,
      AutocompleteTextField(
        controller: split.sourceController,
        suggestions: AutocompleteSuggestions.accountNames(sourceAccounts),
        decoration: _fieldDecoration(l10n, _sourceAccountLabel(l10n)),
        onChanged: (_) => setState(() {}),
      ),
    );

    // For withdrawals the destination is a payee (expense account); allow
    // inline creation. For deposits the source is a revenue account; allow
    // inline creation there too.
    final destinationField = _withTooltip(
      l10n.tooltipFieldDestinationAccount,
      AutocompleteTextField(
        controller: split.destinationController,
        suggestions: AutocompleteSuggestions.accountNames(destinationAccounts),
        decoration: _fieldDecoration(l10n, _destinationAccountLabel(l10n)),
        onChanged: (_) => setState(() {}),
        onCreateNew: _type == 'withdrawal'
            ? (typed) async {
                final created = await showPayeeFormDialog(
                  context: context,
                  ref: ref,
                  initialName: typed,
                );
                if (created == true && mounted) {
                  split.destinationController.text = typed;
                  setState(() {});
                }
              }
            : null,
        createLabel: _type == 'withdrawal' ? l10n.createPayee : null,
      ),
    );

    final sourceFieldWithCreate = _type == 'deposit'
        ? _withTooltip(
            l10n.tooltipFieldSourceAccount,
            AutocompleteTextField(
              controller: split.sourceController,
              suggestions: AutocompleteSuggestions.accountNames(sourceAccounts),
              decoration: _fieldDecoration(l10n, _sourceAccountLabel(l10n)),
              onChanged: (_) => setState(() {}),
              onCreateNew: (typed) async {
                final created = await showPayeeFormDialog(
                  context: context,
                  ref: ref,
                  initialName: typed,
                );
                if (created == true && mounted) {
                  split.sourceController.text = typed;
                  setState(() {});
                }
              },
              createLabel: l10n.createPayee,
            ),
          )
        : sourceField;

    final categoryField = _withTooltip(
      l10n.tooltipFieldCategory,
      AutocompleteTextField(
        controller: split.categoryController,
        suggestions: AutocompleteSuggestions.categoryNames(categories),
        decoration: _fieldDecoration(l10n, l10n.category),
        onCreateNew: (typed) async {
          final created = await showCategoryFormDialog(
            context: context,
            ref: ref,
            initialName: typed,
          );
          if (created == true && mounted) {
            split.categoryController.text = typed;
            setState(() {});
          }
        },
        createLabel: l10n.createCategory,
      ),
    );

    if (split.budgetController.text.isEmpty && split.budgetId != null) {
      final matchingBudget = budgets
          .where((b) => b.id == split.budgetId)
          .firstOrNull;
      if (matchingBudget != null) {
        split.budgetController.text = matchingBudget.name;
      }
    }

    final budgetField = _withTooltip(
      l10n.tooltipFieldBudget,
      AutocompleteTextField(
        controller: split.budgetController,
        suggestions: AutocompleteSuggestions.budgetNames(budgets),
        decoration: _fieldDecoration(l10n, l10n.budgetLabel),
        onCreateNew: (typed) async {
          final created = await showBudgetCreateDialog(
            context: context,
            ref: ref,
            initialName: typed,
          );
          if (created == true && mounted) {
            split.budgetController.text = typed;
            setState(() {});
          }
        },
        createLabel: l10n.createBudget,
      ),
    );

    final currencyField = _withTooltip(
      l10n.tooltipFieldCurrency,
      _currencyDropdown(
        label: l10n.defaultCurrency,
        value: split.currencyCode,
        currencies: currencies,
        onChanged: (code) {
          if (code == null) return;
          setState(() => split.currencyCode = code);
        },
      ),
    );

    final dateField = _withTooltip(
      l10n.tooltipFieldDate,
      InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: _fieldDecoration(l10n, l10n.transactionDate),
          child: Text(format.formatMediumDate(_date)),
        ),
      ),
    );

    final optionalFields = <Widget>[
      currencyField,
      _gapBox(compact: compact),
      _withTooltip(
        l10n.tooltipFieldTags,
        AutocompleteTextField(
          controller: split.tagsController,
          tagMode: true,
          suggestions: tags,
          decoration: _fieldDecoration(l10n, l10n.tags),
        ),
      ),
      _gapBox(compact: compact),
      _withTooltip(
        l10n.tooltipFieldPiggyBank,
        DropdownButtonFormField<String?>(
          initialValue: split.piggyBankId,
          decoration: _fieldDecoration(l10n, l10n.piggyBank),
          isExpanded: true,
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.noPiggyBank)),
            ...piggyBanks.map(
              (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
            ),
          ],
          onChanged: (v) => setState(() => split.piggyBankId = v),
        ),
      ),
      _gapBox(compact: compact),
      _withTooltip(
        l10n.tooltipFieldSubscription,
        DropdownButtonFormField<String?>(
          initialValue: split.billId,
          decoration: _fieldDecoration(l10n, l10n.subscription),
          isExpanded: true,
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.none)),
            ...bills.map(
              (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
            ),
          ],
          onChanged: (v) => setState(() => split.billId = v),
        ),
      ),
      if (bills.isEmpty) ...[
        const SizedBox(height: 4),
        Text(
          l10n.noSubscriptionsHint,
          style: TextStyle(color: colors.text3, fontSize: 11),
        ),
      ],
      _gapBox(compact: compact),
      _withTooltip(
        l10n.tooltipFieldInterestDate,
        InkWell(
          onTap: () => _pickInterestDate(split),
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: _fieldDecoration(l10n, l10n.interestDate),
            child: Text(
              split.interestDate != null
                  ? format.formatMediumDate(split.interestDate!)
                  : l10n.notSet,
            ),
          ),
        ),
      ),
      if (!widget.isCreating) ...[
        _gapBox(compact: compact),
        _withTooltip(
          l10n.tooltipTransactionReconciled,
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.transactionReconciled,
                  style: TextStyle(color: colors.text, fontSize: 13),
                ),
              ),
              Switch(
                value: split.reconciled,
                onChanged: (value) => setState(() => split.reconciled = value),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ],
      _gapBox(compact: compact),
      _withTooltip(
        l10n.tooltipFieldNotes,
        AutocompleteTextField(
          controller: split.notesController,
          maxLines: compact ? 2 : 3,
          suggestions: notesSuggestions,
          decoration: _fieldDecoration(l10n, l10n.notes),
        ),
      ),
      if (requiresForeign) ...[
        _gapBox(compact: compact),
        _withTooltip(
          l10n.tooltipFieldForeignAmount,
          AutocompleteTextField(
            controller: split.foreignAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suggestions: const [],
            decoration: _fieldDecoration(l10n, l10n.foreignAmountLabel),
            onChanged: (_) => setState(() {}),
          ),
        ),
        _gapBox(compact: compact),
        _withTooltip(
          l10n.tooltipFieldForeignCurrency,
          _currencyDropdown(
            label: l10n.foreignCurrency,
            value: split.foreignCurrencyCode ?? split.currencyCode,
            currencies: currencies,
            onChanged: (code) =>
                setState(() => split.foreignCurrencyCode = code),
          ),
        ),
      ],
    ];

    // Payee/destination leads; description sits where currency used to be;
    // default currency lives under optional fields.
    final coreFields = wide
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: destinationField),
                  SizedBox(width: rowGap),
                  Expanded(flex: 2, child: amountField),
                ],
              ),
              _gapBox(compact: compact),
              sourceFieldWithCreate,
              _gapBox(compact: compact),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: categoryField),
                  SizedBox(width: rowGap),
                  Expanded(child: budgetField),
                  if (!compact) ...[
                    SizedBox(width: rowGap),
                    Expanded(child: descriptionField),
                  ],
                ],
              ),
              if (compact) ...[_gapBox(compact: compact), descriptionField],
              if (index == 0) ...[_gapBox(compact: compact), dateField],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              destinationField,
              _gapBox(compact: compact),
              amountField,
              _gapBox(compact: compact),
              sourceFieldWithCreate,
              _gapBox(compact: compact),
              categoryField,
              _gapBox(compact: compact),
              budgetField,
              _gapBox(compact: compact),
              descriptionField,
              if (index == 0) ...[_gapBox(compact: compact), dateField],
            ],
          );

    final expandedOptionalFields = compact
        ? Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            // Transparent Material so the tile's ink renders correctly when
            // the panel is embedded in a decorated row container.
            child: Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                initiallyExpanded: _optionalFieldsExpanded,
                onExpansionChanged: (expanded) =>
                    setState(() => _optionalFieldsExpanded = expanded),
                title: Text(
                  l10n.splitOptionalFields,
                  style: TextStyle(
                    color: colors.text2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: optionalFields,
                    ),
                  ),
                ],
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact) ...[_gapBox(compact: compact), ...optionalFields],
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_splits.length > 1)
          Row(
            children: [
              Text(
                l10n.splitLabel(index + 1),
                style: TextStyle(
                  color: colors.text2,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12 : 13,
                ),
              ),
              const Spacer(),
              _withTooltip(
                l10n.tooltipRemoveSplit,
                TextButton.icon(
                  onPressed: () => _removeSplit(index),
                  icon: Icon(LucideIcons.trash2, size: compact ? 14 : 16),
                  label: Text(l10n.removeSplit),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        if (_splits.length > 1) _gapBox(compact: compact),
        coreFields,
        if (compact) expandedOptionalFields else ...optionalFields,
        if (index < _splits.length - 1)
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 16),
            child: Divider(color: colors.border, height: 1),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final accountsAsync = ref.watch(accountsProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final billsAsync = ref.watch(billsProvider);
    final piggyBanksAsync = ref.watch(piggyBanksProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);
    // Rebuild account pickers once expense/revenue counterparties load.
    ref.watch(counterpartyAccountsProvider);

    final accounts = accountsAsync.value ?? [];
    final budgets = budgetsAsync.value ?? [];
    final bills = billsAsync.value ?? [];
    final piggyBanks = piggyBanksAsync.value ?? [];
    final currencies = currenciesAsync.value ?? [];
    final categories = categoriesAsync.value ?? [];
    final tags =
        (tagsAsync.value ?? [])
            .map((tag) => tag.name)
            .where((tag) => tag.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final descriptionSuggestions = ref.watch(
      transactionDescriptionSuggestionsProvider,
    );
    final notesSuggestions = ref.watch(notesSuggestionsProvider);
    final groupTitleSuggestions = ref.watch(groupTitleSuggestionsProvider);
    final decimalSuggestions = ref.watch(decimalSuggestionsProvider);

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accent.acc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.isCreating ? LucideIcons.plus : LucideIcons.pencil,
                  color: colors.accent.acc,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                _panelTitle(l10n),
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Icon(
                widget.isCreating ? LucideIcons.plus : LucideIcons.pencil,
                size: 14,
                color: colors.text3,
              ),
              const SizedBox(width: 8),
              Text(
                _panelTitle(l10n),
                style: TextStyle(
                  color: colors.text3,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Text(
          l10n.transactionInformation,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 2, color: colors.accent.acc),
        const SizedBox(height: 16),
        if (widget.isCreating && widget.lockedType == null) ...[
          _withTooltip(
            l10n.tooltipTransactionType,
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'withdrawal',
                  label: Text(l10n.transactionTypeWithdrawal),
                ),
                ButtonSegment(
                  value: 'deposit',
                  label: Text(l10n.transactionTypeDeposit),
                ),
                ButtonSegment(
                  value: 'transfer',
                  label: Text(l10n.transactionTypeTransfer),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = widget.embedded || _splits.length > 1;
            final wide = constraints.maxWidth > (compact ? 480 : 720);
            return Column(
              children: [
                if (_splits.length > 1) ...[
                  _withTooltip(
                    l10n.tooltipSubscriptionGroup,
                    AutocompleteTextField(
                      controller: _groupTitleController,
                      suggestions: groupTitleSuggestions,
                      decoration: _fieldDecoration(l10n, l10n.group),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSplitTotalBanner(l10n),
                ],
                for (var i = 0; i < _splits.length; i++)
                  _buildSplitSection(
                    index: i,
                    split: _splits[i],
                    accounts: accounts,
                    budgets: budgets,
                    bills: bills,
                    piggyBanks: piggyBanks,
                    currencies: currencies,
                    categories: categories,
                    tags: tags,
                    descriptionSuggestions: descriptionSuggestions,
                    notesSuggestions: notesSuggestions,
                    decimalSuggestions: decimalSuggestions,
                    wide: wide,
                  ),
              ],
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _withTooltip(
            l10n.tooltipAddSplit,
            TextButton.icon(
              onPressed: _addSplit,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(l10n.addAnotherSplit),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _withTooltip(
              l10n.tooltipCancelTransaction,
              TextButton(
                onPressed: _saving ? null : widget.onCancel,
                child: Text(l10n.cancel),
              ),
            ),
            const SizedBox(width: 8),
            _withTooltip(
              l10n.tooltipSaveTransaction,
              ElevatedButton(
                onPressed:
                    (_saving || !ref.watch(canWriteFinancialDataProvider))
                    ? null
                    : _save,
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
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ],
    );

    if (!widget.embedded) return form;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.embedded && _splits.length > 1 ? 16 : 20),
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: colors.border)),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: form,
    );
  }
}

Transaction newTransactionTemplate({
  required String currencySymbol,
  required String currencyCode,
  String type = 'withdrawal',
  String? sourceName,
  String? sourceId,
  String? destinationName,
  String? destinationId,
}) {
  return Transaction(
    id: '',
    type: type,
    date: DateTime.now(),
    amount: 0,
    description: '',
    sourceName: sourceName ?? '',
    destinationName: destinationName ?? '',
    categoryName: '',
    currencySymbol: currencySymbol,
    currencyCode: currencyCode,
    sourceId: sourceId,
    destinationId: destinationId,
  );
}

Future<bool?> showNewTransactionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Transaction initial,
  required Future<void> Function(Transaction transaction) onCreate,
  String? lockedType,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: TransactionEditPanel(
              transaction: initial,
              isCreating: true,
              embedded: false,
              lockedType: lockedType,
              onCancel: () => Navigator.of(ctx).pop(false),
              onSave: (transaction) async {
                await onCreate(transaction);
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
            ),
          ),
        ),
      ),
    ),
  );
}
