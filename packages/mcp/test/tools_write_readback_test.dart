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
    List<Object?>? limits,
  }) {
    return MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path == '/api/v1/transactions/1') {
        return jsonHttpResponse(transactionEnvelope(transaction!));
      }
      if (request.method == 'GET' && path == '/api/v1/budgets') {
        return jsonHttpResponse(budgets!);
      }
      if (request.method == 'GET' && path == '/api/v1/budgets/3/limits') {
        return jsonHttpResponse({'data': limits ?? <Object?>[]});
      }
      if (request.method == 'GET' && path == '/api/v1/currencies/primary') {
        // What a budget's figures are in when the budget itself names nothing.
        return jsonHttpResponse({
          'data': {
            'id': '17',
            'type': 'currencies',
            'attributes': {
              'code': 'SEK',
              'name': 'Swedish krona',
              'symbol': 'kr',
            },
          },
        });
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

  group('a group rename that did not land', () {
    test('is reported against the title, not skipped', () async {
      // The description check used to skip split groups entirely, so a rename
      // that changed nothing answered ok.
      final recorder = _Recorder();
      final group = {
        'id': '77',
        'type': 'transactions',
        'attributes': {
          'group_title': 'Rent and fees',
          'transactions': [
            {
              'transaction_journal_id': '811',
              'type': 'withdrawal',
              'date': '2026-02-01',
              'amount': '1200.00',
              'description': 'Rent',
              'source_name': 'Checking',
              'destination_name': 'Landlord',
              'currency_code': 'EUR',
              'currency_symbol': '\u20ac',
            },
            {
              'transaction_journal_id': '812',
              'type': 'withdrawal',
              'date': '2026-02-01',
              'amount': '25.00',
              'description': 'Service fee',
              'source_name': 'Checking',
              'destination_name': 'Landlord',
              'currency_code': 'EUR',
              'currency_symbol': '\u20ac',
            },
          ],
        },
      };
      final client = recorder.client(
        transaction: group,
        onWrite: () => transactionEnvelope(group),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'description': 'Rent, February'});

      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('description'));
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

  group('create_budget', () {
    test('sends the currency id, not the code alone', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        onWrite: () => {
          'data': {
            'id': '9',
            'attributes': {
              'name': 'Insurance',
              'active': true,
              'auto_budget_amount': '2500.00',
              'auto_budget_type': 'reset',
              'auto_budget_currency_code': 'SEK',
              'auto_budget_currency_symbol': 'kr',
            },
          },
        },
      );

      final result = await _tool(
        'create_budget',
        client,
      ).run({'name': 'Insurance', 'amount': 2500, 'currency_code': 'SEK'});

      expect(result['ok'], isTrue);
      // Firefly stores nothing from the code, so the code alone left every
      // budget on the instance default.
      expect(recorder.body!['auto_budget_currency_id'], '17');
      expect(recorder.body!['auto_budget_currency_code'], 'SEK');
    });

    test('refuses a currency no enabled currency carries', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        onWrite: () => throw StateError('must not reach the server'),
      );

      final result = await _tool(
        'create_budget',
        client,
      ).run({'name': 'Insurance', 'amount': 2500, 'currency_code': 'XYZ'});

      expect(result['code'], 'bad_input');
      expect('${result['error']}', contains('XYZ'));
      expect(recorder.body, isNull);
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

    test('reports the ledger currency for a budget that names none', () async {
      // A budget list that claimed euro against a krona ledger was actively
      // misleading: the amounts were never euro.
      final recorder = _Recorder();
      final client = recorder.client(
        budgets: budgetsBody(),
        onWrite: () => {
          'data': {
            'id': '3',
            'attributes': {'name': 'Food', 'active': true},
          },
        },
      );

      final result = await _tool(
        'update_budget',
        client,
      ).run({'budget_id': '3', 'name': 'Food'});

      final stored = result['budget']! as Map<String, Object?>;
      expect(stored['currency_code'], 'SEK');
      expect(stored['currency_symbol'], 'kr');
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

    test('says when the period limit did not follow the amount', () async {
      // Firefly keeps the limit in force for a period independent of the rule,
      // so a budget read 220,000 while its 2026 limit still read 100,000 and
      // nothing said so.
      final recorder = _Recorder();
      final client = recorder.client(
        budgets: budgetsBody(),
        limits: [
          {
            'id': '11',
            'type': 'budget_limits',
            'attributes': {
              'budget_id': '3',
              'start': '2026-01-01T00:00:00+00:00',
              'end': '2026-12-31T00:00:00+00:00',
              'amount': '100000.00',
              'currency_code': 'SEK',
              'currency_symbol': 'kr',
            },
          },
        ],
        onWrite: () => {
          'data': {
            'id': '3',
            'attributes': {
              'name': 'Holidays',
              'active': true,
              'auto_budget_amount': '220000.00',
              'auto_budget_type': 'reset',
              'auto_budget_period': 'yearly',
              'auto_budget_currency_code': 'SEK',
              'auto_budget_currency_symbol': 'kr',
            },
          },
        },
      );

      final result = await _tool(
        'update_budget',
        client,
      ).run({'budget_id': '3', 'name': 'Holidays', 'amount': 220000});

      // The write landed, so this is not a failure and not not_applied.
      expect(result['ok'], isTrue);
      expect(result.containsKey('code'), isFalse);

      final stale = result['period_limits_unchanged']! as List;
      expect(stale, hasLength(1));
      expect((stale.single as Map)['limit_id'], '11');
      expect((stale.single as Map)['amount'], 100000);
      expect('${result['note']}', contains('update_budget_limit'));
    });

    test('says nothing when the limit already agrees', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        budgets: budgetsBody(),
        limits: [
          {
            'id': '11',
            'type': 'budget_limits',
            'attributes': {
              'budget_id': '3',
              'start': '2026-01-01T00:00:00+00:00',
              'end': '2026-12-31T00:00:00+00:00',
              'amount': '220000.00',
              'currency_code': 'SEK',
              'currency_symbol': 'kr',
            },
          },
        ],
        onWrite: () => {
          'data': {
            'id': '3',
            'attributes': {
              'name': 'Holidays',
              'active': true,
              'auto_budget_amount': '220000.00',
              'auto_budget_type': 'reset',
              'auto_budget_currency_code': 'SEK',
            },
          },
        },
      );

      final result = await _tool(
        'update_budget',
        client,
      ).run({'budget_id': '3', 'name': 'Holidays', 'amount': 220000});

      expect(result.containsKey('period_limits_unchanged'), isFalse);
      expect(result.containsKey('note'), isFalse);
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

  group('merging a tag', () {
    /// A ledger holding Vacances beside Holidays, and what a merge does to it.
    Map<String, Object?> taggedGroup(String id) => {
      'id': id,
      'type': 'transactions',
      'attributes': {
        'group_title': 'Summer',
        'transactions': [
          {
            'transaction_journal_id': '${id}1',
            'type': 'withdrawal',
            'date': '2026-07-14',
            'amount': '120.00',
            'description': 'Hotel',
            'source_name': 'Checking',
            'destination_name': 'Hotel',
            'currency_code': 'EUR',
            'currency_symbol': '€',
            'tags': const ['Shared'],
          },
          {
            'transaction_journal_id': '${id}2',
            'type': 'withdrawal',
            'date': '2026-07-14',
            'amount': '80.00',
            'description': 'Flights',
            'source_name': 'Checking',
            'destination_name': 'Airline',
            'currency_code': 'EUR',
            'currency_symbol': '€',
            'tags': const ['Vacances'],
          },
        ],
      },
    };

    MockClient ledger({
      required List<Map<String, Object?>> carrying,
      List<Map<String, Object?>>? writes,
      List<String>? deletes,
    }) => MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path == '/api/v1/tags') {
        return jsonHttpResponse({
          'data': [
            {
              'id': '11',
              'type': 'tags',
              'attributes': {'tag': 'Vacances'},
            },
            {
              'id': '12',
              'type': 'tags',
              'attributes': {'tag': 'Holidays'},
            },
          ],
        });
      }
      if (request.method == 'GET' && path == '/api/v1/tags/11/transactions') {
        return jsonHttpResponse(
          transactionsPageBody(items: carrying, total: carrying.length),
        );
      }
      if (request.method == 'PUT' && path.startsWith('/api/v1/transactions/')) {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        writes?.add(body);
        return jsonHttpResponse(
          transactionEnvelope({
            'id': path.split('/').last,
            'type': 'transactions',
            'attributes': {
              'group_title': body['group_title'],
              'transactions': body['transactions'],
            },
          }),
        );
      }
      if (request.method == 'DELETE' && path == '/api/v1/tags/11') {
        deletes?.add('11');
        return http.Response('', 204);
      }
      return http.Response('unexpected ${request.method} $path', 500);
    });

    test('a dry run reports the rows and writes nothing', () async {
      final writes = <Map<String, Object?>>[];
      final deletes = <String>[];

      final result = await _tool(
        'merge_tags',
        ledger(
          carrying: [taggedGroup('97'), taggedGroup('98')],
          writes: writes,
          deletes: deletes,
        ),
      ).run({'from_tag': 'Vacances', 'into_tag': 'Holidays'});

      expect(result['ok'], isTrue);
      expect(result['dry_run'], isTrue);
      expect(result['transaction_count'], 2);
      // One leg of each group carries it. The other is somebody else's row.
      expect(result['leg_count'], 2);
      expect(result['transaction_ids'], ['97', '98']);
      expect(result['tag_removed'], isFalse);
      expect('${result['next']}', contains('dry_run false'));
      expect(writes, isEmpty);
      expect(deletes, isEmpty);
    });

    test('the rows move, the other legs do not, and the tag goes', () async {
      final writes = <Map<String, Object?>>[];
      final deletes = <String>[];

      final result = await _tool(
        'merge_tags',
        ledger(carrying: [taggedGroup('97')], writes: writes, deletes: deletes),
      ).run({'from_tag': 'Vacances', 'into_tag': 'Holidays', 'dry_run': false});

      expect(result['ok'], isTrue);
      expect(result['tag_removed'], isTrue);
      expect(deletes, ['11']);
      final legs = (writes.single['transactions']! as List)
          .cast<Map<String, Object?>>();
      // Both legs go back out with their own ids, or Firefly deletes the one
      // the write left out.
      expect(legs.map((leg) => leg['transaction_journal_id']), ['971', '972']);
      expect(legs[0]['tags'], ['Shared']);
      expect(legs[1]['tags'], ['Holidays']);
    });

    test('a tag nothing carries only needs deleting', () async {
      final result = await _tool(
        'merge_tags',
        ledger(carrying: const []),
      ).run({'from_tag': '11', 'into_tag': '12'});

      expect(result['transaction_count'], 0);
      expect('${result['next']}', contains('delete_tag'));
    });

    test('more rows than fit are counted whole and listed short', () async {
      final result = await _tool(
        'merge_tags',
        ledger(carrying: [for (var i = 0; i < 101; i++) taggedGroup('$i')]),
      ).run({'from_tag': 'Vacances', 'into_tag': 'Holidays'});

      expect(result['transaction_count'], 101);
      expect(result['transaction_ids'], hasLength(100));
      expect(result['transaction_ids_truncated'], 1);
    });

    test('what cannot be merged is refused before any write', () async {
      final refusals = <String, Map<String, Object?>>{
        'from_tag is required': {'from_tag': '  ', 'into_tag': 'Holidays'},
        'into_tag is required': {'from_tag': 'Vacances', 'into_tag': ''},
        'No tag "Ferie"': {'from_tag': 'Ferie', 'into_tag': 'Holidays'},
        // A name nothing carries yet is a rename, which costs one write
        // instead of one per row.
        'update_tag': {'from_tag': 'Vacances', 'into_tag': 'Ferie'},
        'cannot be merged into itself': {
          'from_tag': 'Vacances',
          'into_tag': '11',
        },
      };

      for (final entry in refusals.entries) {
        final writes = <Map<String, Object?>>[];
        final deletes = <String>[];

        final result = await _tool(
          'merge_tags',
          ledger(
            carrying: [taggedGroup('97')],
            writes: writes,
            deletes: deletes,
          ),
        ).run({...entry.value, 'dry_run': false});

        expect(result['ok'], isFalse, reason: entry.key);
        expect('${result['error']}', contains(entry.key));
        expect(writes, isEmpty, reason: entry.key);
        expect(deletes, isEmpty, reason: entry.key);
      }
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
