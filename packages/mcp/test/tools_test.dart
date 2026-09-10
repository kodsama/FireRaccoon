import 'dart:io';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:http/http.dart' as http;
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
      'an unconfigured target reports the state rather than guessing',
      () async {
        final tool = buildTools(target: const FireflyTarget.unconfigured())
            .firstWhere((t) => t.name == 'run_projection');

        final result = await tool.run({});

        // A described state, not a thrown failure. An agent that reads a
        // socket error under `tool_error` retries, or tells the person their
        // ledger is broken; `not_connected` is the one true thing to say.
        expect(result['ok'], isFalse);
        expect(result['code'], 'not_connected');
        expect(result['connected'], isFalse);
        expect(result['remedy'], contains('Settings'));
      },
    );

    test('no tool throws at an agent when there is no connection', () async {
      const describedCodes = {
        // Wanted arguments it did not get, so it never reached the connection.
        'bad_input',
        // Backups, which need somewhere to keep one as well as a ledger.
        'unavailable',
        'not_connected',
      };
      for (final tool in buildTools(
        target: const FireflyTarget.unconfigured(),
      )) {
        final result = await tool.run(const {});
        expect(
          result['ok'] == true || describedCodes.contains(result['code']),
          isTrue,
          reason: '${tool.name} answered ${result['code']}',
        );
      }
    });

    test('a Firefly that never answers is reported as unreachable', () async {
      final tool = _tool(
        'get_current_user',
        client: MockClient((_) async => throw http.ClientException('refused')),
      );

      final result = await tool.run({});

      expect(result['ok'], isFalse);
      expect(result['code'], 'backend_unreachable');
      expect(result['connected'], isFalse);
      expect(result['backend_url'], fireflyBaseUrl);
    });

    test('a sign-in page in front of Firefly is a refused token', () async {
      // A proxy or SSO front door answers every path with a login page. The
      // server is up and talking, so telling an agent it is unreachable sends
      // whoever reads that off to check a network that is fine.
      final tool = _tool(
        'get_accounts',
        client: MockClient(
          (_) async => http.Response(
            '<!DOCTYPE html><html><body>Sign in</body></html>',
            401,
            headers: {'content-type': 'text/html; charset=utf-8'},
          ),
        ),
      );

      final result = await tool.run({});

      expect(result['ok'], isFalse);
      expect(result['code'], 'backend_unauthorized');
      expect(result['connected'], isTrue);
      expect(result['backend_url'], fireflyBaseUrl);
      expect(result['remedy'], contains('personal access token'));
    });

    test('a refusal Firefly sent is not called unreachable', () async {
      // A 404 leaves the API layer with no status code either, so anything
      // reading a missing status as "nothing answered" reported a server that
      // was up and talking as a server nobody could reach.
      final tool = _tool('get_account', client: fireflyMockClient());

      await expectLater(
        tool.run({'account_id': '404'}),
        throwsA(isA<Exception>()),
      );
    });

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
    test('a transaction carries the fields needed to match and copy it', () async {
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
    });

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
      final tool = buildTools(target: const FireflyTarget.unconfigured())
          .firstWhere((t) => t.name == 'get_capabilities');

      final result = await tool.run({});

      expect(result['ok'], isTrue);
      expect(result['tools'], isA<List<Object?>>());
      expect(result['version'], '1.0.0');
      expect(result['write_tools'], isA<List<Object?>>());
    });

    test('reports the app version it was started with', () async {
      final tool = buildTools(
        target: _target,
        httpClient: fireflyMockClient(),
        appVersion: '0.3.2',
      ).firstWhere((t) => t.name == 'get_capabilities');

      final app = (await tool.run({}))['app'] as Map<String, Object?>;

      expect(app['name'], 'FireRaccoon');
      expect(app['version'], '0.3.2');
      expect(app['mcp_version'], '1.0.0');
    });

    test('reports a live backend: where, which version, how many', () async {
      final tool = _tool('get_capabilities', client: fireflyMockClient());

      final backend = (await tool.run({}))['backend'] as Map<String, Object?>;

      expect(backend['configured'], isTrue);
      expect(backend['connected'], isTrue);
      expect(backend['url'], fireflyBaseUrl);
      expect(backend['firefly_version'], '6.0.0');
      expect(backend['firefly_api_version'], '2.1.0');
      expect(backend['user_count'], 2);
    });

    test('says the backend is down rather than failing with it', () async {
      // The tool an agent calls first has to keep answering when the thing it
      // describes is unreachable, or there is nothing left to learn the state
      // from.
      final tool = _tool(
        'get_capabilities',
        client: MockClient((_) async => throw http.ClientException('refused')),
      );

      final result = await tool.run({});
      final backend = result['backend'] as Map<String, Object?>;

      expect(result['ok'], isTrue);
      expect(result['tools'], isNotEmpty);
      expect(backend['connected'], isFalse);
      expect(backend['url'], fireflyBaseUrl);
      expect(backend['reason'], contains('did not answer'));
    });

    test('an unconfigured server says so, and points at Settings', () async {
      final tool = buildTools(target: const FireflyTarget.unconfigured())
          .firstWhere((t) => t.name == 'get_capabilities');

      final backend = (await tool.run({}))['backend'] as Map<String, Object?>;

      expect(backend['configured'], isFalse);
      expect(backend['connected'], isFalse);
      expect(backend['url'], isNull);
      expect(backend['reason'], contains('Settings'));
    });

    test('a user count is omitted where the token may not ask', () async {
      // /api/v1/users is owner-only. A viewer being refused it says nothing
      // about the connection, so the rest of the status still stands.
      final tool = _tool(
        'get_capabilities',
        client: fireflyMockClient(usersReadable: false),
      );

      final backend = (await tool.run({}))['backend'] as Map<String, Object?>;

      expect(backend['connected'], isTrue);
      expect(backend['user_count'], isNull);
      expect(backend['firefly_version'], '6.0.0');
    });

    test('a proxy answering 200 with junk narrows the status', () async {
      // The connection is proved by the 200 and nothing else can be read from
      // it. get_capabilities is the one call that has to keep answering while
      // everything else is going wrong, so it reports less rather than throws.
      final tool = _tool(
        'get_capabilities',
        client: MockClient((_) async => jsonHttpResponse('not json at all')),
      );

      final backend = (await tool.run({}))['backend'] as Map<String, Object?>;

      expect(backend['connected'], isTrue);
      expect(backend['firefly_version'], isNull);
      expect(backend['user'], isNull);
      expect(backend['user_count'], isNull);
    });

    test('a user in a shape nobody expected is left out', () async {
      final tool = _tool(
        'get_capabilities',
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/about/user') {
            return jsonHttpResponse({
              'data': {'id': 1, 'attributes': 'nonsense'},
            });
          }
          return jsonHttpResponse({'version': '6.0.0'});
        }),
      );

      final backend = (await tool.run({}))['backend'] as Map<String, Object?>;

      expect(backend['connected'], isTrue);
      expect(backend['user'], isNull);
    });

    test('users are counted by hand when there is no total', () async {
      final tool = _tool(
        'get_capabilities',
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/users') {
            return jsonHttpResponse({
              'data': [
                {'id': '1'},
                {'id': '2'},
                {'id': '3'},
              ],
            });
          }
          return jsonHttpResponse({'version': '6.0.0'});
        }),
      );

      final backend = (await tool.run({}))['backend'] as Map<String, Object?>;

      expect(backend['user_count'], 3);
    });

    test('a route standing in front of Firefly is named as such', () async {
      // A gated route answers the probe with its sign-in redirect. Reported as
      // unreachable, an agent goes looking for a server that is running fine.
      final tool = _tool(
        'get_capabilities',
        client: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://cosmos.example/cosmos-ui/openid'
                  '?client_id=__route_Firefly-III',
            },
          ),
        ),
      );

      final backend = (await tool.run({}))['backend'] as Map<String, Object?>;

      expect(backend['connected'], isTrue);
      expect(backend['authorized'], isFalse);
      expect(backend['proxy'], 'cosmos');
      expect(backend['reason'], contains('Sign in to Cosmos'));
    });

    test('says whether it holds a session for such a route', () async {
      final without = buildTools(
        target: _target,
        httpClient: fireflyMockClient(),
      ).firstWhere((t) => t.name == 'get_capabilities');
      final with_ = buildTools(
        target: const FireflyTarget(
          baseUrl: fireflyBaseUrl,
          bearer: fireflyToken,
          proxyCookie: 'jwttoken=abc',
        ),
        httpClient: fireflyMockClient(),
      ).firstWhere((t) => t.name == 'get_capabilities');

      expect(((await without.run({}))['app'] as Map)['proxy_session'], isFalse);
      expect(((await with_.run({}))['app'] as Map)['proxy_session'], isTrue);
    });

    test('the session is sent with the request, not just advertised', () async {
      final seen = <String?>[];
      final tool = buildTools(
        target: const FireflyTarget(
          baseUrl: fireflyBaseUrl,
          bearer: fireflyToken,
          proxyCookie: 'jwttoken=abc',
        ),
        httpClient: MockClient((request) async {
          seen.add(request.headers['Cookie']);
          return jsonHttpResponse(userBody());
        }),
      ).firstWhere((t) => t.name == 'get_current_user');

      await tool.run({});

      expect(seen, isNotEmpty);
      expect(seen.every((c) => c == 'jwttoken=abc'), isTrue);
    });

    test('advertises agent keys as the credential', () async {
      final tool = _tool('get_capabilities');

      final auth = (await tool.run({}))['auth'] as Map<String, Object?>;

      expect(auth['env'], ['FIRERACCOON_URL', 'FIRERACCOON_API_KEY']);
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
    test('not_connected when the server has no Firefly connection', () async {
      final tool = buildTools(
        target: const FireflyTarget.unconfigured(),
        httpClient: fireflyMockClient(),
      ).firstWhere((t) => t.name == 'check_connection');

      final result = await tool.run({});

      expect(result['ok'], isFalse);
      expect(result['code'], 'not_connected');
      expect(result['configured'], isFalse);
      expect(result['url'], isNull);
    });

    test('connected on 200, and says where and how many', () async {
      final tool = _tool('check_connection', client: fireflyMockClient());
      final result = await tool.run({});
      expect(result['ok'], isTrue);
      expect(result['connected'], isTrue);
      expect(result['url'], fireflyBaseUrl);
      expect(result['firefly_version'], '6.0.0');
      expect(result['user_count'], 2);
      expect(
        (result['user'] as Map<String, Object?>)['email'],
        'admin@local.test',
      );
    });

    test('a rejected token is reported as reaching Firefly', () async {
      // 401 on /about means the server answered. Calling that "not connected"
      // sent people off to check a network that was fine.
      final tool = _tool(
        'check_connection',
        client: fireflyMockClient(aboutOk: false),
      );
      final result = await tool.run({});
      expect(result['ok'], isFalse);
      expect(result['code'], 'backend_unauthorized');
      expect(result['connected'], isTrue);
      expect(result['authorized'], isFalse);
      expect(result['error'], contains('rejected the token'));
    });

    test('a Firefly that never answers is not connected', () async {
      final tool = _tool(
        'check_connection',
        client: MockClient((_) async => throw http.ClientException('refused')),
      );
      final result = await tool.run({});
      expect(result['ok'], isFalse);
      expect(result['code'], 'backend_unreachable');
      expect(result['connected'], isFalse);
      expect(result['url'], fireflyBaseUrl);
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

    test('always asks for a window, and says which one', () async {
      // Firefly computes spend only over a window it was given, and answers
      // `spent: []` without one. That read as "nothing is attached to this
      // budget" while 798 transactions were.
      final seen = <Uri>[];
      final result = await _tool(
        'get_budgets',
        client: fireflyMockClient(record: seen),
      ).run({});

      final asked = seen.firstWhere((uri) => uri.path == '/api/v1/budgets');
      expect(asked.queryParameters['start'], isNotNull);
      expect(asked.queryParameters['end'], isNotNull);
      // A spend figure means nothing without the window it was measured over.
      // Echoed as the caller's own range, whose end is exclusive everywhere in
      // this surface; the inclusive end on the wire is a day earlier.
      final window = result['window']! as Map<String, Object?>;
      expect(window['start'], '1970-01-03');
      expect(window['end'], '2038-01-16');
    });

    test('passes a window it was given', () async {
      final seen = <Uri>[];
      await _tool(
        'get_budgets',
        client: fireflyMockClient(record: seen),
      ).run({'start_date': '2026-01-01', 'end_date': '2026-02-01'});

      final asked = seen.firstWhere((uri) => uri.path == '/api/v1/budgets');
      expect(asked.queryParameters['start'], '2026-01-01');
      expect(asked.queryParameters['end'], '2026-01-31');
    });

    test('refuses a date it cannot read', () async {
      final result = await _tool(
        'get_budgets',
        client: fireflyMockClient(),
      ).run({'start_date': 'last Tuesday'});
      expect(result['code'], 'bad_input');
      expect('${result['error']}', contains('start_date'));
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
      // The budget as Firefly stored it, not the request read back to itself.
      final stored = result['budget']! as Map<String, Object?>;
      expect(stored['auto_budget_amount'], 500);
      expect(stored['auto_budget_type'], 'rollover');
      expect(stored['auto_budget_period'], 'monthly');
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
