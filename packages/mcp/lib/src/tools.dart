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

Map<String, Object?> _transactionJson(Transaction transaction) => {
  'id': transaction.id,
  'type': transaction.type,
  'date': _dateOnly(transaction.date),
  'amount': transaction.totalAmount,
  'description': transaction.description,
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
  'notes': transaction.notes,
  'currency_symbol': transaction.currencySymbol,
  'currency_code': transaction.currencyCode,
  'foreign_amount': transaction.foreignAmount,
  'foreign_currency_code': transaction.foreignCurrencyCode,
  'split_count': transaction.resolvedSplits().length,
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

/// Slices [all] into a page, for endpoints Firefly cannot window server-side.
Map<String, Object?> _paginateClientSide(
  List<Transaction> all, {
  required int page,
  required int limit,
}) {
  final total = all.length;
  final totalPages = total == 0 ? 0 : ((total + limit - 1) ~/ limit);
  final start = (page - 1) * limit;
  final slice = start >= total
      ? const <Transaction>[]
      : all.sublist(start, min(start + limit, total));
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

/// Builds a Transaction from tool arguments, reusing [base] for anything the
/// caller did not supply. [base] is null on create.
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
  final amount = (args['amount'] as num?)?.toDouble() ?? base?.amount;
  if (amount == null || amount <= 0) {
    throw ArgumentError('amount must be greater than zero');
  }
  final description =
      (args['description'] as String?) ?? base?.description ?? '';
  if (description.trim().isEmpty) {
    throw ArgumentError('description is required');
  }
  final date = _optionalDate(args['date'], 'date') ?? base?.date;
  if (date == null) {
    throw ArgumentError('date is required');
  }
  return Transaction(
    id: id,
    type: type,
    date: date,
    amount: amount,
    description: description,
    sourceName: (args['source_name'] as String?) ?? base?.sourceName ?? '',
    destinationName:
        (args['destination_name'] as String?) ?? base?.destinationName ?? '',
    categoryName:
        (args['category_name'] as String?) ?? base?.categoryName ?? '',
    currencySymbol: base?.currencySymbol ?? '',
    currencyCode:
        (args['currency_code'] as String?) ?? base?.currencyCode ?? '',
    sourceId: (args['source_id'] as String?) ?? base?.sourceId,
    destinationId: (args['destination_id'] as String?) ?? base?.destinationId,
    categoryId: (args['category_id'] as String?) ?? base?.categoryId,
    budgetId: (args['budget_id'] as String?) ?? base?.budgetId,
    notes: (args['notes'] as String?) ?? base?.notes,
    tags: args.containsKey('tags')
        ? _strList(args['tags'])
        : (base?.tags ?? const []),
    billId: (args['bill_id'] as String?) ?? base?.billId,
  );
}

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
        ? BillRepeatFrequency.fromApi(args['repeat_frequency'] as String?)
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

Map<String, Object?> _pageJson(TransactionPageResult result) => {
  'ok': true,
  'pagination': {
    'current_page': result.currentPage,
    'total_pages': result.totalPages,
    'total': result.total,
  },
  'transactions': result.transactions.map(_transactionJson).toList(),
};

Map<String, Object?> _recurrenceJson(Recurrence recurrence) => {
  'id': recurrence.id,
  'title': recurrence.title,
  'description': recurrence.description,
  'active': recurrence.active,
  'first_date': _dateOnly(recurrence.firstDate),
  'repeat_until': recurrence.repeatUntil == null
      ? null
      : _dateOnly(recurrence.repeatUntil!),
  'nr_of_repetitions': recurrence.nrOfRepetitions,
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
    type: RecurrenceTransactionType.fromApi(args['type'] as String?),
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
        type: RecurrenceRepetitionType.fromApi(
          args['repetition_type'] as String?,
        ),
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
List<McpTool> buildTools({
  required FireflyTarget target,
  http.Client? httpClient,
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

  return [
    McpTool(
      name: 'get_capabilities',
      description:
          'Return FireRacoon MCP server capabilities, tool names, and version.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async => {
        'ok': true,
        'version': _mcpVersion,
        'tools': [
          'check_connection',
          'get_current_user',
          'get_primary_currency',
          'set_primary_currency',
          'get_accounts',
          'get_transactions',
          'get_transaction',
          'search_transactions',
          'create_transaction',
          'update_transaction',
          'duplicate_transaction',
          'delete_transaction',
          'set_transaction_reconciled',
          'store_reconciliation',
          'get_budgets',
          'get_budget_transactions',
          'update_account',
          'update_budget',
          'delete_budget',
          'get_account',
          'get_account_balance_at_date',
          'create_account',
          'delete_account',
          'create_budget',
          'get_budget_limits',
          'create_budget_limit',
          'update_budget_limit',
          'get_categories',
          'create_category',
          'update_category',
          'delete_category',
          'get_tags',
          'create_tag',
          'update_tag',
          'delete_tag',
          'get_currencies',
          'get_bills',
          'create_bill',
          'update_bill',
          'delete_bill',
          'get_piggy_banks',
          'create_piggy_bank',
          'update_piggy_bank',
          'delete_piggy_bank',
          'get_recurrences',
          'create_recurrence',
          'update_recurrence',
          'delete_recurrence',
          'get_recurrence_transactions',
          'get_bill_transactions',
          'get_account_balance_history',
          'create_liability',
          'run_projection',
          'get_dashboard_kpis',
          'get_capabilities',
        ],
        // Sorted so this and the schema's list compare by membership, not by
        // the order two hand-maintained lists happen to be in.
        'write_tools': [..._writeToolNames]..sort(),
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
        return {'ok': true, 'transaction': _transactionJson(transaction)};
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
        return {'ok': true, 'transaction': _transactionJson(updated)};
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
          'Firefly match or create the other side.',
      inputSchema: {
        'type': 'object',
        'required': ['type', 'date', 'amount', 'description'],
        'properties': _transactionFieldSchema(),
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
          'transaction': _transactionJson(created),
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
          'transaction': _transactionJson(saved),
        };
      },
    ),
    McpTool(
      name: 'duplicate_transaction',
      writes: true,
      description:
          'Copy an existing transaction into a new one. Any field passed '
          'overrides the copy, so the date or amount can change in the same '
          'call. The original is left untouched.',
      inputSchema: {
        'type': 'object',
        'required': ['transaction_id'],
        'properties': {
          'transaction_id': {
            'type': 'string',
            'description': 'Transaction group ID to copy.',
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
          'transaction': _transactionJson(created),
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
      description: 'Rename a Firefly III account.',
      inputSchema: {
        'type': 'object',
        'required': ['account_id', 'name'],
        'properties': {
          'account_id': {'type': 'string'},
          'name': {'type': 'string'},
        },
      },
      run: (args) async {
        final accountId = args['account_id'] as String?;
        final name = args['name'] as String?;
        if (accountId == null || accountId.isEmpty) {
          return _badInput('account_id is required');
        }
        if (name == null || name.isEmpty) return _badInput('name is required');
        final api = service();
        await api.updateAccount(accountId, name: name);
        return {'ok': true, 'account_id': accountId, 'name': name};
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
      description: 'List recurring transaction rules.',
      inputSchema: const {'type': 'object', 'properties': {}},
      run: (_) async {
        final recurrences = await service().getRecurrences();
        return {
          'ok': true,
          'count': recurrences.length,
          'recurrences': [
            for (final r in recurrences)
              {
                'id': r.id,
                'title': r.title,
                'active': r.active,
                'first_date': _dateOnly(r.firstDate),
                'repeat_until': r.repeatUntil == null
                    ? null
                    : _dateOnly(r.repeatUntil!),
                'nr_of_repetitions': r.nrOfRepetitions,
              },
          ],
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
}
