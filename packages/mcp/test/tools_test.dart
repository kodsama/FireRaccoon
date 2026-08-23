import 'dart:io';

import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon_mcp/fireracoon_mcp.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers/firefly_mock.dart';

const _target = FireflyTarget(baseUrl: fireflyBaseUrl, bearer: fireflyToken);

List<McpTool> _tools({MockClient? client}) =>
    buildTools(target: _target, httpClient: client);

McpTool _tool(String name, {MockClient? client}) =>
    _tools(client: client).firstWhere((tool) => tool.name == name);

void main() {
  group('connection target', () {
    test(
      'an unconfigured target fails the tool rather than guessing',
      () async {
        final tool = buildTools(
          target: const FireflyTarget.unconfigured(),
        ).firstWhere((t) => t.name == 'run_projection');

        expect(() => tool.run({}), throwsA(isA<StateError>()));
      },
    );

    test('arguments cannot redirect a tool at another Firefly', () async {
      final calls = <Uri>[];
      final tool = _tool(
        'get_current_user',
        client: fireflyMockClient(record: calls),
      );

      // The old per-call credential keys are inert: the target fixed at server
      // start is the only thing that decides where a call lands.
      final result = await tool.run({
        'firefly_url': 'https://attacker.test',
        'firefly_token': 'stolen-token',
      });

      expect(result['ok'], isTrue);
      expect(calls, isNotEmpty);
      for (final uri in calls) {
        expect(uri.host, Uri.parse(fireflyBaseUrl).host);
      }
    });

    test('no tool schema advertises a credential argument', () {
      for (final tool in _tools()) {
        final properties = (tool.inputSchema['properties'] as Map?) ?? const {};
        expect(
          properties.keys.map((key) => '$key'),
          isNot(anyOf(contains('firefly_url'), contains('firefly_token'))),
          reason: '${tool.name} must not take credentials',
        );
      }
    });

    test('the injected target serves reads', () async {
      final tool = _tool('get_accounts', client: fireflyMockClient());

      final result = await tool.run({});

      expect(result['ok'], isTrue);
      expect(result['count'], 2);
    });
  });

  group('get_accounts types', () {
    test('defaults to the accounts you own', () async {
      final calls = <Uri>[];
      final tool = _tool(
        'get_accounts',
        client: fireflyMockClient(record: calls),
      );

      final result = await tool.run({});

      expect(result['ok'], isTrue);
      expect(result['types'], ['asset', 'liability']);
      final requested = calls
          .map((u) => u.queryParameters['type'])
          .whereType<String>()
          .toSet();
      expect(requested, {'asset', 'liability'});
    });

    test(
      'expense and revenue reach Firefly, so payees can be listed',
      () async {
        final calls = <Uri>[];
        final tool = _tool(
          'get_accounts',
          client: fireflyMockClient(record: calls),
        );

        // A payee in Firefly is an expense or revenue account. Without this the
        // import flow cannot check whether a payee already exists.
        final result = await tool.run({
          'types': ['expense', 'revenue'],
        });

        expect(result['ok'], isTrue);
        expect(result['types'], ['expense', 'revenue']);
        final requested = calls
            .map((u) => u.queryParameters['type'])
            .whereType<String>()
            .toSet();
        expect(requested, {'expense', 'revenue'});
        expect(requested, isNot(contains('asset')));
      },
    );

    test('an unknown type is refused before any request', () async {
      final calls = <Uri>[];
      final tool = _tool(
        'get_accounts',
        client: fireflyMockClient(record: calls),
      );

      final result = await tool.run({
        'types': ['asset', 'chequing'],
      });

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('chequing'));
      expect(calls, isEmpty);
    });
  });

  group('get_transactions date window', () {
    test(
      'an inclusive end_date reaches the engine as an exclusive end',
      () async {
        final calls = <Uri>[];
        final tool = _tool(
          'get_transactions',
          client: fireflyMockClient(record: calls),
        );

        await tool.run({
          'start_date': '2026-08-20',
          'end_date': '2026-08-20',
          'limit': 100,
        });

        // The engine subtracts a day from whatever end it is handed, so a
        // single-day window has to arrive as the day after. That leaves start
        // and end equal, which Firefly refuses outright rather than tolerating,
        // so the engine widens by a day and trims the answer back.
        final ranged = calls.where(
          (u) => u.queryParameters.containsKey('start'),
        );
        expect(ranged, isNotEmpty, reason: 'no date range was sent at all');
        expect(ranged.first.queryParameters['start'], '2026-08-20');
        expect(ranged.first.queryParameters['end'], '2026-08-21');
      },
    );

    test('a start_date alone names the open end too', () async {
      // An account's transactions endpoint answers a range carrying only one
      // bound with nothing at all, so the open end has to be spelled out. The
      // collection endpoint does not mind either way.
      final calls = <Uri>[];
      final tool = _tool(
        'get_transactions',
        client: fireflyMockClient(record: calls),
      );

      await tool.run({'start_date': '2026-01-01'});

      final ranged = calls.where((u) => u.queryParameters.containsKey('start'));
      expect(ranged.first.queryParameters['start'], '2026-01-01');
      expect(ranged.first.queryParameters['end'], isNotNull);
    });

    test('an unparseable date is refused before any request', () async {
      final calls = <Uri>[];
      final tool = _tool(
        'get_transactions',
        client: fireflyMockClient(record: calls),
      );

      final result = await tool.run({'start_date': 'last tuesday'});

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('start_date'));
      expect(calls, isEmpty);
    });

    test('an end before the start is refused', () async {
      final tool = _tool('get_transactions', client: fireflyMockClient());

      final result = await tool.run({
        'start_date': '2026-08-20',
        'end_date': '2026-08-01',
      });

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('precede'));
    });
  });

  group('calendar dates in responses', () {
    test('a date is reported as its calendar day, not its UTC day', () async {
      final tool = _tool(
        'get_account_balance_at_date',
        client: fireflyMockClient(),
      );

      // Local midnight at a positive offset is the previous day in UTC. Echoing
      // toIso8601String().substring(0, 10) reported 2026-07-31 for 1 August.
      final result = await tool.run({'account_id': '5', 'date': '2026-08-01'});

      expect(result['ok'], isTrue);
      expect(result['date'], '2026-08-01');
    });

    test('a date across a year boundary keeps its calendar day', () async {
      final tool = _tool(
        'get_account_balance_at_date',
        client: fireflyMockClient(),
      );

      final result = await tool.run({'account_id': '5', 'date': '2027-01-01'});

      expect(result['date'], '2027-01-01');
    });

    test('a transaction date is a calendar day, not a timestamp', () async {
      final tool = _tool('get_transaction', client: fireflyMockClient());

      final result = await tool.run({'transaction_id': '1'});

      // Reporting 2026-01-15T00:00:00.000 makes every caller parse a timestamp
      // to get a day back, and it disagrees with the date every other tool
      // reports and every write tool accepts.
      expect((result['transaction'] as Map)['date'], '2026-01-15');
    });
  });

  group('transaction bookkeeping fields', () {
    test(
      'a transaction carries the fields needed to match and copy it',
      () async {
        final tool = _tool('get_transaction', client: fireflyMockClient());

        final transaction =
            (await tool.run({'transaction_id': '1'}))['transaction']
                as Map<String, Object?>;

        // Reconciling a statement needs the payee account ids, because a payee in
        // Firefly is an account and its own transaction list is the candidate
        // history. Copying one needs to show what the copy inherits.
        expect(transaction['source_id'], '5');
        expect(transaction['destination_id'], '9');
        expect(transaction['budget_name'], 'Housekeeping');
        expect(transaction['bill_name'], 'Weekly shop');
        expect(transaction['tags'], ['groceries', 'shared']);
        expect(transaction['notes'], contains('ICA SUPERMARKET'));
        expect(transaction['split_count'], 1);
      },
    );

    test('the same fields appear in a transaction listing', () async {
      final tool = _tool('get_transactions', client: fireflyMockClient());

      final listed = (await tool.run({}))['transactions'] as List<Object?>;
      final first = listed.cast<Map<String, Object?>>().firstWhere(
        (t) => t['id'] == '1',
      );

      expect(first['destination_id'], '9');
      expect(first['tags'], ['groceries', 'shared']);
      expect(first['date'], '2026-01-15');
    });
  });

  group('get_capabilities', () {
    test('answers without a Firefly connection', () async {
      final tool = buildTools(
        target: const FireflyTarget.unconfigured(),
      ).firstWhere((t) => t.name == 'get_capabilities');

      final result = await tool.run({});

      expect(result['ok'], isTrue);
      expect(result['tools'], isA<List<Object?>>());
      expect(result['version'], '1.0.0');
      expect(result['write_tools'], isA<List<Object?>>());
    });

    test('advertises agent keys as the credential', () async {
      final tool = _tool('get_capabilities');

      final auth = (await tool.run({}))['auth'] as Map<String, Object?>;

      expect(auth['env'], ['FIRERACOON_URL', 'FIRERACOON_API_KEY']);
      expect(auth['tcp_param'], 'initialize.params.apiKey');
      expect(auth.containsKey('per_call'), isFalse);
    });
  });

  group('get_capabilities identity', () {
    const caller = AgentIdentity(
      keyId: 'key-9',
      personId: 'p1',
      personName: 'Ada',
      role: 'admin',
    );

    test('reports the person behind the presented key', () async {
      final tool = buildTools(
        target: _target,
        httpClient: fireflyMockClient(),
        identity: caller,
      ).firstWhere((t) => t.name == 'get_capabilities');

      final identity = (await tool.run({}))['identity'] as Map<String, Object?>;

      expect(identity['person_name'], 'Ada');
      expect(identity['key_id'], 'key-9');
      expect(identity['role'], 'admin');
      expect(identity['can_write'], isTrue);
    });

    test('a caller cannot present an identity through its arguments', () async {
      final tool = buildTools(
        target: _target,
        httpClient: fireflyMockClient(),
        identity: caller,
      ).firstWhere((t) => t.name == 'get_capabilities');

      // The identity comes from the authenticator, never from the wire. A tool
      // that merged args would let any key claim to be anyone.
      final identity =
          (await tool.run({
                'identity': {'person_name': 'Someone else', 'role': 'admin'},
              }))['identity']
              as Map<String, Object?>;

      expect(identity['person_name'], 'Ada');
      expect(identity['person_id'], 'p1');
    });

    test(
      'a server with no identity reports none rather than guessing',
      () async {
        final tool = _tool('get_capabilities', client: fireflyMockClient());

        expect((await tool.run({}))['identity'], isNull);
      },
    );

    test('no tool takes a person as an argument', () {
      // The only person id in the system arrives from the authenticator, so a
      // person property on any schema would be a way to ask as someone else.
      for (final tool in _tools()) {
        final properties = (tool.inputSchema['properties'] as Map?) ?? const {};
        expect(
          properties.keys.map((k) => '$k'),
          isNot(anyOf(contains('person_id'), contains('identity'))),
          reason: '${tool.name} must not take a person',
        );
      }
    });
  });

  group('check_connection', () {
    test('bad_input when the server has no Firefly connection', () async {
      final tool = buildTools(
        target: const FireflyTarget.unconfigured(),
        httpClient: fireflyMockClient(),
      ).firstWhere((t) => t.name == 'check_connection');

      final result = await tool.run({});

      expect(result['ok'], isFalse);
      expect(result['code'], 'bad_input');
    });

    test('connected on 200', () async {
      final tool = _tool('check_connection', client: fireflyMockClient());
      final result = await tool.run({});
      expect(result['ok'], isTrue);
      expect(result['connected'], isTrue);
    });

    test('not connected on non-200', () async {
      final tool = _tool(
        'check_connection',
        client: fireflyMockClient(aboutOk: false),
      );
      final result = await tool.run({});
      expect(result['ok'], isFalse);
      expect(result['connected'], isFalse);
      expect(result['error'], isNotNull);
    });

    test('strips a trailing slash from the target base URL', () async {
      final tools = buildTools(
        target: const FireflyTarget(
          baseUrl: '$fireflyBaseUrl/',
          bearer: fireflyToken,
        ),
        httpClient: fireflyMockClient(),
      );
      final tool = tools.firstWhere((t) => t.name == 'check_connection');
      final result = await tool.run({});
      expect(result['ok'], isTrue);
    });

    test(
      'opens and closes an ephemeral client when httpClient omitted',
      () async {
        final server = await HttpServer.bind('127.0.0.1', 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          if (request.uri.path == '/api/v1/about') {
            request.response.statusCode = 200;
            request.response.write('{}');
          } else {
            request.response.statusCode = 404;
          }
          await request.response.close();
        });

        final tool = buildTools(
          target: FireflyTarget(
            baseUrl: 'http://127.0.0.1:${server.port}/',
            bearer: 'token',
          ),
        ).firstWhere((t) => t.name == 'check_connection');

        final result = await tool.run({});

        expect(result['ok'], isTrue);
      },
    );
  });

  group('get_current_user', () {
    test('returns profile', () async {
      final result = await _tool(
        'get_current_user',
        client: fireflyMockClient(),
      ).run({});
      expect(result['ok'], isTrue);
      final user = result['user'] as Map<String, Object?>;
      expect(user['email'], 'admin@local.test');
      expect(user['display_name'], 'Admin');
    });
  });

  group('get_primary_currency', () {
    test('returns currency', () async {
      final result = await _tool(
        'get_primary_currency',
        client: fireflyMockClient(),
      ).run({});
      expect(result['ok'], isTrue);
      expect((result['currency'] as Map)['code'], 'EUR');
    });
  });

  group('set_primary_currency', () {
    test('bad_input when code missing', () async {
      final result = await _tool(
        'set_primary_currency',
        client: fireflyMockClient(),
      ).run({});
      expect(result['code'], 'bad_input');
    });

    test('sets and returns currency', () async {
      final result = await _tool(
        'set_primary_currency',
        client: fireflyMockClient(),
      ).run({'code': 'EUR'});
      expect(result['ok'], isTrue);
      expect((result['currency'] as Map)['symbol'], '€');
    });
  });

  group('get_accounts', () {
    test('lists accounts with balances', () async {
      final result = await _tool(
        'get_accounts',
        client: fireflyMockClient(),
      ).run({});
      expect(result['ok'], isTrue);
      expect(result['count'], 2);
      final accounts = result['accounts'] as List<Object?>;
      expect(accounts.first, containsPair('name', 'Checking'));
    });
  });

  group('get_transactions', () {
    test('returns all transactions by default', () async {
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(),
      ).run({});
      expect(result['ok'], isTrue);
      expect(result['count'], greaterThan(0));
      expect(result['transactions'], isA<List<Object?>>());
    });

    test('paginates globally when page or limit set', () async {
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(),
      ).run({'page': 2, 'limit': 10});
      expect(result['ok'], isTrue);
      expect(result['pagination'], isA<Map<String, Object?>>());
    });

    test('paginates by account', () async {
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(),
      ).run({'account_id': '5', 'page': 1, 'limit': 25});
      expect(result['ok'], isTrue);
      expect(result['pagination'], isA<Map<String, Object?>>());
    });

    test('filters reconciled client-side with pagination', () async {
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(),
      ).run({'reconciled': true, 'page': 2, 'limit': 1});
      expect(result['ok'], isTrue);
      final pagination = result['pagination'] as Map<String, Object?>;
      expect(pagination['filtered_client_side'], isTrue);
    });

    test('filters unreconciled for account client-side', () async {
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(),
      ).run({'account_id': '5', 'reconciled': 'unreconciled'});
      expect(result['ok'], isTrue);
      expect((result['pagination'] as Map)['filtered_client_side'], isTrue);
    });

    test('accepts reconciled string aliases', () async {
      for (final filter in ['all', 'false', 'reconciled']) {
        final result = await _tool(
          'get_transactions',
          client: fireflyMockClient(),
        ).run({'reconciled': filter});
        expect(result['ok'], isTrue, reason: filter);
      }
    });

    test('accepts reconciled boolean', () async {
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(),
      ).run({'reconciled': false});
      expect(result['ok'], isTrue);
    });

    test('bad_input on invalid reconciled filter', () async {
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(),
      ).run({'reconciled': 'maybe'});
      expect(result['code'], 'bad_input');
    });

    test('empty page when start beyond total', () async {
      final result = await _tool(
        'get_transactions',
        client: fireflyMockClient(),
      ).run({'reconciled': true, 'page': 99, 'limit': 1});
      expect(result['transactions'], isEmpty);
    });
  });

  group('get_transaction', () {
    test('bad_input when id missing', () async {
      final result = await _tool(
        'get_transaction',
        client: fireflyMockClient(),
      ).run({});
      expect(result['code'], 'bad_input');
    });

    test('returns transaction', () async {
      final result = await _tool(
        'get_transaction',
        client: fireflyMockClient(),
      ).run({'transaction_id': '1'});
      expect(result['ok'], isTrue);
      expect((result['transaction'] as Map)['id'], '1');
    });
  });

  group('set_transaction_reconciled', () {
    test('validates inputs', () async {
      final tool = _tool(
        'set_transaction_reconciled',
        client: fireflyMockClient(),
      );
      expect((await tool.run({}))['code'], 'bad_input');
      expect((await tool.run({'transaction_id': '1'}))['code'], 'bad_input');
    });

    test('updates reconciled flag', () async {
      final result = await _tool(
        'set_transaction_reconciled',
        client: fireflyMockClient(),
      ).run({'transaction_id': '1', 'reconciled': true});
      expect(result['ok'], isTrue);
      expect((result['transaction'] as Map)['reconciled'], isTrue);
    });
  });

  group('store_reconciliation', () {
    Map<String, Object?> reconciliationArgs() => {
      'account_id': '5',
      'start_date': '2026-01-01',
      'end_date': '2026-01-31',
      'start_balance': 1000.0,
      'end_balance': 1010.0,
      'transaction_ids': ['1'],
    };

    test('validates required fields', () async {
      final tool = _tool('store_reconciliation', client: fireflyMockClient());
      expect((await tool.run({}))['code'], 'bad_input');
      expect((await tool.run({'account_id': '5'}))['code'], 'bad_input');
      expect(
        (await tool.run({
          'account_id': '5',
          'start_date': 'bad',
          'end_date': '2026-01-31',
          'start_balance': 1,
          'end_balance': 2,
          'transaction_ids': ['1'],
        }))['code'],
        'bad_input',
      );
      expect(
        (await tool.run({
          'account_id': '5',
          'start_date': '2026-01-01',
          'end_date': '2026-01-31',
          'transaction_ids': ['1'],
        }))['code'],
        'bad_input',
      );
      expect(
        (await tool.run({
          'account_id': '5',
          'start_date': '2026-01-01',
          'end_date': '2026-01-31',
          'start_balance': 1,
          'end_balance': 2,
          'transaction_ids': [],
        }))['code'],
        'bad_input',
      );
    });

    test('bad_input when account missing', () async {
      final result = await _tool(
        'store_reconciliation',
        client: fireflyMockClient(),
      ).run({...reconciliationArgs(), 'account_id': 'missing'});
      expect(result['code'], 'bad_input');
    });

    test('stores asset reconciliation with correction', () async {
      final result = await _tool(
        'store_reconciliation',
        client: fireflyMockClient(),
      ).run(reconciliationArgs());
      expect(result['ok'], isTrue);
      expect(result['reconciled_count'], 1);
      expect(result['gap'], isA<num>());
    });

    test('skips correction when create_correction is false', () async {
      final result = await _tool(
        'store_reconciliation',
        client: fireflyMockClient(),
      ).run({...reconciliationArgs(), 'create_correction': false});
      expect(result['ok'], isTrue);
      expect(result['correction'], isNull);
    });

    test('credit card requires payback fields', () async {
      final result =
          await _tool('store_reconciliation', client: fireflyMockClient()).run({
            ...reconciliationArgs(),
            'account_id': '6',
            'transaction_ids': ['3'],
          });
      expect(result['code'], 'bad_input');
    });

    test('credit card validates payback date and payment account', () async {
      final tool = _tool('store_reconciliation', client: fireflyMockClient());
      expect(
        (await tool.run({
          ...reconciliationArgs(),
          'account_id': '6',
          'transaction_ids': ['3'],
          'payment_account_id': '5',
          'payback_date': 'not-a-date',
        }))['code'],
        'bad_input',
      );
      expect(
        (await tool.run({
          ...reconciliationArgs(),
          'account_id': '6',
          'transaction_ids': ['3'],
          'payment_account_id': 'missing',
          'payback_date': '2026-01-31',
        }))['code'],
        'bad_input',
      );
    });

    test('credit card payback succeeds', () async {
      final result =
          await _tool('store_reconciliation', client: fireflyMockClient()).run({
            ...reconciliationArgs(),
            'account_id': '6',
            'transaction_ids': ['3'],
            'payment_account_id': '5',
            'payback_date': '2026-01-31',
          });
      expect(result['ok'], isTrue);
      expect(result['reconciled_count'], 1);
      expect(result['payback'], isA<Map<String, Object?>>());
    });
  });

  group('get_budgets', () {
    test('lists budgets', () async {
      final result = await _tool(
        'get_budgets',
        client: fireflyMockClient(),
      ).run({});
      expect(result['ok'], isTrue);
      expect(result['count'], 1);
    });
  });

  group('get_budget_transactions', () {
    test('bad_input when budget_id missing', () async {
      final result = await _tool(
        'get_budget_transactions',
        client: fireflyMockClient(),
      ).run({});
      expect(result['code'], 'bad_input');
    });

    test('returns budget transactions', () async {
      final result = await _tool(
        'get_budget_transactions',
        client: fireflyMockClient(),
      ).run({'budget_id': '3'});
      expect(result['ok'], isTrue);
      expect(result['count'], greaterThan(0));
    });
  });

  group('update_account', () {
    test('validates inputs', () async {
      final tool = _tool('update_account', client: fireflyMockClient());
      expect((await tool.run({}))['code'], 'bad_input');
      expect((await tool.run({'account_id': '5'}))['code'], 'bad_input');
    });

    test('renames account', () async {
      final result = await _tool(
        'update_account',
        client: fireflyMockClient(),
      ).run({'account_id': '5', 'name': 'Main'});
      expect(result['ok'], isTrue);
      expect(result['name'], 'Main');
    });
  });

  group('update_budget', () {
    test('validates inputs', () async {
      final tool = _tool('update_budget', client: fireflyMockClient());
      expect((await tool.run({}))['code'], 'bad_input');
      expect((await tool.run({'budget_id': '3'}))['code'], 'bad_input');
    });

    test('updates budget with auto amount', () async {
      final result = await _tool('update_budget', client: fireflyMockClient())
          .run({
            'budget_id': '3',
            'name': 'Food',
            'amount': 500,
            'auto_budget_type': 'rollover',
            'auto_budget_period': 'monthly',
            'notes': 'groceries',
            'active': true,
          });
      expect(result['ok'], isTrue);
      expect(result['amount'], 500);
    });
  });

  group('delete_budget', () {
    test('bad_input when budget_id missing', () async {
      final result = await _tool(
        'delete_budget',
        client: fireflyMockClient(),
      ).run({});
      expect(result['code'], 'bad_input');
    });

    test('deletes budget', () async {
      final result = await _tool(
        'delete_budget',
        client: fireflyMockClient(),
      ).run({'budget_id': '3'});
      expect(result['ok'], isTrue);
      expect(result['deleted'], isTrue);
    });
  });

  group('run_projection', () {
    test('projects with default savings type', () async {
      final result = await _tool(
        'run_projection',
        client: fireflyMockClient(),
      ).run({});
      expect(result['ok'], isTrue);
      expect(result['end_expected'], isA<num>());
      expect(result['params'], isA<Map<String, Object?>>());
    });

    for (final type in ['compound', 'portfolio', 'cashflow']) {
      test('supports $type projection', () async {
        final result = await _tool(
          'run_projection',
          client: fireflyMockClient(),
        ).run({'projection_type': type});
        expect(result['ok'], isTrue);
        expect((result['params'] as Map)['type'], type);
      });
    }

    test('bad_input on invalid projection_type', () async {
      final result = await _tool(
        'run_projection',
        client: fireflyMockClient(),
      ).run({'projection_type': 'invalid'});
      expect(result['code'], 'bad_input');
    });

    test('includes alert when balance trend is risky', () async {
      final result = await _tool(
        'run_projection',
        client: fireflyMockClient(heavySpending: true),
      ).run({'months': 12, 'projection_type': 'savings'});
      expect(result['ok'], isTrue);
      expect(result['alert'], isA<Map<String, Object?>>());
      expect((result['alert'] as Map)['kind'], isNotEmpty);
    });
  });

  group('get_dashboard_kpis', () {
    test('computes KPIs for default period', () async {
      final result = await _tool(
        'get_dashboard_kpis',
        client: fireflyMockClient(),
      ).run({});
      expect(result['ok'], isTrue);
      final kpis = result['kpis'] as Map<String, Object?>;
      expect(kpis['total_balance'], isA<num>());
      expect(kpis['income_delta'], isA<Map<String, Object?>>());
    });

    test('accepts custom period label', () async {
      final result = await _tool(
        'get_dashboard_kpis',
        client: fireflyMockClient(),
      ).run({'period_label': 'January'});
      expect((result['kpis'] as Map)['period_label'], 'January');
    });

    test('bad_input on invalid period', () async {
      final result = await _tool(
        'get_dashboard_kpis',
        client: fireflyMockClient(),
      ).run({'period': 'never'});
      expect(result['code'], 'bad_input');
    });
  });

  test('ProjectionService integrates with engine models', () {
    final transactions = [
      Transaction(
        id: '1',
        type: 'deposit',
        date: DateTime(2026, 1, 1),
        amount: 2000,
        description: 'Salary',
        sourceName: 'Employer',
        destinationName: 'Checking',
        categoryName: 'Income',
        currencySymbol: '€',
        currencyCode: 'EUR',
      ),
      Transaction(
        id: '2',
        type: 'withdrawal',
        date: DateTime(2026, 1, 2),
        amount: 500,
        description: 'Rent',
        sourceName: 'Checking',
        destinationName: 'Landlord',
        categoryName: 'Housing',
        currencySymbol: '€',
        currencyCode: 'EUR',
      ),
    ];

    final result = ProjectionService.project(
      currentBalance: 5000,
      transactions: transactions,
      params: const ProjectionParams(months: 6),
    );

    expect(result.expected.length, greaterThan(1));
    expect(result.endExpected, greaterThan(0));
  });
}
