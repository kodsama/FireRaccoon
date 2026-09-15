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
  final bodies = <Map<String, Object?>>[];

  /// [refuseWrites] names writes by their position, first write 1, that
  /// Firefly answers with a 500.
  MockClient client({
    required Map<String, Object?> Function() onWrite,
    Map<String, Object?>? transaction,
    Map<String, Object?>? budgets,
    List<Object?>? limits,
    Set<int> refuseWrites = const {},
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
        bodies.add(body!);
        if (refuseWrites.contains(bodies.length)) {
          return jsonHttpResponse({'message': 'refused'}, status: 500);
        }
        return jsonHttpResponse(onWrite());
      }
      return http.Response('unexpected ${request.method} $path', 500);
    });
  }
}

Map<String, Object?> _leg(Map<String, Object?> body) =>
    ((body['transactions'] as List).first) as Map<String, Object?>;

List<Map<String, Object?>> _legsOfItem(Map<String, Object?> item) =>
    ((item['attributes'] as Map)['transactions'] as List)
        .cast<Map<String, Object?>>();

/// A group as Firefly stores it after [body]: each sent leg, found by its
/// journal id, with the fields it sent written over what was there.
Map<String, Object?> _echoGroup(
  Map<String, Object?> item,
  Map<String, Object?> body,
) {
  final sent = {
    for (final leg in body['transactions'] as List)
      '${(leg as Map)['transaction_journal_id']}': leg.cast<String, Object?>(),
  };
  return {
    ...item,
    'attributes': {
      ...item['attributes'] as Map,
      'transactions': [
        for (final leg in _legsOfItem(item))
          {...leg, ...?sent[leg['transaction_journal_id']]},
      ],
    },
  };
}

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

  group('taking a category off a transaction', () {
    // The stored leg carries category_id 7 and "Food". Firefly resolves
    // whichever half of the pair still has a value, so clearing one and
    // sending the other back answered ok and kept the category: removing it
    // needed both halves emptied, which no caller could be expected to guess.
    test('an empty id clears the name beside it', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'category_id': ''});

      final leg = _leg(recorder.body!);
      expect(leg['category_id'], '');
      expect(leg['category_name'], '');
    });

    test('an empty name clears the id beside it', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'category_name': ''});

      final leg = _leg(recorder.body!);
      expect(leg['category_id'], '');
      expect(leg['category_name'], '');
    });

    test('one leg of a group is cleared on its own', () async {
      final group = {
        'id': '1',
        'type': 'transactions',
        'attributes': {
          'group_title': 'Weekly shop',
          'transactions': [
            {
              'transaction_journal_id': '811',
              'type': 'withdrawal',
              'date': '2026-01-15',
              'amount': '45.00',
              'description': 'Groceries',
              'source_name': 'Checking',
              'destination_name': 'Store',
              'category_id': '7',
              'category_name': 'Food',
              'currency_code': 'EUR',
              'currency_symbol': '\u20ac',
              'reconciled': false,
            },
            {
              'transaction_journal_id': '812',
              'type': 'withdrawal',
              'date': '2026-01-15',
              'amount': '5.00',
              'description': 'Bag',
              'source_name': 'Checking',
              'destination_name': 'Store',
              'category_id': '7',
              'category_name': 'Food',
              'currency_code': 'EUR',
              'currency_symbol': '\u20ac',
              'reconciled': false,
            },
          ],
        },
      };
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: group,
        onWrite: () => transactionEnvelope(_echoGroup(group, recorder.body!)),
      );

      await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '811', 'category_id': ''},
        ],
      });

      final legs = (recorder.body!['transactions'] as List)
          .cast<Map<String, Object?>>();
      final cleared = legs.singleWhere(
        (leg) => leg['transaction_journal_id'] == '811',
      );
      expect(cleared['category_id'], '');
      expect(cleared['category_name'], '');
      // A leg the call left out keeps what it had.
      final untouched = legs.singleWhere(
        (leg) => leg['transaction_journal_id'] == '812',
      );
      expect(untouched['category_name'], 'Food');
    });

    test('a category that survived the clear is reported', () async {
      // Firefly answers 200 to a write it declined in part, and a removal
      // that did not remove is that same silent refusal.
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'category_id': ''});

      // The row comes back still carrying the category, so the removal did
      // not happen and saying ok would be the payee-by-name bug again.
      expect(result['ok'], isFalse);
      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('category_id'));
      // Only the half the caller emptied is named: the other went along to
      // keep Firefly from resolving it, and was never asked for.
      expect('${result['error']}', isNot(contains('category_name')));
      expect(result['transaction'], isNotNull);
    });

    test('a clear that took is not reported', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(),
        onWrite: () => transactionEnvelope(_withoutCategory(transactionItem())),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'category_name': ''});

      expect(result['ok'], isTrue);
      expect(result.containsKey('code'), isFalse);
    });
  });

  group('a payee named on an update', () {
    // The stored deposit names revenue account 5 by id. The same preference
    // for an id over a name that kept a category in place kept the payer: the
    // call answered ok, the description and category moved, the payer stayed.
    test('replaces the id it is meant to replace', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(
          type: 'deposit',
          sourceName: 'Employer',
          sourceId: '5',
          destinationName: 'Checking',
          destinationId: '9',
        ),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'source_name': 'Cashback partner',
        'description': 'New description',
      });

      final leg = _leg(recorder.body!);
      expect(leg['source_name'], 'Cashback partner');
      expect(leg.containsKey('source_id'), isFalse);
      // The side the call never mentioned keeps both its name and its id.
      expect(leg['destination_id'], '9');
    });

    test('drops the id on the destination side the same way', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(sourceId: '5', destinationId: '9'),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'destination_name': 'Other store'});

      final leg = _leg(recorder.body!);
      expect(leg['destination_name'], 'Other store');
      expect(leg.containsKey('destination_id'), isFalse);
      expect(leg['source_id'], '5');
    });

    test('leaves an id the caller stated in place', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(sourceId: '5'),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'source_id': '6',
        'source_name': 'Savings',
      });

      expect(_leg(recorder.body!)['source_id'], '6');
    });

    test('is reported when Firefly kept the old one', () async {
      final stored = transactionItem(type: 'deposit', sourceName: 'Employer');
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: stored,
        onWrite: () => transactionEnvelope(stored),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'source_name': 'Cashback partner'});

      expect(result['ok'], isFalse);
      expect(result['code'], 'not_applied');
      expect(result['error'], contains('source_name'));
    });

    test('a leg naming its own payee does not inherit the group id', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool('create_transaction', client).run({
        'type': 'withdrawal',
        'date': '2026-03-01',
        'description': 'Card bill',
        'source_id': '5',
        'destination_id': '9',
        'splits': [
          {'amount': 10, 'description': 'Coffee'},
          {'amount': 20, 'description': 'Books', 'destination_name': 'Shop'},
        ],
      });

      final legs = recorder.body!['transactions'] as List;
      final inherited = legs.first as Map<String, Object?>;
      final named = legs.last as Map<String, Object?>;
      expect(inherited['destination_id'], '9');
      expect(named['destination_name'], 'Shop');
      expect(named.containsKey('destination_id'), isFalse);
      expect(named['source_id'], '5');
    });
  });

  group('a payee identified on an update', () {
    // The other half of the pair above. An id stated at the top level used to
    // travel with the stored name, and Firefly falls through to the name when
    // the id names an account the type will not take, so moving a row to an
    // account by id either landed on the name's account or was refused for an
    // account the caller had never mentioned.
    test('replaces the name it is meant to replace', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(destinationName: 'Handelsbanken'),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'destination_id': '10317'});

      final leg = _leg(recorder.body!);
      expect(leg['destination_id'], '10317');
      expect(leg.containsKey('destination_name'), isFalse);
      // The side the call never mentioned keeps what it has.
      expect(leg['source_name'], 'Checking');
    });

    test('drops the name on the source side the same way', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(type: 'deposit', sourceName: 'Employer'),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'source_id': '12'});

      final leg = _leg(recorder.body!);
      expect(leg['source_id'], '12');
      expect(leg.containsKey('source_name'), isFalse);
      expect(leg['destination_name'], 'Store');
    });

    test('leaves a name the caller stated in place', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(destinationName: 'Handelsbanken'),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'destination_id': '10317',
        'destination_name': 'HSB lån 1',
      });

      final leg = _leg(recorder.body!);
      expect(leg['destination_id'], '10317');
      expect(leg['destination_name'], 'HSB lån 1');
    });

    test('a category id drops the stored category name', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(),
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'category_id': '11'});

      final leg = _leg(recorder.body!);
      expect(leg['category_id'], '11');
      expect(leg.containsKey('category_name'), isFalse);
    });

    test('one leg named by journal_id does the same', () async {
      Map<String, Object?> leg(String journalId, String description) => {
        'transaction_journal_id': journalId,
        'type': 'withdrawal',
        'date': '2026-01-15',
        'amount': '45.00',
        'description': description,
        'source_name': 'Checking',
        'destination_name': 'Handelsbanken',
        'currency_code': 'EUR',
        'currency_symbol': '€',
        'reconciled': false,
      };
      final group = {
        'id': '1',
        'type': 'transactions',
        'attributes': {
          'group_title': 'Mortgage',
          'transactions': [leg('811', 'Amortisation'), leg('812', 'Interest')],
        },
      };
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: group,
        onWrite: () => transactionEnvelope(_echoGroup(group, recorder.body!)),
      );

      await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '811', 'destination_id': '10317'},
        ],
      });

      final legs = (recorder.body!['transactions'] as List)
          .cast<Map<String, Object?>>();
      final changed = legs.singleWhere(
        (leg) => leg['transaction_journal_id'] == '811',
      );
      expect(changed['destination_id'], '10317');
      expect(changed.containsKey('destination_name'), isFalse);
      // A leg the call left out keeps what it had.
      final untouched = legs.singleWhere(
        (leg) => leg['transaction_journal_id'] == '812',
      );
      expect(untouched['destination_name'], 'Handelsbanken');
    });

    test('a leg identifying its own payee does not inherit the group '
        'name', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        onWrite: () => transactionEnvelope(transactionItem()),
      );

      await _tool('create_transaction', client).run({
        'type': 'withdrawal',
        'date': '2026-03-01',
        'description': 'Card bill',
        'source_id': '5',
        'destination_name': 'Store',
        'splits': [
          {'amount': 10, 'description': 'Coffee'},
          {'amount': 20, 'description': 'Books', 'destination_id': '9'},
        ],
      });

      final legs = recorder.body!['transactions'] as List;
      final inherited = legs.first as Map<String, Object?>;
      final identified = legs.last as Map<String, Object?>;
      expect(inherited['destination_name'], 'Store');
      expect(identified['destination_id'], '9');
      expect(identified.containsKey('destination_name'), isFalse);
    });
  });

  group('keeping a row reconciled through a change', () {
    // Moving an account on a reconciled row took two calls: release it with
    // the change, then set the flag back. Between them the row sat
    // unreconciled, and a run that died there left it that way.
    Map<String, Object?> reconciledRow() =>
        transactionItem(reconciled: true, sourceId: '5', destinationId: '9');

    test('releases, changes and reconciles again in one call', () async {
      var current = reconciledRow();
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: current,
        onWrite: () {
          current = storedAfterWrite(
            id: '1',
            sent: _leg(recorder.body!),
            previous: current,
          );
          return transactionEnvelope(current);
        },
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'keep_reconciled': true, 'source_id': '6'});

      expect(recorder.bodies, hasLength(2));
      final released = _leg(recorder.bodies[0]);
      expect(released['reconciled'], isFalse);
      expect(released['source_id'], '6');
      // The second write puts the flag back and resends none of the money.
      final restored = _leg(recorder.bodies[1]);
      expect(restored['reconciled'], isTrue);
      expect(restored.containsKey('amount'), isFalse);
      expect(restored.containsKey('source_id'), isFalse);
      expect(result['ok'], isTrue);
      expect(result['steps'], ['released', 'changed', 'reconciled']);
      final transaction = result['transaction'] as Map;
      expect(transaction['reconciled'], isTrue);
      expect(transaction['source_id'], '6');
    });

    test('a row that was not reconciled takes one write', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: transactionItem(sourceId: '5'),
        onWrite: () => transactionEnvelope(transactionItem(sourceId: '6')),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'keep_reconciled': true, 'source_id': '6'});

      expect(recorder.bodies, hasLength(1));
      expect(result['ok'], isTrue);
      expect(result.containsKey('steps'), isFalse);
    });

    test('refuses reconciled beside it, on the row or on a leg', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: reconciledRow(),
        onWrite: () => transactionEnvelope(reconciledRow()),
      );
      final tool = _tool('update_transaction', client);

      final onRow = await tool.run({
        'transaction_id': '1',
        'keep_reconciled': true,
        'reconciled': false,
      });
      final onLeg = await tool.run({
        'transaction_id': '1',
        'keep_reconciled': true,
        'splits': [
          {'journal_id': '811', 'reconciled': false},
        ],
      });
      final notBool = await tool.run({
        'transaction_id': '1',
        'keep_reconciled': 'yes',
      });

      expect(onRow['code'], 'bad_input');
      expect(onLeg['code'], 'bad_input');
      expect(notBool['code'], 'bad_input');
      expect(recorder.bodies, isEmpty);
    });

    test('says so when the flag could not be put back', () async {
      var current = reconciledRow();
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: current,
        refuseWrites: const {2},
        onWrite: () {
          current = storedAfterWrite(
            id: '1',
            sent: _leg(recorder.body!),
            previous: current,
          );
          return transactionEnvelope(current);
        },
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'keep_reconciled': true, 'source_id': '6'});

      expect(result['ok'], isFalse);
      expect(result['code'], 'left_unreconciled');
      expect(result['error'], contains('set_transaction_reconciled'));
      expect(result['steps'], ['released', 'changed']);
      // What is stored is reported: the change landed, the flag did not.
      final transaction = result['transaction'] as Map;
      expect(transaction['source_id'], '6');
      expect(transaction['reconciled'], isFalse);
    });

    test('a flag Firefly accepted and did not store is reported', () async {
      var current = reconciledRow();
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: current,
        onWrite: () {
          final sent = {..._leg(recorder.body!)};
          // The second write is answered with the row still released.
          if (recorder.bodies.length == 2) sent.remove('reconciled');
          current = storedAfterWrite(id: '1', sent: sent, previous: current);
          return transactionEnvelope(current);
        },
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'keep_reconciled': true, 'source_id': '6'});

      expect(result['ok'], isFalse);
      expect(result['code'], 'not_applied');
      expect(result['error'], contains('reconciled'));
      expect(result['steps'], ['released', 'changed', 'reconciled']);
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

  group('editing one leg of a split group', () {
    // A loan payment as the ledger holds one: an amortisation leg carrying the
    // housing budget, and two interest legs carrying nothing.
    Map<String, Object?> loanGroup({
      bool reconciled = false,
      bool foreign = false,
    }) => {
      'id': '1',
      'type': 'transactions',
      'attributes': {
        'group_title': 'Beijersparksgatan loan',
        'transactions': [
          {
            'transaction_journal_id': '811',
            'type': 'withdrawal',
            'date': '2026-11-01',
            'amount': '3400.00',
            'description': 'Beijersparksgatan loan 1 amortisation',
            'source_name': 'Common account',
            'destination_id': '30',
            'destination_name': 'Handelsbanken',
            'category_id': '791',
            'category_name': 'Loan > Reimbursement',
            'budget_id': '19',
            'currency_code': 'EUR',
            'currency_symbol': '€',
            'reconciled': reconciled,
          },
          {
            'transaction_journal_id': '812',
            'type': 'withdrawal',
            'date': '2026-11-01',
            'amount': '3464.00',
            'description': 'Beijersparksgatan loan 1 interest',
            'source_name': 'Common account',
            'destination_name': 'Handelsbanken',
            'currency_code': 'EUR',
            'currency_symbol': '€',
            'reconciled': reconciled,
            if (foreign) 'foreign_amount': '340.00',
            if (foreign) 'foreign_currency_code': 'SEK',
          },
          {
            'transaction_journal_id': '813',
            'type': 'withdrawal',
            'date': '2026-11-01',
            'amount': '3016.00',
            'description': 'Beijersparksgatan loan 2 interest',
            'source_name': 'Common account',
            'destination_name': 'Handelsbanken',
            'currency_code': 'EUR',
            'currency_symbol': '€',
            'reconciled': reconciled,
          },
        ],
      },
    };

    List<Map<String, Object?>> legsOf(Map<String, Object?> body) => [
      for (final leg in body['transactions'] as List)
        leg as Map<String, Object?>,
    ];

    test('a category reaches the legs named and no others', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        onWrite: () => transactionEnvelope(_storedGroup(recorder.body!)),
      );

      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '812', 'category_name': 'Loan > Interest'},
          {'journal_id': '813', 'category_name': 'Loan > Interest'},
        ],
      });

      expect(result['ok'], isTrue);
      final legs = legsOf(recorder.body!);
      // Every leg goes back out. Firefly deletes the journals an update does
      // not name, so a payload carrying only the two interest legs would take
      // the amortisation with it.
      expect(legs.map((leg) => leg['transaction_journal_id']), [
        '811',
        '812',
        '813',
      ]);
      expect(legs[0]['category_name'], 'Loan > Reimbursement');
      expect(legs[0]['category_id'], '791');
      expect(legs[1]['category_name'], 'Loan > Interest');
      expect(legs[2]['category_name'], 'Loan > Interest');
      // A name replaces the id it stands in for on a leg too, or Firefly would
      // resolve the id and discard the name.
      expect(legs[1].containsKey('category_id'), isFalse);
      // Each leg keeps its own figure and wording.
      expect(legs[0]['amount'], '3400.00');
      expect(legs[1]['amount'], '3464.00');
      expect(legs[1]['description'], 'Beijersparksgatan loan 1 interest');
    });

    test('a budget lands on one leg and leaves the rest budget-less', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        onWrite: () => transactionEnvelope(_storedGroup(recorder.body!)),
      );

      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '812', 'budget_id': '19'},
        ],
      });

      expect(result['ok'], isTrue);
      final legs = legsOf(recorder.body!);
      expect(legs[0]['budget_id'], '19');
      expect(legs[1]['budget_id'], '19');
      // What the group-level write had no way to do: a leg that must carry no
      // budget, beside one that must.
      expect(legs[2].containsKey('budget_id'), isFalse);
    });

    test('a payee named on one leg drops that leg\'s stored id', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        onWrite: () => transactionEnvelope(loanGroup()),
      );

      await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '811', 'destination_name': 'Nordea'},
        ],
      });

      final legs = legsOf(recorder.body!);
      expect(legs[0]['destination_name'], 'Nordea');
      expect(legs[0].containsKey('destination_id'), isFalse);
      expect(legs[1]['destination_name'], 'Handelsbanken');
    });

    test('a partly reconciled group gets each leg its own flag back', () async {
      // Two legs checked against a statement, the third not yet. The release
      // reaches only the leg being changed, and the restore gives every leg
      // back what it had rather than reconciling the whole group.
      var current = loanGroup(reconciled: true);
      _legsOfItem(current)[2]['reconciled'] = false;
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: current,
        onWrite: () {
          current = _echoGroup(current, recorder.body!);
          return transactionEnvelope(current);
        },
      );

      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'keep_reconciled': true,
        'splits': [
          {'journal_id': '811', 'amount': 3500},
        ],
      });

      final released = legsOf(recorder.bodies[0]);
      expect(released[0]['reconciled'], isFalse);
      expect(released[0]['amount'], '3500.00');
      expect(released[1]['reconciled'], isTrue);
      expect(released[2]['reconciled'], isFalse);
      final restored = legsOf(recorder.bodies[1]);
      expect(
        [for (final leg in restored) leg['reconciled']],
        [true, true, false],
      );
      expect(result['ok'], isTrue);
      expect(result['steps'], ['released', 'changed', 'reconciled']);
      expect((result['transaction'] as Map)['partially_reconciled'], isTrue);
    });

    test('a leg description is its own, not the group title', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        onWrite: () => transactionEnvelope(_storedGroup(recorder.body!)),
      );

      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'group_title': 'Beijersparksgatan, November',
        'splits': [
          {'journal_id': '813', 'description': 'Interets du pret 2'},
        ],
      });

      expect(result['ok'], isTrue);
      final body = recorder.body!;
      expect(body['group_title'], 'Beijersparksgatan, November');
      final legs = legsOf(body);
      expect(legs[2]['description'], 'Interets du pret 2');
      expect(legs[0]['description'], 'Beijersparksgatan loan 1 amortisation');
      expect(legs[1]['description'], 'Beijersparksgatan loan 1 interest');
    });

    test('an empty value on a leg clears that leg only', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        onWrite: () => transactionEnvelope(_storedGroup(recorder.body!)),
      );

      await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '811', 'budget_id': ''},
        ],
      });

      final legs = legsOf(recorder.body!);
      // An explicit empty is the only thing Firefly reads as a removal.
      expect(legs[0]['budget_id'], '');
      expect(legs[1].containsKey('budget_id'), isFalse);
    });

    test('releasing a reconciled group reaches every leg', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(reconciled: true),
        onWrite: () => transactionEnvelope(_storedGroup(recorder.body!)),
      );

      final result = await _tool(
        'update_transaction',
        client,
      ).run({'transaction_id': '1', 'reconciled': false});

      expect(result['ok'], isTrue);
      for (final leg in legsOf(recorder.body!)) {
        // The flag stopped at the group, so every leg stayed reconciled and
        // the payload dropped the amounts it was meant to release.
        expect(leg['reconciled'], isFalse);
        expect(leg['amount'], isNotNull);
      }
    });

    test('a journal the group does not hold is refused', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        onWrite: () => throw StateError('must not reach the server'),
      );

      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '999', 'category_name': 'Loan > Interest'},
        ],
      });

      expect(result['code'], 'bad_input');
      expect('${result['error']}', contains('811, 812, 813'));
      expect(recorder.body, isNull);
    });

    test('a leg naming no journal is refused', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        onWrite: () => throw StateError('must not reach the server'),
      );

      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'category_name': 'Loan > Interest'},
        ],
      });

      expect(result['code'], 'bad_input');
      expect('${result['error']}', contains('journal_id is required'));
      expect(recorder.body, isNull);
    });

    test('a group-level field beside splits is refused', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        onWrite: () => throw StateError('must not reach the server'),
      );

      // Ambiguous on its face: category_name at the top level means every leg,
      // and inside splits it means one.
      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'category_name': 'Loan > Interest',
        'splits': [
          {'journal_id': '812', 'budget_id': '19'},
        ],
      });

      expect(result['code'], 'bad_input');
      expect('${result['error']}', contains('category_name'));
      expect(recorder.body, isNull);
    });

    test('a leg Firefly declined is named in the answer', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        // The group exactly as it was: accepted, stored nothing. What a budget
        // on a deposit leg does.
        onWrite: () => transactionEnvelope(loanGroup()),
      );

      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '812', 'budget_id': '19'},
        ],
      });

      expect(result['ok'], isFalse);
      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('splits[0].budget_id'));
    });

    test(
      'what a leg cannot be asked for is refused, nothing written',
      () async {
        final refusals = <String, (Map<String, Object?>, List<Object?>)>{
          'must be an object': (loanGroup(), ['not a leg']),
          'more than once': (
            loanGroup(),
            [
              {'journal_id': '812', 'budget_id': '19'},
              {'journal_id': '812', 'notes': 'twice'},
            ],
          ),
          'amount must be greater than zero': (
            loanGroup(),
            [
              {'journal_id': '812', 'amount': 0},
            ],
          ),
          'foreign_amount must be greater than zero': (
            loanGroup(),
            [
              {'journal_id': '812', 'foreign_amount': 0},
            ],
          ),
          'description cannot be emptied': (
            loanGroup(),
            [
              {'journal_id': '812', 'description': '  '},
            ],
          ),
          'is reconciled': (
            loanGroup(reconciled: true),
            [
              {'journal_id': '812', 'amount': 100},
            ],
          ),
          'rate cannot be derived': (
            loanGroup(foreign: true),
            [
              {'journal_id': '812', 'amount': 100},
            ],
          ),
        };

        for (final entry in refusals.entries) {
          final recorder = _Recorder();
          final client = recorder.client(
            transaction: entry.value.$1,
            onWrite: () => throw StateError('must not reach the server'),
          );

          final result = await _tool(
            'update_transaction',
            client,
          ).run({'transaction_id': '1', 'splits': entry.value.$2});

          expect(result['code'], 'bad_input', reason: entry.key);
          expect('${result['error']}', contains(entry.key));
          expect(recorder.body, isNull, reason: entry.key);
        }
      },
    );

    test('an amount or a flag the server kept is reported per leg', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        onWrite: () => transactionEnvelope(loanGroup()),
      );

      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '811', 'amount': 1000},
          {'journal_id': '812', 'reconciled': true},
        ],
      });

      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('splits[0].amount'));
      expect('${result['error']}', contains('splits[1].reconciled'));
    });

    test('a group rebuilt under new ids is reported, not called ok', () async {
      final recorder = _Recorder();
      final client = recorder.client(
        transaction: loanGroup(),
        // What a destroyed and recreated group looks like from here: the same
        // values, none of the journals the call named.
        onWrite: () => transactionEnvelope(_renumbered(loanGroup())),
      );

      final result = await _tool('update_transaction', client).run({
        'transaction_id': '1',
        'splits': [
          {'journal_id': '812', 'category_name': 'Loan > Interest'},
        ],
      });

      expect(result['code'], 'not_applied');
      expect('${result['error']}', contains('splits[0]'));
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

/// Firefly's answer to a group update: the legs it was sent, read back.
Map<String, Object?> _storedGroup(Map<String, Object?> body) => {
  'id': '1',
  'type': 'transactions',
  'attributes': {
    'group_title': body['group_title'],
    'transactions': body['transactions'],
  },
};

/// The same group with every journal id changed, as a rebuild would leave it.
Map<String, Object?> _renumbered(Map<String, Object?> group) {
  final attrs = group['attributes']! as Map<String, Object?>;
  return {
    ...group,
    'attributes': {
      ...attrs,
      'transactions': [
        for (final leg in attrs['transactions']! as List)
          {
            ...leg as Map<String, Object?>,
            'transaction_journal_id': '9${leg['transaction_journal_id']}',
          },
      ],
    },
  };
}

/// The same item with no category, for a server that took the removal.
Map<String, Object?> _withoutCategory(Map<String, Object?> item) {
  final attrs = item['attributes'] as Map<String, Object?>;
  final legs = attrs['transactions'] as List;
  final leg = {...(legs.first as Map<String, Object?>)};
  leg['category_name'] = null;
  leg['category_id'] = null;
  return {
    ...item,
    'attributes': {
      ...attrs,
      'transactions': [leg, ...legs.skip(1)],
    },
  };
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
