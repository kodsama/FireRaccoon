import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fireracoon_engine/fireracoon_engine.dart';

import 'auth.dart';
import 'mcp_server.dart';

/// Builds the server a freshly authenticated connection will talk to.
///
/// The desktop app returns one shared server: every agent reaches the same
/// Firefly connection and only write access varies. A standalone server instead
/// builds a server per connection so Firefly traffic carries the caller's own
/// agent key, leaving the backend as the authority on what that key may do.
typedef McpServerForConnection =
    McpServer Function(AgentIdentity identity, String agentKey);

/// Serves [server] over stdio: newline-delimited JSON-RPC on stdin/stdout.
///
/// The parent process supplied the agent key in the environment, so [identity]
/// is resolved once at startup rather than challenged per message.
Future<void> serveStdio(
  McpServer server, {
  AgentIdentity? identity,
  Stream<List<int>>? input,
  IOSink? output,
}) async {
  final source = input ?? stdin;
  final sink = output ?? stdout;
  final lines = source.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final response = await processLine(server, line, identity: identity);
    if (response != null) {
      sink.writeln(jsonEncode(response));
      await sink.flush();
    }
  }
}

/// Serves MCP over a localhost TCP socket.
///
/// Any local process can reach the port, so a connection must present a
/// FireRacoon agent key in `initialize` params before any other method is
/// accepted. The resolved account is scoped to that connection and gates write
/// tools for its lifetime.
Future<ServerSocket> serveTcp({
  required McpServerForConnection server,
  required McpAuthenticator authenticator,
  String host = '127.0.0.1',
  int port = 8787,
  void Function(String message)? onLog,
}) async {
  final socket = await ServerSocket.bind(host, port);
  onLog?.call('MCP server listening on $host:${socket.port}');
  onLog?.call('TCP auth required (FireRacoon agent key)');
  socket.listen((client) {
    onLog?.call('client connected: ${client.remoteAddress.address}');
    // The sink reports a broken pipe here as well as at the write site; both
    // paths have to be dead ends or the isolate dies.
    client.done.catchError((Object _) => client.destroy());
    AgentIdentity? identity;
    McpServer? connectionServer;
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
                tail = tail
                    .then((_) async {
                      if (identity == null) {
                        final admission = await admitConnection(
                          captured,
                          authenticator,
                        );
                        if (admission.rejection != null) {
                          client.writeln(jsonEncode(admission.rejection));
                          return;
                        }
                        if (admission.silent) return;
                        identity = admission.identity;
                        connectionServer = server(
                          admission.identity!,
                          admission.agentKey!,
                        );
                        onLog?.call(
                          'client authenticated as ${identity!.personName} '
                          '(${identity!.role})',
                        );
                      }
                      final response = await processLine(
                        connectionServer!,
                        captured,
                        identity: identity,
                      );
                      if (response != null) {
                        client.writeln(jsonEncode(response));
                      }
                      // A client that hangs up mid-exchange makes the next write
                      // throw. Unhandled, that error escapes this chain and takes
                      // the whole server down with one rude disconnect, so every
                      // failure ends at this connection.
                    })
                    .catchError((Object error) {
                      onLog?.call('dropping client after failure: $error');
                      client.destroy();
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

/// Outcome of vetting the first message on an unauthenticated connection.
class ConnectionAdmission {
  const ConnectionAdmission.admitted(this.identity, this.agentKey)
    : rejection = null,
      silent = false;

  const ConnectionAdmission.rejected(this.rejection)
    : identity = null,
      agentKey = null,
      silent = false;

  /// A notification arrived before `initialize`: nothing to answer, nothing to
  /// admit.
  const ConnectionAdmission.ignored()
    : identity = null,
      agentKey = null,
      rejection = null,
      silent = true;

  final AgentIdentity? identity;
  final String? agentKey;
  final Map<String, Object?>? rejection;
  final bool silent;
}

/// Vets [line] as the `initialize` that opens an authenticated session.
Future<ConnectionAdmission> admitConnection(
  String line,
  McpAuthenticator authenticator,
) async {
  final decoded = _decode(line);
  if (decoded.malformed != null) {
    return ConnectionAdmission.rejected(decoded.malformed);
  }
  final request = decoded.request!;
  final id = request['id'];
  if (request['method'] != 'initialize') {
    if (id == null) return const ConnectionAdmission.ignored();
    return ConnectionAdmission.rejected(
      _error(
        id,
        -32000,
        'Unauthorized: authenticate via initialize params.apiKey',
      ),
    );
  }

  final params =
      (request['params'] as Map?)?.cast<String, Object?>() ?? const {};
  final key = extractAgentKey(params);
  final identity = key == null ? null : await authenticator.authenticate(key);
  if (identity == null) {
    return ConnectionAdmission.rejected(
      _error(
        id,
        -32000,
        'Unauthorized: unknown, revoked, or missing FireRacoon agent key. '
        'Issue one in Settings under MCP.',
      ),
    );
  }
  return ConnectionAdmission.admitted(identity, key!);
}

/// Decodes one line and dispatches it against [server].
Future<Map<String, Object?>?> processLine(
  McpServer server,
  String line, {
  AgentIdentity? identity,
}) async {
  final decoded = _decode(line);
  if (decoded.malformed != null) return decoded.malformed;
  return server.handle(decoded.request!, identity: identity);
}

/// A decoded request, or the JSON-RPC error to return instead of one.
class _Decoded {
  const _Decoded.request(this.request) : malformed = null;
  const _Decoded.malformed(this.malformed) : request = null;

  final Map<String, Object?>? request;
  final Map<String, Object?>? malformed;
}

_Decoded _decode(String line) {
  final Object? decoded;
  try {
    decoded = jsonDecode(line);
  } on FormatException {
    return _Decoded.malformed(_error(null, -32700, 'Parse error'));
  }
  if (decoded is! Map) {
    return _Decoded.malformed(_error(null, -32600, 'Invalid Request'));
  }
  return _Decoded.request(decoded.cast<String, Object?>());
}

Map<String, Object?> _error(Object? id, int code, String message) => {
  'jsonrpc': '2.0',
  'id': id,
  'error': {'code': code, 'message': message},
};
