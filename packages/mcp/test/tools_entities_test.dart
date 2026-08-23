import 'dart:convert';
import 'package:fireracoon_mcp/fireracoon_mcp.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers/firefly_mock.dart';

const _target = FireflyTarget(baseUrl: fireflyBaseUrl, bearer: fireflyToken);

List<McpTool> _tools({MockClient? client}) =>
    buildTools(target: _target, httpClient: client);

McpTool _tool(String name, {MockClient? client}) =>
    _tools(client: client).firstWhere((tool) => tool.name == name);

/// A two-leg group, which the shared mock has no example of: it carries a
/// journal id per leg and a title on the group.
Map<String, Object?> _splitGroupItem() => {
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
        'currency_symbol': '€',
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
        'currency_symbol': '€',
      },
    ],
  },
};

/// Every required field of every tool, so the validation sweep below stays in
/// step with the schemas rather than drifting from a hand-written list.
Iterable<(String, List<String>)> _toolsWithRequiredFields() sync* {
  for (final tool in _tools()) {
    final required = (tool.inputSchema['required'] as List?) ?? const [];
    if (required.isEmpty) continue;
    yield (tool.name, required.map((e) => '$e').toList());
  }
}

void main() {
  group('required-field validation', () {
    test('no tool sends a request when a required field is missing', () async {
      // A tool that stops validating fires a malformed request at Firefly and
      // surfaces a 422 as though the user's data were at fault.
      for (final (name, required) in _toolsWithRequiredFields()) {
        final calls = <Uri>[];
        final tool = _tool(name, client: fireflyMockClient(record: calls));

        final result = await tool.run({});

        expect(
          result['code'],
          'bad_input',
          reason: '$name accepted an empty argument map',
        );
        expect(
          calls,
          isEmpty,
          reason: '$name reached Firefly before validating ${required.first}',
        );
      }
    });
  });

  group('accounts', () {
    test('get_account returns one account', () async {
      final result = await _tool(
        'get_account',
        client: fireflyMockClient(),
      ).run({'account_id': '5'});

      expect(result['ok'], isTrue);
      expect((result['account'] as Map)['name'], 'Checking');
    });

    test('get_account surfaces a missing account as a failure', () async {
      // The tool lets the error out; the server turns it into a tool_error
      // response rather than reporting a fabricated empty account.
      await expectLater(
        _tool(
          'get_account',
          client: fireflyMockClient(),
        ).run({'account_id': 'nope'}),
        throwsA(isA<Exception>()),
      );
    });

    test('create_account defaults an asset to a real account role', () async {
      final bodies = <String>[];
      final tool = _tool(
        'create_account',
        client: fireflyMockClient(recordBodies: bodies),
      );

      final result = await tool.run({
        'name': 'Savings',
        'type': 'asset',
        'currency_code': 'EUR',
      });

      // Firefly rejects an asset account with no role: "the account role field
      // is required when type is asset".
      expect(result['ok'], isTrue);
      expect(bodies.single, contains('defaultAsset'));
    });

    test('create_account refuses an unknown type before requesting', () async {
      final calls = <Uri>[];
      final result = await _tool(
        'create_account',
        client: fireflyMockClient(record: calls),
      ).run({'name': 'X', 'type': 'chequing', 'currency_code': 'EUR'});

      expect(result['code'], 'bad_input');
      expect(calls, isEmpty);
    });

    test('create_liability sends its type and direction', () async {
      final bodies = <String>[];
      final result =
          await _tool(
            'create_liability',
            client: fireflyMockClient(recordBodies: bodies),
          ).run({
            'name': 'Car loan',
            'liability_type': 'loan',
            'liability_direction': 'credit',
            'currency_code': 'EUR',
            'amount_owed': 15000,
            'start_date': '2026-01-01',
            'interest': 2.5,
            'interest_period': 'yearly',
          });

      expect(result['ok'], isTrue);
      expect(bodies.single, contains('"liability_type":"loan"'));
      expect(bodies.single, contains('"liability_direction":"credit"'));
    });

    test('create_liability refuses an unknown liability type', () async {
      final calls = <Uri>[];
      final result =
          await _tool(
            'create_liability',
            client: fireflyMockClient(record: calls),
          ).run({
            'name': 'X',
            'liability_type': 'overdraft',
            'liability_direction': 'credit',
          });

      expect(result['code'], 'bad_input');
      expect(calls, isEmpty);
    });

    test('delete_account deletes', () async {
      final result = await _tool(
        'delete_account',
        client: fireflyMockClient(),
      ).run({'account_id': '5'});

      expect(result['ok'], isTrue);
      expect(result['deleted'], isTrue);
    });

    test('get_account_balance_history returns a series per account', () async {
      final calls = <Uri>[];
      final result =
          await _tool(
            'get_account_balance_history',
            client: fireflyMockClient(record: calls),
          ).run({
            'account_ids': ['5'],
            'start_date': '2026-01-01',
            'end_date': '2026-02-01',
          });

      expect(result['ok'], isTrue);
      expect(result['histories'], isA<Map<String, Object?>>());
      final chart = calls.firstWhere(
        (u) => u.path.endsWith('/chart/balance/balance'),
      );
      // end_date is inclusive to the caller, so the chart window has to reach
      // past it or the final month is dropped.
      expect(chart.queryParameters['end'], '2026-02-02');
    });

    test('get_account_balance_history rejects an unknown account', () async {
      final result =
          await _tool(
            'get_account_balance_history',
            client: fireflyMockClient(),
          ).run({
            'account_ids': ['nope'],
            'start_date': '2026-01-01',
            'end_date': '2026-02-01',
          });

      expect(result['code'], 'bad_input');
    });

    test('get_account_balance_history rejects an inverted window', () async {
      final result =
          await _tool(
            'get_account_balance_history',
            client: fireflyMockClient(),
          ).run({
            'account_ids': ['5'],
            'start_date': '2026-02-01',
            'end_date': '2026-01-01',
          });

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('precede'));
    });
  });

  group('update_account', () {
    test('an update naming no field is refused, not sent as a no-op', () async {
      final calls = <Uri>[];
      final result = await _tool(
        'update_account',
        client: fireflyMockClient(record: calls),
      ).run({'account_id': '5'});

      expect(result['code'], 'bad_input');
      // The refusal has to name the fields, or a caller who misspelled one has
      // nothing to correct against.
      expect(result['error'], contains('account_number'));
      expect(result['error'], contains('liability_direction'));
      expect(calls, isEmpty);
    });

    test('an empty name is refused rather than sent', () async {
      final calls = <Uri>[];
      final result = await _tool(
        'update_account',
        client: fireflyMockClient(record: calls),
      ).run({'account_id': '5', 'name': '  '});

      expect(result['code'], 'bad_input');
      expect(calls, isEmpty);
    });

    test('an unknown enum value is refused before requesting', () async {
      // Coercing any of these would rewrite the account as something the
      // caller never asked for: a liability silently turned into an asset.
      const cases = {
        'type': 'chequing',
        'account_role': 'mainAsset',
        'liability_type': 'overdraft',
        'liability_direction': 'sideways',
        'interest_period': 'fortnightly',
      };
      for (final entry in cases.entries) {
        final calls = <Uri>[];
        final result = await _tool(
          'update_account',
          client: fireflyMockClient(record: calls),
        ).run({'account_id': '5', entry.key: entry.value});

        expect(
          result['code'],
          'bad_input',
          reason: '${entry.key} accepted ${entry.value}',
        );
        expect(result['error'], contains(entry.key));
        expect(calls, isEmpty, reason: '${entry.key} reached Firefly');
      }
    });

    test('an unreadable opening_balance_date is refused', () async {
      final calls = <Uri>[];
      final result = await _tool(
        'update_account',
        client: fireflyMockClient(record: calls),
      ).run({'account_id': '5', 'opening_balance_date': 'whenever'});

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('opening_balance_date'));
      expect(calls, isEmpty);
    });

    test('sets the account number that find_account matches on', () async {
      // Without this the next import is back to guessing a payee by name.
      final bodies = <String>[];
      final result =
          await _tool(
            'update_account',
            client: fireflyMockClient(recordBodies: bodies),
          ).run({
            'account_id': '20',
            'account_number': '123456789',
            'iban': 'SE41 0000 0000 0012 3456 7890',
            'bic': 'NORDSESS',
            'notes': 'Statement text: BOLANEBANKEN',
            'active': true,
            'currency_code': 'SEK',
          });

      expect(result['ok'], isTrue);
      expect(bodies.single, contains('"account_number":"123456789"'));
      expect(bodies.single, contains('"bic":"NORDSESS"'));
      // updated_fields reports what was sent and nothing else, so a caller can
      // tell a dropped field from an applied one.
      expect(result['updated_fields'], [
        'iban',
        'bic',
        'account_number',
        'notes',
        'active',
        'currency_code',
      ]);
      expect((result as Map).containsKey('name'), isFalse);
    });

    test('a rename reports only name', () async {
      final result = await _tool(
        'update_account',
        client: fireflyMockClient(),
      ).run({'account_id': '5', 'name': 'Main'});

      expect(result['name'], 'Main');
      expect(result['updated_fields'], ['name']);
    });

    test('forwards liability terms and balances', () async {
      final bodies = <String>[];
      final result =
          await _tool(
            'update_account',
            client: fireflyMockClient(recordBodies: bodies),
          ).run({
            'account_id': '6',
            'type': 'liability',
            'account_role': 'ccAsset',
            'liability_type': 'mortgage',
            'liability_direction': 'debit',
            'interest': 2.5,
            'interest_period': 'half-year',
            'include_net_worth': false,
            'opening_balance': -1500.5,
            'opening_balance_date': '2026-01-01',
            'virtual_balance': 25,
          });

      expect(result['ok'], isTrue);
      expect(bodies.single, contains('"liability_type":"mortgage"'));
      expect(bodies.single, contains('"liability_direction":"debit"'));
      expect(bodies.single, contains('"interest_period":"half-year"'));
      expect(bodies.single, contains('"account_role":"ccAsset"'));
      expect(bodies.single, contains('"opening_balance":"-1500.50"'));
      expect(bodies.single, contains('"opening_balance_date":"2026-01-01"'));
      expect(bodies.single, contains('"virtual_balance":"25.00"'));
      expect(bodies.single, contains('"include_net_worth":false'));
      expect(result['updated_fields'], hasLength(10));
    });
  });

  group('transactions', () {
    test('create_transaction creates', () async {
      final result =
          await _tool('create_transaction', client: fireflyMockClient()).run({
            'type': 'withdrawal',
            'date': '2026-08-18',
            'amount': 34.0,
            'description': 'Lottery win',
            'source_id': '5',
            'destination_id': '9',
          });

      expect(result['ok'], isTrue);
      expect((result['transaction'] as Map)['id'], 'created-1');
    });

    test('create_transaction refuses an unknown type', () async {
      final calls = <Uri>[];
      final result =
          await _tool(
            'create_transaction',
            client: fireflyMockClient(record: calls),
          ).run({
            'type': 'refund',
            'date': '2026-08-18',
            'amount': 1,
            'description': 'x',
          });

      expect(result['code'], 'bad_input');
      expect(calls, isEmpty);
    });

    test('update_transaction keeps omitted fields', () async {
      final result = await _tool(
        'update_transaction',
        client: fireflyMockClient(),
      ).run({'transaction_id': '1', 'amount': 481.0});

      expect(result['ok'], isTrue);
      expect((result['transaction'] as Map)['id'], '1');
    });

    test('duplicate_transaction copies with overrides', () async {
      final result = await _tool(
        'duplicate_transaction',
        client: fireflyMockClient(),
      ).run({'transaction_id': '1', 'date': '2026-08-18', 'amount': 34.0});

      expect(result['ok'], isTrue);
      expect((result['transaction'] as Map)['id'], 'created-1');
    });

    test(
      'duplicate_transaction keeps the foreign side of a conversion',
      () async {
        // Firefly refuses a transfer between accounts of different currencies
        // without a foreign amount, so dropping it on the copy made every
        // cross-currency duplicate a 422.
        final bodies = <String>[];
        final result = await _tool(
          'duplicate_transaction',
          client: fireflyMockClient(
            transactionOverrides: {
              '1': transactionItem(
                id: '1',
                type: 'transfer',
                amount: '10000.00',
                foreignAmount: '14463.32',
                foreignCurrencyCode: 'SEK',
              ),
            },
            recordBodies: bodies,
          ),
        ).run({'transaction_id': '1', 'date': '2026-08-04'});

        expect(result['ok'], isTrue);
        final posted = jsonDecode(bodies.last) as Map<String, Object?>;
        final leg = (posted['transactions'] as List).first as Map;
        expect(leg['foreign_amount'], '14463.32');
        expect(leg['foreign_currency_code'], 'SEK');
      },
    );

    test(
      'duplicate_transaction refuses a new amount without a new rate',
      () async {
        // The rate cannot be read off the local amount, and carrying the old
        // foreign figure over would pair this month's amount with last month's
        // rate. Scaling it would invent a rate and record it as fact.
        await expectLater(
          _tool(
            'duplicate_transaction',
            client: fireflyMockClient(
              transactionOverrides: {
                '1': transactionItem(
                  id: '1',
                  type: 'transfer',
                  amount: '10000.00',
                  foreignAmount: '14463.32',
                  foreignCurrencyCode: 'SEK',
                ),
              },
            ),
          ).run({'transaction_id': '1', 'amount': 15000.0}),
          completion(
            containsPair(
              'error',
              allOf(contains('14463.32 SEK'), contains('pass foreign_amount')),
            ),
          ),
        );
      },
    );

    test('a stated foreign amount rides along with the new one', () async {
      final bodies = <String>[];
      final result =
          await _tool(
            'duplicate_transaction',
            client: fireflyMockClient(
              transactionOverrides: {
                '1': transactionItem(
                  id: '1',
                  type: 'transfer',
                  amount: '10000.00',
                  foreignAmount: '14463.32',
                  foreignCurrencyCode: 'SEK',
                ),
              },
              recordBodies: bodies,
            ),
          ).run({
            'transaction_id': '1',
            'date': '2026-08-04',
            'amount': 15000.0,
            'foreign_amount': 22036.25,
          });

      expect(result['ok'], isTrue);
      final leg =
          ((jsonDecode(bodies.last) as Map)['transactions'] as List).first
              as Map;
      expect(leg['amount'], '15000.00');
      expect(leg['foreign_amount'], '22036.25');
      expect(leg['foreign_currency_code'], 'SEK');
    });

    test('create_transaction can state both sides of a conversion', () async {
      // Without this there was no way to write a cross-currency transfer at
      // all: the field was not on the schema and never reached the payload.
      final bodies = <String>[];
      final result =
          await _tool(
            'create_transaction',
            client: fireflyMockClient(recordBodies: bodies),
          ).run({
            'type': 'transfer',
            'date': '2026-08-04',
            'amount': 15000.0,
            'description': 'Exchanged to SEK',
            'source_id': '5',
            'destination_id': '9',
            'foreign_amount': 22036.25,
            'foreign_currency_code': 'SEK',
          });

      expect(result['ok'], isTrue);
      final leg =
          ((jsonDecode(bodies.last) as Map)['transactions'] as List).first
              as Map;
      expect(leg['foreign_amount'], '22036.25');
      expect(leg['foreign_currency_code'], 'SEK');
    });

    test('a foreign amount of zero is refused, not written', () async {
      await expectLater(
        _tool('create_transaction', client: fireflyMockClient()).run({
          'type': 'transfer',
          'date': '2026-08-04',
          'amount': 15000.0,
          'description': 'Exchanged to SEK',
          'foreign_amount': 0,
        }),
        completion(
          containsPair('error', contains('foreign_amount must be greater')),
        ),
      );
    });

    test(
      'update_transaction keeps a reconciliation it was not asked about',
      () async {
        // Omitting the flag sent the model default of false, so any edit threw
        // away the reconciliation the person had asserted and a later refresh
        // was the first they heard of it.
        final bodies = <String>[];
        final result =
            await _tool(
              'update_transaction',
              client: fireflyMockClient(
                transactionOverrides: {
                  '1': transactionItem(id: '1', reconciled: true),
                },
                recordBodies: bodies,
              ),
            ).run({
              'transaction_id': '1',
              'notes': 'checked against the statement',
            });

        expect(result['ok'], isTrue);
        final leg =
            ((jsonDecode(bodies.last) as Map)['transactions'] as List).first
                as Map;
        expect(leg['reconciled'], isTrue);
      },
    );

    test(
      'update_transaction can release a reconciliation on purpose',
      () async {
        final bodies = <String>[];
        await _tool(
          'update_transaction',
          client: fireflyMockClient(
            transactionOverrides: {
              '1': transactionItem(id: '1', reconciled: true),
            },
            recordBodies: bodies,
          ),
        ).run({'transaction_id': '1', 'reconciled': false});

        final leg =
            ((jsonDecode(bodies.last) as Map)['transactions'] as List).first
                as Map;
        expect(leg['reconciled'], isFalse);
      },
    );

    test('moving the money on a reconciled transaction is refused', () async {
      // Firefly will not move it and toSplitJson drops the fields rather than
      // arguing, so the correction reported success and changed nothing.
      await expectLater(
        _tool(
          'update_transaction',
          client: fireflyMockClient(
            transactionOverrides: {
              '1': transactionItem(id: '1', reconciled: true),
            },
          ),
        ).run({'transaction_id': '1', 'amount': 37380.0}),
        completion(
          containsPair(
            'error',
            allOf(contains('reconciled'), contains('pass reconciled:false')),
          ),
        ),
      );
    });

    test('releasing and re-amounting in one call is allowed', () async {
      final bodies = <String>[];
      final result = await _tool(
        'update_transaction',
        client: fireflyMockClient(
          transactionOverrides: {
            '1': transactionItem(id: '1', reconciled: true),
          },
          recordBodies: bodies,
        ),
      ).run({'transaction_id': '1', 'amount': 37380.0, 'reconciled': false});

      expect(result['ok'], isTrue);
      final leg =
          ((jsonDecode(bodies.last) as Map)['transactions'] as List).first
              as Map;
      expect(leg['amount'], '37380.00');
      expect(leg['reconciled'], isFalse);
    });

    test('a copy of a reconciled transaction is not reconciled', () async {
      // Nothing has been checked against a statement yet, whatever was true of
      // the original.
      final bodies = <String>[];
      await _tool(
        'duplicate_transaction',
        client: fireflyMockClient(
          transactionOverrides: {
            '1': transactionItem(id: '1', reconciled: true),
          },
          recordBodies: bodies,
        ),
      ).run({'transaction_id': '1', 'date': '2026-08-18'});

      final leg =
          ((jsonDecode(bodies.last) as Map)['transactions'] as List).first
              as Map;
      expect(leg['reconciled'], isFalse);
    });

    test('an empty note removes the note', () async {
      // toSplitJson leaves an empty value out, so emptying a field and not
      // mentioning it looked identical on the wire and Firefly kept what it
      // had. A note could be set and never taken away.
      final bodies = <String>[];
      await _tool(
        'update_transaction',
        client: fireflyMockClient(
          transactionOverrides: {
            '1': transactionItem(id: '1', notes: 'bank text: ICA'),
          },
          recordBodies: bodies,
        ),
      ).run({'transaction_id': '1', 'notes': ''});

      final leg =
          ((jsonDecode(bodies.last) as Map)['transactions'] as List).first
              as Map;
      expect(leg['notes'], '');
    });

    test('an omitted note is left exactly as it was', () async {
      final bodies = <String>[];
      await _tool(
        'update_transaction',
        client: fireflyMockClient(
          transactionOverrides: {
            '1': transactionItem(id: '1', notes: 'bank text: ICA'),
          },
          recordBodies: bodies,
        ),
      ).run({'transaction_id': '1', 'description': 'Groceries'});

      final leg =
          ((jsonDecode(bodies.last) as Map)['transactions'] as List).first
              as Map;
      expect(leg['notes'], 'bank text: ICA');
    });

    test('an empty tag list removes the tags', () async {
      final bodies = <String>[];
      await _tool(
        'update_transaction',
        client: fireflyMockClient(
          transactionOverrides: {
            '1': transactionItem(id: '1', tags: ['groceries', 'shared']),
          },
          recordBodies: bodies,
        ),
      ).run({'transaction_id': '1', 'tags': <String>[]});

      final leg =
          ((jsonDecode(bodies.last) as Map)['transactions'] as List).first
              as Map;
      expect(leg['tags'], isEmpty);
    });

    test('duplicate_transaction fails when the source is gone', () async {
      await expectLater(
        _tool(
          'duplicate_transaction',
          client: fireflyMockClient(),
        ).run({'transaction_id': 'missing'}),
        throwsA(isA<Exception>()),
      );
    });

    test('get_transaction returns the legs of a split group', () async {
      // Regression: a group reported split_count and nothing else, so a caller
      // meaning to copy one could not see what it was copying. amount is the
      // group total while description belongs to the first leg, which read as
      // one payment of the whole sum labelled with its first line.
      final result = await _tool(
        'get_transaction',
        client: fireflyMockClient(
          transactionOverrides: {'77': _splitGroupItem()},
        ),
      ).run({'transaction_id': '77'});

      final group = result['transaction'] as Map<String, Object?>;
      expect(group['amount'], 1225.0);
      expect(group['split_count'], 2);
      final splits = (group['splits'] as List).cast<Map<String, Object?>>();
      expect(splits.map((s) => s['amount']), [1200.0, 25.0]);
      expect(splits.map((s) => s['description']), ['Rent', 'Service fee']);
      expect(splits.map((s) => s['journal_id']), ['811', '812']);
    });

    test('a listing still reports only how many legs there are', () async {
      // A 26-leg card bill in a 500-row page would be most of the response.
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(
          transactionOverrides: {'77': _splitGroupItem()},
        ),
      ).run({});

      final group = (result['transactions'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((t) => t['id'] == '77');
      expect(group['split_count'], 2);
      expect(group.containsKey('splits'), isFalse);
    });

    test('duplicate_transaction carries every leg of a split group', () async {
      // Regression: the copy was built from the top-level fields alone, so a
      // three-leg loan payment became one leg of the first leg's amount. The
      // money and the breakdown both went missing, silently.
      final bodies = <String>[];
      final result = await _tool(
        'duplicate_transaction',
        client: fireflyMockClient(
          transactionOverrides: {'77': _splitGroupItem()},
          recordBodies: bodies,
        ),
      ).run({'transaction_id': '77', 'date': '2026-03-01'});

      expect(result['ok'], isTrue);
      final sent = jsonDecode(bodies.single) as Map<String, Object?>;
      final legs = (sent['transactions'] as List).cast<Map<String, Object?>>();
      expect(legs.map((l) => l['amount']), ['1200.00', '25.00']);
      expect(legs.map((l) => l['description']), ['Rent', 'Service fee']);
      expect(sent['group_title'], 'Rent and fees');
      // Nothing has been checked against a statement yet.
      expect(legs.every((l) => l['reconciled'] == false), isTrue);
      expect(
        legs.every((l) => (l['date'] as String).startsWith('2026-03-01')),
        isTrue,
      );
    });

    test('duplicate_transaction refuses an amount for a split group', () async {
      // One figure does not say how to divide it, and guessing is how a fixed
      // amortisation gets scaled along with its interest.
      final calls = <Uri>[];
      final result = await _tool(
        'duplicate_transaction',
        client: fireflyMockClient(
          transactionOverrides: {'77': _splitGroupItem()},
          record: calls,
        ),
      ).run({'transaction_id': '77', 'amount': 1300});

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('2 legs'));
      expect(result['error'], contains('splits'));
      expect(calls.where((u) => u.path.endsWith('/transactions')), isEmpty);
    });

    test('create_transaction writes the legs it is given', () async {
      final bodies = <String>[];
      final result =
          await _tool(
            'create_transaction',
            client: fireflyMockClient(recordBodies: bodies),
          ).run({
            'type': 'withdrawal',
            'date': '2026-09-01',
            'amount': 9889,
            'description': 'Mortgage',
            'source_id': '5',
            'currency_code': 'EUR',
            'splits': [
              {
                'amount': 3400,
                'description': 'Amortisation',
                'destination_name': 'Lender',
              },
              {
                'amount': 3508,
                'description': 'Interest 1',
                'destination_name': 'Lender',
              },
              {
                'amount': 2981,
                'description': 'Interest 2',
                'destination_name': 'Lender',
              },
            ],
          });

      expect(result['ok'], isTrue);
      final sent = jsonDecode(bodies.single) as Map<String, Object?>;
      final legs = (sent['transactions'] as List).cast<Map<String, Object?>>();
      expect(legs.map((l) => l['amount']), ['3400.00', '3508.00', '2981.00']);
      // The account and currency were given once for the group.
      expect(legs.every((l) => l['source_id'] == '5'), isTrue);
      expect(legs.every((l) => l['currency_code'] == 'EUR'), isTrue);
      expect(sent['group_title'], 'Mortgage');
    });

    test('create_transaction refuses a leg without an amount', () async {
      final calls = <Uri>[];
      final result =
          await _tool(
            'create_transaction',
            client: fireflyMockClient(record: calls),
          ).run({
            'type': 'withdrawal',
            'date': '2026-09-01',
            'amount': 100,
            'description': 'Mortgage',
            'splits': [
              {'amount': 60, 'description': 'One'},
              {'description': 'Two'},
            ],
          });

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('splits[1].amount'));
      expect(calls.where((u) => u.path.endsWith('/transactions')), isEmpty);
    });

    test('delete_transaction deletes the group', () async {
      final result = await _tool(
        'delete_transaction',
        client: fireflyMockClient(),
      ).run({'transaction_id': '1'});

      expect(result['ok'], isTrue);
      expect(result['deleted'], isTrue);
    });

    test('a listing carries the journal id and the group title', () async {
      // match_statement reports one leg of a split, and only the journal id
      // addresses a leg: the group id reaches every leg at once.
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(
          transactionOverrides: {'77': _splitGroupItem()},
        ),
      ).run({});

      final listed = (result['transactions'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final group = listed.firstWhere((t) => t['id'] == '77');

      expect(group['journal_id'], '811');
      expect(group['group_title'], 'Rent and fees');
      expect(group['split_count'], 2);
    });

    test('export_firefly_data snapshots every entity with a receipt', () async {
      final result = await _tool(
        'export_firefly_data',
        client: fireflyMockClient(),
      ).run({});

      expect(result['ok'], isTrue);
      final export = result['export'] as Map<String, Object?>;
      final counts = export['counts'] as Map<String, Object?>;
      expect(counts['accounts'], greaterThan(0));
      expect(counts['transactions'], greaterThan(0));
      expect(export['transactions'], isA<List<Object?>>());
      // A snapshot that read like a backup would be worse than none.
      expect(export['excludes'], contains('database'));
    });

    test('export_firefly_data counts_only leaves the rows out', () async {
      final result = await _tool(
        'export_firefly_data',
        client: fireflyMockClient(),
      ).run({'counts_only': true});

      final export = result['export'] as Map<String, Object?>;
      expect(result['counts_only'], isTrue);
      expect((export['counts'] as Map)['accounts'], greaterThan(0));
      expect(export.containsKey('transactions'), isFalse);
      expect(export.containsKey('accounts'), isFalse);
      // The receipt still says what a full snapshot would and would not hold.
      expect(export['excludes'], contains('database'));
      expect(export['covers'], contains('transactions'));
    });

    test('export_firefly_data refuses an inverted window', () async {
      final result = await _tool(
        'export_firefly_data',
        client: fireflyMockClient(),
      ).run({'start_date': '2026-02-01', 'end_date': '2026-01-01'});

      expect(result['code'], 'bad_input');
    });

    test(
      'find_incomplete_transactions reports the rows and the counts',
      () async {
        final result =
            await _tool(
              'find_incomplete_transactions',
              client: fireflyMockClient(),
            ).run({
              'fields': ['tags'],
            });

        expect(result['ok'], isTrue);
        final listed = (result['transactions'] as List)
            .cast<Map<String, Object?>>();
        // Only the first mock row carries tags.
        expect(listed.map((t) => t['id']), containsAll(['2', '3']));
        expect(
          listed.every((t) => (t['missing'] as List).contains('tags')),
          isTrue,
        );
        expect((result['missing_counts'] as Map)['tags'], listed.length);
      },
    );

    test(
      'find_incomplete_transactions never asks a deposit for a budget',
      () async {
        // The deposit in the mock has no budget and never can have one, so only
        // the withdrawal without one is work anybody can do.
        final result =
            await _tool(
              'find_incomplete_transactions',
              client: fireflyMockClient(),
            ).run({
              'fields': ['budget'],
            });

        final ids = (result['transactions'] as List)
            .cast<Map<String, Object?>>()
            .map((t) => t['id']);
        expect(ids, ['3']);
        expect((result['missing_counts'] as Map)['budget'], 1);
      },
    );

    test('find_incomplete_transactions refuses an unknown field', () async {
      final calls = <Uri>[];
      final result =
          await _tool(
            'find_incomplete_transactions',
            client: fireflyMockClient(record: calls),
          ).run({
            'fields': ['colour'],
          });

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('colour'));
      expect(calls, isEmpty);
    });

    test('search_transactions searches by description', () async {
      final calls = <Uri>[];
      final result = await _tool(
        'search_transactions',
        client: fireflyMockClient(record: calls),
      ).run({'query': 'Groceries'});

      expect(result['ok'], isTrue);
      expect(result['transactions'], isNotEmpty);
      expect(
        calls.any((u) => u.queryParameters['query'] == 'Groceries'),
        isTrue,
      );
    });
  });

  group('budget limits', () {
    test('get_budget_limits lists periods', () async {
      final result = await _tool(
        'get_budget_limits',
        client: fireflyMockClient(),
      ).run({'budget_id': '3'});

      expect(result['ok'], isTrue);
      expect((result['limits'] as List).single, containsPair('amount', 400.0));
    });

    test('create_budget_limit sets one period', () async {
      final result =
          await _tool('create_budget_limit', client: fireflyMockClient()).run({
            'budget_id': '3',
            'start_date': '2026-01-01',
            'end_date': '2026-01-31',
            'amount': 400,
          });

      expect(result['ok'], isTrue);
      expect((result['limit'] as Map)['amount'], 400.0);
    });

    test('update_budget_limit changes the amount', () async {
      final result =
          await _tool('update_budget_limit', client: fireflyMockClient()).run({
            'budget_id': '3',
            'limit_id': '11',
            'start_date': '2026-01-01',
            'end_date': '2026-01-31',
            'amount': 450,
          });

      expect(result['ok'], isTrue);
      expect(result['budget_id'], '3');
      expect(result['limit_id'], '11');
    });

    test('create_budget_limit rejects an inverted window', () async {
      final calls = <Uri>[];
      final result =
          await _tool(
            'create_budget_limit',
            client: fireflyMockClient(record: calls),
          ).run({
            'budget_id': '3',
            'start_date': '2026-01-31',
            'end_date': '2026-01-01',
            'amount': 400,
          });

      expect(result['code'], 'bad_input');
      expect(calls, isEmpty);
    });

    test('create_budget creates', () async {
      final result = await _tool(
        'create_budget',
        client: fireflyMockClient(),
      ).run({'name': 'Travel'});

      expect(result['ok'], isTrue);
      expect((result['budget'] as Map)['name'], 'Food');
    });
  });

  group('categories and tags', () {
    test('get_categories lists', () async {
      final result = await _tool(
        'get_categories',
        client: fireflyMockClient(),
      ).run({});

      expect(result['ok'], isTrue);
      expect(
        (result['categories'] as List).single,
        containsPair('name', 'Food'),
      );
    });

    test('create, rename and delete a category', () async {
      final client = fireflyMockClient();
      expect(
        (await _tool(
          'create_category',
          client: client,
        ).run({'name': 'Groceries'}))['ok'],
        isTrue,
      );
      expect(
        ((await _tool(
              'update_category',
              client: client,
            ).run({'category_id': 'c1', 'name': 'Renamed'}))['category']
            as Map)['name'],
        'Renamed',
      );
      expect(
        (await _tool(
          'delete_category',
          client: client,
        ).run({'category_id': 'c1'}))['deleted'],
        isTrue,
      );
    });

    test('get_tags lists', () async {
      final result = await _tool(
        'get_tags',
        client: fireflyMockClient(),
      ).run({});

      expect(result['ok'], isTrue);
      expect((result['tags'] as List).single, containsPair('name', 'urgent'));
    });

    test('create, rename and delete a tag', () async {
      final client = fireflyMockClient();
      expect(
        (await _tool(
          'create_tag',
          client: client,
        ).run({'tag': 'shared'}))['ok'],
        isTrue,
      );
      expect(
        ((await _tool(
              'update_tag',
              client: client,
            ).run({'tag_id': 't1', 'tag': 'renamed'}))['tag']
            as Map)['name'],
        'renamed',
      );
      expect(
        (await _tool(
          'delete_tag',
          client: client,
        ).run({'tag_id': 't1'}))['deleted'],
        isTrue,
      );
    });
  });

  group('bills', () {
    test('get_bills lists with amount ranges', () async {
      final result = await _tool(
        'get_bills',
        client: fireflyMockClient(),
      ).run({});

      expect(result['ok'], isTrue);
      final bill = (result['bills'] as List).single as Map<String, Object?>;
      expect(bill['name'], 'Rent');
      expect(bill['amount_min'], 1200.0);
      expect(bill['date'], '2026-03-01');
    });

    test('create_bill creates', () async {
      final result = await _tool('create_bill', client: fireflyMockClient())
          .run({
            'name': 'Rent',
            'amount_min': 1200,
            'amount_max': 1250,
            'date': '2026-03-01',
            'repeat_frequency': 'monthly',
            'currency_code': 'EUR',
          });

      expect(result['ok'], isTrue);
      expect((result['bill'] as Map)['name'], 'Rent');
    });

    test('create_bill refuses an unknown frequency', () async {
      final bodies = <String>[];
      final result =
          await _tool(
            'create_bill',
            client: fireflyMockClient(recordBodies: bodies),
          ).run({
            'name': 'Rent',
            'amount_min': 1,
            'amount_max': 2,
            'date': '2026-03-01',
            'repeat_frequency': 'fortnightly',
          });

      // Firefly's own parser would quietly read an unknown frequency as
      // monthly, so the bill has to be refused before anything is written.
      expect(result['code'], 'bad_input');
      expect(result['error'], contains('repeat_frequency'));
      expect(bodies, isEmpty);
    });

    test('update_bill keeps omitted fields', () async {
      final result = await _tool(
        'update_bill',
        client: fireflyMockClient(),
      ).run({'bill_id': '9', 'name': 'Rent raised'});

      expect(result['ok'], isTrue);
      expect((result['bill'] as Map)['name'], 'Rent raised');
    });

    test('delete_bill deletes', () async {
      final result = await _tool(
        'delete_bill',
        client: fireflyMockClient(),
      ).run({'bill_id': '9'});

      expect(result['deleted'], isTrue);
    });

    test('get_bill_transactions pages', () async {
      final result = await _tool(
        'get_bill_transactions',
        client: fireflyMockClient(),
      ).run({'bill_id': '9', 'limit': 5});

      expect(result['ok'], isTrue);
      expect(result['transactions'], isNotEmpty);
      expect(result['pagination'], isA<Map<String, Object?>>());
    });
  });

  group('piggy banks', () {
    test('get_piggy_banks lists progress', () async {
      final result = await _tool(
        'get_piggy_banks',
        client: fireflyMockClient(),
      ).run({});

      expect(result['ok'], isTrue);
      final piggy =
          (result['piggy_banks'] as List).single as Map<String, Object?>;
      expect(piggy['target_amount'], 2500.0);
      expect(piggy['current_amount'], 100.0);
    });

    test('create_piggy_bank creates', () async {
      final result =
          await _tool('create_piggy_bank', client: fireflyMockClient()).run({
            'name': 'New Laptop',
            'target_amount': 2500,
            'account_ids': ['5'],
            'start_date': '2026-01-01',
            'currency_code': 'EUR',
          });

      expect(result['ok'], isTrue);
      expect((result['piggy_bank'] as Map)['name'], 'New Laptop');
    });

    test('create_piggy_bank refuses an empty account list', () async {
      final calls = <Uri>[];
      final result =
          await _tool(
            'create_piggy_bank',
            client: fireflyMockClient(record: calls),
          ).run({
            'name': 'X',
            'target_amount': 1,
            'account_ids': <String>[],
            'start_date': '2026-01-01',
          });

      expect(result['code'], 'bad_input');
      expect(calls, isEmpty);
    });

    test('update_piggy_bank updates', () async {
      final result = await _tool(
        'update_piggy_bank',
        client: fireflyMockClient(),
      ).run({'piggy_bank_id': '4', 'name': 'Laptop 2'});

      expect((result['piggy_bank'] as Map)['name'], 'Laptop 2');
    });

    test('delete_piggy_bank deletes', () async {
      final result = await _tool(
        'delete_piggy_bank',
        client: fireflyMockClient(),
      ).run({'piggy_bank_id': '4'});

      expect(result['deleted'], isTrue);
    });
  });

  group('recurrences', () {
    Map<String, Object?> recurrenceArgs() => {
      'title': 'Rent',
      'first_date': '2026-09-01',
      'type': 'withdrawal',
      'amount': 1200,
      'description': 'Rent payment',
      'source_id': '5',
      'destination_id': '9',
      'repetition_type': 'monthly',
      'moment': '1',
      'currency_code': 'EUR',
    };

    test('get_recurrences lists rules with their repetition', () async {
      final result = await _tool(
        'get_recurrences',
        client: fireflyMockClient(),
      ).run({});

      expect(result['ok'], isTrue);
      final rule =
          (result['recurrences'] as List).single as Map<String, Object?>;
      expect(rule['title'], 'Salary');
      expect(rule['first_date'], '2026-09-01');
    });

    test('get_recurrences names what each rule moves and between which '
        'accounts', () async {
      // Regression: the listing carried only a title and its dates, so a
      // ledger with one standing transfer per person offered nothing but
      // identical titles and a caller could not say which rule to correct.
      final result = await _tool(
        'get_recurrences',
        client: fireflyMockClient(),
      ).run({});

      final rule =
          (result['recurrences'] as List).single as Map<String, Object?>;
      expect(rule['type'], 'withdrawal');

      final line =
          (rule['transactions'] as List).single as Map<String, Object?>;
      expect(line['amount'], 1200.0);
      expect(line['currency_code'], 'EUR');
      expect(line['source_name'], 'Joint Current');
      expect(line['destination_name'], 'Landlord');
      expect(line['category_name'], 'Housing');
      expect(line['budget_name'], 'Fixed costs');
      expect(line['tags'], ['standing']);

      final repetition =
          (rule['repetitions'] as List).single as Map<String, Object?>;
      expect(repetition['type'], 'monthly');
      expect(repetition['moment'], '1');
      expect(repetition['weekend'], 'createAnyway');
    });

    test('create_recurrence creates a rule', () async {
      final result = await _tool(
        'create_recurrence',
        client: fireflyMockClient(),
      ).run(recurrenceArgs());

      expect(result['ok'], isTrue);
      expect((result['recurrence'] as Map)['id'], '12');
    });

    test('create_recurrence refuses an unknown repetition type', () async {
      final calls = <Uri>[];
      final result = await _tool(
        'create_recurrence',
        client: fireflyMockClient(record: calls),
      ).run({...recurrenceArgs(), 'repetition_type': 'fortnightly'});

      expect(result['code'], 'bad_input');
      expect(calls, isEmpty);
    });

    test('update_recurrence replaces the rule', () async {
      final result =
          await _tool('update_recurrence', client: fireflyMockClient()).run({
            ...recurrenceArgs(),
            'recurrence_id': '12',
            'title': 'Rent raised',
          });

      expect(result['ok'], isTrue);
      expect((result['recurrence'] as Map)['title'], 'Salary raised');
    });

    test('delete_recurrence deletes', () async {
      final result = await _tool(
        'delete_recurrence',
        client: fireflyMockClient(),
      ).run({'recurrence_id': '12'});

      expect(result['deleted'], isTrue);
    });

    test('get_recurrence_transactions pages', () async {
      final result = await _tool(
        'get_recurrence_transactions',
        client: fireflyMockClient(),
      ).run({'recurrence_id': '12'});

      expect(result['ok'], isTrue);
      expect(result['transactions'], isNotEmpty);
    });
  });

  group('currencies', () {
    test('get_currencies lists which are enabled', () async {
      final result = await _tool(
        'get_currencies',
        client: fireflyMockClient(),
      ).run({});

      expect(result['ok'], isTrue);
      expect(
        (result['currencies'] as List).single,
        containsPair('code', 'EUR'),
      );
    });
  });

  group('per-field validation', () {
    // The sweep above passes an empty map, which trips only the first check in
    // each builder. These pin the rest, so a field that stops being validated
    // reaches Firefly as a malformed write instead of a message.
    Future<Map<String, Object?>> run(
      String tool,
      Map<String, Object?> args,
    ) async {
      final calls = <Uri>[];
      final result = await _tool(
        tool,
        client: fireflyMockClient(record: calls),
      ).run(args);
      expect(result['code'], 'bad_input', reason: '$tool $args');
      return result;
    }

    Map<String, Object?> transaction() => {
      'type': 'withdrawal',
      'date': '2026-08-18',
      'amount': 10.0,
      'description': 'Groceries',
      'source_id': '5',
      'destination_id': '9',
    };

    test('a transaction needs an amount, a description and a date', () async {
      expect(
        (await run('create_transaction', {
          ...transaction(),
          'amount': 0,
        }))['error'],
        contains('amount'),
      );
      expect(
        (await run('create_transaction', {
          ...transaction(),
          'description': '  ',
        }))['error'],
        contains('description'),
      );
      final noDate = {...transaction()}..remove('date');
      expect(
        (await run('create_transaction', noDate))['error'],
        contains('date'),
      );
    });

    test('a budget limit needs a window and a positive amount', () async {
      final base = {
        'budget_id': '3',
        'start_date': '2026-01-01',
        'end_date': '2026-01-31',
        'amount': 100.0,
      };
      expect(
        (await run('create_budget_limit', {...base, 'amount': 0}))['error'],
        contains('amount'),
      );
      final noStart = {...base}..remove('start_date');
      expect(
        (await run('create_budget_limit', noStart))['error'],
        contains('start_date'),
      );
      final noEnd = {...base}..remove('end_date');
      expect(
        (await run('create_budget_limit', noEnd))['error'],
        contains('end_date'),
      );
    });

    test('a bill needs both amounts, in order, and a date', () async {
      final base = {
        'name': 'Rent',
        'amount_min': 10.0,
        'amount_max': 20.0,
        'date': '2026-03-01',
      };
      final noMax = {...base}..remove('amount_max');
      expect(
        (await run('create_bill', noMax))['error'],
        contains('amount_min'),
      );
      expect(
        (await run('create_bill', {...base, 'amount_min': 0}))['error'],
        contains('greater than zero'),
      );
      expect(
        (await run('create_bill', {...base, 'amount_max': 5.0}))['error'],
        contains('below'),
      );
      final noDate = {...base}..remove('date');
      expect((await run('create_bill', noDate))['error'], contains('date'));
    });

    test('a bill falls back to the instance currency', () async {
      final result = await _tool('create_bill', client: fireflyMockClient())
          .run({
            'name': 'Rent',
            'amount_min': 10.0,
            'amount_max': 20.0,
            'date': '2026-03-01',
          });

      expect(result['ok'], isTrue);
      expect((result['bill'] as Map)['currency_code'], 'EUR');
    });

    test('a piggy bank needs a positive target and a start date', () async {
      final base = {
        'name': 'Laptop',
        'target_amount': 100.0,
        'account_ids': ['5'],
        'start_date': '2026-01-01',
      };
      expect(
        (await run('create_piggy_bank', {
          ...base,
          'target_amount': 0,
        }))['error'],
        contains('target_amount'),
      );
      final noStart = {...base}..remove('start_date');
      expect(
        (await run('create_piggy_bank', noStart))['error'],
        contains('start_date'),
      );
    });

    test('a piggy bank falls back to the instance currency', () async {
      final result =
          await _tool('create_piggy_bank', client: fireflyMockClient()).run({
            'name': 'Laptop',
            'target_amount': 100.0,
            'account_ids': ['5'],
            'start_date': '2026-01-01',
          });

      expect(result['ok'], isTrue);
      expect((result['piggy_bank'] as Map)['currency_code'], 'EUR');
    });

    test(
      'a recurrence needs each part of the transaction it repeats',
      () async {
        final base = {
          'title': 'Rent',
          'first_date': '2026-09-01',
          'type': 'withdrawal',
          'amount': 1200.0,
          'description': 'Rent payment',
          'source_id': '5',
          'destination_id': '9',
        };
        for (final field in [
          'first_date',
          'description',
          'source_id',
          'destination_id',
        ]) {
          final args = {...base}..remove(field);
          expect(
            (await run('create_recurrence', args))['error'],
            contains(field),
            reason: field,
          );
        }
        expect(
          (await run('create_recurrence', {...base, 'amount': 0}))['error'],
          contains('amount'),
        );
      },
    );

    test('a recurrence reports its end date as a calendar day', () async {
      final result =
          await _tool('create_recurrence', client: fireflyMockClient()).run({
            'title': 'Rent',
            'first_date': '2026-09-01',
            'repeat_until': '2027-09-01',
            'type': 'withdrawal',
            'amount': 1200.0,
            'description': 'Rent payment',
            'source_id': '5',
            'destination_id': '9',
          });

      expect(result['ok'], isTrue);
    });
  });

  group('client-side pagination', () {
    test(
      'an account page filtered by reconciled paginates in memory',
      () async {
        // Firefly cannot filter by reconciled, so the page is cut here, and a
        // slice past the end has to come back empty rather than throwing.
        final tool = _tool('get_transactions', client: fireflyMockClient());

        final first = await tool.run({
          'account_id': '5',
          'reconciled': true,
          'page': 1,
          'limit': 1,
        });
        expect(first['ok'], isTrue);
        expect((first['pagination'] as Map)['filtered_client_side'], isTrue);

        final past = await tool.run({
          'account_id': '5',
          'reconciled': true,
          'page': 99,
          'limit': 1,
        });
        expect(past['transactions'], isEmpty);
      },
    );
  });

  group('update_budget', () {
    test('an unknown budget is refused rather than created', () async {
      final result = await _tool(
        'update_budget',
        client: fireflyMockClient(),
      ).run({'budget_id': 'missing', 'name': 'Nope'});

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('missing'));
    });

    test('an omitted auto-budget keeps the one already set', () async {
      final bodies = <String>[];
      final result = await _tool(
        'update_budget',
        client: fireflyMockClient(recordBodies: bodies),
      ).run({'budget_id': '3', 'name': 'Food renamed'});

      // Firefly rejects auto_budget_type 'none' without an amount, so an
      // update that says nothing about it has to resend what is there.
      expect(result['ok'], isTrue);
      expect(bodies.single, contains('auto_budget'));
    });
  });

  group('update paths on entities that are gone or malformed', () {
    test('updating a bill or piggy bank that is gone is refused', () async {
      expect(
        (await _tool(
          'update_bill',
          client: fireflyMockClient(),
        ).run({'bill_id': 'missing', 'name': 'x'}))['error'],
        contains('missing'),
      );
      expect(
        (await _tool(
          'update_piggy_bank',
          client: fireflyMockClient(),
        ).run({'piggy_bank_id': 'missing', 'name': 'x'}))['error'],
        contains('missing'),
      );
    });

    test('a bad field on an update is refused, not sent', () async {
      final bodies = <String>[];
      expect(
        (await _tool(
          'update_bill',
          client: fireflyMockClient(recordBodies: bodies),
        ).run({'bill_id': '9', 'amount_min': 0}))['code'],
        'bad_input',
      );
      expect(
        (await _tool(
          'update_piggy_bank',
          client: fireflyMockClient(recordBodies: bodies),
        ).run({'piggy_bank_id': '4', 'target_amount': 0}))['code'],
        'bad_input',
      );
      expect(
        (await _tool(
          'update_recurrence',
          client: fireflyMockClient(recordBodies: bodies),
        ).run({'recurrence_id': '12', 'title': ''}))['code'],
        'bad_input',
      );
      expect(bodies, isEmpty, reason: 'nothing may be written');
    });

    test('a budget limit update needs the limit it is changing', () async {
      final result =
          await _tool('update_budget_limit', client: fireflyMockClient()).run({
            'budget_id': '3',
            'start_date': '2026-01-01',
            'end_date': '2026-01-31',
            'amount': 100,
          });

      expect(result['error'], contains('limit_id'));
    });

    test('an unparseable date on a limit is refused', () async {
      expect(
        (await _tool('create_budget_limit', client: fireflyMockClient()).run({
          'budget_id': '3',
          'start_date': 'whenever',
          'end_date': '2026-01-31',
          'amount': 100,
        }))['code'],
        'bad_input',
      );
    });
  });

  group('remaining account and transaction paths', () {
    test('an account window is paged in memory, not by Firefly', () async {
      // Firefly's paged account endpoint takes no date range, so a statement
      // period would end up split across pages if this paged first.
      final tool = _tool('get_transactions', client: fireflyMockClient());

      final result = await tool.run({
        'account_id': '5',
        'start_date': '2026-01-01',
        'end_date': '2026-12-31',
        'page': 1,
        'limit': 1,
      });

      expect(result['ok'], isTrue);
      expect((result['pagination'] as Map)['current_page'], 1);
      expect(result['transactions'], hasLength(1));

      final past = await tool.run({
        'account_id': '5',
        'start_date': '2026-01-01',
        'end_date': '2026-12-31',
        'page': 99,
        'limit': 1,
      });
      expect(past['transactions'], isEmpty);
    });

    test('a transaction carries the tags it was given', () async {
      final bodies = <String>[];
      final result =
          await _tool(
            'create_transaction',
            client: fireflyMockClient(recordBodies: bodies),
          ).run({
            'type': 'withdrawal',
            'date': '2026-08-18',
            'amount': 10.0,
            'description': 'Groceries',
            'source_id': '5',
            'destination_id': '9',
            'tags': ['weekly', 'shared'],
          });

      expect(result['ok'], isTrue);
      expect(bodies.single, contains('weekly'));
    });

    test('create_account needs a currency', () async {
      final result = await _tool(
        'create_account',
        client: fireflyMockClient(),
      ).run({'name': 'Savings', 'type': 'asset'});

      expect(result['error'], contains('currency_code'));
    });

    test('create_liability refuses an unknown direction', () async {
      final result =
          await _tool('create_liability', client: fireflyMockClient()).run({
            'name': 'Loan',
            'liability_type': 'loan',
            'liability_direction': 'sideways',
          });

      expect(result['error'], contains('liability_direction'));
    });

    test('create_liability falls back to the instance currency', () async {
      final bodies = <String>[];
      final result =
          await _tool(
            'create_liability',
            client: fireflyMockClient(recordBodies: bodies),
          ).run({
            'name': 'Loan',
            'liability_type': 'loan',
            'liability_direction': 'credit',
          });

      expect(result['ok'], isTrue);
      expect(bodies.single, contains('EUR'));
    });

    test('a liability with an unparseable start date is refused', () async {
      expect(
        (await _tool('create_liability', client: fireflyMockClient()).run({
          'name': 'Loan',
          'liability_type': 'loan',
          'liability_direction': 'credit',
          'start_date': 'someday',
        }))['code'],
        'bad_input',
      );
    });

    test('balance history needs both ends of its window', () async {
      final noStart =
          await _tool(
            'get_account_balance_history',
            client: fireflyMockClient(),
          ).run({
            'account_ids': ['5'],
            'end_date': '2026-02-01',
          });
      expect(noStart['error'], contains('start_date'));

      final noEnd =
          await _tool(
            'get_account_balance_history',
            client: fireflyMockClient(),
          ).run({
            'account_ids': ['5'],
            'start_date': '2026-01-01',
          });
      expect(noEnd['error'], contains('end_date'));

      final bad =
          await _tool(
            'get_account_balance_history',
            client: fireflyMockClient(),
          ).run({
            'account_ids': ['5'],
            'start_date': 'whenever',
            'end_date': '2026-02-01',
          });
      expect(bad['code'], 'bad_input');
    });

    test('an auto-budget amount replaces a none type', () async {
      final bodies = <String>[];
      final result = await _tool(
        'update_budget',
        client: fireflyMockClient(recordBodies: bodies),
      ).run({'budget_id': '3', 'name': 'Food', 'amount': 500});

      // Firefly has no way to clear an auto-budget, so an amount with no type
      // has to pick one rather than send 'none' and be rejected.
      expect(result['ok'], isTrue);
      expect(bodies.single, isNot(contains('"auto_budget_type":"none"')));
    });
  });

  group('unparseable dates are refused before any request', () {
    // Every tool that takes a date parses it the same way, and each has to turn
    // a bad one into a message rather than an exception escaping the call.
    test('across every tool that accepts one', () async {
      final cases = <String, Map<String, Object?>>{
        'update_transaction': {'transaction_id': '1', 'date': 'whenever'},
        'duplicate_transaction': {'transaction_id': '1', 'date': 'whenever'},
        'get_account': {'account_id': '5', 'date': 'whenever'},
        'get_account_balance_at_date': {'account_id': '5', 'date': 'whenever'},
        'get_budget_limits': {'budget_id': '3', 'start_date': 'whenever'},
        'update_budget_limit': {
          'budget_id': '3',
          'limit_id': '11',
          'start_date': 'whenever',
          'end_date': '2026-01-31',
          'amount': 100,
        },
      };

      for (final entry in cases.entries) {
        final calls = <Uri>[];
        final result = await _tool(
          entry.key,
          client: fireflyMockClient(record: calls),
        ).run(entry.value);

        expect(result['code'], 'bad_input', reason: entry.key);
      }
    });

    test('a balance needs the date it is asked for', () async {
      final result = await _tool(
        'get_account_balance_at_date',
        client: fireflyMockClient(),
      ).run({'account_id': '5'});

      expect(result['error'], contains('date'));
    });

    test('a budget limit window reaches the day it says', () async {
      final calls = <Uri>[];
      await _tool(
        'get_budget_limits',
        client: fireflyMockClient(record: calls),
      ).run({
        'budget_id': '3',
        'start_date': '2026-01-01',
        'end_date': '2026-01-31',
      });

      // end_date is inclusive to the caller and exclusive on this endpoint, so
      // the day after is what goes out. The transactions range converts the
      // other way, which is why each one is pinned separately.
      final ranged = calls.where((u) => u.queryParameters.containsKey('start'));
      expect(ranged, isNotEmpty);
      expect(ranged.first.queryParameters['start'], '2026-01-01');
      expect(ranged.first.queryParameters['end'], '2026-02-01');
    });

    test(
      'a new budget with an amount gets a usable auto-budget type',
      () async {
        final bodies = <String>[];
        final result = await _tool(
          'create_budget',
          client: fireflyMockClient(recordBodies: bodies),
        ).run({'name': 'Travel', 'amount': 300});

        expect(result['ok'], isTrue);
        expect(bodies.single, isNot(contains('"auto_budget_type":"none"')));
      },
    );

    test('a recurring rule reports its end date as a calendar day', () async {
      final result = await _tool(
        'get_recurrences',
        client: fireflyMockClient(),
      ).run({});

      final rule =
          (result['recurrences'] as List).single as Map<String, Object?>;
      expect(rule['repeat_until'], '2027-09-01');
    });
  });

  group('find_account', () {
    test('an account number beats a name that also matches', () async {
      // An identifier hit ends the search, so a fuzzy name tier can never be
      // appended below one and read as an equally good answer.
      final result = await _tool(
        'find_account',
        client: fireflyMockClient(),
      ).run({'query': 'Checking'});

      expect(result['ok'], isTrue);
      expect(result['candidates'], isA<List<Object?>>());
      expect(result['ambiguity_band'], isA<num>());
      expect(result['searched_types'], [
        'asset',
        'liability',
        'expense',
        'revenue',
      ]);
    });

    test('never returns the identifier it matched on', () async {
      final result = await _tool(
        'find_account',
        client: fireflyMockClient(),
      ).run({'query': 'Checking'});

      // The matcher needs the IBAN and the account number; the transcript does
      // not. A candidate carries a last-four hint and nothing more.
      final encoded = jsonEncode(result);
      expect(encoded, isNot(contains('"iban":')));
      expect(encoded, isNot(contains('"account_number":')));
      for (final candidate
          in (result['candidates'] as List<Object?>)
              .cast<Map<String, Object?>>()) {
        expect(candidate.containsKey('has_iban'), isTrue);
        expect(candidate.containsKey('identifier_hint'), isTrue);
        expect(candidate['confidence'], isA<String>());
      }
    });

    test('validates its own arguments before any request', () async {
      final calls = <Uri>[];
      final tool = _tool(
        'find_account',
        client: fireflyMockClient(record: calls),
      );

      expect((await tool.run({}))['code'], 'bad_input');
      expect((await tool.run({'query': '  '}))['code'], 'bad_input');
      expect(
        (await tool.run({
          'query': 'x',
          'types': ['chequing'],
        }))['error'],
        contains('chequing'),
      );
      expect(
        (await tool.run({'query': 'x', 'limit': 99}))['error'],
        contains('limit'),
      );
      expect(calls, isEmpty);
    });
  });

  group('find_account collisions', () {
    test('a shared key comes back on the wire, keyed by its tier', () async {
      // The engine's collisions map is tested, but nothing pinned the shape an
      // agent actually reads, and the map is keyed by every matching tier, not
      // only identifiers.
      final client = fireflyMockClient(collidingNames: true);
      final result = await _tool(
        'find_account',
        client: client,
      ).run({'query': 'Sparkonto'});

      final collisions = (result['collisions'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(collisions, isNotEmpty);
      for (final collision in collisions) {
        expect(collision['key'], isA<String>());
        expect(collision['key'], contains(':'));
        expect(collision['account_ids'], isA<List<Object?>>());
        expect((collision['account_ids'] as List).length, greaterThan(1));
      }
      expect(result['ambiguous'], isTrue);
      for (final candidate
          in (result['candidates'] as List<Object?>)
              .cast<Map<String, Object?>>()) {
        expect(candidate['confidence'], isNot('exact'));
      }
    });
  });

  group('find_account batching', () {
    test('many texts resolve from one read of the accounts', () async {
      // A ledger here holds nearly two thousand payees and takes seconds to
      // read. Resolving a statement one row at a time paid that per row.
      final calls = <Uri>[];
      final result =
          await _tool(
            'find_account',
            client: fireflyMockClient(record: calls),
          ).run({
            'queries': ['Checking', 'BOLANEBANK', 'nothing like an account'],
            'types': ['asset', 'expense'],
          });

      expect(result['ok'], isTrue);
      final results = (result['results'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(results, hasLength(3));
      expect(results.map((r) => r['query']), [
        'Checking',
        'BOLANEBANK',
        'nothing like an account',
      ]);
      // Each text gets its own verdict, including none at all.
      expect(results.last['candidate_count'], 0);
      expect(result['accounts_read'], isA<int>());

      // Two account types, so two list requests however many texts were given.
      final listed = calls.where(
        (u) =>
            u.path.endsWith('/accounts') &&
            u.queryParameters.containsKey('type'),
      );
      expect(listed, hasLength(2));
    });

    test('a single query keeps the flat shape', () async {
      final result = await _tool(
        'find_account',
        client: fireflyMockClient(),
      ).run({'query': 'Checking'});

      expect(result.containsKey('results'), isFalse);
      expect(result['query'], 'Checking');
      expect(result['candidates'], isA<List<Object?>>());
    });

    test('query and queries together is refused', () async {
      final calls = <Uri>[];
      final result =
          await _tool(
            'find_account',
            client: fireflyMockClient(record: calls),
          ).run({
            'query': 'a',
            'queries': ['b'],
          });

      expect(result['code'], 'bad_input');
      expect(calls, isEmpty);
    });

    test('an empty batch is refused before any request', () async {
      final calls = <Uri>[];
      final tool = _tool(
        'find_account',
        client: fireflyMockClient(record: calls),
      );

      expect((await tool.run({'queries': <String>[]}))['code'], 'bad_input');
      expect(
        (await tool.run({
          'queries': ['  ', ''],
        }))['code'],
        'bad_input',
      );
      expect(
        (await tool.run({
          'queries': [for (var i = 0; i < 201; i++) 'q$i'],
        }))['error'],
        contains('200'),
      );
      expect(calls, isEmpty);
    });
  });

  test('an account reports the identifiers it can be found by', () async {
    // find_account matches on these and update_account sets them, so leaving
    // them out of the response meant an identifier could be written and
    // matched but never read back, and the only way to tell whether one was
    // set at all was a boolean on a search result.
    final result = await _tool(
      'get_account',
      client: fireflyMockClient(),
    ).run({'account_id': '5'});

    final account = result['account'] as Map<String, Object?>;
    expect(account.containsKey('account_number'), isTrue);
    expect(account.containsKey('iban'), isTrue);
  });

  group('match_statement', () {
    Map<String, Object?> statementArgs() => {
      'account_id': '5',
      'start_date': '2026-01-01',
      'end_date': '2026-01-31',
      'rows': [
        {'row_id': 'r1', 'date': '2026-01-15', 'amount': '-45,00'},
      ],
    };

    test('reaches back far enough to see what the tolerance allows', () async {
      // The matcher pairs a row up to five days from its recorded counterpart,
      // but the fetch only reached forward from the statement's first row. A
      // transaction the bank dated the day before came back as missing, and
      // writing it would have duplicated what was already there.
      final calls = <Uri>[];
      await _tool(
        'match_statement',
        client: fireflyMockClient(record: calls),
      ).run(statementArgs());

      final fetch = calls.firstWhere(
        (u) => u.path.contains('/accounts/5/transactions'),
      );
      expect(fetch.queryParameters['start'], '2025-12-27');
      expect(fetch.queryParameters['end'], '2026-02-05');
    });

    test('takes a whole account, not a thousand rows of it', () async {
      // One currency pocket of a multi-currency wallet can hold several
      // thousand rows, and the old ceiling of 1000 meant the export that most
      // needed checking was the one that could not be checked at all.
      final rows = [
        for (var i = 0; i < 4000; i++)
          {
            'row_id': 'r$i',
            'date': '2026-01-15',
            'amount': '-${(10 + i % 900)}.00',
          },
      ];
      final result = await _tool(
        'match_statement',
        client: fireflyMockClient(),
      ).run({...statementArgs(), 'rows': rows});

      expect(result['ok'], isTrue);
      expect(
        (result['matched'] as List).length +
            (result['missing'] as List).length +
            (result['near_matches'] as List).length,
        4000,
      );
    });

    test('a statement past the ceiling says how to split it', () async {
      final rows = [
        for (var i = 0; i < 10001; i++)
          {'row_id': 'r$i', 'date': '2026-01-15', 'amount': '-1.00'},
      ];
      final result = await _tool(
        'match_statement',
        client: fireflyMockClient(),
      ).run({...statementArgs(), 'rows': rows});

      expect(
        result['error'],
        allOf(contains('10000'), contains('balances already agree')),
      );
    });

    test('matches a row against what is recorded', () async {
      final result = await _tool(
        'match_statement',
        client: fireflyMockClient(),
      ).run(statementArgs());

      expect(result['ok'], isTrue);
      // Tolerances are fixed rather than caller-settable, so they cannot drift
      // between one conversation and the next, and are echoed to prove it.
      final window = result['window'] as Map<String, Object?>;
      expect(window['date_tolerance_days'], 3);
      expect(window['near_date_tolerance_days'], 5);
      expect(window['amount_equality_tolerance'], 0.005);
      expect(result['arithmetic'], isA<Map<String, Object?>>());
    });

    test(
      'a row whose amount cannot be read is returned, not guessed',
      () async {
        final result =
            await _tool('match_statement', client: fireflyMockClient()).run({
              ...statementArgs(),
              'amount_format': 'comma',
              'rows': [
                {'row_id': 'r1', 'date': '2026-01-15', 'amount': '-45,00'},
                {'row_id': 'r2', 'date': '2026-01-16', 'amount': '-9 889,00-'},
              ],
            });

        expect(result['ok'], isTrue);
        final needsInput = result['needs_input'] as List<Object?>;
        expect(needsInput, hasLength(1));
        expect((needsInput.single as Map)['row_id'], 'r2');
      },
    );

    test('validates the window, the rows and the account', () async {
      final tool = _tool('match_statement', client: fireflyMockClient());

      expect((await tool.run({}))['code'], 'bad_input');
      expect(
        (await tool.run({...statementArgs(), 'rows': <Object?>[]}))['error'],
        contains('rows'),
      );
      expect(
        (await tool.run({
          ...statementArgs(),
          'end_date': '2025-12-01',
        }))['error'],
        contains('precede'),
      );
      expect(
        (await tool.run({
          ...statementArgs(),
          'rows': [
            {'date': '2026-01-15', 'amount': '1'},
          ],
        }))['error'],
        contains('row_id'),
      );
      expect(
        (await tool.run({
          ...statementArgs(),
          'account_id': 'missing',
        }))['error'],
        contains('missing'),
      );
    });
  });

  group('find_account identifiers', () {
    test('an account number in the query wins and yields a hint', () async {
      final result = await _tool(
        'find_account',
        client: fireflyMockClient(),
      ).run({'query': 'Joint Current 123 456 789'});

      final candidate =
          (result['candidates'] as List<Object?>).first as Map<String, Object?>;
      expect(candidate['matched_on'], contains('account_number'));
      expect(candidate['identifier_hint'], 'account number ending 6789');
      expect(candidate['confidence'], 'exact');
      expect(candidate['requires_confirmation'], isFalse);
    });

    test('a supplied iban confirms without being echoed back', () async {
      final result = await _tool(
        'find_account',
        client: fireflyMockClient(),
      ).run({'query': 'whatever', 'iban': 'SE41 0000 0000 0012 3456 7890'});

      final candidate =
          (result['candidates'] as List<Object?>).first as Map<String, Object?>;
      expect(candidate['identifier_hint'], 'iban ending 7890');
      expect(jsonEncode(result), isNot(contains('1234567890')));
    });
  });

  group('match_statement edges', () {
    Map<String, Object?> base() => {
      'account_id': '5',
      'start_date': '2026-01-01',
      'end_date': '2026-01-31',
      'rows': [
        {'row_id': 'r1', 'date': '2026-01-15', 'amount': '-45.00'},
      ],
    };

    test('reports the self check and the missing rows', () async {
      final result = await _tool('match_statement', client: fireflyMockClient())
          .run({
            ...base(),
            'opening_balance': '100.00',
            'closing_balance': '55.00',
            'rows': [
              {'row_id': 'r1', 'date': '2026-01-15', 'amount': '-45.00'},
              {'row_id': 'r2', 'date': '2026-01-20', 'amount': '-12.00'},
            ],
          });

      expect(result['ok'], isTrue);
      expect(result['statement_self_check'], isA<Map<String, Object?>>());
      expect(result['missing'], isA<List<Object?>>());
    });

    test(
      'an unreadable date is refused with the row that carried it',
      () async {
        final tool = _tool('match_statement', client: fireflyMockClient());

        expect(
          (await tool.run({...base(), 'start_date': 'whenever'}))['code'],
          'bad_input',
        );
        expect(
          (await tool.run({
            ...base(),
            'rows': [
              {'row_id': 'r1', 'date': 'whenever', 'amount': '1'},
            ],
          }))['error'],
          contains('r1'),
        );
        expect(
          (await tool.run({
            ...base(),
            'rows': [
              {'row_id': 'r1', 'amount': '1'},
            ],
          }))['error'],
          contains('date'),
        );
        expect(
          (await tool.run({
            ...base(),
            'rows': [
              {'row_id': 'r1', 'date': '2026-01-15'},
            ],
          }))['error'],
          contains('amount'),
        );
      },
    );

    test('an unknown amount_format is refused, not thrown', () async {
      final result = await _tool(
        'match_statement',
        client: fireflyMockClient(),
      ).run({...base(), 'amount_format': 'swedish'});

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('amount_format'));
    });

    test('an omitted window is refused rather than defaulted', () async {
      final tool = _tool('match_statement', client: fireflyMockClient());
      final noStart = {...base()}..remove('start_date');
      final noEnd = {...base()}..remove('end_date');

      // Defaulting either end would silently match against a window the caller
      // never asked for, and report the arithmetic as if it had.
      expect((await tool.run(noStart))['error'], contains('start_date'));
      expect((await tool.run(noEnd))['error'], contains('end_date'));
      expect(
        (await tool.run({...base(), 'start_date': '  '}))['code'],
        'bad_input',
      );
    });

    test('a thousand rows is well within what it will take', () async {
      // The ceiling used to sit here, below what one real account produces.
      final result = await _tool('match_statement', client: fireflyMockClient())
          .run({
            ...base(),
            'rows': [
              for (var i = 0; i < 1001; i++)
                {'row_id': 'r$i', 'date': '2026-01-15', 'amount': '-1.00'},
            ],
          });

      expect(result['ok'], isTrue);
      expect(result.containsKey('error'), isFalse);
    });

    test('a corpus that settles nothing asks rather than assuming', () async {
      // A bare 1,234 is worth either 1234 or 1.234, and picking one silently
      // values a statement row at a thousandth of its real amount.
      final result = await _tool('match_statement', client: fireflyMockClient())
          .run({
            ...base(),
            'rows': [
              {'row_id': 'r1', 'date': '2026-01-15', 'amount': '1,234'},
            ],
          });

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('amount_format'));
    });
  });
}
