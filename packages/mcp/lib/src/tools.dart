import 'dart:math' show min;

import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:http/http.dart' as http;

/// One MCP tool: name, description, JSON Schema, and executor.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.run,
    this.writes = false,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final Future<Map<String, Object?>> Function(Map<String, Object?> args) run;

  /// Mutates Firefly data, so it needs an agent key bound to a person who can
  /// write. Viewer keys get these listed but refused.
  final bool writes;
}

const _mcpVersion = '1.0.0';

/// Tools gated on write access, named here so `get_capabilities` can advertise
/// the gate without an agent having to probe for it.
const List<String> _writeToolNames = [
  'set_primary_currency',
  'set_transaction_reconciled',
  'store_reconciliation',
  'create_transaction',
  'update_transaction',
  'duplicate_transaction',
  'delete_transaction',
  'update_account',
  'update_budget',
  'delete_budget',
  'create_category',
  'update_category',
  'delete_category',
  'create_tag',
  'update_tag',
  'delete_tag',
  'create_account',
  'delete_account',
  'create_budget',
  'create_budget_limit',
  'update_budget_limit',
  'create_bill',
  'update_bill',
  'delete_bill',
  'create_piggy_bank',
  'update_piggy_bank',
  'delete_piggy_bank',
  'create_recurrence',
  'update_recurrence',
  'delete_recurrence',
  'create_liability',
];

List<String> _strList(Object? value) =>
    value is List ? value.map((e) => '$e').toList() : const [];

Map<String, Object?> _badInput(String message) => {
  'ok': false,
  'code': 'bad_input',
  'error': message,
};

/// Fields `update_account` forwards, in the order it reports them back. Named
/// once so the at-least-one guard and the `updated_fields` report cannot drift.
const List<String> _accountUpdateFields = [
  'name',
  'type',
  'iban',
  'bic',
  'account_number',
  'notes',
  'active',
  'account_role',
  'currency_code',
  'liability_type',
  'liability_direction',
  'include_net_worth',
  'opening_balance',
  'opening_balance_date',
  'virtual_balance',
  'interest',
  'interest_period',
];

Map<String, Object?> _accountJson(Account account) => {
  'id': account.id,
  'name': account.name,
  'type': account.type,
  'role': account.role,
  'current_balance': account.currentBalance,
  'currency_symbol': account.currencySymbol,
  'currency_code': account.currencyCode,
  'active': account.active,
};

/// One leg of a split group, in the shape the write tools accept back.
///
/// Deliberately mirrors an entry of the `splits` argument, so a caller can read
/// a group and hand the same legs to `create_transaction` unchanged.
Map<String, Object?> _transactionSplitJson(Transaction split) => {
  'journal_id': split.journalId,
  'type': split.type,
  'amount': split.amount,
  'description': split.description,
  'source_id': split.sourceId,
  'source_name': split.sourceName,
  'destination_id': split.destinationId,
  'destination_name': split.destinationName,
  'category_id': split.categoryId,
  'category_name': split.categoryName,
  'budget_id': split.budgetId,
  'bill_id': split.billId,
  'tags': split.tags,
  'notes': split.notes,
  'reconciled': split.reconciled,
};

/// [withSplits] adds the legs of a split group.
///
/// On a group, `amount` is the total while the other top-level fields belong to
/// the first leg, so a three-leg mortgage otherwise reads as one payment of the
/// whole amount described as its amortisation line. Listings stay lean and say
/// only how many legs there are; a caller that means to copy one fetches it.
Map<String, Object?> _transactionJson(
  Transaction transaction, {
  bool withSplits = false,
}) => {
  'id': transaction.id,
  // One leg of a split is only addressable by its journal id; the group id
  // reaches the whole group. match_statement reports a leg, so a caller acting
  // on its output needs the id that identifies one.
  'journal_id': transaction.journalId,
  'type': transaction.type,
  'date': _dateOnly(transaction.date),
  'amount': transaction.totalAmount,
  'description': transaction.description,
  'group_title': transaction.groupTitle,
  'source_id': transaction.sourceId,
  'source_name': transaction.sourceName,
  'destination_id': transaction.destinationId,
  'destination_name': transaction.destinationName,
  'category_id': transaction.categoryId,
  'category_name': transaction.categoryName,
  'budget_id': transaction.budgetId,
  'budget_name': transaction.budgetName,
  'bill_id': transaction.billId,
  'bill_name': transaction.billName,
  'tags': transaction.tags,
  // Deliberately carried, unlike on an account. A transaction note is what
  // records where a row came from, such as the raw bank text an import kept so
  // the origin stays traceable, and an agent reading transactions needs it.
  // Account notes are unbounded free text on an entity that appears in every
  // payee row, which is why _accountJson does not carry them.
  'notes': transaction.notes,
  'currency_symbol': transaction.currencySymbol,
  'currency_code': transaction.currencyCode,
  'foreign_amount': transaction.foreignAmount,
  'foreign_currency_code': transaction.foreignCurrencyCode,
  'split_count': transaction.resolvedSplits().length,
  if (withSplits && transaction.isSplitGroup)
    'splits': [
      for (final split in transaction.resolvedSplits())
        _transactionSplitJson(split),
    ],
  'reconciled': transaction.isReconciled,
  'partially_reconciled': transaction.isPartiallyReconciled,
};

ReconciledFilter _reconciledFilterFromArgs(Map<String, Object?> args) {
  final raw = args['reconciled'];
  if (raw == null) return ReconciledFilter.all;
  if (raw is bool) {
    return raw ? ReconciledFilter.reconciled : ReconciledFilter.unreconciled;
  }
  return switch ('$raw'.toLowerCase()) {
    'true' || 'reconciled' => ReconciledFilter.reconciled,
    'false' || 'unreconciled' => ReconciledFilter.unreconciled,
    'all' => ReconciledFilter.all,
    _ => throw ArgumentError(
      'Invalid reconciled filter "$raw". '
      'Expected all, true/reconciled, or false/unreconciled.',
    ),
  };
}

List<Transaction> _filterByReconciled(
  List<Transaction> transactions,
  ReconciledFilter filter,
) {
  if (filter == ReconciledFilter.all) return transactions;
  return transactions
      .where((transaction) => matchesReconciledFilter(transaction, filter))
      .toList();
}

Map<String, Object?> _budgetJson(Budget budget) => {
  'id': budget.id,
  'name': budget.name,
  'active': budget.active,
  'notes': budget.notes,
  'spent': budget.spent,
  'auto_budget_amount': budget.autoBudgetAmount,
  'auto_budget_type': budget.autoBudgetType.apiValue,
  'auto_budget_period': budget.autoBudgetPeriod?.apiValue,
  'currency_symbol': budget.currencySymbol,
  'currency_code': budget.currencyCode,
};

/// Formats the calendar date, not the UTC one.
///
/// `toIso8601String().substring(0, 10)` reports the UTC day: local midnight at
/// +02:00 is 22:00 the previous day in UTC, so a budget period starting 1 August
/// came back as 31 July.
String _dateOnly(DateTime date) {
  final local = date.isUtc ? date.toLocal() : date;
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// Parses a `YYYY-MM-DD` (or full ISO-8601) argument, or null when absent.
DateTime? _optionalDate(Object? raw, String field) {
  if (raw == null) return null;
  final text = '$raw'.trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    throw ArgumentError('$field must be a date like 2026-08-19, got "$text"');
  }
  return parsed;
}

/// One page of [all] and the pagination describing it, for endpoints Firefly
/// cannot window server-side.
///
/// Separate from [_paginateClientSide] because a caller that annotates each row
/// needs the transactions, not a finished response.
({List<Transaction> items, Map<String, Object?> pagination}) _pageOf(
  List<Transaction> all, {
  required int page,
  required int limit,
}) {
  final total = all.length;
  final totalPages = total == 0 ? 0 : ((total + limit - 1) ~/ limit);
  final start = (page - 1) * limit;
  return (
    items: start >= total
        ? const <Transaction>[]
        : all.sublist(start, min(start + limit, total)),
    pagination: {
      'current_page': page,
      'total_pages': totalPages,
      'total': total,
      'filtered_client_side': true,
    },
  );
}

/// Slices [all] into a page, for endpoints Firefly cannot window server-side.
Map<String, Object?> _paginateClientSide(
  List<Transaction> all, {
  required int page,
  required int limit,
}) {
  final slice = _pageOf(all, page: page, limit: limit);
  return {
    'ok': true,
    'pagination': slice.pagination,
    'transactions': slice.items.map(_transactionJson).toList(),
  };
}

/// Builds a Transaction from tool arguments, reusing [base] for anything the
/// caller did not supply. [base] is null on create.
/// One leg the caller stated, falling back to the group's arguments for
/// anything it left out.
///
/// So an account or a currency is given once for the whole group and only the
/// amount, description and category vary per leg, which is how a loan payment
/// or a card bill is actually written.
Transaction _splitFromArgs(
  Map<String, Object?> leg,
  Map<String, Object?> args, {
  required String type,
  required DateTime date,
  required String currencyCode,
  required String currencySymbol,
  required int index,
}) {
  String? pick(String key) => (leg[key] as String?) ?? (args[key] as String?);

  final amount = (leg['amount'] as num?)?.toDouble();
  if (amount == null || amount <= 0) {
    throw ArgumentError('splits[$index].amount must be greater than zero');
  }
  final description =
      (leg['description'] as String?) ?? (args['description'] as String?) ?? '';
  if (description.trim().isEmpty) {
    throw ArgumentError('splits[$index].description is required');
  }
  return Transaction(
    id: '0',
    type: (leg['type'] as String?) ?? type,
    date: date,
    amount: amount,
    description: description,
    sourceName: pick('source_name') ?? '',
    destinationName: pick('destination_name') ?? '',
    categoryName: pick('category_name') ?? '',
    currencySymbol: currencySymbol,
    currencyCode: (leg['currency_code'] as String?) ?? currencyCode,
    sourceId: pick('source_id'),
    destinationId: pick('destination_id'),
    categoryId: pick('category_id'),
    budgetId: pick('budget_id'),
    billId: pick('bill_id'),
    notes: pick('notes'),
    foreignAmount:
        (leg['foreign_amount'] as num?)?.toDouble() ??
        (args['foreign_amount'] as num?)?.toDouble(),
    foreignCurrencyCode: pick('foreign_currency_code'),
    tags: leg.containsKey('tags')
        ? _strList(leg['tags'])
        : (args.containsKey('tags') ? _strList(args['tags']) : const []),
  );
}

Transaction _transactionFromArgs(
  Map<String, Object?> args, {
  Transaction? base,
  String id = '0',
}) {
  final type = (args['type'] as String?) ?? base?.type;
  if (type == null ||
      !const ['withdrawal', 'deposit', 'transfer'].contains(type)) {
    throw ArgumentError(
      'type must be withdrawal, deposit, or transfer, got "$type"',
    );
  }
  final date = _optionalDate(args['date'], 'date') ?? base?.date;
  if (date == null) {
    throw ArgumentError('date is required');
  }

  final statedLegs = args['splits'];
  if (statedLegs != null && statedLegs is! List) {
    throw ArgumentError('splits must be a list of legs');
  }
  final legs = statedLegs is List ? statedLegs : const [];
  final copyingGroup = legs.isEmpty && (base?.isSplitGroup ?? false);

  // A single amount says nothing about how to divide it across legs, and
  // guessing is how a mortgage's fixed amortisation gets scaled along with its
  // interest. The caller restates the legs or leaves them alone.
  if (copyingGroup && args.containsKey('amount')) {
    throw ArgumentError(
      'amount cannot override a group of ${base!.resolvedSplits().length} '
      'legs; pass splits to restate them',
    );
  }

  final currencyCode =
      (args['currency_code'] as String?) ?? base?.currencyCode ?? '';
  final currencySymbol = base?.currencySymbol ?? '';

  final splits = <Transaction>[
    if (legs.isNotEmpty)
      for (final (index, leg) in legs.indexed)
        _splitFromArgs(
          leg is Map<String, Object?>
              ? leg
              : throw ArgumentError('splits[$index] must be an object'),
          args,
          type: type,
          date: date,
          currencyCode: currencyCode,
          currencySymbol: currencySymbol,
          index: index,
        )
    else if (copyingGroup)
      // A copy is not reconciled: nothing has been checked against a statement
      // yet, whatever was true of the original.
      for (final split in base!.resolvedSplits())
        split.copyWith(id: '0', date: date, reconciled: false),
  ];

  final leadingLeg = splits.isEmpty ? null : splits.first;
  final amount =
      leadingLeg?.amount ??
      (args['amount'] as num?)?.toDouble() ??
      base?.amount;
  if (amount == null || amount <= 0) {
    throw ArgumentError('amount must be greater than zero');
  }

  final statedForeign = (args['foreign_amount'] as num?)?.toDouble();
  if (statedForeign != null && statedForeign <= 0) {
    throw ArgumentError('foreign_amount must be greater than zero');
  }
  // Carrying the original's foreign amount alongside a new local one would
  // pair this month's figure with last month's rate. Nobody can derive the
  // rate from the local amount alone, so the caller states it or nothing is
  // written: scaling it would invent an exchange rate and record it as fact.
  if (leadingLeg == null &&
      statedForeign == null &&
      args.containsKey('amount') &&
      base?.foreignAmount != null &&
      amount != base!.amount) {
    final was = [
      base.foreignAmount!.toStringAsFixed(2),
      ?base.foreignCurrencyCode,
    ].join(' ');
    throw ArgumentError(
      'amount overrides a transaction carrying a foreign amount of $was; '
      'pass foreign_amount too, since the rate cannot be derived',
    );
  }
  final foreignAmount =
      leadingLeg?.foreignAmount ?? statedForeign ?? base?.foreignAmount;
  final foreignCurrencyCode =
      leadingLeg?.foreignCurrencyCode ??
      (args['foreign_currency_code'] as String?) ??
      base?.foreignCurrencyCode;
  final description =
      leadingLeg?.description ??
      (args['description'] as String?) ??
      base?.description ??
      '';
  if (description.trim().isEmpty) {
    throw ArgumentError('description is required');
  }
  return Transaction(
    id: id,
    type: type,
    date: date,
    amount: amount,
    description: description,
    splits: splits,
    groupTitle: splits.length > 1
        ? (args['group_title'] as String?) ??
              base?.groupTitle ??
              (args['description'] as String?) ??
              description
        : null,
    // The model keeps the first leg in the top-level fields, so they mirror it
    // when there are legs. Serialisation reads the legs either way; this is
    // what makes the returned object describe itself the way a fetched one
    // does.
    sourceName:
        leadingLeg?.sourceName ??
        (args['source_name'] as String?) ??
        base?.sourceName ??
        '',
    destinationName:
        leadingLeg?.destinationName ??
        (args['destination_name'] as String?) ??
        base?.destinationName ??
        '',
    categoryName:
        leadingLeg?.categoryName ??
        (args['category_name'] as String?) ??
        base?.categoryName ??
        '',
    currencySymbol: currencySymbol,
    currencyCode: leadingLeg?.currencyCode ?? currencyCode,
    sourceId:
        leadingLeg?.sourceId ??
        (args['source_id'] as String?) ??
        base?.sourceId,
    destinationId:
        leadingLeg?.destinationId ??
        (args['destination_id'] as String?) ??
        base?.destinationId,
    categoryId:
        leadingLeg?.categoryId ??
        (args['category_id'] as String?) ??
        base?.categoryId,
    budgetId:
        leadingLeg?.budgetId ??
        (args['budget_id'] as String?) ??
        base?.budgetId,
    notes: leadingLeg?.notes ?? (args['notes'] as String?) ?? base?.notes,
    foreignAmount: foreignAmount,
    foreignCurrencyCode: foreignCurrencyCode,
    tags: leadingLeg != null
        ? leadingLeg.tags
        : (args.containsKey('tags')
              ? _strList(args['tags'])
              : (base?.tags ?? const [])),
    billId: leadingLeg?.billId ?? (args['bill_id'] as String?) ?? base?.billId,
  );
}

/// The `splits` argument create and duplicate accept.
///
/// A leg takes the group's values for anything it omits, so the account and the
/// currency are given once and only the amount, description and category vary,
/// which is how a loan payment or a card bill is written.
Map<String, Object?> _splitsFieldSchema() => {
  'group_title': {
    'type': 'string',
    'description':
        'Title for a multi-leg group. Defaults to the top-level description.',
  },
  'splits': {
    'type': 'array',
    'minItems': 1,
    'description':
        'Legs of a split transaction, such as the amortisation, interest and '
        'fee of one loan payment. Omit for a single-leg transaction. Each leg '
        'inherits any field it does not set from the top-level arguments.',
    'items': {
      'type': 'object',
      'required': ['amount'],
      'properties': {
        'amount': {'type': 'number', 'exclusiveMinimum': 0},
        'description': {'type': 'string'},
        'type': {
          'type': 'string',
          'enum': ['withdrawal', 'deposit', 'transfer'],
        },
        'currency_code': {'type': 'string'},
        'source_id': {'type': 'string'},
        'source_name': {'type': 'string'},
        'destination_id': {'type': 'string'},
        'destination_name': {'type': 'string'},
        'category_id': {'type': 'string'},
        'category_name': {'type': 'string'},
        'budget_id': {'type': 'string'},
        'bill_id': {'type': 'string'},
        'notes': {'type': 'string'},
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
    },
  },
};

/// Shared schema for the fields create, update, and duplicate all accept.
Map<String, Object?> _transactionFieldSchema() => {
  'type': {
    'type': 'string',
    'enum': ['withdrawal', 'deposit', 'transfer'],
  },
  'date': {'type': 'string', 'description': 'YYYY-MM-DD or full ISO-8601.'},
  'amount': {'type': 'number', 'exclusiveMinimum': 0},
  'description': {'type': 'string'},
  'currency_code': {'type': 'string'},
  'foreign_amount': {
    'type': 'number',
    'exclusiveMinimum': 0,
    'description':
        'What the other side received, when the two accounts hold different '
        'currencies. Firefly requires it on such a transfer and refuses the '
        'write without it.',
  },
  'foreign_currency_code': {
    'type': 'string',
    'description': 'Currency of foreign_amount. Defaults to the other side.',
  },
  'source_id': {'type': 'string'},
  'source_name': {'type': 'string'},
  'destination_id': {'type': 'string'},
  'destination_name': {'type': 'string'},
  'category_id': {'type': 'string'},
  'category_name': {'type': 'string'},
  'budget_id': {'type': 'string'},
  'bill_id': {'type': 'string'},
  'notes': {'type': 'string'},
  'tags': {
    'type': 'array',
    'items': {'type': 'string'},
  },
};

Map<String, Object?> _budgetLimitJson(BudgetLimit limit) => {
  'id': limit.id,
  'budget_id': limit.budgetId,
  'start': _dateOnly(limit.start),
  'end': _dateOnly(limit.end),
  'amount': limit.amount,
  'currency_code': limit.currencyCode,
  'notes': limit.notes,
};

/// Shared by create and update: both take the same period and amount.
Future<BudgetLimitInput> _budgetLimitInput(
  Map<String, Object?> args,
  FireflyService api,
) async {
  final start = _optionalDate(args['start_date'], 'start_date');
  final inclusiveEnd = _optionalDate(args['end_date'], 'end_date');
  if (start == null) throw ArgumentError('start_date is required');
  if (inclusiveEnd == null) throw ArgumentError('end_date is required');
  if (inclusiveEnd.isBefore(start)) {
    throw ArgumentError('end_date must not precede start_date');
  }
  final amount = (args['amount'] as num?)?.toDouble();
  if (amount == null || amount <= 0) {
    throw ArgumentError('amount must be greater than zero');
  }
  return BudgetLimitInput(
    start: start,
    end: inclusiveEnd,
    amount: amount,
    currencyCode:
        args['currency_code'] as String? ??
        (await api.getPrimaryCurrency()).code,
    notes: args['notes'] as String?,
  );
}

Map<String, Object?> _billJson(Bill bill) => {
  'id': bill.id,
  'name': bill.name,
  'amount_min': bill.amountMin,
  'amount_max': bill.amountMax,
  'currency_code': bill.currencyCode,
  'date': _dateOnly(bill.date),
  'end_date': bill.endDate == null ? null : _dateOnly(bill.endDate!),
  'repeat_frequency': bill.repeatFrequency.apiValue,
  'skip': bill.skip,
  'active': bill.active,
};

Map<String, Object?> _billFieldSchema() => {
  'name': {'type': 'string'},
  'amount_min': {'type': 'number', 'exclusiveMinimum': 0},
  'amount_max': {'type': 'number', 'exclusiveMinimum': 0},
  'currency_code': {'type': 'string'},
  'date': {'type': 'string', 'description': 'First due date, YYYY-MM-DD.'},
  'end_date': {'type': 'string'},
  'repeat_frequency': {
    'type': 'string',
    'enum': ['weekly', 'monthly', 'quarterly', 'half-year', 'yearly'],
  },
  'skip': {'type': 'integer', 'minimum': 0},
  'active': {'type': 'boolean'},
  'notes': {'type': 'string'},
};

Future<BillInput> _billInput(
  Map<String, Object?> args,
  FireflyService api, {
  Bill? base,
}) async {
  final name = (args['name'] as String?)?.trim() ?? base?.name;
  if (name == null || name.isEmpty) throw ArgumentError('name is required');
  final min = (args['amount_min'] as num?)?.toDouble() ?? base?.amountMin;
  final max = (args['amount_max'] as num?)?.toDouble() ?? base?.amountMax;
  if (min == null || max == null) {
    throw ArgumentError('amount_min and amount_max are required');
  }
  if (min <= 0 || max <= 0) {
    throw ArgumentError('amounts must be greater than zero');
  }
  if (max < min) throw ArgumentError('amount_max must not be below amount_min');
  final date = _optionalDate(args['date'], 'date') ?? base?.date;
  if (date == null) throw ArgumentError('date is required');
  return BillInput(
    name: name,
    amountMin: min,
    amountMax: max,
    currencyCode:
        args['currency_code'] as String? ??
        base?.currencyCode ??
        (await api.getPrimaryCurrency()).code,
    date: date,
    repeatFrequency: args.containsKey('repeat_frequency')
        ? _requireEnum(
            BillRepeatFrequency.values,
            args['repeat_frequency'] as String?,
            (v) => v.apiValue,
            'repeat_frequency',
          )
        : (base?.repeatFrequency ?? BillRepeatFrequency.monthly),
    skip: (args['skip'] as num?)?.toInt() ?? base?.skip ?? 0,
    active: args['active'] as bool? ?? base?.active ?? true,
    endDate: _optionalDate(args['end_date'], 'end_date') ?? base?.endDate,
    notes: args['notes'] as String?,
  );
}

Map<String, Object?> _piggyJson(PiggyBank piggy) => {
  'id': piggy.id,
  'name': piggy.name,
  'target_amount': piggy.targetAmount,
  'current_amount': piggy.currentAmount,
  'percentage': piggy.percentage,
  'left_to_save': piggy.leftToSave,
  'currency_code': piggy.currencyCode,
  'start_date': _dateOnly(piggy.startDate),
};

Map<String, Object?> _piggyFieldSchema() => {
  'name': {'type': 'string'},
  'target_amount': {'type': 'number', 'exclusiveMinimum': 0},
  'account_ids': {
    'type': 'array',
    'items': {'type': 'string'},
    'description': 'Asset accounts the piggy bank saves from.',
  },
  'start_date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
  'target_date': {'type': 'string'},
  'currency_code': {'type': 'string'},
  'notes': {'type': 'string'},
};

Future<PiggyBankInput> _piggyInput(
  Map<String, Object?> args,
  FireflyService api, {
  PiggyBank? base,
}) async {
  final name = (args['name'] as String?)?.trim() ?? base?.name;
  if (name == null || name.isEmpty) throw ArgumentError('name is required');
  final target =
      (args['target_amount'] as num?)?.toDouble() ?? base?.targetAmount;
  if (target == null || target <= 0) {
    throw ArgumentError('target_amount must be greater than zero');
  }
  final accountIds = args.containsKey('account_ids')
      ? _strList(args['account_ids'])
      : <String>[
          for (final account
              in base?.accounts ?? const <PiggyBankAccountLink>[])
            account.accountId,
        ];
  if (accountIds.isEmpty) {
    throw ArgumentError('account_ids must name at least one account');
  }
  final start =
      _optionalDate(args['start_date'], 'start_date') ?? base?.startDate;
  if (start == null) throw ArgumentError('start_date is required');
  return PiggyBankInput(
    name: name,
    targetAmount: target,
    currencyCode:
        args['currency_code'] as String? ??
        base?.currencyCode ??
        (await api.getPrimaryCurrency()).code,
    accountIds: accountIds,
    startDate: start,
    targetDate: _optionalDate(args['target_date'], 'target_date'),
    notes: args['notes'] as String?,
  );
}

/// Finds an enum value by its Firefly API string, or null when unmatched.
T? _enumByApiValue<T>(
  List<T> values,
  String? raw,
  String Function(T) apiValue,
) {
  if (raw == null || raw.isEmpty) return null;
  for (final value in values) {
    if (apiValue(value) == raw) return value;
  }
  return null;
}

/// Like [_enumByApiValue] but refuses an unknown value instead of returning
/// null. The engine's own `fromApi` constructors fall back to a default, which
/// is right when parsing whatever Firefly sends but wrong for agent input: it
/// would turn `type: 'refund'` into a withdrawal and create it without comment.
T _requireEnum<T>(
  List<T> values,
  String? raw,
  String Function(T) apiValue,
  String field,
) {
  final match = _enumByApiValue(values, raw, apiValue);
  if (match != null) return match;
  throw ArgumentError(
    '$field must be one of ${values.map(apiValue).join(', ')}',
  );
}

Map<String, Object?> _pageJson(TransactionPageResult result) => {
  'ok': true,
  'pagination': {
    'current_page': result.currentPage,
    'total_pages': result.totalPages,
    'total': result.total,
  },
  'transactions': result.transactions.map(_transactionJson).toList(),
};

/// One line of a recurring rule: what it moves, between which accounts, and the
/// bookkeeping a transaction created from it inherits.
Map<String, Object?> _recurrenceLineJson(RecurrenceTransactionLine line) => {
  'description': line.description,
  'amount': line.amount,
  'currency_code': line.currencyCode,
  'foreign_amount': line.foreignAmount,
  'foreign_currency_code': line.foreignCurrencyCode,
  'source_id': line.sourceId,
  'source_name': line.sourceName,
  'destination_id': line.destinationId,
  'destination_name': line.destinationName,
  'category_id': line.categoryId,
  'category_name': line.categoryName,
  'budget_id': line.budgetId,
  'budget_name': line.budgetName,
  'bill_id': line.billId,
  'bill_name': line.billName,
  'tags': line.tags,
};

Map<String, Object?> _recurrenceRepetitionJson(
  RecurrenceRepetition repetition,
) => {
  'type': repetition.type.apiValue,
  'moment': repetition.moment,
  'skip': repetition.skip,
  'weekend': repetition.weekend.name,
};

/// A recurring rule with the lines it creates.
///
/// The lines are what make two rules telling apart: a title carries no accounts
/// and no amount, so a ledger with one standing transfer per person offers only
/// identical titles to choose between. Without them a caller cannot say which
/// rule to correct, and `find_account` cannot be pointed at the payee a rule
/// already names.
Map<String, Object?> _recurrenceJson(Recurrence recurrence) => {
  'id': recurrence.id,
  'title': recurrence.title,
  'type': recurrence.type.apiValue,
  'description': recurrence.description,
  'active': recurrence.active,
  'apply_rules': recurrence.applyRules,
  'notes': recurrence.notes,
  'first_date': _dateOnly(recurrence.firstDate),
  'latest_date': recurrence.latestDate == null
      ? null
      : _dateOnly(recurrence.latestDate!),
  'repeat_until': recurrence.repeatUntil == null
      ? null
      : _dateOnly(recurrence.repeatUntil!),
  'nr_of_repetitions': recurrence.nrOfRepetitions,
  'repetitions': [
    for (final r in recurrence.repetitions) _recurrenceRepetitionJson(r),
  ],
  'transactions': [
    for (final line in recurrence.transactions) _recurrenceLineJson(line),
  ],
};

Map<String, Object?> _recurrenceFieldSchema() => {
  'title': {'type': 'string'},
  'description': {'type': 'string'},
  'first_date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
  'repeat_until': {'type': 'string'},
  'nr_of_repetitions': {'type': 'integer', 'minimum': 1},
  'active': {'type': 'boolean', 'default': true},
  'apply_rules': {'type': 'boolean', 'default': true},
  'notes': {'type': 'string'},
  'repetition_type': {
    'type': 'string',
    'enum': ['daily', 'weekly', 'ndom', 'monthly', 'yearly'],
    'default': 'monthly',
  },
  'moment': {
    'type': 'string',
    'description':
        'Which point in the period: day of month for monthly, 1-7 for weekly, '
        'MM-DD for yearly, empty for daily.',
  },
  'skip': {'type': 'integer', 'minimum': 0, 'default': 0},
  'type': {
    'type': 'string',
    'enum': ['withdrawal', 'deposit', 'transfer'],
  },
  'amount': {'type': 'number', 'exclusiveMinimum': 0},
  'source_id': {'type': 'string'},
  'destination_id': {'type': 'string'},
  'category_id': {'type': 'string'},
  'budget_id': {'type': 'string'},
  'bill_id': {'type': 'string'},
  'currency_code': {'type': 'string'},
  'tags': {
    'type': 'array',
    'items': {'type': 'string'},
  },
};

/// Firefly replaces a recurrence wholesale, so create and update build the same
/// complete input rather than merging over what is stored.
Future<RecurrenceInput> _recurrenceInput(
  Map<String, Object?> args,
  FireflyService api,
) async {
  final title = (args['title'] as String?)?.trim();
  if (title == null || title.isEmpty) throw ArgumentError('title is required');
  final firstDate = _optionalDate(args['first_date'], 'first_date');
  if (firstDate == null) throw ArgumentError('first_date is required');
  final amount = (args['amount'] as num?)?.toDouble();
  if (amount == null || amount <= 0) {
    throw ArgumentError('amount must be greater than zero');
  }
  final description = (args['description'] as String?)?.trim();
  if (description == null || description.isEmpty) {
    throw ArgumentError('description is required');
  }
  final sourceId = (args['source_id'] as String?)?.trim();
  final destinationId = (args['destination_id'] as String?)?.trim();
  if (sourceId == null || sourceId.isEmpty) {
    throw ArgumentError('source_id is required');
  }
  if (destinationId == null || destinationId.isEmpty) {
    throw ArgumentError('destination_id is required');
  }
  final currency =
      args['currency_code'] as String? ?? (await api.getPrimaryCurrency()).code;
  return RecurrenceInput(
    type: _requireEnum(
      RecurrenceTransactionType.values,
      args['type'] as String?,
      (v) => v.apiValue,
      'type',
    ),
    title: title,
    description: args['description'] as String?,
    firstDate: firstDate,
    repeatUntil: _optionalDate(args['repeat_until'], 'repeat_until'),
    nrOfRepetitions: (args['nr_of_repetitions'] as num?)?.toInt(),
    applyRules: args['apply_rules'] as bool? ?? true,
    active: args['active'] as bool? ?? true,
    notes: args['notes'] as String?,
    repetitions: [
      RecurrenceRepetitionInput(
        type: args.containsKey('repetition_type')
            ? _requireEnum(
                RecurrenceRepetitionType.values,
                args['repetition_type'] as String?,
                (v) => v.apiValue,
                'repetition_type',
              )
            : RecurrenceRepetitionType.monthly,
        moment: (args['moment'] as String?) ?? '',
        skip: (args['skip'] as num?)?.toInt() ?? 0,
      ),
    ],
    transactions: [
      RecurrenceTransactionInput(
        description: description,
        amount: amount,
        currencyCode: currency,
        sourceId: sourceId,
        destinationId: destinationId,
        budgetId: args['budget_id'] as String?,
        categoryId: args['category_id'] as String?,
        billId: args['bill_id'] as String?,
        tags: _strList(args['tags']),
      ),
    ],
  );
}

ProjectionType _projectionType(String? raw) {
  final name = raw ?? 'savings';
  for (final value in ProjectionType.values) {
    if (value.name == name) return value;
  }
  throw ArgumentError(
    'Invalid projection_type "$name". '
    'Expected one of: ${ProjectionType.values.map((e) => e.name).join(', ')}.',
  );
}

DashboardPeriod _dashboardPeriod(String? raw) {
  final name = raw ?? 'thisMonth';
  for (final value in DashboardPeriod.values) {
    if (value.name == name) return value;
  }
  throw ArgumentError(
    'Invalid period "$name". '
    'Expected one of: ${DashboardPeriod.values.map((e) => e.name).join(', ')}.',
  );
}

/// Where an MCP server sends Firefly traffic, and with what bearer.
///
/// In server mode [baseUrl] is the BFF proxy (`<host>/api/firefly`) and [bearer]
/// is the caller's agent key, so the Firefly PAT never enters this process. On
/// desktop it is the app's own saved Firefly connection.
class FireflyTarget {
  const FireflyTarget({required this.baseUrl, required this.bearer});

  const FireflyTarget.unconfigured() : baseUrl = '', bearer = '';

  final String baseUrl;
  final String bearer;

  bool get isConfigured => baseUrl.isNotEmpty && bearer.isNotEmpty;

  String get normalizedBaseUrl => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
}

/// Builds the FireRacoon MCP tool catalog.
///
/// Tools take no credentials. [target] is fixed when the server starts, from
/// the agent key the process authenticated with or the desktop app's saved
/// connection, so an agent can never widen its own reach through arguments.

/// A resolver candidate, without the identifier it matched on.
///
/// The matcher needs the IBAN and the account number; the transcript does not.
/// A last-four hint is enough for a person to confirm the right account without
/// putting the identifier itself on the wire.
Map<String, Object?> _accountCandidateJson(AccountCandidate candidate) {
  final account = candidate.account;
  final iban = account.iban?.trim() ?? '';
  final number = account.accountNumber?.trim() ?? '';
  final String? hint;
  if (candidate.matchedOn.contains('account_number') && number.length >= 4) {
    hint = 'account number ending ${number.substring(number.length - 4)}';
  } else if (candidate.matchedOn.any((m) => m.startsWith('iban')) &&
      iban.length >= 4) {
    hint = 'iban ending ${iban.substring(iban.length - 4)}';
  } else {
    hint = null;
  }
  return {
    'account_id': account.id,
    'name': account.name,
    'normalized_name': foldAccountName(account.name),
    'type': account.type,
    'role': account.role,
    'currency_code': account.currencyCode,
    'active': account.active,
    'has_iban': iban.isNotEmpty,
    'has_account_number': number.isNotEmpty,
    'identifier_hint': hint,
    'matched_on': candidate.matchedOn,
    'confidence': candidate.confidence.name,
    'requires_confirmation': candidate.confidence != MatchConfidence.exact,
    'score': candidate.score,
    'reasons': candidate.reasons,
  };
}

Map<String, Object?> _legJson(LedgerLeg leg) => {
  'transaction_id': leg.transactionId,
  'journal_id': leg.journalId,
  'split_index': leg.isSplitGroup ? leg.index : null,
  'date': _dateOnly(leg.date),
  'signed_amount': leg.signedAmount,
  'description': leg.split.description,
};

Map<String, Object?> _statementMatchJson(StatementMatch match) => {
  'row_id': match.row.rowId,
  ..._legJson(match.leg),
  // More than one when a single bank line settled a whole split journal, in
  // which case no individual leg is the match and the sum is what agreed.
  'legs_consumed': match.legsConsumed,
  'group_amount': match.groupAmount,
  'statement_amount': match.row.amount,
  'recorded_amount': match.recordedAmount,
  'amount_delta': match.amountDelta,
  'amount_delta_pct': match.amountDeltaPct,
  'date_delta_days': match.dateDeltaDays,
  'date_field_used': match.dateFieldUsed,
  'reasons': match.reasons,
  'blocked_reason': match.blockedReason,
};

List<McpTool> buildTools({
  required FireflyTarget target,
  http.Client? httpClient,
  AgentIdentity? identity,
}) {
  FireflyService service() {
    if (!target.isConfigured) {
      throw StateError(
        'No Firefly connection: start the server with FIRERACOON_URL and '
        'FIRERACOON_API_KEY, or run it from the FireRacoon desktop app.',
      );
    }
    return FireflyApiService(
      serverUrl: target.normalizedBaseUrl,
      apiToken: target.bearer,
      client: httpClient,
    );
  }

  Future<bool> checkAbout() async {
    final client = httpClient ?? http.Client();
    try {
      final response = await client.get(
        Uri.parse('${target.normalizedBaseUrl}/api/v1/about'),
        headers: {
          'Authorization': 'Bearer ${target.bearer}',
          'Accept': 'application/json',
        },
      );
      return response.statusCode == 200;
    } finally {
      if (httpClient == null) client.close();
    }
  }

  // Filled once the list below is built, so get_capabilities reports the tools
  // that actually exist rather than a second list someone has to remember.
  final toolNames = <String>[];
  final tools = <McpTool>[
    McpTool(
      name: 'find_account',
      description:
          'Resolve raw bank text to an account. Matches on account number and '
          'IBAN first, then on the name, and returns ranked candidates with '
          'the reason each matched rather than picking one. Identifiers are '
          'never returned, only a last-four hint.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                "Raw bank text, such as 'Joint Current 12 345 678'. Give this "
                'or queries, not both.',
          },
          'queries': {
            'type': 'array',
            'items': {'type': 'string'},
            'maxItems': 200,
            'description':
                'Several texts resolved against one read of the chart of '
                'accounts. A ledger with a couple of thousand payees takes '
                'seconds to read, so resolving a statement a row at a time '
                'pays that cost once per row.',
          },
          'types': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': ['asset', 'liability', 'expense', 'revenue'],
            },
            'description': 'Account types to search. Defaults to all four.',
          },
          'iban': {
            'type': 'string',
            'description': 'An IBAN you already hold, to confirm against.',
          },
          'account_number': {'type': 'string'},
          'limit': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 25,
            'default': 5,
          },
        },
      },
      run: (args) async {
        final single = (args['query'] as String?)?.trim();
        final batch = [
          for (final raw in _strList(args['queries']))
            if (raw.trim().isNotEmpty) raw.trim(),
        ];
        if (single != null && single.isNotEmpty && batch.isNotEmpty) {
          return _badInput('give query or queries, not both');
        }
        final queries = batch.isNotEmpty
            ? batch
            : (single == null || single.isEmpty ? const <String>[] : [single]);
        if (queries.isEmpty) return _badInput('query or queries is required');
        if (queries.length > 200) {
          return _badInput('queries must not exceed 200 entries');
        }
        final requested = _strList(args['types']);
        const known = ['asset', 'liability', 'expense', 'revenue'];
        for (final type in requested) {
          if (!known.contains(type)) {
            return _badInput('unknown account type: $type');
          }
        }
        final types = requested.isEmpty ? known : requested;
        final limit = (args['limit'] as num?)?.toInt() ?? 5;
        if (limit < 1 || limit > 25) {
          return _badInput('limit must be between 1 and 25');
        }

        // Read once, however many texts are being resolved.
        final accounts = await service().getAccounts(types: types);
        final iban = (args['iban'] as String?)?.trim();
        final accountNumber = (args['account_number'] as String?)?.trim();

        Map<String, Object?> resolve(String text) {
          final resolution = resolveAccountCandidates(
            accounts: accounts,
            query: text,
            iban: iban,
            accountNumber: accountNumber,
            limit: limit,
          );
          return {
            'query': text,
            'normalized_query': foldAccountName(text),
            'query_digits': digitsOnly(text),
            'candidate_count': resolution.candidates.length,
            'ambiguous': resolution.ambiguous,
            'skipped_blank_names': resolution.skippedBlankNames,
            'collisions': [
              for (final entry in resolution.collisions.entries)
                {'key': entry.key, 'account_ids': entry.value},
            ],
            'warnings': resolution.warnings,
            'candidates': [
              for (final candidate in resolution.candidates)
                _accountCandidateJson(candidate),
            ],
          };
        }

        final header = {
          'ok': true,
          'searched_types': types,
          'accounts_read': accounts.length,
          'ambiguity_band': kAmbiguityBand,
        };
        // A single query keeps its flat shape so an existing caller is
        // unaffected; a batch reports one entry per text.
        if (batch.isEmpty) return {...header, ...resolve(queries.single)};
        return {
          ...header,
          'results': [for (final text in queries) resolve(text)],
        };
      },
    ),
    McpTool(
      name: 'match_statement',
      description:
          'Match bank statement rows against what is recorded on an account. '
          'Returns matched, near-matched and missing rows with the arithmetic '
          'that proves the classification. Tolerances are fixed and echoed in '
          'the response; a row whose amount cannot be read is returned for a '
          'person to settle rather than guessed.',
      inputSchema: {
        'type': 'object',
        'required': ['account_id', 'start_date', 'end_date', 'rows'],
        'properties': {
          'account_id': {
            'type': 'string',
            'description': 'Account id, never a name. Use find_account first.',
          },
          'start_date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
          'end_date': {
            'type': 'string',
            'description': 'YYYY-MM-DD, inclusive.',
          },
          'opening_balance': {'type': 'string'},
          'closing_balance': {'type': 'string'},
          'amount_format': {
            'type': 'string',
            'enum': ['auto', 'dot', 'comma'],
            'default': 'auto',
          },
          'rows': {
            'type': 'array',
            'minItems': 1,
            'maxItems': 1000,
            'items': {
              'type': 'object',
              'required': ['row_id', 'date', 'amount'],
              'properties': {
                'row_id': {'type': 'string'},
                'date': {'type': 'string'},
                'book_date': {'type': 'string'},
                'amount': {
                  'type': 'string',
                  'description': 'Signed. Raw bank text is accepted.',
                },
                'text': {'type': 'string'},
              },
            },
          },
        },
      },
      run: (args) async {
        final accountId = (args['account_id'] as String?)?.trim();
        if (accountId == null || accountId.isEmpty) {
          return _badInput('account_id is required');
        }
        final DateTime? start;
        final DateTime? inclusiveEnd;
        try {
          start = _optionalDate(args['start_date'], 'start_date');
          inclusiveEnd = _optionalDate(args['end_date'], 'end_date');
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        if (start == null) return _badInput('start_date is required');
        if (inclusiveEnd == null) return _badInput('end_date is required');
        if (inclusiveEnd.isBefore(start)) {
          return _badInput('end_date must not precede start_date');
        }

        final rawRows = args['rows'];
        if (rawRows is! List || rawRows.isEmpty) {
          return _badInput('rows must list at least one statement row');
        }
        if (rawRows.length > 1000) {
          return _badInput('rows must not exceed 1000 entries');
        }
        final parsedRows = <RawStatementRow>[];
        for (final entry in rawRows) {
          if (entry is! Map) return _badInput('each row must be an object');
          final row = entry.cast<String, Object?>();
          final rowId = (row['row_id'] as String?)?.trim();
          if (rowId == null || rowId.isEmpty) {
            return _badInput('every row needs a row_id');
          }
          final DateTime? date;
          final DateTime? bookDate;
          try {
            date = _optionalDate(row['date'], 'date');
            bookDate = _optionalDate(row['book_date'], 'book_date');
          } on ArgumentError catch (e) {
            return _badInput('row $rowId: ${e.message}');
          }
          if (date == null) return _badInput('row $rowId needs a date');
          final amount = row['amount'];
          if (amount == null) return _badInput('row $rowId needs an amount');
          parsedRows.add(
            RawStatementRow(
              rowId: rowId,
              date: date,
              bookDate: bookDate,
              rawAmount: '$amount',
              text: row['text'] as String?,
            ),
          );
        }

        final format = (args['amount_format'] as String?) ?? 'auto';
        if (!const ['auto', 'dot', 'comma'].contains(format)) {
          return _badInput('amount_format must be auto, dot or comma');
        }
        final grammar = switch (format) {
          'dot' => AmountGrammar.dotDecimal,
          'comma' => AmountGrammar.commaDecimal,
          _ => null,
        };

        final parsed = parseStatementRows(
          rows: parsedRows,
          openingBalance: args['opening_balance'] as String?,
          closingBalance: args['closing_balance'] as String?,
          amountFormat: grammar,
        );
        if (parsed is StatementParseFailure) {
          return _badInput('${parsed.field}: ${parsed.message}');
        }
        final settled = parsed as StatementParsed;

        final api = service();
        final accounts = await api.getAccounts(
          types: const ['asset', 'liability'],
        );
        final account = accounts.where((a) => a.id == accountId).firstOrNull;
        if (account == null) {
          return _badInput('no asset or liability account with id $accountId');
        }

        final recorded = await api.getAccountTransactions(
          accountId,
          start: start,
          end: inclusiveEnd.add(const Duration(days: 1)),
        );

        final plan = matchStatementRows(
          accountId: accountId,
          rows: settled.rows,
          recorded: recorded,
          periodStart: start,
          periodEnd: inclusiveEnd,
          currencyCode: account.currencyCode,
          openingBalance: settled.openingBalance,
          closingBalance: settled.closingBalance,
          needsInput: settled.needsInput,
        );

        final arithmetic = plan.arithmetic;
        return {
          'ok': true,
          'account': {
            'id': account.id,
            'name': account.name,
            'currency_code': account.currencyCode,
          },
          'window': {
            'start': _dateOnly(start),
            'end': _dateOnly(inclusiveEnd),
            'date_tolerance_days': kStatementDateToleranceDays,
            'near_date_tolerance_days': kStatementNearDateToleranceDays,
            'near_amount_tolerance_pct': kStatementNearAmountTolerancePct,
            'amount_equality_tolerance': kAmountEqualityTolerance,
          },
          'parse': {
            'amount_format_used': settled.grammar.name,
            'rows_read': settled.rows.length,
            'rows_needing_input': settled.needsInput.length,
          },
          'matched': [
            for (final match in plan.matched) _statementMatchJson(match),
          ],
          'near_matches': [
            for (final match in plan.near) _statementMatchJson(match),
          ],
          'missing': [
            for (final row in plan.missing)
              {
                'row_id': row.rowId,
                'date': _dateOnly(row.date),
                'amount': row.amount,
                'text': row.text,
              },
          ],
          'needs_input': [
            for (final row in plan.needsInput)
              {
                'row_id': row.rowId,
                'raw_amount': row.rawAmount,
                'reason': row.reason,
                'candidates': row.candidates,
              },
          ],
          'unmatched_recorded': [
            for (final leg in plan.unmatchedRecorded) _legJson(leg),
          ],
          'excluded': {
            'foreign_currency_splits': plan.excludedForeignCurrencySplits,
            'fetched_outside_period': plan.excludedOutsidePeriod,
          },
          'arithmetic': {
            'statement_rows_sum': arithmetic.statementRowsSum,
            'recorded_sum': arithmetic.recordedSum,
            'rows_minus_recorded': arithmetic.rowsMinusRecorded,
            'opening_balance': arithmetic.openingBalance,
            'closing_balance': arithmetic.closingBalance,
            'balance_gap': arithmetic.balanceGap,
            'missing_rows_sum': arithmetic.missingRowsSum,
            'gap_closed_by_plan': arithmetic.gapClosedByPlan,
            'agrees': arithmetic.agrees,
            'disagreement_reason': arithmetic.disagreementReason,
          },
          'statement_self_check': plan.selfCheck == null
              ? null
              : {
                  'opening': plan.selfCheck!.opening,
                  'rows_sum': plan.selfCheck!.rowsSum,
                  'implied_closing': plan.selfCheck!.impliedClosing,
                  'stated_closing': plan.selfCheck!.statedClosing,
                  'agrees': plan.selfCheck!.agrees,
                },
        };
      },
    ),
    McpTool(
      name: 'get_capabilities',
      description:
          'Return FireRacoon MCP server capabilities, tool names, and version.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async => {
        'ok': true,
        'version': _mcpVersion,
        'tools': [...toolNames]..sort(),
        // Sorted so this and the schema's list compare by membership, not by
        // the order two hand-maintained lists happen to be in.
        'write_tools': [..._writeToolNames]..sort(),
        // Who the presented key belongs to. The same block comes back from
        // initialize, and repeating it here means an agent that has been
        // running a while does not have to have kept that first response.
        'identity': identity == null
            ? null
            : {
                'key_id': identity.keyId,
                'person_id': identity.personId,
                'person_name': identity.personName,
                'role': identity.role,
                'can_write': identity.canWrite,
              },
        'auth': {
          'credential': 'FireRacoon agent key',
          'env': ['FIRERACOON_URL', 'FIRERACOON_API_KEY'],
          'tcp_param': 'initialize.params.apiKey',
          'note':
              'Keys are issued per agent in FireRacoon Settings and inherit '
              'their person\'s role. Firefly III credentials are never accepted '
              'here; the server holds the PAT.',
        },
      },
    ),
    McpTool(
      name: 'check_connection',
      description:
          'Verify that the configured Firefly III connection answers /api/v1/about.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async {
        if (!target.isConfigured) {
          return _badInput('No Firefly connection configured for this server');
        }
        final connected = await checkAbout();
        return {
          'ok': connected,
          'connected': connected,
          if (!connected)
            'error': 'Firefly III returned non-200 for /api/v1/about',
        };
      },
    ),
    McpTool(
      name: 'get_current_user',
      description: 'Fetch the authenticated Firefly III user profile.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (args) async {
        final api = service();
        final user = await api.getCurrentUser();
        return {
          'ok': true,
          'user': {
            'id': user.id,
            'email': user.email,
            'display_name': user.displayName,
          },
        };
      },
    ),
    McpTool(
      name: 'get_primary_currency',
      description: 'Fetch the primary currency configured in Firefly III.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (args) async {
        final api = service();
        final currency = await api.getPrimaryCurrency();
        return {
          'ok': true,
          'currency': {
            'id': currency.id,
            'code': currency.code,
            'name': currency.name,
            'symbol': currency.symbol,
          },
        };
      },
    ),
    McpTool(
      name: 'set_primary_currency',
      writes: true,
      description: 'Set the primary currency in Firefly III.',
      inputSchema: {
        'type': 'object',
        'required': ['code'],
        'properties': {
          'code': {
            'type': 'string',
            'description': 'ISO currency code (e.g. EUR, USD).',
          },
        },
      },
      run: (args) async {
        final code = args['code'] as String?;
        if (code == null || code.isEmpty) {
          return _badInput('code is required');
        }
        final api = service();
        await api.setPrimaryCurrency(code);
        final currency = await api.getPrimaryCurrency();
        return {
          'ok': true,
          'currency': {
            'id': currency.id,
            'code': currency.code,
            'name': currency.name,
            'symbol': currency.symbol,
          },
        };
      },
    ),
    McpTool(
      name: 'get_accounts',
      description:
          'List Firefly III accounts with balances. Defaults to the accounts you '
          'own (asset and liability). Pass types to reach payees: an expense '
          'account is who you paid, a revenue account is who paid you.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'types': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': ['asset', 'liability', 'expense', 'revenue'],
            },
            'default': ['asset', 'liability'],
            'description':
                'Account types to include. Use expense and revenue to list '
                'existing payees before creating a new one.',
          },
        },
      },
      run: (args) async {
        final api = service();
        final types = _strList(args['types']);
        const allowed = {'asset', 'liability', 'expense', 'revenue'};
        final unknown = types.where((t) => !allowed.contains(t)).toList();
        if (unknown.isNotEmpty) {
          return _badInput(
            'unknown account types: ${unknown.join(', ')}. '
            'Expected any of: ${allowed.join(', ')}.',
          );
        }
        final accounts = types.isEmpty
            ? await api.getAccounts()
            : await api.getAccounts(types: types);
        return {
          'ok': true,
          'count': accounts.length,
          'types': types.isEmpty ? const ['asset', 'liability'] : types,
          'accounts': accounts.map(_accountJson).toList(),
        };
      },
    ),
    McpTool(
      name: 'get_transactions',
      description:
          'Fetch transactions (last 365 days by default). Optionally filter by account and paginate.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'account_id': {
            'type': 'string',
            'description':
                'When set, fetch transactions for this account only.',
          },
          'page': {'type': 'integer', 'minimum': 1, 'default': 1},
          'limit': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 500,
            'default': 50,
          },
          'start_date': {
            'type': 'string',
            'description':
                'Only transactions on or after this date (YYYY-MM-DD). Pair with '
                'end_date to match a bank statement period.',
          },
          'end_date': {
            'type': 'string',
            'description':
                'Only transactions on or before this date (YYYY-MM-DD).',
          },
          'reconciled': {
            'description':
                'Filter by reconciliation status: all, true/reconciled, or false/unreconciled.',
            'oneOf': [
              {'type': 'boolean'},
              {
                'type': 'string',
                'enum': ['all', 'true', 'false', 'reconciled', 'unreconciled'],
              },
            ],
            'default': 'all',
          },
        },
      },
      run: (args) async {
        final api = service();
        final accountId = args['account_id'] as String?;
        final page = (args['page'] as num?)?.toInt() ?? 1;
        final limit = (args['limit'] as num?)?.toInt() ?? 50;
        final DateTime? startDate;
        final DateTime? inclusiveEnd;
        try {
          startDate = _optionalDate(args['start_date'], 'start_date');
          inclusiveEnd = _optionalDate(args['end_date'], 'end_date');
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        if (startDate != null &&
            inclusiveEnd != null &&
            inclusiveEnd.isBefore(startDate)) {
          return _badInput('end_date must not precede start_date');
        }
        // end_date is inclusive to the caller, which is what anyone naming a
        // statement period means. The engine's range query subtracts a day from
        // whatever it is given, so it wants an exclusive end: passing the
        // caller's date straight through inverts a single-day window and the
        // filter is silently dropped.
        final endDate = inclusiveEnd?.add(const Duration(days: 1));
        final ReconciledFilter reconciledFilter;
        try {
          reconciledFilter = _reconciledFilterFromArgs(args);
        } on ArgumentError catch (e) {
          return _badInput('$e');
        }

        // When filtering by reconciled status, fetch the full lookback window
        // then paginate client-side so totals match the filtered set.
        if (reconciledFilter != ReconciledFilter.all) {
          final all = accountId != null && accountId.isNotEmpty
              ? await api.getAccountTransactions(
                  accountId,
                  start: startDate,
                  end: endDate,
                )
              : await api.getTransactions(start: startDate, end: endDate);
          final filtered = _filterByReconciled(all, reconciledFilter);
          final total = filtered.length;
          final totalPages = total == 0 ? 0 : ((total + limit - 1) ~/ limit);
          final start = (page - 1) * limit;
          final slice = start >= total
              ? const <Transaction>[]
              : filtered.sublist(start, min(start + limit, total));
          return {
            'ok': true,
            'pagination': {
              'current_page': page,
              'total_pages': totalPages,
              'total': total,
              'filtered_client_side': true,
            },
            'transactions': slice.map(_transactionJson).toList(),
          };
        }

        if (accountId != null && accountId.isNotEmpty) {
          // The account window has to be applied to the whole set, not a page:
          // Firefly's paged account endpoint takes no date range, so paging
          // first would leave a statement period split across pages.
          if (startDate != null || endDate != null) {
            final all = await api.getAccountTransactions(
              accountId,
              start: startDate,
              end: endDate,
            );
            return _paginateClientSide(all, page: page, limit: limit);
          }
          final pageResult = await api.getAccountTransactionsPage(
            accountId,
            page: page,
            limit: limit,
          );
          return {
            'ok': true,
            'pagination': {
              'current_page': pageResult.currentPage,
              'total_pages': pageResult.totalPages,
              'total': pageResult.total,
            },
            'transactions': pageResult.transactions
                .map(_transactionJson)
                .toList(),
          };
        }

        if (page > 1 ||
            args['limit'] != null ||
            startDate != null ||
            endDate != null) {
          final pageResult = await api.getTransactionsPage(
            page: page,
            limit: limit,
            start: startDate,
            end: endDate,
          );
          return {
            'ok': true,
            'pagination': {
              'current_page': pageResult.currentPage,
              'total_pages': pageResult.totalPages,
              'total': pageResult.total,
            },
            'transactions': pageResult.transactions
                .map(_transactionJson)
                .toList(),
          };
        }

        final transactions = await api.getTransactions(
          start: startDate,
          end: endDate,
        );
        return {
          'ok': true,
          'count': transactions.length,
          'transactions': transactions.map(_transactionJson).toList(),
        };
      },
    ),
    McpTool(
      name: 'get_transaction',
      description:
          'Fetch a single Firefly III transaction by its transaction group ID '
          '(the id returned by get_transactions, not a journal ID).',
      inputSchema: {
        'type': 'object',
        'required': ['transaction_id'],
        'properties': {
          'transaction_id': {
            'type': 'string',
            'description':
                'Transaction group ID, as returned by get_transactions.',
          },
        },
      },
      run: (args) async {
        final transactionId = args['transaction_id'] as String?;
        if (transactionId == null || transactionId.isEmpty) {
          return _badInput('transaction_id is required');
        }
        final api = service();
        final transaction = await api.getTransaction(transactionId);
        return {
          'ok': true,
          'transaction': _transactionJson(transaction, withSplits: true),
        };
      },
    ),
    McpTool(
      name: 'set_transaction_reconciled',
      writes: true,
      description:
          'Mark a transaction as reconciled or unreconciled after verifying it against a bank statement.',
      inputSchema: {
        'type': 'object',
        'required': ['transaction_id', 'reconciled'],
        'properties': {
          'transaction_id': {'type': 'string'},
          'reconciled': {'type': 'boolean'},
        },
      },
      run: (args) async {
        final transactionId = args['transaction_id'] as String?;
        final reconciled = args['reconciled'];
        if (transactionId == null || transactionId.isEmpty) {
          return _badInput('transaction_id is required');
        }
        if (reconciled is! bool) {
          return _badInput('reconciled must be a boolean');
        }
        final api = service();
        final current = await api.getTransaction(transactionId);
        final updated = await api.updateTransaction(
          current.withReconciled(reconciled),
        );
        return {
          'ok': true,
          'transaction': _transactionJson(updated, withSplits: true),
        };
      },
    ),
    McpTool(
      name: 'store_reconciliation',
      writes: true,
      description:
          'Store an account reconciliation: mark transactions reconciled and '
          'optionally create a correction transaction. For credit-card '
          '(ccAsset) accounts, pass payment_account_id and payback_date to '
          'also create a multi-split payback transfer. Not atomic — a mid-loop '
          'failure leaves already-updated journals reconciled; the error '
          'message reports how many journals were updated.',
      inputSchema: {
        'type': 'object',
        'required': [
          'account_id',
          'start_date',
          'end_date',
          'start_balance',
          'end_balance',
          'transaction_ids',
        ],
        'properties': {
          'account_id': {'type': 'string'},
          'start_date': {
            'type': 'string',
            'description': 'Period start date (YYYY-MM-DD).',
          },
          'end_date': {
            'type': 'string',
            'description': 'Period end date (YYYY-MM-DD).',
          },
          'start_balance': {'type': 'number'},
          'end_balance': {'type': 'number'},
          'transaction_ids': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'create_correction': {'type': 'boolean', 'default': true},
          'payment_account_id': {
            'type': 'string',
            'description':
                'Asset account funding a credit-card payback transfer '
                '(required with payback_date for ccAsset accounts).',
          },
          'payback_date': {
            'type': 'string',
            'description':
                'Payback transfer date YYYY-MM-DD (required with '
                'payment_account_id for ccAsset accounts).',
          },
        },
      },
      run: (args) async {
        final accountId = args['account_id'] as String?;
        final startDateRaw = args['start_date'] as String?;
        final endDateRaw = args['end_date'] as String?;
        final startBalance = (args['start_balance'] as num?)?.toDouble();
        final endBalance = (args['end_balance'] as num?)?.toDouble();
        final transactionIds = _strList(args['transaction_ids']);
        final createCorrection = args['create_correction'] as bool? ?? true;
        final paymentAccountId = args['payment_account_id'] as String?;
        final paybackDateRaw = args['payback_date'] as String?;

        if (accountId == null || accountId.isEmpty) {
          return _badInput('account_id is required');
        }
        final startDate = DateTime.tryParse(startDateRaw ?? '');
        final endDate = DateTime.tryParse(endDateRaw ?? '');
        if (startDate == null || endDate == null) {
          return _badInput('start_date and end_date must be YYYY-MM-DD');
        }
        if (startBalance == null || endBalance == null) {
          return _badInput('start_balance and end_balance are required');
        }
        if (transactionIds.isEmpty) {
          return _badInput('transaction_ids must contain at least one id');
        }

        final api = service();
        final accounts = await api.getAccounts();
        final account = accounts
            .where((item) => item.id == accountId)
            .firstOrNull;
        if (account == null) {
          return _badInput('account_id not found');
        }

        final journals = <Transaction>[];
        for (final id in transactionIds) {
          journals.add(await api.getTransaction(id));
        }

        if (isCreditCardAccount(account)) {
          if (paymentAccountId == null ||
              paymentAccountId.isEmpty ||
              paybackDateRaw == null) {
            return _badInput(
              'payment_account_id and payback_date are required for '
              'credit-card accounts',
            );
          }
          final paybackDate = DateTime.tryParse(paybackDateRaw);
          if (paybackDate == null) {
            return _badInput('payback_date must be YYYY-MM-DD');
          }
          final paymentAccount = accounts
              .where((item) => item.id == paymentAccountId)
              .firstOrNull;
          if (paymentAccount == null) {
            return _badInput('payment_account_id not found');
          }
          final result = await ReconciliationService(api)
              .storeCreditCardPayback(
                journalsToReconcile: journals,
                creditCard: account,
                paymentAccount: paymentAccount,
                paybackDate: paybackDate,
              );
          return {
            'ok': true,
            'reconciled_count': result.reconciled.length,
            'payback': result.payback == null
                ? null
                : _transactionJson(result.payback!),
          };
        }

        final gap = computeReconciliationGap(
          startBalance: startBalance,
          endBalance: endBalance,
          selectedTransactions: journals,
          accountName: account.name,
          startDate: startDate,
          endDate: endDate,
        );
        final result = await ReconciliationService(api).store(
          journalsToReconcile: journals,
          accountId: account.id,
          accountName: account.name,
          currencyCode: account.currencyCode,
          currencySymbol: account.currencySymbol,
          endDate: endDate,
          gap: gap,
          createCorrection: createCorrection,
        );

        return {
          'ok': true,
          'gap': gap,
          'reconciled_count': result.reconciled.length,
          'correction': result.correction == null
              ? null
              : _transactionJson(result.correction!),
        };
      },
    ),
    McpTool(
      name: 'create_transaction',
      writes: true,
      description:
          'Create a Firefly III transaction. Use source_id/destination_id when '
          'the account ids are known, or source_name/destination_name to let '
          'Firefly match or create the other side. Pass splits to write one '
          'journal with several legs, such as a loan payment divided into '
          'amortisation, interest and fee.',
      inputSchema: {
        'type': 'object',
        'required': ['type', 'date', 'amount', 'description'],
        'properties': {..._transactionFieldSchema(), ..._splitsFieldSchema()},
      },
      run: (args) async {
        final Transaction draft;
        try {
          draft = _transactionFromArgs(args);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final created = await service().createTransaction(draft);
        return {
          'ok': true,
          'transaction_id': created.id,
          'transaction': _transactionJson(created, withSplits: true),
        };
      },
    ),
    McpTool(
      name: 'update_transaction',
      writes: true,
      description:
          'Update fields on an existing transaction. Anything omitted keeps its '
          'current value.',
      inputSchema: {
        'type': 'object',
        'required': ['transaction_id'],
        'properties': {
          'transaction_id': {
            'type': 'string',
            'description':
                'Transaction group ID, as returned by get_transactions.',
          },
          ..._transactionFieldSchema(),
        },
      },
      run: (args) async {
        final id = args['transaction_id'] as String?;
        if (id == null || id.isEmpty) {
          return _badInput('transaction_id is required');
        }
        final api = service();
        // Merged over what is stored, so a one-field edit cannot blank the rest.
        final existing = await api.getTransaction(id);
        final Transaction updated;
        try {
          updated = _transactionFromArgs(args, base: existing, id: id);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final saved = await api.updateTransaction(updated);
        return {
          'ok': true,
          'transaction_id': saved.id,
          'transaction': _transactionJson(saved, withSplits: true),
        };
      },
    ),
    McpTool(
      name: 'duplicate_transaction',
      writes: true,
      description:
          'Copy an existing transaction into a new one. Any field passed '
          'overrides the copy, so the date or amount can change in the same '
          'call. The original is left untouched. Every leg of a split group '
          'is carried over; amount cannot override a group, since one figure '
          'does not say how to divide it, so pass splits to restate the legs. '
          'A copy is never reconciled.',
      inputSchema: {
        'type': 'object',
        'required': ['transaction_id'],
        'properties': {
          'transaction_id': {
            'type': 'string',
            'description': 'Transaction group ID to copy.',
          },
          ..._transactionFieldSchema(),
          ..._splitsFieldSchema(),
        },
      },
      run: (args) async {
        final id = args['transaction_id'] as String?;
        if (id == null || id.isEmpty) {
          return _badInput('transaction_id is required');
        }
        final api = service();
        final source = await api.getTransaction(id);
        final Transaction draft;
        try {
          // Left at id '0' so Firefly assigns a new one instead of overwriting.
          draft = _transactionFromArgs(args, base: source);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final created = await api.createTransaction(draft);
        return {
          'ok': true,
          'copied_from': id,
          'transaction_id': created.id,
          'transaction': _transactionJson(created, withSplits: true),
        };
      },
    ),
    McpTool(
      name: 'delete_transaction',
      writes: true,
      description:
          'Delete a transaction by its group ID. Removes every split in the '
          'group.',
      inputSchema: {
        'type': 'object',
        'required': ['transaction_id'],
        'properties': {
          'transaction_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = args['transaction_id'] as String?;
        if (id == null || id.isEmpty) {
          return _badInput('transaction_id is required');
        }
        await service().deleteTransaction(id);
        return {'ok': true, 'transaction_id': id, 'deleted': true};
      },
    ),
    McpTool(
      name: 'export_firefly_data',
      description:
          'Read a snapshot of everything the Firefly API will hand over: '
          'accounts, transactions with every split leg, budgets, categories, '
          'tags, bills, piggy banks, recurring rules and currencies. Take one '
          'before a bulk change so there is something to compare against. It '
          'is not a backup: Firefly has no backup endpoint and an API client '
          'cannot reach the database, the attachments or the instance key, so '
          'restoring a working instance still needs the volume archive. Pass '
          'counts_only to check what is there without moving the whole thing.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'start_date': {
            'type': 'string',
            'description':
                'YYYY-MM-DD. Limits the transactions only; every other entity '
                'is read whole. Defaults to the service lookback.',
          },
          'end_date': {
            'type': 'string',
            'description': 'YYYY-MM-DD, inclusive. Transactions only.',
          },
          'counts_only': {
            'type': 'boolean',
            'default': false,
            'description':
                'Return the receipt without the rows, for confirming a '
                'snapshot is worth taking before taking it.',
          },
        },
      },
      run: (args) async {
        final DateTime? start;
        final DateTime? inclusiveEnd;
        try {
          start = _optionalDate(args['start_date'], 'start_date');
          inclusiveEnd = _optionalDate(args['end_date'], 'end_date');
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        if (start != null &&
            inclusiveEnd != null &&
            inclusiveEnd.isBefore(start)) {
          return _badInput('end_date must not precede start_date');
        }

        final snapshot = await DataExportService(
          service(),
        ).export(from: start, to: inclusiveEnd?.add(const Duration(days: 1)));
        final countsOnly = args['counts_only'] as bool? ?? false;
        final json = snapshot.toJson();
        if (countsOnly) {
          // Everything but the rows, so the receipt reads the same either way.
          json.removeWhere(
            (key, value) =>
                value is List && key != 'covers' && key != 'excludes',
          );
        }
        return {'ok': true, 'counts_only': countsOnly, 'export': json};
      },
    ),
    McpTool(
      name: 'find_incomplete_transactions',
      description:
          'Find transactions missing bookkeeping, for filling the blanks: '
          'description, category, budget, tags, payee, notes or piggy_bank. '
          'Judged leg by leg, so half a split group left uncategorised is '
          'found. A field that cannot apply is never reported: a deposit is not '
          'missing a budget and a transfer is not missing a payee.',
      inputSchema: {
        'type': 'object',
        'required': ['fields'],
        'properties': {
          'fields': {
            'type': 'array',
            'minItems': 1,
            'description':
                'Which gaps to look for. Asked one at a time because '
                'incomplete is not a single standard: a ledger that never uses '
                'piggy banks is not missing one on every row.',
            'items': {
              'type': 'string',
              'enum': [for (final f in TransactionField.values) f.name],
            },
          },
          'account_id': {
            'type': 'string',
            'description': 'Limit to one account. Defaults to every account.',
          },
          'start_date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
          'end_date': {
            'type': 'string',
            'description': 'YYYY-MM-DD, inclusive.',
          },
          'page': {'type': 'integer', 'minimum': 1, 'default': 1},
          'limit': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 500,
            'default': 50,
          },
        },
      },
      run: (args) async {
        final requested = _strList(args['fields']);
        if (requested.isEmpty) {
          return _badInput('fields must name at least one gap to look for');
        }
        final byName = {
          for (final field in TransactionField.values) field.name: field,
        };
        final fields = <TransactionField>{};
        for (final name in requested) {
          final field = byName[name];
          if (field == null) {
            return _badInput(
              'unknown field "$name". Expected one of: '
              '${byName.keys.join(', ')}',
            );
          }
          fields.add(field);
        }

        final DateTime? start;
        final DateTime? inclusiveEnd;
        try {
          start = _optionalDate(args['start_date'], 'start_date');
          inclusiveEnd = _optionalDate(args['end_date'], 'end_date');
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final end = inclusiveEnd?.add(const Duration(days: 1));

        final api = service();
        final accountId = (args['account_id'] as String?)?.trim();
        final transactions = accountId != null && accountId.isNotEmpty
            ? await api.getAccountTransactions(
                accountId,
                start: start,
                end: end,
              )
            : await api.getTransactions(start: start, end: end);

        final incomplete = transactionsMissingFields(
          transactions,
          fields: fields,
        );
        final page = (args['page'] as num?)?.toInt() ?? 1;
        final limit = (args['limit'] as num?)?.toInt() ?? 50;
        final slice = _pageOf(incomplete, page: page, limit: limit);

        return {
          'ok': true,
          'fields': [for (final field in fields) field.name],
          'scanned': transactions.length,
          // Where the work is, over the whole match rather than this page. One
          // transaction counts towards every field it lacks.
          'missing_counts': {
            for (final entry in countMissingByField(
              incomplete,
              fields: fields,
            ).entries)
              entry.key.name: entry.value,
          },
          'pagination': slice.pagination,
          'transactions': [
            for (final transaction in slice.items)
              {
                ..._transactionJson(transaction),
                'missing': [
                  for (final field in missingTransactionFields(
                    transaction,
                    fields: fields,
                  ))
                    field.name,
                ],
              },
          ],
        };
      },
    ),
    McpTool(
      name: 'search_transactions',
      description:
          'Full-text search across transactions, for matching a bank statement '
          'line against what is already recorded.',
      inputSchema: {
        'type': 'object',
        'required': ['query'],
        'properties': {
          'query': {'type': 'string'},
          'page': {'type': 'integer', 'minimum': 1, 'default': 1},
          'limit': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 500,
            'default': 50,
          },
        },
      },
      run: (args) async {
        final query = (args['query'] as String?)?.trim();
        if (query == null || query.isEmpty) {
          return _badInput('query is required');
        }
        final result = await service().searchTransactionsPage(
          query,
          page: (args['page'] as num?)?.toInt() ?? 1,
          limit: (args['limit'] as num?)?.toInt() ?? 50,
        );
        return {
          'ok': true,
          'pagination': {
            'current_page': result.currentPage,
            'total_pages': result.totalPages,
            'total': result.total,
          },
          'transactions': result.transactions.map(_transactionJson).toList(),
        };
      },
    ),
    McpTool(
      name: 'get_budgets',
      description: 'List all Firefly III budgets with spent amounts.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (args) async {
        final api = service();
        final budgets = await api.getBudgets();
        return {
          'ok': true,
          'count': budgets.length,
          'budgets': budgets.map(_budgetJson).toList(),
        };
      },
    ),
    McpTool(
      name: 'get_budget_transactions',
      description: 'Fetch all transactions linked to a budget.',
      inputSchema: {
        'type': 'object',
        'required': ['budget_id'],
        'properties': {
          'budget_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final budgetId = args['budget_id'] as String?;
        if (budgetId == null || budgetId.isEmpty) {
          return _badInput('budget_id is required');
        }
        final api = service();
        final transactions = await api.getBudgetTransactions(budgetId);
        return {
          'ok': true,
          'count': transactions.length,
          'transactions': transactions.map(_transactionJson).toList(),
        };
      },
    ),
    McpTool(
      name: 'update_account',
      writes: true,
      description:
          'Update an account: name, type, identifiers, notes, role, currency, '
          'liability terms, or balances. Anything omitted keeps its current '
          'value. Setting account_number or iban on a payee is what lets '
          'find_account resolve a statement line to it next time instead of '
          'guessing from the name.',
      inputSchema: {
        'type': 'object',
        'required': ['account_id'],
        'properties': {
          'account_id': {'type': 'string'},
          'name': {'type': 'string'},
          'type': {
            'type': 'string',
            'enum': ['asset', 'expense', 'revenue', 'liability'],
          },
          'iban': {'type': 'string'},
          'bic': {'type': 'string'},
          'account_number': {'type': 'string'},
          'notes': {'type': 'string'},
          'active': {'type': 'boolean'},
          'account_role': {
            'type': 'string',
            'enum': [
              'defaultAsset',
              'sharedAsset',
              'savingAsset',
              'ccAsset',
              'cashWalletAsset',
            ],
          },
          'currency_code': {'type': 'string'},
          'liability_type': {
            'type': 'string',
            'enum': ['debt', 'loan', 'mortgage'],
          },
          'liability_direction': {
            'type': 'string',
            'enum': ['credit', 'debit'],
          },
          'include_net_worth': {'type': 'boolean'},
          'opening_balance': {'type': 'number'},
          'opening_balance_date': {
            'type': 'string',
            'description': 'YYYY-MM-DD.',
          },
          'virtual_balance': {'type': 'number'},
          'interest': {'type': 'number'},
          'interest_period': {
            'type': 'string',
            'enum': [
              'daily',
              'weekly',
              'monthly',
              'quarterly',
              'half-year',
              'yearly',
            ],
          },
        },
      },
      run: (args) async {
        final accountId = (args['account_id'] as String?)?.trim();
        if (accountId == null || accountId.isEmpty) {
          return _badInput('account_id is required');
        }
        // Firefly answers 200 to a PUT that changes nothing, so without this a
        // caller who misspelled a field name would be told the edit landed.
        final updated = _accountUpdateFields
            .where((field) => args[field] != null)
            .toList();
        if (updated.isEmpty) {
          return _badInput(
            'pass at least one field to change: '
            '${_accountUpdateFields.join(', ')}',
          );
        }
        final name = (args['name'] as String?)?.trim();
        if (name != null && name.isEmpty) {
          return _badInput('name must not be empty');
        }
        const accountTypes = ['asset', 'expense', 'revenue', 'liability'];
        final type = args['type'] as String?;
        if (type != null && !accountTypes.contains(type)) {
          return _badInput('type must be one of ${accountTypes.join(', ')}');
        }
        const accountRoles = [
          'defaultAsset',
          'sharedAsset',
          'savingAsset',
          'ccAsset',
          'cashWalletAsset',
        ];
        final role = args['account_role'] as String?;
        if (role != null && !accountRoles.contains(role)) {
          return _badInput(
            'account_role must be one of ${accountRoles.join(', ')}',
          );
        }
        final liabilityType = _enumByApiValue(
          LiabilityType.values,
          args['liability_type'] as String?,
          (v) => v.apiValue,
        );
        if (args['liability_type'] != null && liabilityType == null) {
          return _badInput('liability_type must be debt, loan, or mortgage');
        }
        final liabilityDirection = _enumByApiValue(
          LiabilityDirection.values,
          args['liability_direction'] as String?,
          (v) => v.apiValue,
        );
        if (args['liability_direction'] != null && liabilityDirection == null) {
          return _badInput('liability_direction must be credit or debit');
        }
        final interestPeriod = _enumByApiValue(
          InterestPeriod.values,
          args['interest_period'] as String?,
          (v) => v.apiValue,
        );
        if (args['interest_period'] != null && interestPeriod == null) {
          return _badInput(
            'interest_period must be one of '
            '${InterestPeriod.values.map((v) => v.apiValue).join(', ')}',
          );
        }
        final DateTime? openingBalanceDate;
        try {
          openingBalanceDate = _optionalDate(
            args['opening_balance_date'],
            'opening_balance_date',
          );
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        await service().updateAccount(
          accountId,
          name: name,
          type: type,
          iban: args['iban'] as String?,
          bic: args['bic'] as String?,
          accountNumber: args['account_number'] as String?,
          notes: args['notes'] as String?,
          active: args['active'] as bool?,
          role: role,
          currencyCode: args['currency_code'] as String?,
          liabilityType: liabilityType?.apiValue,
          liabilityDirection: liabilityDirection?.apiValue,
          includeNetWorth: args['include_net_worth'] as bool?,
          openingBalance: (args['opening_balance'] as num?)?.toDouble(),
          openingBalanceDate: openingBalanceDate,
          virtualBalance: (args['virtual_balance'] as num?)?.toDouble(),
          interest: (args['interest'] as num?)?.toDouble(),
          interestPeriod: interestPeriod?.apiValue,
        );
        return {
          'ok': true,
          'account_id': accountId,
          'name': ?name,
          'updated_fields': updated,
        };
      },
    ),
    McpTool(
      name: 'update_budget',
      writes: true,
      description:
          'Update a budget name, active flag, notes, and auto-budget settings.',
      inputSchema: {
        'type': 'object',
        'required': ['budget_id', 'name'],
        'properties': {
          'budget_id': {'type': 'string'},
          'name': {'type': 'string'},
          'active': {'type': 'boolean'},
          'notes': {'type': 'string'},
          'amount': {'type': 'number'},
          'auto_budget_type': {
            'type': 'string',
            'enum': ['none', 'reset', 'rollover', 'adjusted'],
          },
          'auto_budget_period': {
            'type': 'string',
            'enum': [
              'daily',
              'weekly',
              'monthly',
              'quarterly',
              'half_year',
              'yearly',
            ],
          },
          'currency_code': {'type': 'string'},
        },
      },
      run: (args) async {
        final budgetId = args['budget_id'] as String?;
        final name = args['name'] as String?;
        if (budgetId == null || budgetId.isEmpty) {
          return _badInput('budget_id is required');
        }
        if (name == null || name.isEmpty) return _badInput('name is required');
        final api = service();
        // Merged over what the budget already is, so a name-only call cannot
        // blank notes or drop an auto-budget the caller never mentioned.
        final existing = (await api.getBudgets())
            .where((budget) => budget.id == budgetId)
            .firstOrNull;
        if (existing == null) {
          return _badInput('No budget with id $budgetId');
        }

        final amount =
            (args['amount'] as num?)?.toDouble() ?? existing.autoBudgetAmount;
        final autoBudgetType = args.containsKey('auto_budget_type')
            ? AutoBudgetType.parse(args['auto_budget_type'] as String?)
            : existing.autoBudgetType;
        final input = BudgetInput(
          name: name,
          active: args['active'] as bool? ?? existing.active,
          notes: args['notes'] as String? ?? existing.notes,
          autoBudgetType: amount > 0
              ? (autoBudgetType == AutoBudgetType.none
                    ? AutoBudgetType.reset
                    : autoBudgetType)
              : AutoBudgetType.none,
          autoBudgetAmount: amount,
          autoBudgetPeriod:
              AutoBudgetPeriod.parse(args['auto_budget_period'] as String?) ??
              existing.autoBudgetPeriod,
          // The budget's own currency, never a hardcoded EUR: an instance whose
          // primary is not EUR would have had its budget redenominated.
          currencyCode:
              args['currency_code'] as String? ?? existing.currencyCode,
        );
        await api.updateBudget(budgetId, input);
        return {
          'ok': true,
          'budget_id': budgetId,
          'name': name,
          'amount': amount,
        };
      },
    ),
    McpTool(
      name: 'delete_budget',
      writes: true,
      description: 'Delete a Firefly III budget by ID.',
      inputSchema: {
        'type': 'object',
        'required': ['budget_id'],
        'properties': {
          'budget_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final budgetId = args['budget_id'] as String?;
        if (budgetId == null || budgetId.isEmpty) {
          return _badInput('budget_id is required');
        }
        final api = service();
        await api.deleteBudget(budgetId);
        return {'ok': true, 'budget_id': budgetId, 'deleted': true};
      },
    ),
    McpTool(
      name: 'get_account',
      description: 'Fetch one account, optionally as it stood on a given date.',
      inputSchema: {
        'type': 'object',
        'required': ['account_id'],
        'properties': {
          'account_id': {'type': 'string'},
          'date': {
            'type': 'string',
            'description': 'YYYY-MM-DD; returns the balance as of that date.',
          },
        },
      },
      run: (args) async {
        final id = (args['account_id'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('account_id is required');
        }
        final DateTime? date;
        try {
          date = _optionalDate(args['date'], 'date');
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final account = await service().getAccount(id, date: date);
        return {'ok': true, 'account': _accountJson(account)};
      },
    ),
    McpTool(
      name: 'get_account_balance_at_date',
      description:
          'Balance of an account on a date, for checking a statement closing '
          'balance against what is recorded.',
      inputSchema: {
        'type': 'object',
        'required': ['account_id', 'date'],
        'properties': {
          'account_id': {'type': 'string'},
          'date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
        },
      },
      run: (args) async {
        final id = (args['account_id'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('account_id is required');
        }
        final DateTime? date;
        try {
          date = _optionalDate(args['date'], 'date');
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        if (date == null) return _badInput('date is required');
        final balance = await service().getAccountBalanceAtDate(id, date);
        return {
          'ok': true,
          'account_id': id,
          'date': _dateOnly(date),
          'balance': balance,
        };
      },
    ),
    McpTool(
      name: 'create_account',
      writes: true,
      description:
          'Create an account. Use asset, expense, revenue, or liability for '
          'type.',
      inputSchema: {
        'type': 'object',
        'required': ['name', 'type', 'currency_code'],
        'properties': {
          'name': {'type': 'string'},
          'type': {
            'type': 'string',
            'enum': ['asset', 'expense', 'revenue', 'liability'],
          },
          'currency_code': {'type': 'string'},
          'account_role': {
            'type': 'string',
            'description':
                'Required by Firefly for asset accounts; defaults to '
                'defaultAsset when omitted.',
            'enum': [
              'defaultAsset',
              'sharedAsset',
              'savingAsset',
              'ccAsset',
              'cashWalletAsset',
            ],
          },
        },
      },
      run: (args) async {
        final name = (args['name'] as String?)?.trim();
        final type = (args['type'] as String?)?.trim();
        final currency = (args['currency_code'] as String?)?.trim();
        if (name == null || name.isEmpty) return _badInput('name is required');
        if (type == null || type.isEmpty) return _badInput('type is required');
        if (currency == null || currency.isEmpty) {
          return _badInput('currency_code is required');
        }
        const accountTypes = ['asset', 'expense', 'revenue', 'liability'];
        if (!accountTypes.contains(type)) {
          return _badInput('type must be one of ${accountTypes.join(', ')}');
        }
        final created = await service().createAccount(
          name: name,
          type: type,
          currencyCode: currency,
          role: args['account_role'] as String?,
        );
        return {'ok': true, 'account': _accountJson(created)};
      },
    ),
    McpTool(
      name: 'delete_account',
      writes: true,
      description:
          'Delete an account. Firefly also removes the transactions that belong '
          'to it, so this is not recoverable.',
      inputSchema: {
        'type': 'object',
        'required': ['account_id'],
        'properties': {
          'account_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['account_id'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('account_id is required');
        }
        await service().deleteAccount(id);
        return {'ok': true, 'account_id': id, 'deleted': true};
      },
    ),
    McpTool(
      name: 'create_budget',
      writes: true,
      description:
          'Create a budget. Supply amount to give it an auto-budget, which '
          'defaults to a monthly reset.',
      inputSchema: {
        'type': 'object',
        'required': ['name'],
        'properties': {
          'name': {'type': 'string'},
          'active': {'type': 'boolean', 'default': true},
          'notes': {'type': 'string'},
          'amount': {'type': 'number'},
          'auto_budget_type': {
            'type': 'string',
            'enum': ['none', 'reset', 'rollover', 'adjusted'],
          },
          'auto_budget_period': {
            'type': 'string',
            'enum': [
              'daily',
              'weekly',
              'monthly',
              'quarterly',
              'half_year',
              'yearly',
            ],
          },
          'currency_code': {'type': 'string'},
        },
      },
      run: (args) async {
        final name = (args['name'] as String?)?.trim();
        if (name == null || name.isEmpty) return _badInput('name is required');
        final api = service();
        final amount = (args['amount'] as num?)?.toDouble();
        final requested = AutoBudgetType.parse(
          args['auto_budget_type'] as String?,
        );
        final created = await api.createBudget(
          BudgetInput(
            name: name,
            active: args['active'] as bool? ?? true,
            notes: args['notes'] as String?,
            autoBudgetType: amount != null && amount > 0
                ? (requested == AutoBudgetType.none
                      ? AutoBudgetType.reset
                      : requested)
                : AutoBudgetType.none,
            autoBudgetAmount: amount,
            autoBudgetPeriod: AutoBudgetPeriod.parse(
              args['auto_budget_period'] as String?,
            ),
            currencyCode:
                args['currency_code'] as String? ??
                (await api.getPrimaryCurrency()).code,
          ),
        );
        return {'ok': true, 'budget': _budgetJson(created)};
      },
    ),
    McpTool(
      name: 'get_budget_limits',
      description:
          'List the per-period amounts set on a budget. These are the actual '
          'monthly figures, separate from an auto-budget rule.',
      inputSchema: {
        'type': 'object',
        'required': ['budget_id'],
        'properties': {
          'budget_id': {'type': 'string'},
          'start_date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
          'end_date': {
            'type': 'string',
            'description': 'YYYY-MM-DD, inclusive.',
          },
        },
      },
      run: (args) async {
        final id = (args['budget_id'] as String?)?.trim();
        if (id == null || id.isEmpty) return _badInput('budget_id is required');
        final DateTime? start;
        final DateTime? inclusiveEnd;
        try {
          start = _optionalDate(args['start_date'], 'start_date');
          inclusiveEnd = _optionalDate(args['end_date'], 'end_date');
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final limits = await service().getBudgetLimits(
          id,
          start: start,
          end: inclusiveEnd?.add(const Duration(days: 1)),
        );
        return {
          'ok': true,
          'count': limits.length,
          'limits': [for (final limit in limits) _budgetLimitJson(limit)],
        };
      },
    ),
    McpTool(
      name: 'create_budget_limit',
      writes: true,
      description:
          'Set an amount on a budget for one period, such as a single month.',
      inputSchema: {
        'type': 'object',
        'required': ['budget_id', 'start_date', 'end_date', 'amount'],
        'properties': {
          'budget_id': {'type': 'string'},
          'start_date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
          'end_date': {
            'type': 'string',
            'description': 'YYYY-MM-DD, inclusive.',
          },
          'amount': {'type': 'number', 'exclusiveMinimum': 0},
          'currency_code': {'type': 'string'},
          'notes': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['budget_id'] as String?)?.trim();
        if (id == null || id.isEmpty) return _badInput('budget_id is required');
        final api = service();
        final BudgetLimitInput input;
        try {
          input = await _budgetLimitInput(args, api);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final created = await api.createBudgetLimit(id, input);
        return {'ok': true, 'limit': _budgetLimitJson(created)};
      },
    ),
    McpTool(
      name: 'update_budget_limit',
      writes: true,
      description: 'Change an existing budget limit.',
      inputSchema: {
        'type': 'object',
        'required': [
          'budget_id',
          'limit_id',
          'start_date',
          'end_date',
          'amount',
        ],
        'properties': {
          'budget_id': {'type': 'string'},
          'limit_id': {'type': 'string'},
          'start_date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
          'end_date': {
            'type': 'string',
            'description': 'YYYY-MM-DD, inclusive.',
          },
          'amount': {'type': 'number', 'exclusiveMinimum': 0},
          'currency_code': {'type': 'string'},
          'notes': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['budget_id'] as String?)?.trim();
        final limitId = (args['limit_id'] as String?)?.trim();
        if (id == null || id.isEmpty) return _badInput('budget_id is required');
        if (limitId == null || limitId.isEmpty) {
          return _badInput('limit_id is required');
        }
        final api = service();
        final BudgetLimitInput input;
        try {
          input = await _budgetLimitInput(args, api);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        await api.updateBudgetLimit(id, limitId, input);
        return {'ok': true, 'budget_id': id, 'limit_id': limitId};
      },
    ),
    McpTool(
      name: 'get_categories',
      description: 'List Firefly III categories.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async {
        final categories = await service().getCategories();
        return {
          'ok': true,
          'count': categories.length,
          'categories': [
            for (final category in categories)
              {'id': category.id, 'name': category.name},
          ],
        };
      },
    ),
    McpTool(
      name: 'create_category',
      writes: true,
      description: 'Create a category.',
      inputSchema: {
        'type': 'object',
        'required': ['name'],
        'properties': {
          'name': {'type': 'string'},
          'notes': {'type': 'string'},
        },
      },
      run: (args) async {
        final name = (args['name'] as String?)?.trim();
        if (name == null || name.isEmpty) return _badInput('name is required');
        final created = await service().createCategory(
          name,
          notes: args['notes'] as String?,
        );
        return {
          'ok': true,
          'category': {'id': created.id, 'name': created.name},
        };
      },
    ),
    McpTool(
      name: 'update_category',
      writes: true,
      description: 'Rename a category, and optionally replace its notes.',
      inputSchema: {
        'type': 'object',
        'required': ['category_id', 'name'],
        'properties': {
          'category_id': {'type': 'string'},
          'name': {'type': 'string'},
          'notes': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['category_id'] as String?)?.trim();
        final name = (args['name'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('category_id is required');
        }
        if (name == null || name.isEmpty) return _badInput('name is required');
        final updated = await service().updateCategory(
          id,
          name,
          notes: args['notes'] as String?,
        );
        return {
          'ok': true,
          'category': {'id': updated.id, 'name': updated.name},
        };
      },
    ),
    McpTool(
      name: 'delete_category',
      writes: true,
      description:
          'Delete a category. Transactions keep their data but lose this '
          'category.',
      inputSchema: {
        'type': 'object',
        'required': ['category_id'],
        'properties': {
          'category_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['category_id'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('category_id is required');
        }
        await service().deleteCategory(id);
        return {'ok': true, 'category_id': id, 'deleted': true};
      },
    ),
    McpTool(
      name: 'get_tags',
      description: 'List Firefly III tags.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async {
        final tags = await service().getTags();
        return {
          'ok': true,
          'count': tags.length,
          'tags': [
            for (final tag in tags) {'id': tag.id, 'name': tag.name},
          ],
        };
      },
    ),
    McpTool(
      name: 'create_tag',
      writes: true,
      description: 'Create a tag.',
      inputSchema: {
        'type': 'object',
        'required': ['tag'],
        'properties': {
          'tag': {'type': 'string'},
          'description': {'type': 'string'},
        },
      },
      run: (args) async {
        final tag = (args['tag'] as String?)?.trim();
        if (tag == null || tag.isEmpty) return _badInput('tag is required');
        final created = await service().createTag(
          tag,
          description: args['description'] as String?,
        );
        return {
          'ok': true,
          'tag': {'id': created.id, 'name': created.name},
        };
      },
    ),
    McpTool(
      name: 'update_tag',
      writes: true,
      description: 'Rename a tag, and optionally replace its description.',
      inputSchema: {
        'type': 'object',
        'required': ['tag_id', 'tag'],
        'properties': {
          'tag_id': {'type': 'string'},
          'tag': {'type': 'string'},
          'description': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['tag_id'] as String?)?.trim();
        final tag = (args['tag'] as String?)?.trim();
        if (id == null || id.isEmpty) return _badInput('tag_id is required');
        if (tag == null || tag.isEmpty) return _badInput('tag is required');
        final updated = await service().updateTag(
          id,
          tag,
          description: args['description'] as String?,
        );
        return {
          'ok': true,
          'tag': {'id': updated.id, 'name': updated.name},
        };
      },
    ),
    McpTool(
      name: 'delete_tag',
      writes: true,
      description: 'Delete a tag. Transactions keep their data but lose it.',
      inputSchema: {
        'type': 'object',
        'required': ['tag_id'],
        'properties': {
          'tag_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['tag_id'] as String?)?.trim();
        if (id == null || id.isEmpty) return _badInput('tag_id is required');
        await service().deleteTag(id);
        return {'ok': true, 'tag_id': id, 'deleted': true};
      },
    ),
    McpTool(
      name: 'get_bills',
      description: 'List bills (recurring payables) with their amount ranges.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async {
        final bills = await service().getBills();
        return {
          'ok': true,
          'count': bills.length,
          'bills': [for (final bill in bills) _billJson(bill)],
        };
      },
    ),
    McpTool(
      name: 'create_bill',
      writes: true,
      description:
          'Create a bill. amount_min and amount_max bound what a matching '
          'payment may be; pass the same value for both when it is fixed.',
      inputSchema: {
        'type': 'object',
        'required': ['name', 'amount_min', 'amount_max', 'date'],
        'properties': _billFieldSchema(),
      },
      run: (args) async {
        final api = service();
        final BillInput input;
        try {
          input = await _billInput(args, api);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final created = await api.createBill(input);
        return {'ok': true, 'bill': _billJson(created)};
      },
    ),
    McpTool(
      name: 'update_bill',
      writes: true,
      description: 'Update a bill. Omitted fields keep their current value.',
      inputSchema: {
        'type': 'object',
        'required': ['bill_id'],
        'properties': {
          'bill_id': {'type': 'string'},
          ..._billFieldSchema(),
        },
      },
      run: (args) async {
        final id = (args['bill_id'] as String?)?.trim();
        if (id == null || id.isEmpty) return _badInput('bill_id is required');
        final api = service();
        final existing = (await api.getBills())
            .where((b) => b.id == id)
            .firstOrNull;
        if (existing == null) return _badInput('No bill with id $id');
        final BillInput input;
        try {
          input = await _billInput(args, api, base: existing);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final updated = await api.updateBill(id, input);
        return {'ok': true, 'bill': _billJson(updated)};
      },
    ),
    McpTool(
      name: 'delete_bill',
      writes: true,
      description:
          'Delete a bill. Transactions linked to it survive but lose the link.',
      inputSchema: {
        'type': 'object',
        'required': ['bill_id'],
        'properties': {
          'bill_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['bill_id'] as String?)?.trim();
        if (id == null || id.isEmpty) return _badInput('bill_id is required');
        await service().deleteBill(id);
        return {'ok': true, 'bill_id': id, 'deleted': true};
      },
    ),
    McpTool(
      name: 'get_piggy_banks',
      description: 'List piggy banks with their progress toward target.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async {
        final piggies = await service().getPiggyBanks();
        return {
          'ok': true,
          'count': piggies.length,
          'piggy_banks': [for (final piggy in piggies) _piggyJson(piggy)],
        };
      },
    ),
    McpTool(
      name: 'create_piggy_bank',
      writes: true,
      description: 'Create a piggy bank linked to one or more asset accounts.',
      inputSchema: {
        'type': 'object',
        'required': ['name', 'target_amount', 'account_ids', 'start_date'],
        'properties': _piggyFieldSchema(),
      },
      run: (args) async {
        final api = service();
        final PiggyBankInput input;
        try {
          input = await _piggyInput(args, api);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final created = await api.createPiggyBank(input);
        return {'ok': true, 'piggy_bank': _piggyJson(created)};
      },
    ),
    McpTool(
      name: 'update_piggy_bank',
      writes: true,
      description: 'Update a piggy bank. Omitted fields keep their value.',
      inputSchema: {
        'type': 'object',
        'required': ['piggy_bank_id'],
        'properties': {
          'piggy_bank_id': {'type': 'string'},
          ..._piggyFieldSchema(),
        },
      },
      run: (args) async {
        final id = (args['piggy_bank_id'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('piggy_bank_id is required');
        }
        final api = service();
        final existing = (await api.getPiggyBanks())
            .where((p) => p.id == id)
            .firstOrNull;
        if (existing == null) return _badInput('No piggy bank with id $id');
        final PiggyBankInput input;
        try {
          input = await _piggyInput(args, api, base: existing);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final updated = await api.updatePiggyBank(id, input);
        return {'ok': true, 'piggy_bank': _piggyJson(updated)};
      },
    ),
    McpTool(
      name: 'delete_piggy_bank',
      writes: true,
      description: 'Delete a piggy bank. The linked accounts are untouched.',
      inputSchema: {
        'type': 'object',
        'required': ['piggy_bank_id'],
        'properties': {
          'piggy_bank_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['piggy_bank_id'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('piggy_bank_id is required');
        }
        await service().deletePiggyBank(id);
        return {'ok': true, 'piggy_bank_id': id, 'deleted': true};
      },
    ),
    McpTool(
      name: 'get_recurrences',
      description:
          'List recurring transaction rules, each with the lines it creates: '
          'amount, source and destination accounts, category, budget, bill and '
          'tags. Those name the payee behind a standing payment and are what '
          'tells two rules with the same title apart.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async {
        final recurrences = await service().getRecurrences();
        return {
          'ok': true,
          'count': recurrences.length,
          'recurrences': [for (final r in recurrences) _recurrenceJson(r)],
        };
      },
    ),
    McpTool(
      name: 'create_recurrence',
      writes: true,
      description:
          'Create a recurring transaction rule. repetition_type monthly with '
          'moment "1" means the 1st of each month; weekly takes 1-7, yearly a '
          'MM-DD.',
      inputSchema: {
        'type': 'object',
        'required': [
          'title',
          'first_date',
          'type',
          'amount',
          'description',
          'source_id',
          'destination_id',
        ],
        'properties': _recurrenceFieldSchema(),
      },
      run: (args) async {
        final api = service();
        final RecurrenceInput input;
        try {
          input = await _recurrenceInput(args, api);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final created = await api.createRecurrence(input);
        return {'ok': true, 'recurrence': _recurrenceJson(created)};
      },
    ),
    McpTool(
      name: 'update_recurrence',
      writes: true,
      description:
          'Replace a recurring rule. Firefly takes the whole rule, so pass every '
          'field you want kept.',
      inputSchema: {
        'type': 'object',
        'required': [
          'recurrence_id',
          'title',
          'first_date',
          'type',
          'amount',
          'description',
          'source_id',
          'destination_id',
        ],
        'properties': {
          'recurrence_id': {'type': 'string'},
          ..._recurrenceFieldSchema(),
        },
      },
      run: (args) async {
        final id = (args['recurrence_id'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('recurrence_id is required');
        }
        final api = service();
        final RecurrenceInput input;
        try {
          input = await _recurrenceInput(args, api);
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final updated = await api.updateRecurrence(id, input);
        return {'ok': true, 'recurrence': _recurrenceJson(updated)};
      },
    ),
    McpTool(
      name: 'get_recurrence_transactions',
      description: 'Transactions a recurring rule has created.',
      inputSchema: {
        'type': 'object',
        'required': ['recurrence_id'],
        'properties': {
          'recurrence_id': {'type': 'string'},
          'page': {'type': 'integer', 'minimum': 1, 'default': 1},
          'limit': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 500,
            'default': 50,
          },
        },
      },
      run: (args) async {
        final id = (args['recurrence_id'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('recurrence_id is required');
        }
        final result = await service().getRecurrenceTransactionsPage(
          id,
          page: (args['page'] as num?)?.toInt() ?? 1,
          limit: (args['limit'] as num?)?.toInt() ?? 50,
        );
        return _pageJson(result);
      },
    ),
    McpTool(
      name: 'get_bill_transactions',
      description: 'Transactions matched to a bill.',
      inputSchema: {
        'type': 'object',
        'required': ['bill_id'],
        'properties': {
          'bill_id': {'type': 'string'},
          'page': {'type': 'integer', 'minimum': 1, 'default': 1},
          'limit': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 500,
            'default': 50,
          },
        },
      },
      run: (args) async {
        final id = (args['bill_id'] as String?)?.trim();
        if (id == null || id.isEmpty) return _badInput('bill_id is required');
        final result = await service().getBillTransactionsPage(
          id,
          page: (args['page'] as num?)?.toInt() ?? 1,
          limit: (args['limit'] as num?)?.toInt() ?? 50,
        );
        return _pageJson(result);
      },
    ),
    McpTool(
      name: 'get_account_balance_history',
      description:
          'Balance series for one or more accounts across a window, for charting '
          'or comparing month ends.',
      inputSchema: {
        'type': 'object',
        'required': ['account_ids', 'start_date', 'end_date'],
        'properties': {
          'account_ids': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'start_date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
          'end_date': {
            'type': 'string',
            'description': 'YYYY-MM-DD, inclusive.',
          },
          'period': {
            'type': 'string',
            'default': '1M',
            'description': 'Firefly bucket size, such as 1D, 1W, or 1M.',
          },
        },
      },
      run: (args) async {
        final ids = _strList(args['account_ids']);
        if (ids.isEmpty) {
          return _badInput('account_ids must name at least one account');
        }
        final DateTime? start;
        final DateTime? inclusiveEnd;
        try {
          start = _optionalDate(args['start_date'], 'start_date');
          inclusiveEnd = _optionalDate(args['end_date'], 'end_date');
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        if (start == null) return _badInput('start_date is required');
        if (inclusiveEnd == null) return _badInput('end_date is required');
        if (inclusiveEnd.isBefore(start)) {
          return _badInput('end_date must not precede start_date');
        }
        final api = service();
        final all = await api.getAccounts(
          types: const ['asset', 'liability', 'expense', 'revenue'],
        );
        final wanted = all.where((a) => ids.contains(a.id)).toList();
        if (wanted.isEmpty) {
          return _badInput('none of account_ids matched an account');
        }
        final histories = await api.getAccountBalanceHistories(
          accounts: wanted,
          start: start,
          end: inclusiveEnd.add(const Duration(days: 1)),
          period: (args['period'] as String?) ?? '1M',
        );
        return {
          'ok': true,
          'period': (args['period'] as String?) ?? '1M',
          'histories': histories,
        };
      },
    ),
    McpTool(
      name: 'create_liability',
      writes: true,
      description:
          'Create a liability account such as a loan, debt, or mortgage.',
      inputSchema: {
        'type': 'object',
        'required': ['name', 'liability_type', 'liability_direction'],
        'properties': {
          'name': {'type': 'string'},
          'currency_code': {'type': 'string'},
          'liability_type': {
            'type': 'string',
            'enum': ['debt', 'loan', 'mortgage'],
          },
          'liability_direction': {
            'type': 'string',
            'enum': ['credit', 'debit'],
          },
          'amount_owed': {'type': 'number'},
          'start_date': {'type': 'string', 'description': 'YYYY-MM-DD.'},
          'interest': {'type': 'number'},
          'interest_period': {
            'type': 'string',
            'enum': [
              'daily',
              'weekly',
              'monthly',
              'quarterly',
              'half-year',
              'yearly',
            ],
          },
          'include_net_worth': {'type': 'boolean', 'default': true},
          'notes': {'type': 'string'},
        },
      },
      run: (args) async {
        final name = (args['name'] as String?)?.trim();
        if (name == null || name.isEmpty) return _badInput('name is required');
        final type = _enumByApiValue(
          LiabilityType.values,
          args['liability_type'] as String?,
          (v) => v.apiValue,
        );
        if (type == null) {
          return _badInput('liability_type must be debt, loan, or mortgage');
        }
        final direction = _enumByApiValue(
          LiabilityDirection.values,
          args['liability_direction'] as String?,
          (v) => v.apiValue,
        );
        if (direction == null) {
          return _badInput('liability_direction must be credit or debit');
        }
        final DateTime? startDate;
        try {
          startDate = _optionalDate(args['start_date'], 'start_date');
        } on ArgumentError catch (e) {
          return _badInput('${e.message}');
        }
        final api = service();
        final created = await api.createLiability(
          LiabilityInput(
            name: name,
            currencyCode:
                args['currency_code'] as String? ??
                (await api.getPrimaryCurrency()).code,
            liabilityType: type,
            liabilityDirection: direction,
            amountOwed: (args['amount_owed'] as num?)?.toDouble(),
            startDate: startDate,
            interest: (args['interest'] as num?)?.toDouble(),
            interestPeriod: _enumByApiValue(
              InterestPeriod.values,
              args['interest_period'] as String?,
              (v) => v.apiValue,
            ),
            includeNetWorth: args['include_net_worth'] as bool? ?? true,
            notes: args['notes'] as String?,
          ),
        );
        return {'ok': true, 'account': _accountJson(created)};
      },
    ),
    McpTool(
      name: 'delete_recurrence',
      writes: true,
      description:
          'Delete a recurring transaction rule. Transactions it already created '
          'are kept.',
      inputSchema: {
        'type': 'object',
        'required': ['recurrence_id'],
        'properties': {
          'recurrence_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final id = (args['recurrence_id'] as String?)?.trim();
        if (id == null || id.isEmpty) {
          return _badInput('recurrence_id is required');
        }
        await service().deleteRecurrence(id);
        return {'ok': true, 'recurrence_id': id, 'deleted': true};
      },
    ),
    McpTool(
      name: 'get_currencies',
      description:
          'List currencies known to Firefly III, with which are enabled.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async {
        final currencies = await service().getCurrencies();
        return {
          'ok': true,
          'count': currencies.length,
          'currencies': [
            for (final currency in currencies)
              {
                'id': currency.id,
                'code': currency.code,
                'name': currency.name,
                'symbol': currency.symbol,
                'enabled': currency.enabled,
              },
          ],
        };
      },
    ),
    McpTool(
      name: 'run_projection',
      description:
          'Run an on-device financial projection (savings, compound, portfolio, or cashflow).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'projection_type': {
            'type': 'string',
            'enum': ['savings', 'compound', 'portfolio', 'cashflow'],
            'default': 'savings',
          },
          'months': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 120,
            'default': 6,
          },
          'what_if_percent': {
            'type': 'integer',
            'minimum': 0,
            'maximum': 100,
            'default': 0,
          },
          'annual_return_percent': {'type': 'number', 'default': 7.0},
          'volatility_percent': {'type': 'number', 'default': 12.0},
        },
      },
      run: (args) async {
        final api = service();
        final accounts = await api.getAccounts();
        final transactions = await api.getTransactions();
        final currentBalance = computeNetWorth(accounts);
        final ProjectionType projectionType;
        try {
          projectionType = _projectionType(args['projection_type'] as String?);
        } on ArgumentError catch (e) {
          return _badInput('$e');
        }
        final params = ProjectionParams(
          type: projectionType,
          months: (args['months'] as num?)?.toInt() ?? 6,
          whatIfPercent: (args['what_if_percent'] as num?)?.toInt() ?? 0,
          annualReturnPercent:
              (args['annual_return_percent'] as num?)?.toDouble() ?? 7.0,
          volatilityPercent:
              (args['volatility_percent'] as num?)?.toDouble() ?? 12.0,
        );
        final result = ProjectionService.project(
          currentBalance: currentBalance,
          transactions: transactions,
          params: params,
          accounts: accounts,
        );
        return {
          'ok': true,
          'current_balance': currentBalance,
          'params': {
            'type': params.type.name,
            'months': params.months,
            'what_if_percent': params.whatIfPercent,
          },
          'end_expected': result.endExpected,
          'end_worst': result.endWorst,
          'end_best': result.endBest,
          'growth_percent': result.growthPercent(result.startBalance),
          'alert': result.alert == null
              ? null
              : {
                  'kind': result.alert!.kind.name,
                  'liability_name': result.alert!.liabilityName,
                  'liability_balance': result.alert!.liabilityBalance,
                },
        };
      },
    ),
    McpTool(
      name: 'get_dashboard_kpis',
      description:
          'Compute dashboard KPIs (net worth, income, spending, savings) for a period.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'period': {
            'type': 'string',
            'enum': _strList(DashboardPeriod.values.map((p) => p.name)),
            'default': 'thisMonth',
          },
          'period_label': {
            'type': 'string',
            'description':
                'Human label for the period (default: period enum name).',
          },
        },
      },
      run: (args) async {
        final api = service();
        final accounts = await api.getAccounts();
        final transactions = await api.getTransactions();
        final currency = await api.getPrimaryCurrency();
        final DashboardPeriod period;
        try {
          period = _dashboardPeriod(args['period'] as String?);
        } on ArgumentError catch (e) {
          return _badInput('$e');
        }
        final range = resolveDashboardDateRange(period: period);
        final comparison = previousDashboardPeriodRange(period: period);
        final label = (args['period_label'] as String?) ?? period.name;
        final kpis = computeDashboardKpis(
          accounts: accounts,
          transactions: transactions,
          periodRange: range,
          comparisonRange: comparison,
          primaryCurrencySymbol: currency.symbol,
          periodLabel: label,
        );
        Map<String, Object?> deltaJson(DeltaResult delta) => {
          'kind': delta.kind.name,
          'percent': delta.percent,
          'is_positive': delta.isPositive,
        };
        return {
          'ok': true,
          'period': period.name,
          'kpis': {
            'total_balance': kpis.totalBalance,
            'period_income': kpis.periodIncome,
            'period_spending': kpis.periodSpending,
            'period_saved': kpis.periodSaved,
            'currency': kpis.currency,
            'period_label': kpis.periodLabel,
            'income_delta': deltaJson(kpis.incomeDelta),
            'spending_delta': deltaJson(kpis.spendingDelta),
            'saved_delta': deltaJson(kpis.savedDelta),
          },
        };
      },
    ),
  ];
  toolNames.addAll(tools.map((tool) => tool.name));
  return tools;
}
