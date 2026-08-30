import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:test/test.dart';

McpServer _server() => McpServer(
  tools: buildTools(
    target: const FireflyTarget(
      baseUrl: 'http://localhost:8080',
      bearer: 'test-token',
    ),
  ),
);

const _admin = AgentIdentity(
  keyId: 'k1',
  personId: 'p1',
  personName: 'Ada',
  role: 'admin',
);

const _viewer = AgentIdentity(
  keyId: 'k2',
  personId: 'p2',
  personName: 'Grace',
  role: 'viewer',
);

Map<String, Object?> _req(
  int id,
  String method, [
  Map<String, Object?>? params,
]) {
  final message = <String, Object?>{
    'jsonrpc': '2.0',
    'id': id,
    'method': method,
  };
  if (params != null) message['params'] = params;
  return message;
}

void main() {
  test('initialize advertises tools capability', () async {
    final response = await _server().handle(
      _req(1, 'initialize', {'protocolVersion': '2025-06-18'}),
    );
    final result = response!['result'] as Map<String, Object?>;
    expect(result['protocolVersion'], '2025-06-18');
    expect(
      (result['capabilities'] as Map<String, Object?>).containsKey('tools'),
      isTrue,
    );
    expect(
      (result['serverInfo'] as Map<String, Object?>)['name'],
      'fireraccoon',
    );
  });

  test('initialize reports the session account and its write access', () async {
    final response = await _server().handle(
      _req(1, 'initialize', {'protocolVersion': '2025-06-18'}),
      identity: _admin,
    );
    final fireraccoon =
        (response!['result'] as Map<String, Object?>)['fireraccoon']
            as Map<String, Object?>;

    expect(fireraccoon['write_access'], isTrue);
    final account = fireraccoon['account'] as Map<String, Object?>;
    expect(account['person_name'], 'Ada');
    expect(account['role'], 'admin');
    expect(account['key_id'], 'k1');
  });

  test('initialize without an account reports no write access', () async {
    final response = await _server().handle(
      _req(1, 'initialize', {'protocolVersion': '2025-06-18'}),
    );
    final fireraccoon =
        (response!['result'] as Map<String, Object?>)['fireraccoon']
            as Map<String, Object?>;

    expect(fireraccoon['account'], isNull);
    expect(fireraccoon['write_access'], isFalse);
  });

  test('notifications return null', () async {
    final response = await _server().handle({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
    expect(response, isNull);
  });

  test('tools/list returns catalog with schemas', () async {
    final response = await _server().handle(_req(2, 'tools/list'));
    final tools =
        (response!['result'] as Map<String, Object?>)['tools'] as List<Object?>;
    final names = tools.map((t) => (t as Map<String, Object?>)['name']).toSet();
    expect(names, contains('get_capabilities'));
    expect(names, contains('run_projection'));
    for (final tool in tools) {
      expect(
        (tool as Map<String, Object?>)['inputSchema'],
        isA<Map<String, Object?>>(),
      );
    }
  });

  test('tools/list marks mutating tools as not read-only', () async {
    final response = await _server().handle(_req(2, 'tools/list'));
    final tools =
        ((response!['result'] as Map<String, Object?>)['tools']
                as List<Object?>)
            .cast<Map<String, Object?>>();

    bool readOnly(String name) =>
        (tools.firstWhere((t) => t['name'] == name)['annotations']
                as Map<String, Object?>)['readOnlyHint']
            as bool;

    expect(readOnly('get_accounts'), isTrue);
    expect(readOnly('delete_budget'), isFalse);
    expect(readOnly('store_reconciliation'), isFalse);
  });

  test('the full catalog is listed to a viewer, gated only on call', () async {
    final response = await _server().handle(
      _req(2, 'tools/list'),
      identity: _viewer,
    );
    final tools =
        (response!['result'] as Map<String, Object?>)['tools'] as List<Object?>;

    expect(tools, hasLength(mcpToolNames().length));
  });

  group('onActivity', () {
    McpServer serverReporting(List<AgentIdentity> seen) => McpServer(
      tools: buildTools(target: const FireflyTarget.unconfigured()),
      onActivity: seen.add,
    );

    test('fires for every message an authenticated agent sends', () async {
      final seen = <AgentIdentity>[];
      final server = serverReporting(seen);

      await server.handle(_req(1, 'initialize'), identity: _admin);
      await server.handle(_req(2, 'ping'), identity: _admin);
      await server.handle(_req(3, 'tools/list'), identity: _admin);
      await server.handle(
        _req(4, 'tools/call', {'name': 'get_capabilities', 'arguments': {}}),
        identity: _admin,
      );

      expect(seen, hasLength(4));
      expect(seen.map((i) => i.keyId).toSet(), {'k1'});
    });

    test('fires for a notification, which returns no response', () async {
      final seen = <AgentIdentity>[];

      final response = await serverReporting(seen).handle({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      }, identity: _admin);

      expect(response, isNull);
      expect(seen, hasLength(1));
    });

    test('fires for a viewer refused a write tool', () async {
      final seen = <AgentIdentity>[];

      await serverReporting(seen).handle(
        _req(1, 'tools/call', {'name': 'delete_budget', 'arguments': {}}),
        identity: _viewer,
      );

      expect(seen.single.keyId, 'k2');
    });

    test('does not fire without a resolved account', () async {
      final seen = <AgentIdentity>[];

      await serverReporting(seen).handle(_req(1, 'initialize'));
      await serverReporting(seen).handle(_req(2, 'tools/list'));

      expect(seen, isEmpty);
    });
  });

  group('write gate', () {
    const writeTools = [
      'set_primary_currency',
      'set_transaction_reconciled',
      'store_reconciliation',
      'update_account',
      'update_budget',
      'delete_budget',
    ];

    Future<Map<String, Object?>> call(
      String tool, {
      AgentIdentity? identity,
    }) async {
      final response = await _server().handle(
        _req(9, 'tools/call', {'name': tool, 'arguments': {}}),
        identity: identity,
      );
      return (response!['result'] as Map<String, Object?>)['structuredContent']
          as Map<String, Object?>;
    }

    for (final tool in writeTools) {
      test('$tool is refused for a viewer key', () async {
        final structured = await call(tool, identity: _viewer);

        expect(structured['ok'], isFalse);
        expect(structured['code'], 'forbidden');
        expect(structured['error'], contains('Grace'));
        expect(structured['error'], contains('viewer'));
      });

      test('$tool is refused when no key resolved an account', () async {
        final structured = await call(tool);

        expect(structured['code'], 'forbidden');
        expect(structured['error'], contains('no account'));
      });
    }

    test('a read tool is served to a viewer', () async {
      final structured = await call('get_capabilities', identity: _viewer);

      expect(structured['ok'], isTrue);
    });

    test(
      'a user key clears the gate and reaches argument validation',
      () async {
        final structured = await call(
          'delete_budget',
          identity: const AgentIdentity(
            keyId: 'k3',
            personId: 'p3',
            personName: 'Linus',
            role: 'user',
          ),
        );

        expect(structured['code'], 'bad_input');
      },
    );
  });

  test('get_capabilities returns tool list', () async {
    final response = await _server().handle(
      _req(3, 'tools/call', {'name': 'get_capabilities', 'arguments': {}}),
    );
    final result = response!['result'] as Map<String, Object?>;
    expect(result['isError'], isFalse);
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(structured['ok'], isTrue);
    expect(structured['tools'], isA<List<Object?>>());
  });

  test('unknown tool returns invalid params', () async {
    final response = await _server().handle(
      _req(4, 'tools/call', {'name': 'missing', 'arguments': {}}),
    );
    expect((response!['error'] as Map<String, Object?>)['code'], -32602);
  });

  test('unknown method returns not found', () async {
    final response = await _server().handle(_req(7, 'nope'));
    expect((response!['error'] as Map<String, Object?>)['code'], -32601);
  });

  test('delete_budget validates budget_id', () async {
    final response = await _server().handle(
      _req(5, 'tools/call', {'name': 'delete_budget', 'arguments': {}}),
      identity: _admin,
    );
    final result = response!['result'] as Map<String, Object?>;
    expect(result['isError'], isTrue);
    expect(
      (result['structuredContent'] as Map<String, Object?>)['code'],
      'bad_input',
    );
  });

  test('thrown tool errors include structuredContent', () async {
    final server = McpServer(
      tools: [
        McpTool(
          name: 'boom',
          description: 'throws',
          inputSchema: const {'type': 'object'},
          run: (_) async => throw StateError('boom'),
        ),
      ],
    );
    final response = await server.handle(
      _req(6, 'tools/call', {'name': 'boom', 'arguments': {}}),
    );
    final result = response!['result'] as Map<String, Object?>;
    expect(result['isError'], isTrue);
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(structured['ok'], isFalse);
    expect(structured['code'], 'tool_error');
    expect(structured['error'], contains('boom'));
  });
}
