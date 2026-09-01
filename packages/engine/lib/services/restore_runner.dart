import '../models/bill.dart';
import '../models/budget.dart';
import '../models/liability.dart';
import '../models/piggy_bank.dart';
import '../models/recurrence.dart';
import '../models/transaction.dart';
import '../utils/budget_period.dart';
import 'firefly_service.dart';
import 'restore_planner.dart';

/// What became of one step.
class RestoreOutcome {
  const RestoreOutcome({
    required this.step,
    required this.applied,
    this.newId,
    this.error,
  });

  final RestoreStep step;
  final bool applied;

  /// Firefly's id for a row put back, which is never the one it had.
  final String? newId;
  final String? error;

  Map<String, Object?> toJson() => {
    ...step.toJson(),
    'applied': applied,
    if (newId != null) 'new_id': newId,
    if (error != null) 'error': error,
  };
}

/// Applies a [RestorePlan] to a Firefly instance.
///
/// A row put back is a new row: Firefly assigns ids and an API client cannot ask
/// for one, so a recreated account comes back under a new id and everything
/// naming the old one is pointed at the new one as the run goes. The mapping is
/// reported, because a restore that silently renumbers someone's ledger is worse
/// than one that says what it did.
///
/// A step that fails does not stop the run. The rest of a restore is still worth
/// having, and the outcome list is where the failures are, one line each.
class RestoreRunner {
  RestoreRunner(this._api);

  final FireflyService _api;
  final Map<String, String> _remapped = {};

  /// Old id to new id, for rows this run recreated.
  Map<String, String> get remappedIds => Map.unmodifiable(_remapped);

  Future<List<RestoreOutcome>> apply(RestorePlan plan) async {
    final outcomes = <RestoreOutcome>[];
    for (final step in plan.steps) {
      try {
        final newId = await _applyStep(step);
        if (newId != null) _remapped[step.id] = newId;
        outcomes.add(RestoreOutcome(step: step, applied: true, newId: newId));
      } on Object catch (error) {
        outcomes.add(
          RestoreOutcome(step: step, applied: false, error: '$error'),
        );
      }
    }
    return outcomes;
  }

  Future<String?> _applyStep(RestoreStep step) => switch (step.action) {
    RestoreAction.create => _create(step),
    RestoreAction.update => _update(step),
    RestoreAction.delete => _delete(step),
  };

  Future<String?> _create(RestoreStep step) async {
    final row = step.row;
    switch (step.type) {
      case 'accounts':
        return _createAccount(row);
      case 'categories':
        final created = await _api.createCategory(_string(row['name']));
        return created.id;
      case 'tags':
        final created = await _api.createTag(_string(row['name']));
        return created.id;
      case 'budgets':
        final created = await _api.createBudget(_budgetInput(row));
        return created.id;
      case 'bills':
        final created = await _api.createBill(_billInput(row));
        return created.id;
      case 'piggy_banks':
        final created = await _api.createPiggyBank(_piggyInput(row));
        return created.id;
      case 'recurrences':
        final created = await _api.createRecurrence(_recurrenceInput(row));
        return created.id;
      case 'transactions':
        final created = await _api.createTransaction(_transaction(row, null));
        return created.id;
      default:
        throw ArgumentError('cannot create a ${step.type} row');
    }
  }

  Future<String?> _update(RestoreStep step) async {
    final row = step.row;
    final id = _live(step.id);
    switch (step.type) {
      case 'accounts':
        await _api.updateAccount(
          id,
          name: _string(row['name']),
          iban: row['iban'] as String?,
          bic: row['bic'] as String?,
          accountNumber: row['account_number'] as String?,
          notes: row['notes'] as String?,
          active: row['active'] as bool?,
          role: row['role'] as String?,
          currencyCode: row['currency_code'] as String?,
          liabilityType: row['liability_type'] as String?,
          liabilityDirection: row['liability_direction'] as String?,
          includeNetWorth: row['include_net_worth'] as bool?,
          openingBalance: _double(row['opening_balance']),
          openingBalanceDate: _date(row['opening_balance_date']),
          virtualBalance: _double(row['virtual_balance']),
          interest: _double(row['interest']),
          interestPeriod: row['interest_period'] as String?,
        );
      case 'categories':
        await _api.updateCategory(id, _string(row['name']));
      case 'tags':
        await _api.updateTag(id, _string(row['name']));
      case 'budgets':
        await _api.updateBudget(id, _budgetInput(row));
      case 'bills':
        await _api.updateBill(id, _billInput(row));
      case 'piggy_banks':
        await _api.updatePiggyBank(id, _piggyInput(row));
      case 'recurrences':
        await _api.updateRecurrence(id, _recurrenceInput(row));
      case 'transactions':
        await _api.updateTransaction(_transaction(row, id));
      default:
        throw ArgumentError('cannot update a ${step.type} row');
    }
    return null;
  }

  Future<String?> _delete(RestoreStep step) async {
    final id = _live(step.id);
    switch (step.type) {
      case 'accounts':
        await _api.deleteAccount(id);
      case 'categories':
        await _api.deleteCategory(id);
      case 'tags':
        await _api.deleteTag(id);
      case 'budgets':
        await _api.deleteBudget(id);
      case 'bills':
        await _api.deleteBill(id);
      case 'piggy_banks':
        await _api.deletePiggyBank(id);
      case 'recurrences':
        await _api.deleteRecurrence(id);
      case 'transactions':
        await _api.deleteTransaction(id);
      default:
        throw ArgumentError('cannot delete a ${step.type} row');
    }
    return null;
  }

  /// A liability carries fields `createAccount` has nowhere to put, so it goes
  /// back as one. Everything else is created and then filled in, because the
  /// create call takes a name, a type and a currency and nothing else.
  Future<String> _createAccount(Map<String, Object?> row) async {
    final type = _string(row['type']);
    if (type.startsWith('liabilit')) {
      final created = await _api.createLiability(
        LiabilityInput(
          name: _string(row['name']),
          currencyCode: _string(row['currency_code'], fallback: 'EUR'),
          liabilityType: LiabilityType.values.firstWhere(
            (value) => value.apiValue == row['liability_type'],
            orElse: () => LiabilityType.debt,
          ),
          liabilityDirection: LiabilityDirection.values.firstWhere(
            (value) => value.apiValue == row['liability_direction'],
            orElse: () => LiabilityDirection.credit,
          ),
          amountOwed: _double(row['opening_balance']),
          startDate: _date(row['opening_balance_date']),
          interest: _double(row['interest']),
          interestPeriod: InterestPeriod.values
              .where((value) => value.apiValue == row['interest_period'])
              .firstOrNull,
          includeNetWorth: row['include_net_worth'] as bool? ?? true,
          iban: row['iban'] as String?,
          bic: row['bic'] as String?,
          accountNumber: row['account_number'] as String?,
          notes: row['notes'] as String?,
        ),
      );
      return created.id;
    }
    final created = await _api.createAccount(
      name: _string(row['name']),
      type: type,
      currencyCode: _string(row['currency_code'], fallback: 'EUR'),
      role: row['role'] as String?,
    );
    await _api.updateAccount(
      created.id,
      iban: row['iban'] as String?,
      bic: row['bic'] as String?,
      accountNumber: row['account_number'] as String?,
      notes: row['notes'] as String?,
      active: row['active'] as bool?,
      includeNetWorth: row['include_net_worth'] as bool?,
      openingBalance: _double(row['opening_balance']),
      openingBalanceDate: _date(row['opening_balance_date']),
      virtualBalance: _double(row['virtual_balance']),
    );
    return created.id;
  }

  BudgetInput _budgetInput(Map<String, Object?> row) => BudgetInput(
    name: _string(row['name']),
    active: row['active'] as bool? ?? true,
    notes: row['notes'] as String?,
    autoBudgetType: AutoBudgetType.values.firstWhere(
      (type) => type.apiValue == row['auto_budget_type'],
      orElse: () => AutoBudgetType.none,
    ),
    autoBudgetAmount: _double(row['auto_budget_amount']),
    autoBudgetPeriod: AutoBudgetPeriod.values
        .where((period) => period.apiValue == row['auto_budget_period'])
        .firstOrNull,
    currencyCode: _string(row['currency_code'], fallback: 'EUR'),
  );

  BillInput _billInput(Map<String, Object?> row) => BillInput(
    name: _string(row['name']),
    amountMin: _double(row['amount_min']) ?? 0,
    amountMax: _double(row['amount_max']) ?? 0,
    currencyCode: _string(row['currency_code'], fallback: 'EUR'),
    date: _date(row['date']) ?? DateTime.now(),
    repeatFrequency: BillRepeatFrequency.values.firstWhere(
      (frequency) => frequency.apiValue == row['repeat_freq'],
      orElse: () => BillRepeatFrequency.monthly,
    ),
    skip: (row['skip'] as num?)?.toInt() ?? 0,
    active: row['active'] as bool? ?? true,
    endDate: _date(row['end_date']),
    extensionDate: _date(row['extension_date']),
    notes: row['notes'] as String?,
    objectGroupTitle: row['object_group_title'] as String?,
  );

  PiggyBankInput _piggyInput(Map<String, Object?> row) => PiggyBankInput(
    name: _string(row['name']),
    targetAmount: _double(row['target_amount']) ?? 0,
    currencyCode: _string(row['currency_code'], fallback: 'EUR'),
    accountIds: [
      for (final link in (row['accounts'] as List? ?? const []))
        if (link is Map && link['account_id'] != null)
          _live('${link['account_id']}'),
    ],
    startDate: _date(row['start_date']) ?? DateTime.now(),
    targetDate: _date(row['target_date']),
    notes: row['notes'] as String?,
    objectGroupTitle: row['object_group_title'] as String?,
  );

  RecurrenceInput _recurrenceInput(Map<String, Object?> row) => RecurrenceInput(
    type: RecurrenceTransactionType.fromApi(row['type'] as String?),
    title: _string(row['title']),
    description: row['description'] as String?,
    firstDate: _date(row['first_date']) ?? DateTime.now(),
    repeatUntil: _date(row['repeat_until']),
    nrOfRepetitions: (row['nr_of_repetitions'] as num?)?.toInt(),
    applyRules: row['apply_rules'] as bool? ?? true,
    active: row['active'] as bool? ?? true,
    notes: row['notes'] as String?,
    repetitions: [
      for (final repetition in (row['repetitions'] as List? ?? const []))
        if (repetition is Map)
          RecurrenceRepetitionInput(
            type: RecurrenceRepetitionType.fromApi(
              repetition['type'] as String?,
            ),
            moment: '${repetition['moment'] ?? ''}',
            skip: (repetition['skip'] as num?)?.toInt() ?? 0,
            weekend: RecurrenceWeekendMode.fromApi(
              (repetition['weekend'] as num?)?.toInt(),
            ),
          ),
    ],
    transactions: [
      for (final line in (row['transactions'] as List? ?? const []))
        if (line is Map)
          RecurrenceTransactionInput(
            description: '${line['description'] ?? ''}',
            amount: _double(line['amount']) ?? 0,
            currencyCode: '${line['currency_code'] ?? 'EUR'}',
            foreignAmount: _double(line['foreign_amount']),
            foreignCurrencyCode: line['foreign_currency_code'] as String?,
            sourceId: _liveOrNull(line['source_id']) ?? '',
            destinationId: _liveOrNull(line['destination_id']) ?? '',
            budgetId: _liveOrNull(line['budget_id']),
            categoryId: _liveOrNull(line['category_id']),
            billId: _liveOrNull(line['bill_id']),
            tags: [
              for (final tag in (line['tags'] as List? ?? const [])) '$tag',
            ],
          ),
    ],
  );

  /// Rebuilds a transaction group, legs and all.
  ///
  /// Every id inside goes through the remap, so a group naming an account this
  /// run recreated points at the account that now exists rather than the one
  /// that does not.
  Transaction _transaction(Map<String, Object?> row, String? id) {
    final splits = [
      for (final leg in (row['splits'] as List? ?? const []))
        if (leg is Map) _leg(leg.cast<String, Object?>(), id ?? ''),
    ];
    if (splits.isEmpty) {
      throw ArgumentError('a transaction with no legs cannot be written back');
    }
    final first = splits.first;
    return Transaction(
      id: id ?? '',
      type: first.type,
      date: first.date,
      amount: first.amount,
      description: first.description,
      sourceName: first.sourceName,
      destinationName: first.destinationName,
      categoryName: first.categoryName,
      currencySymbol: '',
      currencyCode: first.currencyCode,
      foreignAmount: first.foreignAmount,
      foreignCurrencyCode: first.foreignCurrencyCode,
      sourceId: first.sourceId,
      destinationId: first.destinationId,
      categoryId: first.categoryId,
      budgetId: first.budgetId,
      budgetName: first.budgetName,
      billId: first.billId,
      billName: first.billName,
      piggyBankId: first.piggyBankId,
      notes: first.notes,
      tags: first.tags,
      reconciled: first.reconciled,
      groupTitle: row['group_title'] as String?,
      // A single leg is the group itself; more than one and the legs are what
      // carry it, which is what a split group needs to come back as one.
      splits: splits.length > 1 ? splits : const [],
    );
  }

  Transaction _leg(Map<String, Object?> leg, String groupId) => Transaction(
    id: groupId,
    journalId: leg['journal_id'] as String?,
    type: _string(leg['type'], fallback: 'withdrawal'),
    date: _date(leg['date']) ?? DateTime.now(),
    amount: _double(leg['amount']) ?? 0,
    description: _string(leg['description']),
    sourceName: _string(leg['source_name']),
    destinationName: _string(leg['destination_name']),
    categoryName: _string(leg['category_name']),
    currencySymbol: '',
    currencyCode: _string(leg['currency_code'], fallback: 'EUR'),
    foreignAmount: _double(leg['foreign_amount']),
    foreignCurrencyCode: leg['foreign_currency_code'] as String?,
    sourceId: _liveOrNull(leg['source_id']),
    destinationId: _liveOrNull(leg['destination_id']),
    categoryId: _liveOrNull(leg['category_id']),
    budgetId: _liveOrNull(leg['budget_id']),
    budgetName: leg['budget_name'] as String?,
    billId: _liveOrNull(leg['bill_id']),
    billName: leg['bill_name'] as String?,
    piggyBankId: _liveOrNull(leg['piggy_bank_id']),
    notes: leg['notes'] as String?,
    tags: [for (final tag in (leg['tags'] as List? ?? const [])) '$tag'],
    reconciled: leg['reconciled'] as bool? ?? false,
  );

  /// The id this row has now, which is the recreated one when this run made it.
  String _live(String id) => _remapped[id] ?? id;

  String? _liveOrNull(Object? id) {
    if (id == null) return null;
    final text = '$id';
    return text.isEmpty ? null : _live(text);
  }

  String _string(Object? value, {String fallback = ''}) =>
      value is String && value.isNotEmpty ? value : fallback;

  double? _double(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
