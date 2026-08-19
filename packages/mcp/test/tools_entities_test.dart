import 'package:fireracoon_mcp/fireracoon_mcp.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers/firefly_mock.dart';

const _target = FireflyTarget(baseUrl: fireflyBaseUrl, bearer: fireflyToken);

List<McpTool> _tools({MockClient? client}) =>
    buildTools(target: _target, httpClient: client);

McpTool _tool(String name, {MockClient? client}) =>
    _tools(client: client).firstWhere((tool) => tool.name == name);

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

    test('duplicate_transaction fails when the source is gone', () async {
      await expectLater(
        _tool(
          'duplicate_transaction',
          client: fireflyMockClient(),
        ).run({'transaction_id': 'missing'}),
        throwsA(isA<Exception>()),
      );
    });

    test('delete_transaction deletes the group', () async {
      final result = await _tool(
        'delete_transaction',
        client: fireflyMockClient(),
      ).run({'transaction_id': '1'});

      expect(result['ok'], isTrue);
      expect(result['deleted'], isTrue);
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

    test('create_recurrence creates a rule', () async {
      final result = await _tool(
        'create_recurrence',
        client: fireflyMockClient(),
      ).run(recurrenceArgs());

      expect(result['ok'], isTrue);
      expect((result['recurrence'] as Map)['id'], '12');
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
}
