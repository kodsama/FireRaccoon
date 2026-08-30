import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:test/test.dart';

McpServer _server() =>
    McpServer(tools: buildTools(target: const FireflyTarget.unconfigured()));

const _adminIdentity = AgentIdentity(
  keyId: 'k1',
  personId: 'p1',
  personName: 'Ada',
  role: 'admin',
);

/// Admits exactly one secret, so tests can assert on both outcomes without
/// standing up a key store.
class _StubAuthenticator implements McpAuthenticator {
  _StubAuthenticator(this.accepted, {this.identity = _adminIdentity});

  final String accepted;
  final AgentIdentity identity;
  final keysSeen = <String>[];

  @override
  Future<AgentIdentity?> authenticate(String key) async {
    keysSeen.add(key);
    return key == accepted ? identity : null;
  }
}

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

/// Opens a socket, collects [expected] response frames, and returns them.
Future<List<Map<String, Object?>>> _exchange(
  ServerSocket socket,
  List<Map<String, Object?>> requests, {
  required int expected,
}) async {
  final client = await Socket.connect('127.0.0.1', socket.port);
  addTearDown(() => client.destroy());

  final responses = <Map<String, Object?>>[];
  final done = Completer<void>();
  utf8.decoder.bind(client).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;
    responses.add(jsonDecode(line) as Map<String, Object?>);
    if (responses.length == expected && !done.isCompleted) done.complete();
  });

  for (final request in requests) {
    client.writeln(jsonEncode(request));
  }
  await client.flush();
  await done.future.timeout(const Duration(seconds: 5));
  return responses;
}

Map<String, Object?> _initialize(String? key) => {
  'jsonrpc': '2.0',
  'id': 1,
  'method': 'initialize',
  'params': {'protocolVersion': '2025-06-18', 'apiKey': ?key},
};

Map<String, Object?> _call(int id, String tool) => {
  'jsonrpc': '2.0',
  'id': id,
  'method': 'tools/call',
  'params': {'name': tool, 'arguments': <String, Object?>{}},
};

Map<String, Object?> _errorOf(Map<String, Object?> response) =>
    response['error'] as Map<String, Object?>;

Map<String, Object?> _structuredOf(Map<String, Object?> response) =>
    (response['result'] as Map<String, Object?>)['structuredContent']
        as Map<String, Object?>;

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
      expect(_errorOf(response!)['code'], -32700);
    });

    test('non-object JSON is invalid request', () async {
      final response = await processLine(_server(), '123');
      expect(_errorOf(response!)['code'], -32600);
    });
  });

  group('serveStdio', () {
    test('reads frames from input and writes responses to output', () async {
      final input = Stream<List<int>>.fromIterable([
        utf8.encode(
          '${jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'})}\n',
        ),
        utf8.encode('\n'),
        utf8.encode('${jsonEncode(_call(2, 'get_capabilities'))}\n'),
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
      expect(
        _structuredOf(frames.firstWhere((frame) => frame['id'] == 2))['ok'],
        isTrue,
      );
    });

    test('passes its startup identity to write tools', () async {
      final input = Stream<List<int>>.fromIterable([
        utf8.encode('${jsonEncode(_initialize(null))}\n'),
      ]);
      final captured = <int>[];
      final output = IOSink(_ByteCollector(captured));

      await serveStdio(
        _server(),
        identity: _adminIdentity,
        input: input,
        output: output,
      );
      await output.close();

      final frame =
          jsonDecode(utf8.decode(captured).trim()) as Map<String, Object?>;
      final fireraccoon =
          (frame['result'] as Map<String, Object?>)['fireraccoon']
              as Map<String, Object?>;
      expect(fireraccoon['write_access'], isTrue);
      expect(
        (fireraccoon['account'] as Map<String, Object?>)['person_name'],
        'Ada',
      );
    });
  });

  group('extractAgentKey', () {
    test('reads apiKey and api_key', () {
      expect(extractAgentKey({'apiKey': 'a'}), 'a');
      expect(extractAgentKey({'api_key': 'b'}), 'b');
    });

    test('reads nested authentication token', () {
      expect(
        extractAgentKey({
          'authentication': {'token': 'nested'},
        }),
        'nested',
      );
      expect(
        extractAgentKey({
          'authentication': {'api_key': 'nested-key'},
        }),
        'nested-key',
      );
    });

    test('returns null when no key is present', () {
      expect(extractAgentKey(const {}), isNull);
      expect(extractAgentKey({'apiKey': ''}), isNull);
      expect(extractAgentKey({'mcpToken': 'legacy'}), isNull);
    });
  });

  group('serveTcp', () {
    Future<ServerSocket> start(
      McpAuthenticator authenticator, {
      List<String>? logs,
      McpServer Function()? server,
    }) async {
      final socket = await serveTcp(
        server: (_, _) => (server ?? _server)(),
        authenticator: authenticator,
        port: 0,
        onLog: logs?.add,
      );
      addTearDown(() => socket.close());
      return socket;
    }

    test('announces that a key is required', () async {
      final logs = <String>[];
      await start(_StubAuthenticator('good'), logs: logs);

      expect(logs.any((line) => line.contains('TCP auth required')), isTrue);
    });

    test('invokes onLog when clients connect', () async {
      final logs = <String>[];
      final socket = await start(_StubAuthenticator('good'), logs: logs);

      final client = await Socket.connect('127.0.0.1', socket.port);
      addTearDown(() => client.destroy());
      await client.flush();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      client.destroy();

      expect(logs.any((line) => line.contains('listening')), isTrue);
      expect(logs.any((line) => line.contains('connected')), isTrue);
    });

    test('serves JSON-RPC once a valid key authenticates', () async {
      final logs = <String>[];
      final socket = await start(_StubAuthenticator('good'), logs: logs);

      final responses = await _exchange(socket, [
        _initialize('good'),
        _call(2, 'get_capabilities'),
      ], expected: 2);

      final init = responses.firstWhere((r) => r['id'] == 1);
      expect(
        (init['result'] as Map<String, Object?>)['protocolVersion'],
        '2025-06-18',
      );
      expect(
        _structuredOf(responses.firstWhere((r) => r['id'] == 2))['ok'],
        isTrue,
      );
      expect(logs.any((line) => line.contains('authenticated as Ada')), isTrue);
    });

    test(
      'rejects every method until initialize supplies a valid key',
      () async {
        final socket = await start(_StubAuthenticator('good'));

        final responses = await _exchange(socket, [
          {
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'tools/list',
            'params': <String, Object?>{},
          },
          {
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'initialize',
            'params': {'protocolVersion': '2025-06-18', 'apiKey': 'wrong'},
          },
          {
            'jsonrpc': '2.0',
            'id': 3,
            'method': 'initialize',
            'params': {'protocolVersion': '2025-06-18', 'apiKey': 'good'},
          },
        ], expected: 3);

        expect(
          _errorOf(responses.firstWhere((r) => r['id'] == 1))['code'],
          -32000,
        );
        expect(
          _errorOf(responses.firstWhere((r) => r['id'] == 2))['code'],
          -32000,
        );
        expect(
          responses.firstWhere((r) => r['id'] == 3)['result'],
          isA<Map<String, Object?>>(),
        );
      },
    );

    test('an initialize with no key at all is rejected', () async {
      final socket = await start(_StubAuthenticator('good'));

      final responses = await _exchange(socket, [
        _initialize(null),
      ], expected: 1);

      expect(_errorOf(responses.single)['code'], -32000);
      expect(_errorOf(responses.single)['message'], contains('agent key'));
    });

    test('hands the connection its own key to the server factory', () async {
      final seen = <String>[];
      final socket = await serveTcp(
        server: (_, agentKey) {
          seen.add(agentKey);
          return _server();
        },
        authenticator: _StubAuthenticator('good'),
        port: 0,
      );
      addTearDown(() => socket.close());

      await _exchange(socket, [_initialize('good')], expected: 1);

      expect(seen, ['good']);
    });

    test('pipelined requests respond in arrival order', () async {
      final socket = await start(
        _StubAuthenticator('good'),
        server: () => McpServer(
          tools: [
            McpTool(
              name: 'slow',
              description: 'delay',
              inputSchema: const {'type': 'object', 'properties': {}},
              run: (_) async {
                await Future<void>.delayed(const Duration(milliseconds: 100));
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
        ),
      );

      final responses = await _exchange(socket, [
        _initialize('good'),
        _call(2, 'slow'),
        _call(3, 'fast'),
      ], expected: 3);

      expect(responses.map((response) => response['id']).toList(), [1, 2, 3]);
    });

    test(
      'a client that hangs up mid-exchange does not kill the server',
      () async {
        final socket = await start(_StubAuthenticator('good'));

        // Fire requests and reset the connection without reading any reply, so
        // the server's next write lands on a dead peer.
        for (var attempt = 0; attempt < 3; attempt++) {
          final rude = await Socket.connect('127.0.0.1', socket.port);
          rude.writeln(jsonEncode(_initialize('good')));
          rude.writeln(jsonEncode(_call(2, 'get_capabilities')));
          await rude.flush();
          rude.destroy();
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // The listener must still be serving a well-behaved client.
        final responses = await _exchange(socket, [
          _initialize('good'),
          _call(2, 'get_capabilities'),
        ], expected: 2);

        expect(
          _structuredOf(responses.firstWhere((r) => r['id'] == 2))['ok'],
          isTrue,
        );
      },
    );

    test('a half-written frame from a dropped client is survivable', () async {
      final logs = <String>[];
      final socket = await start(_StubAuthenticator('good'), logs: logs);

      final rude = await Socket.connect('127.0.0.1', socket.port);
      rude.write('{"jsonrpc":"2.0","id":1,"method":"initi');
      await rude.flush();
      rude.destroy();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final responses = await _exchange(socket, [
        _initialize('good'),
      ], expected: 1);

      expect(responses.single['result'], isNotNull);
    });

    test('a viewer key is admitted but refused write tools', () async {
      final socket = await start(
        _StubAuthenticator(
          'good',
          identity: const AgentIdentity(
            keyId: 'k2',
            personId: 'p2',
            personName: 'Grace',
            role: 'viewer',
          ),
        ),
      );

      final responses = await _exchange(socket, [
        _initialize('good'),
        _call(2, 'delete_budget'),
      ], expected: 2);

      final init = responses.firstWhere((r) => r['id'] == 1);
      expect(
        ((init['result'] as Map<String, Object?>)['fireraccoon']
            as Map<String, Object?>)['write_access'],
        isFalse,
      );
      final refusal = _structuredOf(responses.firstWhere((r) => r['id'] == 2));
      expect(refusal['ok'], isFalse);
      expect(refusal['code'], 'forbidden');
      expect(refusal['error'], contains('Grace'));
    });
  });
}
