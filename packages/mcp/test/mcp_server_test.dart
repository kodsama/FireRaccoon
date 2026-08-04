import 'package:fireracoon_mcp/fireracoon_mcp.dart';
import 'package:test/test.dart';

McpServer _server() => McpServer(
  tools: buildTools(
    defaultUrl: 'http://localhost:8080',
    defaultToken: 'test-token',
  ),
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
      'fireracoon',
    );
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
