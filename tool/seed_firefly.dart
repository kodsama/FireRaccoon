// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Seeds a local Firefly III with sample data.
///
/// Requires env vars (or a local `.env` loaded by your shell):
///   FIREFLY_URL   — e.g. http://localhost:8081
///   FIREFLY_TOKEN — personal access token
final baseUrl = '${(Platform.environment['FIREFLY_URL'] ?? 'http://localhost:8081').replaceAll(RegExp(r'/+$'), '')}/api/v1';
final token = Platform.environment['FIREFLY_TOKEN'] ?? '';

Map<String, String> get headers {
  if (token.isEmpty) {
    throw StateError(
      'FIREFLY_TOKEN is not set. Export it or copy .env.example to .env.',
    );
  }
  return {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}

Future<dynamic> post(String path, Map<String, dynamic> body) async {
  final res = await http.post(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body));
  return jsonDecode(res.body);
}

Future<dynamic> get(String path) async {
  final res = await http.get(Uri.parse('$baseUrl$path'), headers: headers);
  return jsonDecode(res.body);
}

Future<String> createCurrency(String name, String code, String symbol) async {
  await post('/currencies', {
    'name': name, 'code': code, 'symbol': symbol, 'decimal_places': 2, 'enabled': true
  });
  return "ok";
}

Future<String> createBudget(String name) async {
  final res = await http.post(Uri.parse('$baseUrl/budgets'), headers: headers, body: jsonEncode({'name': name}));
  if (res.statusCode != 200 && res.statusCode != 201) {
    final search = await get('/budgets');
    final match = (search['data'] as List).firstWhere((e) => e['attributes']['name'] == name, orElse: () => null);
    if (match != null) return match['id'].toString();
    return '';
  }
  return jsonDecode(res.body)['data']['id'].toString();
}

Future<void> createBudgetLimit(String budgetId, String start, String end, String amount) async {
  await post('/budgets/$budgetId/limits', {
    'start': start, 'end': end, 'amount': amount
  });
}

Future<String> createCategory(String name) async {
  final res = await http.post(Uri.parse('$baseUrl/categories'), headers: headers, body: jsonEncode({'name': name}));
  if (res.statusCode != 200 && res.statusCode != 201) {
    final search = await get('/categories');
    final match = (search['data'] as List).firstWhere((e) => e['attributes']['name'] == name, orElse: () => null);
    if (match != null) return match['id'].toString();
    return '';
  }
  return jsonDecode(res.body)['data']['id'].toString();
}

Future<String> createTag(String name) async {
  final res = await http.post(Uri.parse('$baseUrl/tags'), headers: headers, body: jsonEncode({'tag': name}));
  if (res.statusCode != 200 && res.statusCode != 201) {
    final search = await get('/tags');
    final match = (search['data'] as List).firstWhere((e) => e['attributes']['tag'] == name, orElse: () => null);
    if (match != null) return match['id'].toString();
    return '';
  }
  return jsonDecode(res.body)['data']['id'].toString();
}

Future<String> createBill(String name, String amountMin, String amountMax, String date) async {
  final res = await http.post(Uri.parse('$baseUrl/bills'), headers: headers, body: jsonEncode({
    'name': name,
    'amount_min': amountMin,
    'amount_max': amountMax,
    'date': date,
    'repeat_freq': 'monthly',
  }));
  if (res.statusCode != 200 && res.statusCode != 201) {
    final search = await get('/bills');
    final match = (search['data'] as List).firstWhere((e) => e['attributes']['name'] == name, orElse: () => null);
    if (match != null) return match['id'].toString();
    return '';
  }
  return jsonDecode(res.body)['data']['id'].toString();
}

Future<String> createPiggyBank(String name, String targetAmount, String accountId) async {
  final res = await http.post(Uri.parse('$baseUrl/piggy-banks'), headers: headers, body: jsonEncode({
    'name': name,
    'accounts': [{'account_id': accountId}],
    'target_amount': targetAmount,
    'start_date': '2021-01-01',
    'transaction_currency_code': 'USD',
  }));
  if (res.statusCode != 200 && res.statusCode != 201) {
    print('Piggy Bank creation failed: ${res.statusCode} ${res.body}');
    final search = await get('/piggy-banks');
    if (search['data'] == null) return '';
    final match = (search['data'] as List).firstWhere((e) => e['attributes']['name'] == name, orElse: () => null);
    if (match != null) return match['id'].toString();
    return '';
  }
  return jsonDecode(res.body)['data']['id'].toString();
}

Future<void> addPiggyBankEvent(String id, String amount) async {
  await post('/piggy-banks/$id/add', {'amount': amount});
}

Future<String> createRuleGroup(String title) async {
  final res = await http.post(Uri.parse('$baseUrl/rule-groups'), headers: headers, body: jsonEncode({'title': title}));
  if (res.statusCode != 200 && res.statusCode != 201) {
    final search = await get('/rule-groups');
    final match = (search['data'] as List).firstWhere((e) => e['attributes']['title'] == title, orElse: () => null);
    if (match != null) return match['id'].toString();
    return '';
  }
  return jsonDecode(res.body)['data']['id'].toString();
}

Future<void> createRule(String groupId, String title, String triggerValue, String actionValue) async {
  await post('/rules', {
    'title': title,
    'rule_group_id': groupId,
    'trigger': 'store-journal',
    'triggers': [
      { 'type': 'description_contains', 'value': triggerValue, 'active': true }
    ],
    'actions': [
      { 'type': 'add_tag', 'value': actionValue, 'active': true }
    ]
  });
}

Future<String> createAccount(String name, String type, String? initialBalance, String currencyCode, [String liabilityType = '']) async {
  final body = {
    'name': name,
    'type': type,
    'currency_code': currencyCode,
  };
  if (type == 'liability') {
    body['liability_type'] = liabilityType.isNotEmpty ? liabilityType : 'debt';
    body['liability_direction'] = 'credit';
  }
  if (initialBalance != null && type == 'asset') {
    body['initial_balance'] = initialBalance;
    body['initial_balance_date'] = DateTime.now().subtract(Duration(days: 2000)).toIso8601String().split('T')[0];
    body['account_role'] = 'defaultAsset';
  }
  
  final res = await http.post(Uri.parse('$baseUrl/accounts'), headers: headers, body: jsonEncode(body));
  if (res.statusCode != 200 && res.statusCode != 201) {
    final search = await get('/accounts?type=$type');
    final match = (search['data'] as List).firstWhere((e) => e['attributes']['name'] == name, orElse: () => null);
    if (match != null) return match['id'].toString();
    return '';
  }
  return jsonDecode(res.body)['data']['id'].toString();
}

Future<void> createTransaction({
  required String sourceId, required String sourceName, required String destId, required String destName, 
  required String description, required String amount, required String type, required String dateStr, 
  required String currencyCode, String? budgetId, String? categoryId, List<String>? tags, String? billId
}) async {
  final Map<String, dynamic> tx = {
    'type': type,
    'date': dateStr,
    'amount': amount,
    'description': description,
    'source_id': sourceId,
    'source_name': sourceName,
    'destination_id': destId,
    'destination_name': destName,
    'currency_code': currencyCode,
  };
  if (budgetId != null && budgetId.isNotEmpty) tx['budget_id'] = budgetId;
  if (categoryId != null && categoryId.isNotEmpty) tx['category_id'] = categoryId;
  if (tags != null && tags.isNotEmpty) tx['tags'] = tags;
  if (billId != null && billId.isNotEmpty) tx['bill_id'] = billId;
  
  await http.post(Uri.parse('$baseUrl/transactions'), headers: headers, body: jsonEncode({'transactions': [tx]}));
}

Future<void> main() async {
  print('Creating Categories & Tags...');
  final catFood = await createCategory('Groceries');
  final catHousing = await createCategory('Housing');
  final catEntertainment = await createCategory('Entertainment');
  final catTransport = await createCategory('Transport');
  final catIncome = await createCategory('Income');
  
  await createTag('vacation');
  final tagCoffee = await createTag('coffee');
  final tagShared = await createTag('shared-expense');
  
  print('Creating Budgets...');
  final foodBudget = await createBudget('Food & Dining');
  final housingBudget = await createBudget('Housing');
  final funBudget = await createBudget('Entertainment');

  print('Creating Accounts & Liabilities...');
  final checking = await createAccount('FireRacoon Checking', 'asset', '50000.00', 'USD');
  final savings = await createAccount('FireRacoon Savings', 'asset', '150000.00', 'USD');
  final creditCard = await createAccount('FireRacoon Credit Card', 'liability', null, 'USD', 'credit');
  final carLoan = await createAccount('FireRacoon Car Loan', 'liability', null, 'USD', 'loan');
  
  final salary = await createAccount('FireRacoon Employer', 'revenue', null, 'USD');

  final groceries = await createAccount('FireRacoon Supermarket', 'expense', null, 'USD');
  final rent = await createAccount('FireRacoon Landlord', 'expense', null, 'USD');
  final internet = await createAccount('FireRacoon ISP', 'expense', null, 'USD');
  final restaurants = await createAccount('FireRacoon Restaurants', 'expense', null, 'USD');
  final gasStation = await createAccount('FireRacoon Fuel', 'expense', null, 'USD');

  print('Creating Bills/Subscriptions...');
  final rentBill = await createBill('Monthly Rent', '1200', '1200', '2021-01-03');
  final netflixBill = await createBill('Netflix', '15', '20', '2021-01-15');

  print('Creating Piggy Banks...');
  final laptopPiggy = await createPiggyBank('New Laptop', '2500.00', savings);

  print('Creating Automations/Rules...');
  final ruleGroup = await createRuleGroup('Auto-Tagging');
  await createRule(ruleGroup, 'Tag Starbucks as Coffee', 'Starbucks', tagCoffee);

  print('Creating Years of Fake Transactions...');
  final random = Random();
  int transactionsCreated = 0;

  for (int year = 2021; year <= 2026; year++) {
    int maxMonth = (year == 2026) ? 7 : 12;
    for (int month = 1; month <= maxMonth; month++) {
      final monthStr = month.toString().padLeft(2, '0');
      final daysInMonth = DateTime(year, month + 1, 0).day;
      String dateStr(int day) => '$year-$monthStr-${day.toString().padLeft(2, '0')}';
      String endOfMonth = dateStr(daysInMonth);
      
      // Budget limits for the month
      await createBudgetLimit(foodBudget, dateStr(1), endOfMonth, '600.00');
      await createBudgetLimit(housingBudget, dateStr(1), endOfMonth, '1500.00');
      await createBudgetLimit(funBudget, dateStr(1), endOfMonth, '400.00');

      // Salary
      final salaryAmount = 4000 + random.nextInt(1000);
      await createTransaction(sourceId: salary, sourceName: 'FireRacoon Employer', destId: checking, destName: 'FireRacoon Checking', description: 'Salary', amount: '$salaryAmount.00', type: 'deposit', dateStr: dateStr(1), currencyCode: 'USD', categoryId: catIncome);
      transactionsCreated++;
      
      // Rent
      await createTransaction(sourceId: checking, sourceName: 'FireRacoon Checking', destId: rent, destName: 'FireRacoon Landlord', description: 'Rent', amount: '1200.00', type: 'withdrawal', dateStr: dateStr(3), currencyCode: 'USD', budgetId: housingBudget, categoryId: catHousing, billId: rentBill, tags: [tagShared]);
      transactionsCreated++;

      // Netflix
      await createTransaction(sourceId: creditCard, sourceName: 'FireRacoon Credit Card', destId: internet, destName: 'Netflix', description: 'Netflix Subscription', amount: '15.99', type: 'withdrawal', dateStr: dateStr(15), currencyCode: 'USD', budgetId: funBudget, categoryId: catEntertainment, billId: netflixBill);
      transactionsCreated++;

      // Batch 90 random transactions to prevent 500s or making it too slow
      List<Future> txFutures = [];
      for (int i = 0; i < 90; i++) {
        final day = 1 + random.nextInt(daysInMonth - 1);
        final r = random.nextInt(100);
        
        if (r < 30) {
          final amt = 10 + random.nextInt(90);
          txFutures.add(createTransaction(sourceId: creditCard, sourceName: 'FireRacoon Credit Card', destId: groceries, destName: 'FireRacoon Supermarket', description: 'Groceries', amount: '$amt.00', type: 'withdrawal', dateStr: dateStr(day), currencyCode: 'USD', budgetId: foodBudget, categoryId: catFood));
        } else if (r < 60) {
          final amt = 15 + random.nextInt(60);
          txFutures.add(createTransaction(sourceId: creditCard, sourceName: 'FireRacoon Credit Card', destId: restaurants, destName: 'FireRacoon Restaurants', description: 'Dining Out', amount: '$amt.00', type: 'withdrawal', dateStr: dateStr(day), currencyCode: 'USD', budgetId: funBudget, categoryId: catEntertainment, tags: (random.nextBool() ? [tagShared] : null)));
        } else if (r < 80) {
          final amt = 30 + random.nextInt(40);
          txFutures.add(createTransaction(sourceId: creditCard, sourceName: 'FireRacoon Credit Card', destId: gasStation, destName: 'FireRacoon Fuel', description: 'Gas', amount: '$amt.00', type: 'withdrawal', dateStr: dateStr(day), currencyCode: 'USD', categoryId: catTransport));
        } else if (r < 90) {
          final amt = 4 + random.nextInt(6);
          txFutures.add(createTransaction(sourceId: creditCard, sourceName: 'FireRacoon Credit Card', destId: restaurants, destName: 'Starbucks', description: 'Starbucks Coffee', amount: '$amt.00', type: 'withdrawal', dateStr: dateStr(day), currencyCode: 'USD', budgetId: funBudget, categoryId: catEntertainment, tags: [tagCoffee]));
        } else {
          final amt = 5 + random.nextInt(20);
          txFutures.add(createTransaction(sourceId: checking, sourceName: 'FireRacoon Checking', destId: restaurants, destName: 'Local Shop', description: 'Misc', amount: '$amt.00', type: 'withdrawal', dateStr: dateStr(day), currencyCode: 'USD'));
        }
        transactionsCreated++;
      }
      
      // Execute in chunks
      for (int i = 0; i < txFutures.length; i += 10) {
        final end = (i + 10 < txFutures.length) ? i + 10 : txFutures.length;
        await Future.wait(txFutures.sublist(i, end));
      }
      
      // Transfer to Savings
      final saveAmt = 200 + random.nextInt(300);
      await createTransaction(sourceId: checking, sourceName: 'FireRacoon Checking', destId: savings, destName: 'FireRacoon Savings', description: 'Monthly Transfer', amount: '$saveAmt.00', type: 'transfer', dateStr: dateStr(28), currencyCode: 'USD');
      transactionsCreated++;
      
      // Piggy Bank add
      if (random.nextInt(100) < 50) {
        await addPiggyBankEvent(laptopPiggy, '100.00');
      }

      // Credit card payoff
      final ccPayoff = 500 + random.nextInt(500);
      await createTransaction(sourceId: checking, sourceName: 'FireRacoon Checking', destId: creditCard, destName: 'FireRacoon Credit Card', description: 'Credit Card Payment', amount: '$ccPayoff.00', type: 'transfer', dateStr: dateStr(25), currencyCode: 'USD');
      transactionsCreated++;

      // Car Loan Payment
      await createTransaction(sourceId: checking, sourceName: 'FireRacoon Checking', destId: carLoan, destName: 'FireRacoon Car Loan', description: 'Car Loan Installment', amount: '350.00', type: 'transfer', dateStr: dateStr(12), currencyCode: 'USD');
      transactionsCreated++;
      
      print('Processed $year-$monthStr');
    }
  }

  print('Seed complete! Created $transactionsCreated transactions.');
}
