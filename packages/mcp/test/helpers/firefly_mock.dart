import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const fireflyBaseUrl = 'https://firefly.test';
const fireflyToken = 'test-token';

http.Response jsonHttpResponse(
  Object body, {
  int status = 200,
  Map<String, String>? headers,
}) {
  return http.Response.bytes(
    utf8.encode(body is String ? body : jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
  );
}

Map<String, Object?> primaryCurrencyBody() => {
  'data': {
    'id': '1',
    'type': 'currencies',
    'attributes': {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
  },
};

Map<String, Object?> userBody() => {
  'data': {
    'id': '1',
    'type': 'users',
    'attributes': {'email': 'admin@local.test'},
  },
};

Map<String, Object?> assetAccountsBody({String balance = '2500.00'}) => {
  'data': [
    {
      'id': '5',
      'type': 'accounts',
      'attributes': {
        'name': 'Checking',
        'type': 'asset',
        'account_role': 'defaultAsset',
        'iban': 'SE4100000000001234567890',
        'account_number': '123456789',
        'current_balance': balance,
        'currency_symbol': '€',
        'currency_code': 'EUR',
      },
    },
  ],
  'meta': {
    'pagination': {'total_pages': 1},
  },
};

Map<String, Object?> liabilityAccountsBody() => {
  'data': [
    {
      'id': '6',
      'type': 'accounts',
      'attributes': {
        'name': 'Credit Card',
        'type': 'liabilities',
        'account_role': 'ccAsset',
        'current_balance': '-120.50',
        'currency_symbol': '€',
        'currency_code': 'EUR',
      },
    },
  ],
  'meta': {
    'pagination': {'total_pages': 1},
  },
};

/// Payees: in Firefly an expense account is who you paid.
Map<String, Object?> expenseAccountsBody() => {
  'data': [
    {
      'id': '20',
      'type': 'accounts',
      'attributes': {
        'name': 'BOLANEBANKEN',
        'type': 'expense',
        'current_balance': '0.00',
        'currency_symbol': '\u20ac',
        'currency_code': 'EUR',
      },
    },
  ],
  'meta': {
    'pagination': {'total_pages': 1},
  },
};

/// Payers: a revenue account is who paid you.
Map<String, Object?> revenueAccountsBody() => {
  'data': [
    {
      'id': '30',
      'type': 'accounts',
      'attributes': {
        'name': 'Employer',
        'type': 'revenue',
        'current_balance': '0.00',
        'currency_symbol': '\u20ac',
        'currency_code': 'EUR',
      },
    },
  ],
  'meta': {
    'pagination': {'total_pages': 1},
  },
};

Map<String, Object?> budgetsBody() => {
  'data': [
    {
      'id': '3',
      'type': 'budgets',
      'attributes': {
        'name': 'Food',
        'active': true,
        'spent': [
          {'sum': '-120.00', 'currency_code': 'EUR'},
        ],
        'auto_budget_amount': '400.00',
        'auto_budget_currency_symbol': '€',
        'auto_budget_currency_code': 'EUR',
      },
    },
  ],
};

/// `{'data': {'id': …, 'attributes': {key: name}}}`, the shape Firefly uses for
/// categories (`name`) and tags (`tag`).
Map<String, Object?> namedEnvelope(
  String id,
  String name, {
  String key = 'name',
}) => {
  'data': {
    'id': id,
    'attributes': {key: name},
  },
};

Map<String, Object?> budgetLimitEnvelope({String amount = '400.00'}) => {
  'data': {
    'id': '11',
    'attributes': {
      'budget_id': '3',
      'start': '2026-01-01',
      'end': '2026-01-31',
      'amount': amount,
      'currency_code': 'EUR',
      'currency_symbol': '€',
    },
  },
};

Map<String, Object?> billEnvelope({String name = 'Rent'}) => {
  'data': {
    'id': '9',
    'attributes': {
      'name': name,
      'amount_min': '1200.00',
      'amount_max': '1250.00',
      'amount_avg': '1225.00',
      'currency_code': 'EUR',
      'currency_symbol': '€',
      'date': '2026-03-01',
      'repeat_freq': 'monthly',
      'active': true,
    },
  },
};

Map<String, Object?> piggyEnvelope({String name = 'New Laptop'}) => {
  'data': {
    'id': '4',
    'attributes': {
      'name': name,
      'target_amount': '2500.00',
      'current_amount': '100.00',
      'currency_code': 'EUR',
      'currency_symbol': '€',
      'start_date': '2026-01-01T00:00:00+00:00',
      'accounts': [
        {'account_id': '5', 'name': 'Checking', 'current_amount': '100.00'},
      ],
    },
  },
};

Map<String, Object?> recurrenceEnvelope({String title = 'Salary'}) => {
  'data': {
    'id': '12',
    'attributes': {
      'type': 'withdrawal',
      'title': title,
      'first_date': '2026-09-01',
      'repeat_until': '2027-09-01',
      'active': true,
      'apply_rules': true,
      'repetitions': [
        {'type': 'monthly', 'moment': '1', 'skip': 0, 'weekend': 1},
      ],
      'transactions': [
        {
          'id': '55',
          'description': 'Rent payment',
          'amount': '1200.00',
          'currency_code': 'EUR',
          'currency_symbol': '€',
          'source_id': '5',
          'source_name': 'Joint Current',
          'destination_id': '9',
          'destination_name': 'Landlord',
          'category_name': 'Housing',
          'budget_name': 'Fixed costs',
          'tags': ['standing'],
        },
      ],
    },
  },
};

Map<String, Object?> transactionItem({
  String id = '1',
  String type = 'withdrawal',
  String date = '2026-01-15',
  String amount = '45.00',
  String description = 'Groceries',
  String sourceName = 'Checking',
  String destinationName = 'Store',
  String? sourceId,
  String? destinationId,
  String? budgetName,
  String? billName,
  String? notes,
  List<String> tags = const [],
  bool reconciled = false,
}) => {
  'id': id,
  'type': 'transactions',
  'attributes': {
    'transactions': [
      {
        'type': type,
        'date': date,
        'amount': amount,
        'description': description,
        'source_id': sourceId,
        'source_name': sourceName,
        'destination_id': destinationId,
        'destination_name': destinationName,
        'category_id': '7',
        'category_name': 'Food',
        'budget_id': budgetName == null ? null : '3',
        'budget_name': budgetName,
        'bill_id': billName == null ? null : '4',
        'bill_name': billName,
        'notes': notes,
        'tags': tags,
        'currency_symbol': '€',
        'currency_code': 'EUR',
        'reconciled': reconciled,
      },
    ],
  },
};

Map<String, Object?> transactionsPageBody({
  required List<Map<String, Object?>> items,
  int currentPage = 1,
  int totalPages = 1,
  int total = 1,
}) => {
  'data': items,
  'meta': {
    'pagination': {
      'total': total,
      'count': items.length,
      'per_page': 50,
      'current_page': currentPage,
      'total_pages': totalPages,
    },
  },
};

/// Routes Firefly III API calls for MCP tool tests.
Map<String, Object?> transactionEnvelope(Map<String, Object?> item) => {
  'data': item,
};

MockClient fireflyMockClient({
  bool aboutOk = true,
  bool collidingNames = false,
  bool heavySpending = false,
  Map<String, Map<String, Object?>> transactionOverrides = const {},
  List<Uri>? record,
  List<String>? recordBodies,
}) {
  final transactions = <String, Map<String, Object?>>{
    '1': transactionItem(
      id: '1',
      reconciled: false,
      sourceId: '5',
      destinationId: '9',
      budgetName: 'Housekeeping',
      billName: 'Weekly shop',
      notes: 'bank text: ICA SUPERMARKET',
      tags: ['groceries', 'shared'],
    ),
    '2': transactionItem(
      id: '2',
      type: 'deposit',
      amount: '2000.00',
      description: 'Salary',
      sourceName: 'Employer',
      destinationName: 'Checking',
      reconciled: true,
    ),
    '3': transactionItem(
      id: '3',
      amount: '40.00',
      sourceName: 'Credit Card',
      destinationName: 'Store',
      reconciled: false,
    ),
    if (heavySpending) ...{
      '4': transactionItem(
        id: '4',
        amount: '5000.00',
        date: '2025-01-01',
        description: 'Big spend',
      ),
      '5': transactionItem(
        id: '5',
        amount: '5000.00',
        date: '2025-02-01',
        description: 'Big spend',
      ),
    },
    ...transactionOverrides,
  };

  return MockClient((request) async {
    record?.add(request.url);
    if (request.body.isNotEmpty) recordBodies?.add(request.body);
    final path = request.url.path;
    final method = request.method;

    if (path == '/api/v1/about') {
      return jsonHttpResponse({
        'version': '6.0.0',
      }, status: aboutOk ? 200 : 401);
    }
    if (path == '/api/v1/about/user') {
      return jsonHttpResponse(userBody());
    }
    if (path == '/api/v1/currencies/primary') {
      return jsonHttpResponse(primaryCurrencyBody());
    }
    if (path.startsWith('/api/v1/currencies/') && path.endsWith('/primary')) {
      return http.Response('', 204);
    }
    if (path == '/api/v1/accounts' &&
        collidingNames &&
        request.url.queryParameters['type'] == 'asset') {
      // Two accounts whose folded names share a prefix, so no single candidate
      // can honestly come back exact.
      return jsonHttpResponse({
        'data': [
          for (final row in [
            ('40', 'Sparkonto Alfa'),
            ('41', 'Sparkonto Beta'),
          ])
            {
              'id': row.$1,
              'type': 'accounts',
              'attributes': {
                'name': row.$2,
                'type': 'asset',
                'account_role': 'savingAsset',
                'current_balance': '1.00',
                'currency_symbol': '€',
                'currency_code': 'EUR',
              },
            },
        ],
        'meta': {
          'pagination': {'total_pages': 1},
        },
      });
    }
    if (path == '/api/v1/accounts' &&
        request.url.queryParameters['type'] == 'asset') {
      return jsonHttpResponse(
        assetAccountsBody(balance: heavySpending ? '1000.00' : '2500.00'),
      );
    }
    if (path == '/api/v1/accounts' &&
        request.url.queryParameters['type'] == 'liability') {
      return jsonHttpResponse(liabilityAccountsBody());
    }
    if (path == '/api/v1/accounts' &&
        request.url.queryParameters['type'] == 'expense') {
      return jsonHttpResponse(expenseAccountsBody());
    }
    if (path == '/api/v1/accounts' &&
        request.url.queryParameters['type'] == 'revenue') {
      return jsonHttpResponse(revenueAccountsBody());
    }
    if (path == '/api/v1/budgets' && method != 'POST') {
      return jsonHttpResponse(budgetsBody());
    }
    if (path == '/api/v1/budgets/3/transactions') {
      return jsonHttpResponse(
        transactionsPageBody(items: [transactions['1']!]),
      );
    }
    if (path == '/api/v1/search/transactions') {
      return jsonHttpResponse(
        transactionsPageBody(items: [transactions['1']!]),
      );
    }
    if (path == '/api/v1/chart/balance/balance') {
      return jsonHttpResponse([
        {
          'label': 'Checking',
          'entries': {'2026-01-01': '100', '2026-02-01': '250'},
        },
      ]);
    }
    if (path == '/api/v1/accounts' && method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return jsonHttpResponse({
        'data': {
          'id': 'new-account',
          'attributes': {
            'name': body['name'],
            'type': body['type'],
            'account_role': body['account_role'],
            'liability_type': body['liability_type'],
            'liability_direction': body['liability_direction'],
            'current_balance': '0.00',
            'currency_code': body['currency_code'] ?? 'EUR',
            'currency_symbol': '€',
            'active': true,
          },
        },
      }, status: 201);
    }
    if (path == '/api/v1/budgets' && method == 'POST') {
      final data = budgetsBody()['data']! as List<Object?>;
      return jsonHttpResponse(
        transactionEnvelope(data.first as Map<String, Object?>),
        status: 201,
      );
    }
    if (path == '/api/v1/budgets/3/limits') {
      if (method == 'POST') {
        return jsonHttpResponse(budgetLimitEnvelope(), status: 201);
      }
      return jsonHttpResponse({
        'data': [budgetLimitEnvelope()['data']],
      });
    }
    if (path == '/api/v1/budgets/3/limits/11' && method == 'PUT') {
      return jsonHttpResponse(budgetLimitEnvelope(amount: '450.00'));
    }
    if (path == '/api/v1/categories') {
      if (method == 'POST') {
        return jsonHttpResponse(namedEnvelope('c1', 'Groceries'), status: 201);
      }
      return jsonHttpResponse({
        'data': [namedEnvelope('c1', 'Food')['data']],
      });
    }
    if (path.startsWith('/api/v1/categories/')) {
      if (method == 'DELETE') return http.Response('', 204);
      return jsonHttpResponse(namedEnvelope('c1', 'Renamed'));
    }
    if (path == '/api/v1/tags') {
      if (method == 'POST') {
        return jsonHttpResponse(
          namedEnvelope('t1', 'shared', key: 'tag'),
          status: 201,
        );
      }
      return jsonHttpResponse({
        'data': [namedEnvelope('t1', 'urgent', key: 'tag')['data']],
      });
    }
    if (path.startsWith('/api/v1/tags/')) {
      if (method == 'DELETE') return http.Response('', 204);
      return jsonHttpResponse(namedEnvelope('t1', 'renamed', key: 'tag'));
    }
    if (path == '/api/v1/bills') {
      if (method == 'POST') {
        return jsonHttpResponse(billEnvelope(), status: 201);
      }
      return jsonHttpResponse({
        'data': [billEnvelope()['data']],
      });
    }
    if (path == '/api/v1/bills/9/transactions') {
      return jsonHttpResponse(
        transactionsPageBody(items: [transactions['1']!]),
      );
    }
    if (path.startsWith('/api/v1/bills/')) {
      if (method == 'DELETE') return http.Response('', 204);
      return jsonHttpResponse(billEnvelope(name: 'Rent raised'));
    }
    if (path == '/api/v1/piggy-banks') {
      if (method == 'POST') {
        return jsonHttpResponse(piggyEnvelope(), status: 201);
      }
      return jsonHttpResponse({
        'data': [piggyEnvelope()['data']],
      });
    }
    if (path.startsWith('/api/v1/piggy-banks/')) {
      if (method == 'DELETE') return http.Response('', 204);
      return jsonHttpResponse(piggyEnvelope(name: 'Laptop 2'));
    }
    if (path == '/api/v1/recurrences') {
      if (method == 'POST') {
        return jsonHttpResponse(recurrenceEnvelope(), status: 201);
      }
      return jsonHttpResponse({
        'data': [recurrenceEnvelope()['data']],
      });
    }
    if (path == '/api/v1/recurrences/12/transactions') {
      return jsonHttpResponse(
        transactionsPageBody(items: [transactions['1']!]),
      );
    }
    if (path.startsWith('/api/v1/recurrences/')) {
      if (method == 'DELETE') return http.Response('', 204);
      return jsonHttpResponse(recurrenceEnvelope(title: 'Salary raised'));
    }
    if (path == '/api/v1/currencies') {
      return jsonHttpResponse({
        'data': [
          {
            'id': '1',
            'attributes': {
              'code': 'EUR',
              'name': 'Euro',
              'symbol': '€',
              'enabled': true,
              'primary': true,
            },
          },
        ],
      });
    }
    // Single account, used by get_account and get_account_balance_at_date.
    if (path.startsWith('/api/v1/accounts/') &&
        !path.endsWith('/transactions') &&
        method == 'GET') {
      final accountId = path.split('/')[4];
      final body = assetAccountsBody();
      final match = (body['data'] as List)
          .cast<Map<String, Object?>>()
          .where((item) => item['id'] == accountId)
          .toList();
      if (match.isEmpty) {
        return jsonHttpResponse({'message': 'Not found'}, status: 404);
      }
      return jsonHttpResponse({'data': match.first});
    }
    if (path.startsWith('/api/v1/accounts/') &&
        path.endsWith('/transactions')) {
      final accountId = path.split('/')[4];
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      final items = transactions.values
          .where(
            (item) =>
                (item['attributes'] as Map)['transactions'][0]['source_name'] ==
                    (accountId == '5' ? 'Checking' : 'Credit Card') ||
                (item['attributes']
                        as Map)['transactions'][0]['destination_name'] ==
                    (accountId == '5' ? 'Checking' : 'Credit Card'),
          )
          .toList();
      if (items.isEmpty) {
        items.addAll(transactions.values.take(2));
      }
      return jsonHttpResponse(
        transactionsPageBody(
          items: items,
          currentPage: page,
          totalPages: 2,
          total: items.length * 2,
        ),
      );
    }
    if (path == '/api/v1/transactions') {
      if (method == 'POST') {
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        final txType =
            (decoded['transactions'] as List?)?.first?['type'] as String? ??
            'reconciliation';
        final created = transactionItem(id: 'created-1', type: txType);
        return jsonHttpResponse(transactionEnvelope(created), status: 201);
      }
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      final all = transactions.values.toList();
      return jsonHttpResponse(
        transactionsPageBody(
          items: all,
          currentPage: page,
          totalPages: page > 1 ? 2 : 1,
          total: all.length,
        ),
      );
    }
    if (path.startsWith('/api/v1/transactions/')) {
      final id = path.split('/').last;
      if (method == 'GET') {
        final body = transactions[id];
        if (body == null) {
          return jsonHttpResponse({'message': 'not found'}, status: 404);
        }
        return jsonHttpResponse(transactionEnvelope(body));
      }
      if (method == 'PUT') {
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        final txList = decoded['transactions'] as List?;
        final reconciled =
            txList != null &&
            txList.isNotEmpty &&
            txList.first['reconciled'] == true;
        final updated = transactionItem(id: id, reconciled: reconciled);
        transactions[id] = updated;
        return jsonHttpResponse(transactionEnvelope(updated));
      }
      if (method == 'DELETE') {
        return http.Response('', 204);
      }
    }
    if (path.startsWith('/api/v1/accounts/') && method == 'DELETE') {
      return http.Response('', 204);
    }
    if (path.startsWith('/api/v1/accounts/') && method == 'PUT') {
      final data = assetAccountsBody()['data']! as List<Object?>;
      return jsonHttpResponse(
        transactionEnvelope(data.first as Map<String, Object?>),
      );
    }
    if (path.startsWith('/api/v1/budgets/') && method == 'PUT') {
      final data = budgetsBody()['data']! as List<Object?>;
      return jsonHttpResponse(
        transactionEnvelope(data.first as Map<String, Object?>),
      );
    }
    if (path.startsWith('/api/v1/budgets/') && method == 'DELETE') {
      return http.Response('', 204);
    }

    return jsonHttpResponse({
      'message': 'unhandled ${request.method} $path',
    }, status: 404);
  });
}
