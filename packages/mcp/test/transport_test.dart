import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fireracoon_mcp/fireracoon_mcp.dart';
import 'package:test/test.dart';

McpServer _server() => McpServer(tools: buildTools());

class _ByteCollector implements StreamConsumer<List<int>> {
  _ByteCollector(this.sink);

  final List<int> sink;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      sink.addAll(chunk);
    }
  }

  @override
  Future<void> close() async {}
}

void main() {
  group('processLine', () {
    test('dispatches ping', () async {
      final response = await processLine(
        _server(),
        jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}),
      );
      expect(response, isNotNull);
      expect(response!['id'], 1);
      expect(response['result'], isA<Map<String, Object?>>());
    });

    test('returns null for notifications', () async {
      final response = await processLine(
        _server(),
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
      );
      expect(response, isNull);
    });

    test('malformed JSON is parse error', () async {
      final response = await processLine(_server(), '{bad');
      expect((response!['error'] as Map<String, Object?>)['code'], -32700);
    });

    test('non-object JSON is invalid request', () async {
      final response = await processLine(_server(), '123');
      expect((response!['error'] as Map<String, Object?>)['code'], -32600);
    });
  });

  group('serveStdio', () {
    test('reads frames from input and writes responses to output', () async {
      final input = Stream<List<int>>.fromIterable([
        utf8.encode(
          '${jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'})}\n',
        ),
        utf8.encode('\n'),
        utf8.encode(
          '${jsonEncode({
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'tools/call',
            'params': {'name': 'get_capabilities', 'arguments': <String, Object?>{}},
          })}\n',
        ),
      ]);

      final captured = <int>[];
      final output = IOSink(_ByteCollector(captured));
      await serveStdio(_server(), input: input, output: output);
      await output.close();

      final frames = utf8
          .decode(captured)
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .toList();

      expect(frames, hasLength(2));
      expect(
        frames.firstWhere((frame) => frame['id'] == 1)['result'],
        isNotNull,
      );
      final caps = frames.firstWhere((frame) => frame['id'] == 2);
      final structured =
          ((caps['result'] as Map<String, Object?>)['structuredContent'])
              as Map<String, Object?>;
      expect(structured['ok'], isTrue);
    });
  });

  group('extractMcpToken', () {
    test('reads mcpToken and mcp_token', () {
      expect(extractMcpToken({'mcpToken': 'a'}), 'a');
      expect(extractMcpToken({'mcp_token': 'b'}), 'b');
    });

    test('reads nested authentication token', () {
      expect(
        extractMcpToken({
          'authentication': {'token': 'nested'},
        }),
        'nested',
      );
      expect(
        extractMcpToken({
          'authentication': {'mcpToken': 'nested-mcp'},
        }),
        'nested-mcp',
      );
    });
  });

  group('serveTcp', () {
    test('logs auth requirement when token configured', () async {
      final logs = <String>[];
      final socket = await serveTcp(
        _server(),
        port: 0,
        authToken: 'secret-token',
        onLog: logs.add,
      );
      addTearDown(() => socket.close());
      expect(logs.any((line) => line.contains('TCP auth required')), isTrue);
    });

    test('invokes onLog when clients connect', () async {
      final logs = <String>[];
      final socket = await serveTcp(_server(), port: 0, onLog: logs.add);
      addTearDown(() => socket.close());

      final client = await Socket.connect('127.0.0.1', socket.port);
      addTearDown(() => client.destroy());
      await client.flush();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      client.destroy();

      expect(logs.any((line) => line.contains('listening')), isTrue);
      expect(logs.any((line) => line.contains('connected')), isTrue);
    });

    test('serves JSON-RPC over a real socket', () async {
      final socket = await serveTcp(_server(), port: 0);
      addTearDown(() => socket.close());

      final client = await Socket.connect('127.0.0.1', socket.port);
      addTearDown(() => client.destroy());

      final responses = <Map<String, Object?>>[];
      final done = Completer<void>();
      utf8.decoder.bind(client).transform(const LineSplitter()).listen((line) {
        if (line.trim().isEmpty) return;
        responses.add(jsonDecode(line) as Map<String, Object?>);
        if (responses.length == 2 && !done.isCompleted) done.complete();
      });

      client.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {'protocolVersion': '2025-06-18'},
        }),
      );
      client.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/call',
          'params': {
            'name': 'get_capabilities',
            'arguments': <String, Object?>{},
          },
        }),
      );
      await client.flush();
      await done.future.timeout(const Duration(seconds: 5));

      expect(
        ((responses.firstWhere((r) => r['id'] == 1)['result'])
            as Map<String, Object?>)['protocolVersion'],
        '2025-06-18',
      );
      final structured =
          (((responses.firstWhere((r) => r['id'] == 2)['result'])
                  as Map<String, Object?>)['structuredContent'])
              as Map<String, Object?>;
      expect(structured['ok'], isTrue);
    });

    test('pipelined requests respond in arrival order', () async {
      final slowDone = Completer<void>();
      final server = McpServer(
        tools: [
          McpTool(
            name: 'slow',
            description: 'delay',
            inputSchema: const {'type': 'object', 'properties': {}},
            run: (_) async {
              await Future<void>.delayed(const Duration(milliseconds: 100));
              slowDone.complete();
              return {'ok': true, 'tool': 'slow'};
            },
          ),
          McpTool(
            name: 'fast',
            description: 'instant',
            inputSchema: const {'type': 'object', 'properties': {}},
            run: (_) async => {'ok': true, 'tool': 'fast'},
          ),
        ],
      );

      final socket = await serveTcp(server, port: 0);
      addTearDown(() => socket.close());

      final client = await Socket.connect('127.0.0.1', socket.port);
      addTearDown(() => client.destroy());

      final responses = <Map<String, Object?>>[];
      final done = Completer<void>();
      utf8.decoder.bind(client).transform(const LineSplitter()).listen((line) {
        if (line.trim().isEmpty) return;
        responses.add(jsonDecode(line) as Map<String, Object?>);
        if (responses.length == 2 && !done.isCompleted) done.complete();
      });

      client.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {'name': 'slow', 'arguments': <String, Object?>{}},
        }),
      );
      await client.flush();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      client.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/call',
          'params': {'name': 'fast', 'arguments': <String, Object?>{}},
        }),
      );
      await client.flush();
      await done.future.timeout(const Duration(seconds: 5));

      expect(responses.map((response) => response['id']).toList(), [1, 2]);
    });

    test('rejects tools/call until initialize supplies mcpToken', () async {
      final socket = await serveTcp(
        _server(),
        port: 0,
        authToken: 'secret-token',
      );
      addTearDown(() => socket.close());

      final client = await Socket.connect('127.0.0.1', socket.port);
      addTearDown(() => client.destroy());

      final responses = <Map<String, Object?>>[];
      final done = Completer<void>();
      utf8.decoder.bind(client).transform(const LineSplitter()).listen((line) {
        if (line.trim().isEmpty) return;
        responses.add(jsonDecode(line) as Map<String, Object?>);
        if (responses.length == 3 && !done.isCompleted) done.complete();
      });

      client.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/list',
          'params': <String, Object?>{},
        }),
      );
      client.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'initialize',
          'params': {'protocolVersion': '2025-06-18', 'mcpToken': 'wrong'},
        }),
      );
      client.writeln(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-06-18',
            'mcpToken': 'secret-token',
          },
        }),
      );
      await client.flush();
      await done.future.timeout(const Duration(seconds: 5));

      expect(
        (responses.firstWhere((r) => r['id'] == 1)['error']
            as Map<String, Object?>)['code'],
        -32000,
      );
      expect(
        (responses.firstWhere((r) => r['id'] == 2)['error']
            as Map<String, Object?>)['code'],
        -32000,
      );
      expect(
        responses.firstWhere((r) => r['id'] == 3)['result'],
        isA<Map<String, Object?>>(),
      );
    });
  });
}
