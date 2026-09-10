import 'dart:convert';

import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers/firefly_mock.dart';

const _target = FireflyTarget(baseUrl: fireflyBaseUrl, bearer: fireflyToken);

McpTool _tool(String name, MockClient client) => buildTools(
  target: _target,
  httpClient: client,
).firstWhere((tool) => tool.name == name);

/// Captures the write body while answering the reads a tool makes first.
class _Recorder {
  Map<String, Object?>? body;

  MockClient client({
    required Map<String, Object?> Function() onWrite,
    Map<String, Object?>? transaction,
    Map<String, Object?>? budgets,
  }) {
    return MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path == '/api/v1/transactions/1') {
        return jsonHttpResponse(transactionEnvelope(transaction!));
      }
      if (request.method == 'GET' && path == '/api/v1/budgets') {
        return jsonHttpResponse(budgets!);
      }
      if (request.method == 'GET' && path == '/api/v1/currencies') {
        return jsonHttpResponse({
          'data': [
            {
              'id': '17',
              'type': 'currencies',
              'attributes': {
                'code': 'SEK',
                'name': 'Swedish krona',
                'symbol': 'kr',
                'enabled': true,
              },
            },
          ],
        });
      }
      if (request.method == 'PUT' || request.method == 'POST') {
        body = jsonDecode(request.body) as Map<String, Object?>;
        return jsonHttpResponse(onWrite());
      }
      return http.Response('unexpected ${request.method} $path', 500);
    });
  }
}

Map<String, Object?> _leg(Map<String, Object?> body) =>
    ((body['transactions'] as List).first) as Map<String, Object?>;

void main() {
  group('a category named on an update', () {
    test('replaces the id it is meant to replace', () async {
      // The base carries category_id 7 / "Food". Firefly resolves an id in
      // preference to a name, so sending the new name beside the old id left
      // the category exactly where it was and answered 200.
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'category_name': 'Lottery'});

      final leg = _leg(recorder.body!);
      expect(leg['category_name'], 'Lottery');
      expect(
        leg.containsKey('category_id'),
        isFalse,
        reason: 'the stale id would win and discard the name',
      );
    });

    test('leaves an id the caller stated in place', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'category_id': '9',
        'category_name': 'Lottery',
      });

      expect(_leg(recorder.body!)['category_id'], '9');
    });
  });

  group('a write that did not take', () {
    test('is reported rather than echoed back as a success', () async {
      // What thirteen reconciled split rows did: accepted, unchanged, ok.
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(reconciled: true),
        onWrite: () => transactionEnvelope(transactionItem(reconciled: true)),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'category_name': 'Lottery'});

      expect(result['ok'], isFalse);
      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('category_name'));
      // The stored state travels with the refusal, so nobody has to re-read it.
      expect(result['transaction'], isNotNull);
    });

    test('is a success when the field did land', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(),
        onWrite: () =>
            transactionEnvelope(_withCategory(transactionItem(), 'Lottery')),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'category_name': 'Lottery'});

      expect(result['ok'], isTrue);
      expect(result.containsKey('code'), isFalse);
    });
  });

  group('every field a write can quietly drop is reported', () {
    test('an amount that did not move', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(amount: '45.00'),
        onWrite: () => transactionEnvelope(transactionItem(amount: '45.00')),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'amount': 60.0});

      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('amount'));
    });

    test('a reconciliation that did not take', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'reconciled': true});

      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('reconciled'));
    });

    test('a date the server put somewhere else', () async {
      // The day is compared as a calendar date, so this is the check that
      // would have caught sixty rows landing twenty-four hours early.
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(date: '2026-09-02'),
        onWrite: () => transactionEnvelope(transactionItem(date: '2026-09-01')),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'date': '2026-09-02'});

      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('date'));
    });
  });

  group('dates', () {
    test('an update that never mentions the date keeps the day', () async {
      // Bug and fix in one: the day came back off the wire, went out again as
      // midnight plus an offset, and Firefly stored the day before. An edit to
      // the description alone was enough to move it.
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(date: '2026-09-02T00:00:00+02:00'),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'description': 'Groceries, renamed'});

      // Exactly what came off the wire, offset and all dropped, so the day
      // and the time of day are both what Firefly already had.
      expect(_leg(recorder.body!)['date'], '2026-09-02T00:00:00.000');
    });

    test('a bare calendar date is created on that day', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool('create_transaction', client).run({
        'type': 'withdrawal',
        'date': '2026-09-02',
        'amount': 12.5,
        'description': 'Coffee',
        'source_name': 'Checking',
        'destination_name': 'Cafe',
      });

      expect(_leg(recorder.body!)['date'], '2026-09-02T00:00:00.000');
    });
  });

  group('update_budget', () {
    test('reports a currency Firefly accepted and dropped', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        budgets: budgetsBody(),
        onWrite: () => {
          'data': {
            'id': '3',
            'attributes': {
              'name': 'Food',
              'active': true,
              'auto_budget_amount': '3000.00',
              'auto_budget_type': 'reset',
              'auto_budget_period': 'monthly',
              // Unmoved, which is the whole complaint.
              'auto_budget_currency_code': 'EUR',
              'auto_budget_currency_symbol': '€',
            },
          },
        },
      );

      final result = await _tool('update_budget', client).run({
        'budget_id': '3',
        'name': 'Food',
        'amount': 3000,
        'currency_code': 'SEK',
      });

      // The id is the field Firefly reads, so it has to be on the wire.
      expect(recorder.body!['auto_budget_currency_id'], '17');
      expect(result['ok'], isFalse);
      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('currency_code'));
    });

    test('refuses a currency code no enabled currency carries', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        budgets: budgetsBody(),
        onWrite: () => throw StateError('must not reach the server'),
      );

      final result = await _tool(
        'update_budget',
        client,
      ).run({'budget_id': '3', 'name': 'Food', 'currency_code': 'XYZ'});

      expect(result['code'], 'bad_input');
      expect('${result['error']}', contains('XYZ'));
      expect(recorder.body, isNull);
    });

    test('reports an amount and a period that did not stick', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        budgets: budgetsBody(),
        onWrite: () => {
          'data': {
            'id': '3',
            'attributes': {
              'name': 'Food',
              'active': true,
              // Both unmoved.
              'auto_budget_amount': '400.00',
              'auto_budget_type': 'reset',
              'auto_budget_period': 'monthly',
              'auto_budget_currency_code': 'EUR',
            },
          },
        },
      );

      final result = await _tool('update_budget', client).run({
        'budget_id': '3',
        'name': 'Food',
        'amount': 7500,
        'auto_budget_period': 'yearly',
      });

      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('amount'));
      expect('${result['error']}', contains('auto_budget_period'));
    });

    test('refuses to pretend it cleared an auto-budget', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        budgets: _budgetWithAutoBudget(),
        onWrite: () => throw StateError('must not reach the server'),
      );

      final result = await _tool('update_budget', client).run({
        'budget_id': '3',
        'name': 'Food',
        'amount': 0,
        'auto_budget_type': 'none',
      });

      expect(result['ok'], isFalse);
      expect(result['code'], 'not_supported');
      expect('${result['error']}', contains('cannot clear an auto-budget'));
      expect(recorder.body, isNull);
    });
  });
}

/// The same item with a different category, for a server that took the change.
Map<String, Object?> _withCategory(Map<String, Object?> item, String name) {
  final attrs = item['attributes'] as Map<String, Object?>;
  final legs = attrs['transactions'] as List;
  final leg = {...(legs.first as Map<String, Object?>)};
  leg['category_name'] = name;
  leg['category_id'] = '9';
  return {
    ...item,
    'attributes': {
      ...attrs,
      'transactions': [leg],
    },
  };
}

/// A budget on a reset schedule, which is what cannot be cleared through the
/// API. The shared fixture carries no auto-budget type at all.
Map<String, Object?> _budgetWithAutoBudget() => {
  'data': [
    {
      'id': '3',
      'type': 'budgets',
      'attributes': {
        'name': 'Work income',
        'active': true,
        'spent': <Object?>[],
        'auto_budget_amount': '40000.00',
        'auto_budget_type': 'reset',
        'auto_budget_period': 'monthly',
        'auto_budget_currency_code': 'EUR',
        'auto_budget_currency_symbol': '\u20ac',
      },
    },
  ],
};
