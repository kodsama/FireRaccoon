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

Map<String, Object?> transactionItem({
  String id = '1',
  String type = 'withdrawal',
  String date = '2026-01-15',
  String amount = '45.00',
  String description = 'Groceries',
  String sourceName = 'Checking',
  String destinationName = 'Store',
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
        'source_name': sourceName,
        'destination_name': destinationName,
        'category_name': 'Food',
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
  bool heavySpending = false,
  Map<String, Map<String, Object?>> transactionOverrides = const {},
}) {
  final transactions = <String, Map<String, Object?>>{
    '1': transactionItem(id: '1', reconciled: false),
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
        request.url.queryParameters['type'] == 'asset') {
      return jsonHttpResponse(
        assetAccountsBody(balance: heavySpending ? '1000.00' : '2500.00'),
      );
    }
    if (path == '/api/v1/accounts' &&
        request.url.queryParameters['type'] == 'liability') {
      return jsonHttpResponse(liabilityAccountsBody());
    }
    if (path == '/api/v1/budgets') {
      return jsonHttpResponse(budgetsBody());
    }
    if (path == '/api/v1/budgets/3/transactions') {
      return jsonHttpResponse(
        transactionsPageBody(items: [transactions['1']!]),
      );
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
