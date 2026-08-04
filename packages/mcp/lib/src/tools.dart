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
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final Future<Map<String, Object?>> Function(Map<String, Object?> args) run;
}

const _mcpVersion = '1.0.0';

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
  'date': transaction.date.toIso8601String(),
  'amount': transaction.totalAmount,
  'description': transaction.description,
  'source_name': transaction.sourceName,
  'destination_name': transaction.destinationName,
  'category_name': transaction.categoryName,
  'currency_symbol': transaction.currencySymbol,
  'currency_code': transaction.currencyCode,
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

FireflyService? _serviceFromArgs(
  Map<String, Object?> args, {
  http.Client? client,
}) {
  final url = args['firefly_url'] as String?;
  final token = args['firefly_token'] as String?;
  if (url == null || url.isEmpty || token == null || token.isEmpty) {
    return null;
  }
  return FireflyApiService(serverUrl: url, apiToken: token, client: client);
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

/// Builds the FireRacoon MCP tool catalog.
///
/// [defaultUrl] and [defaultToken] are injected when tools omit per-call
/// credentials (stdio binary reads env; the desktop app passes saved auth).
List<McpTool> buildTools({
  String? defaultUrl,
  String? defaultToken,
  http.Client? httpClient,
}) {
  FireflyService service(Map<String, Object?> args) {
    final fromArgs = _serviceFromArgs(args, client: httpClient);
    if (fromArgs != null) return fromArgs;
    if (defaultUrl != null &&
        defaultUrl.isNotEmpty &&
        defaultToken != null &&
        defaultToken.isNotEmpty) {
      return FireflyApiService(
        serverUrl: defaultUrl,
        apiToken: defaultToken,
        client: httpClient,
      );
    }
    throw StateError(
      'Firefly credentials required: set FIREFLY_URL and FIREFLY_TOKEN '
      'or pass firefly_url and firefly_token in tool arguments.',
    );
  }

  Future<bool> checkAbout(String url, String token) async {
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final client = httpClient ?? http.Client();
    try {
      final response = await client.get(
        Uri.parse('$base/api/v1/about'),
        headers: {
          'Authorization': 'Bearer $token',
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
          'set_transaction_reconciled',
          'store_reconciliation',
          'get_budgets',
          'get_budget_transactions',
          'update_account',
          'update_budget',
          'delete_budget',
          'run_projection',
          'get_dashboard_kpis',
          'get_capabilities',
        ],
        'auth': {
          'env': ['FIREFLY_URL', 'FIREFLY_TOKEN'],
          'per_call': ['firefly_url', 'firefly_token'],
        },
      },
    ),
    McpTool(
      name: 'check_connection',
      description:
          'Verify connectivity and credentials against the Firefly III /api/v1/about endpoint.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'firefly_url': {
            'type': 'string',
            'description': 'Firefly III base URL (overrides env FIREFLY_URL).',
          },
          'firefly_token': {
            'type': 'string',
            'description':
                'Personal access token (overrides env FIREFLY_TOKEN).',
          },
        },
      },
      run: (args) async {
        final url = (args['firefly_url'] as String?) ?? defaultUrl;
        final token = (args['firefly_token'] as String?) ?? defaultToken;
        if (url == null || url.isEmpty || token == null || token.isEmpty) {
          return _badInput('firefly_url and firefly_token are required');
        }
        final connected = await checkAbout(url, token);
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
      inputSchema: _credentialsSchema(),
      run: (args) async {
        final api = service(args);
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
      inputSchema: _credentialsSchema(),
      run: (args) async {
        final api = service(args);
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
      description: 'Set the primary currency in Firefly III.',
      inputSchema: {
        'type': 'object',
        'required': ['code'],
        'properties': {
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
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
        final api = service(args);
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
      description: 'List all Firefly III accounts with balances.',
      inputSchema: _credentialsSchema(),
      run: (args) async {
        final api = service(args);
        final accounts = await api.getAccounts();
        return {
          'ok': true,
          'count': accounts.length,
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
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
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
        final api = service(args);
        final accountId = args['account_id'] as String?;
        final page = (args['page'] as num?)?.toInt() ?? 1;
        final limit = (args['limit'] as num?)?.toInt() ?? 50;
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
              ? await api.getAccountTransactions(accountId)
              : await api.getTransactions();
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

        if (page > 1 || (args['limit'] != null)) {
          final pageResult = await api.getTransactionsPage(
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

        final transactions = await api.getTransactions();
        return {
          'ok': true,
          'count': transactions.length,
          'transactions': transactions.map(_transactionJson).toList(),
        };
      },
    ),
    McpTool(
      name: 'get_transaction',
      description: 'Fetch a single Firefly III transaction by journal ID.',
      inputSchema: {
        'type': 'object',
        'required': ['transaction_id'],
        'properties': {
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
          'transaction_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final transactionId = args['transaction_id'] as String?;
        if (transactionId == null || transactionId.isEmpty) {
          return _badInput('transaction_id is required');
        }
        final api = service(args);
        final transaction = await api.getTransaction(transactionId);
        return {'ok': true, 'transaction': _transactionJson(transaction)};
      },
    ),
    McpTool(
      name: 'set_transaction_reconciled',
      description:
          'Mark a transaction as reconciled or unreconciled after verifying it against a bank statement.',
      inputSchema: {
        'type': 'object',
        'required': ['transaction_id', 'reconciled'],
        'properties': {
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
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
        final api = service(args);
        final current = await api.getTransaction(transactionId);
        final updated = await api.updateTransaction(
          current.withReconciled(reconciled),
        );
        return {'ok': true, 'transaction': _transactionJson(updated)};
      },
    ),
    McpTool(
      name: 'store_reconciliation',
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
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
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

        final api = service(args);
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
      name: 'get_budgets',
      description: 'List all Firefly III budgets with spent amounts.',
      inputSchema: _credentialsSchema(),
      run: (args) async {
        final api = service(args);
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
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
          'budget_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final budgetId = args['budget_id'] as String?;
        if (budgetId == null || budgetId.isEmpty) {
          return _badInput('budget_id is required');
        }
        final api = service(args);
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
      description: 'Rename a Firefly III account.',
      inputSchema: {
        'type': 'object',
        'required': ['account_id', 'name'],
        'properties': {
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
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
        final api = service(args);
        await api.updateAccount(accountId, name: name);
        return {'ok': true, 'account_id': accountId, 'name': name};
      },
    ),
    McpTool(
      name: 'update_budget',
      description:
          'Update a budget name, active flag, notes, and auto-budget settings.',
      inputSchema: {
        'type': 'object',
        'required': ['budget_id', 'name'],
        'properties': {
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
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
        final amount = (args['amount'] as num?)?.toDouble();
        final autoBudgetType = AutoBudgetType.parse(
          args['auto_budget_type'] as String?,
        );
        final input = BudgetInput(
          name: name,
          active: args['active'] as bool? ?? true,
          notes: args['notes'] as String?,
          autoBudgetType: amount != null && amount > 0
              ? autoBudgetType == AutoBudgetType.none
                    ? AutoBudgetType.reset
                    : autoBudgetType
              : AutoBudgetType.none,
          autoBudgetAmount: amount,
          autoBudgetPeriod: AutoBudgetPeriod.parse(
            args['auto_budget_period'] as String?,
          ),
          currencyCode: args['currency_code'] as String? ?? 'EUR',
        );
        final api = service(args);
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
      description: 'Delete a Firefly III budget by ID.',
      inputSchema: {
        'type': 'object',
        'required': ['budget_id'],
        'properties': {
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
          'budget_id': {'type': 'string'},
        },
      },
      run: (args) async {
        final budgetId = args['budget_id'] as String?;
        if (budgetId == null || budgetId.isEmpty) {
          return _badInput('budget_id is required');
        }
        final api = service(args);
        await api.deleteBudget(budgetId);
        return {'ok': true, 'budget_id': budgetId, 'deleted': true};
      },
    ),
    McpTool(
      name: 'run_projection',
      description:
          'Run an on-device financial projection (savings, compound, portfolio, or cashflow).',
      inputSchema: {
        'type': 'object',
        'properties': {
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
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
        final api = service(args);
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
          ..._credentialsSchema()['properties'] as Map<String, Object?>,
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
        final api = service(args);
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

Map<String, Object?> _credentialsSchema() => {
  'type': 'object',
  'properties': {
    'firefly_url': {
      'type': 'string',
      'description': 'Firefly III base URL (overrides env FIREFLY_URL).',
    },
    'firefly_token': {
      'type': 'string',
      'description': 'Personal access token (overrides env FIREFLY_TOKEN).',
    },
  },
};
