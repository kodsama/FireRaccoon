import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mcp_server.dart';

/// Serves [server] over stdio: newline-delimited JSON-RPC on stdin/stdout.
Future<void> serveStdio(
  McpServer server, {
  Stream<List<int>>? input,
  IOSink? output,
}) async {
  final source = input ?? stdin;
  final sink = output ?? stdout;
  final lines = source.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final response = await processLine(server, line);
    if (response != null) {
      sink.writeln(jsonEncode(response));
      await sink.flush();
    }
  }
}

/// Serves [server] over a localhost TCP socket.
///
/// When [authToken] is non-empty, each connection must authenticate via
/// `initialize` params (`mcpToken` or `authentication.token`) before other
/// methods are accepted.
Future<ServerSocket> serveTcp(
  McpServer server, {
  String host = '127.0.0.1',
  int port = 8787,
  String? authToken,
  void Function(String message)? onLog,
}) async {
  final requiredToken = (authToken == null || authToken.isEmpty)
      ? null
      : authToken;
  final socket = await ServerSocket.bind(host, port);
  onLog?.call('MCP server listening on $host:${socket.port}');
  if (requiredToken != null) {
    onLog?.call('TCP auth required (MCP_TOKEN)');
  }
  socket.listen((client) {
    onLog?.call('client connected: ${client.remoteAddress.address}');
    var authenticated = requiredToken == null;
    const splitter = LineSplitter();
    var buffer = '';
    var tail = Future<void>.value();
    utf8.decoder
        .bind(client)
        .listen(
          (chunk) {
            buffer += chunk;
            final parts = buffer.split('\n');
            buffer = parts.removeLast();
            for (final raw in parts) {
              for (final line in splitter.convert(raw)) {
                if (line.trim().isEmpty) continue;
                final captured = line;
                tail = tail.then((_) async {
                  final response = await processLine(
                    server,
                    captured,
                    requiredAuthToken: requiredToken,
                    isAuthenticated: () => authenticated,
                    onAuthenticated: () => authenticated = true,
                  );
                  if (response != null) client.writeln(jsonEncode(response));
                });
              }
            }
          },
          onDone: () => onLog?.call('client disconnected'),
          onError: (Object _) => client.destroy(),
          cancelOnError: true,
        );
  });
  return socket;
}

String? extractMcpToken(Map<String, Object?> params) {
  final direct = params['mcpToken'] ?? params['mcp_token'];
  if (direct is String && direct.isNotEmpty) return direct;
  final auth = params['authentication'];
  if (auth is Map) {
    final token = auth['token'] ?? auth['mcpToken'];
    if (token is String && token.isNotEmpty) return token;
  }
  return null;
}

/// Decodes one line, dispatches it, and returns the response map (or null).
Future<Map<String, Object?>?> processLine(
  McpServer server,
  String line, {
  String? requiredAuthToken,
  bool Function()? isAuthenticated,
  void Function()? onAuthenticated,
}) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(line);
  } on FormatException {
    return {
      'jsonrpc': '2.0',
      'id': null,
      'error': {'code': -32700, 'message': 'Parse error'},
    };
  }
  if (decoded is! Map) {
    return {
      'jsonrpc': '2.0',
      'id': null,
      'error': {'code': -32600, 'message': 'Invalid Request'},
    };
  }
  final request = decoded.cast<String, Object?>();
  final id = request['id'];
  final method = request['method'];
  final params =
      (request['params'] as Map?)?.cast<String, Object?>() ?? const {};

  if (requiredAuthToken != null) {
    final already = isAuthenticated?.call() ?? false;
    if (!already) {
      if (method != 'initialize') {
        if (id == null) return null;
        return {
          'jsonrpc': '2.0',
          'id': id,
          'error': {
            'code': -32000,
            'message':
                'Unauthorized: authenticate via initialize params.mcpToken',
          },
        };
      }
      final provided = extractMcpToken(params);
      if (provided != requiredAuthToken) {
        return {
          'jsonrpc': '2.0',
          'id': id,
          'error': {
            'code': -32000,
            'message': 'Unauthorized: invalid or missing mcpToken',
          },
        };
      }
      onAuthenticated?.call();
    }
  }

  return server.handle(request);
}
