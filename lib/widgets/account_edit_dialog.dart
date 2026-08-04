import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../models/account.dart';
import '../providers/account_classification_provider.dart';
import '../providers/data_providers.dart';
import '../providers/people_providers.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/autocomplete_suggestions.dart';
import '../utils/locale_formatting.dart';
import 'autocomplete_text_field.dart';
import 'tooltip_helpers.dart';

Future<bool?> showAccountEditDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Account account,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AccountEditDialog(account: account),
  ).then((saved) {
    if (saved == true) {
      ref.invalidate(accountsProvider);
    }
    return saved;
  });
}

class AccountEditDialog extends ConsumerStatefulWidget {
  final Account account;

  const AccountEditDialog({super.key, required this.account});

  @override
  ConsumerState<AccountEditDialog> createState() => _AccountEditDialogState();
}

class _AccountEditDialogState extends ConsumerState<AccountEditDialog>
    with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _ibanController;
  late TextEditingController _bicController;
  late TextEditingController _accountNumberController;
  late TextEditingController _openingBalanceController;
  late TextEditingController _virtualBalanceController;
  late TextEditingController _interestController;
  late TextEditingController _notesController;

  late String _type;
  late String _currencyCode;
  late AccountCategory _selectedCategory;
  late String _selectedRole;
  late String _liabilityType;
  late String _liabilityDirection;
  late bool _active;
  late bool _includeNetWorth;
  DateTime? _openingBalanceDate;
  String? _interestPeriod;

  bool _saving = false;
  bool _deleting = false;

  late TabController _tabController;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _nameController = TextEditingController(text: acc.name);
    _ibanController = TextEditingController(text: acc.iban ?? '');
    _bicController = TextEditingController(text: acc.bic ?? '');
    _accountNumberController = TextEditingController(
      text: acc.accountNumber ?? '',
    );
    _openingBalanceController = TextEditingController(
      text: acc.openingBalance != null
          ? acc.openingBalance!.toStringAsFixed(2)
          : '',
    );
    _virtualBalanceController = TextEditingController(
      text: acc.virtualBalance != null
          ? acc.virtualBalance!.toStringAsFixed(2)
          : '',
    );
    _interestController = TextEditingController(
      text: acc.interest != null ? acc.interest!.toString() : '',
    );
    _notesController = TextEditingController(text: acc.notes ?? '');

    _type = acc.type;
    _currencyCode = acc.currencyCode;
    _selectedRole = acc.role;
    _liabilityType = acc.liabilityType ?? 'debt';
    _liabilityDirection = acc.liabilityDirection ?? 'credit';
    _active = acc.active;
    _includeNetWorth = acc.includeNetWorth;
    _openingBalanceDate = acc.openingBalanceDate;
    _interestPeriod = acc.interestPeriod ?? 'monthly';

    final customMap = ref.read(accountClassificationProvider);
    _selectedCategory = getCategoryForAccount(acc, customMap);

    _tabController = TabController(length: 3, vsync: this);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ibanController.dispose();
    _bicController.dispose();
    _accountNumberController.dispose();
    _openingBalanceController.dispose();
    _virtualBalanceController.dispose();
    _interestController.dispose();
    _notesController.dispose();
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool get _isMismatch {
    final isLiability = _type == 'liability';
    if (isLiability) {
      return _selectedCategory == AccountCategory.asset ||
          _selectedCategory == AccountCategory.savings ||
          _selectedCategory == AccountCategory.investment;
    } else {
      return _selectedCategory == AccountCategory.liability;
    }
  }

  String get _mismatchMessage {
    if (_type == 'liability') {
      return 'This account is a Liability in Firefly III. To classify it as an Asset or Investment account, please change the account type.';
    } else {
      return 'This account is an Asset in Firefly III. To classify it as a Loan (liability), please change the account type.';
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isMismatch) return;

    setState(() => _saving = true);
    try {
      final service = ref.read(apiServiceProvider);
      final iban = _ibanController.text.trim();
      final bic = _bicController.text.trim();
      final accountNumber = _accountNumberController.text.trim();
      final notes = _notesController.text.trim();
      final openingBalance = double.tryParse(
        _openingBalanceController.text.trim(),
      );
      final virtualBalance = double.tryParse(
        _virtualBalanceController.text.trim(),
      );
      final interest = double.tryParse(_interestController.text.trim());

      final acc = widget.account;

      await service?.updateAccount(
        acc.id,
        name: name != acc.name ? name : null,
        type: _type != acc.type ? _type : null,
        currencyCode: _currencyCode != acc.currencyCode ? _currencyCode : null,
        iban: iban != (acc.iban ?? '') ? iban : null,
        bic: bic != (acc.bic ?? '') ? bic : null,
        accountNumber: accountNumber != (acc.accountNumber ?? '')
            ? accountNumber
            : null,
        notes: notes != (acc.notes ?? '') ? notes : null,
        active: _active != acc.active ? _active : null,
        role: _type == 'asset' && _selectedRole != acc.role
            ? _selectedRole
            : null,
        liabilityType:
            _type == 'liability' && _liabilityType != acc.liabilityType
            ? _liabilityType
            : null,
        liabilityDirection:
            _type == 'liability' &&
                _liabilityDirection != acc.liabilityDirection
            ? _liabilityDirection
            : null,
        includeNetWorth: _includeNetWorth != acc.includeNetWorth
            ? _includeNetWorth
            : null,
        openingBalance: openingBalance != acc.openingBalance
            ? openingBalance
            : null,
        openingBalanceDate: _openingBalanceDate != acc.openingBalanceDate
            ? _openingBalanceDate
            : null,
        virtualBalance: virtualBalance != acc.virtualBalance
            ? virtualBalance
            : null,
        interest: _type == 'liability' && interest != acc.interest
            ? interest
            : null,
        interestPeriod:
            _type == 'liability' && _interestPeriod != acc.interestPeriod
            ? _interestPeriod
            : null,
      );

      if (name != acc.name) {
        ref
            .read(undoHistoryProvider.notifier)
            .record(
              title: 'Account updated',
              details: 'Account name: ${acc.name} -> $name',
              type: UndoActionType.accountUpdate,
              undoPayload: {'accountId': acc.id, 'name': acc.name},
              redoPayload: {'accountId': acc.id, 'name': name},
            );
      }

      await ref
          .read(accountClassificationProvider.notifier)
          .setClassification(acc.id, _selectedCategory);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failedToUpdate(e.toString()))),
        );
      }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteAccountConfirmBody(widget.account.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      final service = ref.read(apiServiceProvider);
      await service?.deleteAccount(widget.account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountDeleted(widget.account.name))),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToDeleteAccount(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final account = widget.account;
    final accounts = ref.watch(accountsProvider).value ?? [];
    final currenciesAsync = ref.watch(currenciesProvider);
    final formatter = ref.watch(localeFormattingProvider);

    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.accent.acc.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.wrench,
                        color: colors.accent.acc,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.editAccount,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${account.name} (${account.currencyCode})',
                            style: TextStyle(color: colors.text3, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Navigation Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: colors.accent.acc,
                  unselectedLabelColor: colors.text3,
                  indicatorColor: colors.accent.acc,
                  indicatorWeight: 2,
                  tabs: const [
                    Tab(icon: Icon(LucideIcons.info, size: 16), text: 'Basic'),
                    Tab(
                      icon: Icon(LucideIcons.landmark, size: 16),
                      text: 'Banking',
                    ),
                    Tab(
                      icon: Icon(LucideIcons.settings, size: 16),
                      text: 'Settings',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Content Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: BASIC DETAILS
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            withTooltip(
                              l10n.tooltipAccountName,
                              AutocompleteTextField(
                                controller: _nameController,
                                suggestions:
                                    AutocompleteSuggestions.accountNames(
                                      accounts,
                                    ),
                                decoration: InputDecoration(
                                  labelText: l10n.accountName,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue:
                                        [
                                          'asset',
                                          'expense',
                                          'revenue',
                                          'liability',
                                        ].contains(_type)
                                        ? _type
                                        : 'asset',
                                    decoration: const InputDecoration(
                                      labelText: 'Account Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'asset',
                                        child: Text('Asset Account'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'expense',
                                        child: Text('Expense Account'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'revenue',
                                        child: Text('Revenue Account'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'liability',
                                        child: Text('Liability Account'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _type = val);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: currenciesAsync.when(
                                    data: (currencies) {
                                      final validCode = currencies.any(
                                        (c) => c.code == _currencyCode,
                                      );
                                      return DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: validCode
                                            ? _currencyCode
                                            : null,
                                        decoration: const InputDecoration(
                                          labelText: 'Currency',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: currencies
                                            .map(
                                              (c) => DropdownMenuItem(
                                                value: c.code,
                                                child: Text(
                                                  '${c.code} (${c.symbol})',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _currencyCode = val);
                                          }
                                        },
                                      );
                                    },
                                    loading: () =>
                                        const LinearProgressIndicator(),
                                    error: (err, st) => TextField(
                                      readOnly: true,
                                      controller: TextEditingController(
                                        text: _currencyCode,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Currency',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_type == 'asset') ...[
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue:
                                    [
                                      'defaultAsset',
                                      'savingAsset',
                                      'ccAsset',
                                      'sharedAsset',
                                    ].contains(_selectedRole)
                                    ? _selectedRole
                                    : 'defaultAsset',
                                decoration: const InputDecoration(
                                  labelText: 'Firefly Asset Role',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'defaultAsset',
                                    child: Text(
                                      localizedAccountRole(
                                        l10n,
                                        'defaultAsset',
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'savingAsset',
                                    child: Text(
                                      localizedAccountRole(l10n, 'savingAsset'),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ccAsset',
                                    child: Text(
                                      localizedAccountRole(l10n, 'ccAsset'),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'sharedAsset',
                                    child: Text(
                                      localizedAccountRole(l10n, 'sharedAsset'),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedRole = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (_type == 'liability') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue:
                                          [
                                            'loan',
                                            'debt',
                                            'mortgage',
                                            'creditCard',
                                          ].contains(_liabilityType)
                                          ? _liabilityType
                                          : 'debt',
                                      decoration: const InputDecoration(
                                        labelText: 'Liability Subtype',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'debt',
                                          child: Text('Debt'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'loan',
                                          child: Text('Loan'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'mortgage',
                                          child: Text('Mortgage'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'creditCard',
                                          child: Text('Credit Card'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _liabilityType = val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue:
                                          [
                                            'credit',
                                            'debit',
                                          ].contains(_liabilityDirection)
                                          ? _liabilityDirection
                                          : 'credit',
                                      decoration: const InputDecoration(
                                        labelText: 'Direction',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'credit',
                                          child: Text('I owe (Credit)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'debit',
                                          child: Text('Owed to me (Debit)'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => _liabilityDirection = val,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ],
                            DropdownButtonFormField<AccountCategory>(
                              isExpanded: true,
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Custom Classification',
                                helperText:
                                    'Determines which section this account appears in',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: AccountCategory.asset,
                                  child: Text('Asset Accounts'),
                                ),
                                DropdownMenuItem(
                                  value: AccountCategory.savings,
                                  child: Text('Savings Accounts'),
                                ),
                                DropdownMenuItem(
                                  value: AccountCategory.creditCard,
                                  child: Text('Credit Cards'),
                                ),
                                DropdownMenuItem(
                                  value: AccountCategory.investment,
                                  child: Text('Investment Accounts'),
                                ),
                                DropdownMenuItem(
                                  value: AccountCategory.liability,
                                  child: Text('Loans (liabilities)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCategory = val);
                                }
                              },
                            ),
                            if (_isMismatch) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      LucideIcons.triangleAlert,
                                      size: 18,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _mismatchMessage,
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // TAB 2: BANKING & BALANCES
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _openingBalanceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Opening Balance',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 54),
                                    ),
                                    icon: const Icon(
                                      LucideIcons.calendar,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _openingBalanceDate != null
                                          ? formatter.formatMonth(
                                              _openingBalanceDate!,
                                            )
                                          : 'Opening Date',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _openingBalanceDate ??
                                            DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(
                                          () => _openingBalanceDate = picked,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _virtualBalanceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Virtual Balance',
                                helperText:
                                    'Custom balance overlay used in calculations',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _ibanController,
                                    decoration: const InputDecoration(
                                      labelText: 'IBAN',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _bicController,
                                    decoration: const InputDecoration(
                                      labelText: 'BIC / SWIFT',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _accountNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Account Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // TAB 3: SETTINGS & NOTES
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: const Text('Active Account'),
                              subtitle: const Text(
                                'Inactive accounts are hidden from default views',
                              ),
                              value: _active,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _active = val),
                            ),
                            const Divider(),
                            SwitchListTile(
                              title: const Text('Include in Net Worth'),
                              subtitle: const Text(
                                'Calculate this account in total net worth',
                              ),
                              value: _includeNetWorth,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) =>
                                  setState(() => _includeNetWorth = val),
                            ),
                            const Divider(),
                            const SizedBox(height: 4),
                            Consumer(
                              builder: (context, ref, _) {
                                final peopleConfig = ref.watch(
                                  peopleSettingsProvider,
                                );
                                final people = peopleConfig.people;
                                final ownership = peopleConfig
                                    .accountOwnerships[widget.account.id];
                                final assignedShares =
                                    ownership?.personShares ?? const {};

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Owner',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.text2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (people.isEmpty)
                                      Text(
                                        'No people configured yet. Add people in Settings → People & Ownership.',
                                        style: TextStyle(
                                          color: colors.text3,
                                          fontSize: 12,
                                        ),
                                      )
                                    else
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: people.map((person) {
                                          final isAssigned = assignedShares
                                              .containsKey(person.id);
                                          return FilterChip(
                                            label: Text(
                                              person.name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isAssigned
                                                    ? Colors.white
                                                    : colors.text2,
                                              ),
                                            ),
                                            selected: isAssigned,
                                            selectedColor: person.color,
                                            checkmarkColor: Colors.white,
                                            onSelected: (selected) {
                                              final currentOwnerIds =
                                                  List<String>.from(
                                                    ownership?.ownerIds ?? [],
                                                  );
                                              if (selected) {
                                                if (!currentOwnerIds.contains(
                                                  person.id,
                                                )) {
                                                  currentOwnerIds.add(
                                                    person.id,
                                                  );
                                                }
                                              } else {
                                                currentOwnerIds.remove(
                                                  person.id,
                                                );
                                              }
                                              ref
                                                  .read(peopleProvider.notifier)
                                                  .setAccountOwners(
                                                    widget.account.id,
                                                    ownerIds: currentOwnerIds,
                                                  );
                                            },
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            if (_type == 'liability') ...[
                              const Divider(),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _interestController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Interest Rate (%)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue:
                                          [
                                            'daily',
                                            'weekly',
                                            'monthly',
                                            'quarterly',
                                            'half-year',
                                            'yearly',
                                          ].contains(_interestPeriod)
                                          ? _interestPeriod
                                          : 'monthly',
                                      decoration: const InputDecoration(
                                        labelText: 'Interest Period',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'daily',
                                          child: Text('Daily'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'weekly',
                                          child: Text('Weekly'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'monthly',
                                          child: Text('Monthly'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'quarterly',
                                          child: Text('Quarterly'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'half-year',
                                          child: Text('Half-year'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'yearly',
                                          child: Text('Yearly'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _interestPeriod = val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            TextField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Bottom Action Buttons
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: (_saving || _deleting) ? null : _delete,
                      icon: _deleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : const Icon(LucideIcons.trash2, size: 16),
                      label: Text(l10n.delete),
                    ),
                    const Spacer(),
                    withTooltip(
                      l10n.tooltipCancel,
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    withTooltip(
                      l10n.tooltipSave,
                      ElevatedButton(
                        onPressed: (_saving || _deleting || _isMismatch)
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
            ),
          ),
        ),
      ),
    );
  }
}
