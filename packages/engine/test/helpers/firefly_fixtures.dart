import 'dart:convert';

String jsonResponse(Map<String, Object?> body) => jsonEncode(body);

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

Map<String, Object?> accountsBody() => {
  'data': [
    {
      'id': '5',
      'type': 'accounts',
      'attributes': {
        'name': 'Checking',
        'type': 'asset',
        'account_role': 'defaultAsset',
        'current_balance': '2500.00',
        'currency_symbol': '€',
        'currency_code': 'EUR',
      },
    },
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
        'source_name': 'Checking',
        'destination_name': 'Store',
        'category_name': 'Food',
        'currency_symbol': '€',
        'currency_code': 'EUR',
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
