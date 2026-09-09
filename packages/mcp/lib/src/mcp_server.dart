import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import 'tools.dart';

/// A minimal, dependency-free implementation of the Model Context Protocol
/// (JSON-RPC 2.0) sufficient for tool serving: `initialize`, `tools/list`,
/// `tools/call`, `ping`, and the `initialized` notification.
class McpServer {
  /// Creates a server exposing [tools].
  McpServer({
    required this.tools,
    this.name = 'fireraccoon',
    this.version = '1.0.0',
    this.appVersion,
    this.protocolVersion = '2025-06-18',
    this.onActivity,
  });

  /// The tool catalog.
  final List<McpTool> tools;

  /// Called for every message an authenticated agent sends, so a host can keep
  /// the key's usage stamp current. Hooked here rather than at authentication:
  /// a connection is opened once but worked for hours, and a key that only ever
  /// authenticated is exactly what someone debugging a client wants to see.
  ///
  /// Hosts are expected to throttle; this fires as often as the agent talks.
  final void Function(AgentIdentity identity)? onActivity;

  /// Advertised server name.
  final String name;

  /// Advertised server version.
  final String version;

  /// The FireRaccoon release this server is part of, when the host knows it.
  ///
  /// Reported at `initialize`, before any tool has been called, because a
  /// model that does not know which app it is driving guesses: it invents
  /// features from another release, or blames the ledger for something this
  /// version simply does not do.
  final String? appVersion;

  /// Protocol revision used when the client doesn't request one.
  final String protocolVersion;

  /// Handles one decoded JSON-RPC request. Returns the response map, or null
  /// when the message is a notification (no `id`) needing no reply.
  ///
  /// [identity] is the account the caller's agent key resolved to. A null
  /// identity is treated as read-only: there is no unauthenticated path that
  /// should be able to move money.
  Future<Map<String, Object?>?> handle(
    Map<String, Object?> request, {
    AgentIdentity? identity,
  }) async {
    final id = request['id'];
    final method = request['method'];
    final params =
        (request['params'] as Map?)?.cast<String, Object?>() ?? const {};

    if (identity != null) onActivity?.call(identity);

    if (id == null) return null;

    switch (method) {
      case 'initialize':
        return _ok(id, {
          'protocolVersion':
              (params['protocolVersion'] as String?) ?? protocolVersion,
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {
            'name': name,
            'title': 'FireRaccoon',
            // The app's release when the host knows it, because that is the
            // version a person reads off the About screen and quotes in a bug
            // report. The server's own version is reported beside it rather
            // than in its place.
            'version': appVersion ?? version,
          },
          'instructions': _instructions,
          // Tools are shared across connections, so the session's own account
          // is reported here rather than through a tool call.
          'fireraccoon': {
            'app': {
              'name': 'FireRaccoon',
              'version': appVersion,
              'mcp_version': version,
            },
            'account': identity?.toJson(),
            'write_access': identity?.canWrite ?? false,
          },
        });

      case 'ping':
        return _ok(id, const {});

      case 'tools/list':
        return _ok(id, {
          'tools': [
            for (final t in tools)
              {
                'name': t.name,
                'description': t.description,
                'inputSchema': t.inputSchema,
                'annotations': {'readOnlyHint': !t.writes},
              },
          ],
        });

      case 'tools/call':
        return _call(id, params, identity);

      default:
        return _err(id, -32601, 'Method not found: $method');
    }
  }

  /// What a model needs before its first call, in the one place every client
  /// reads without being asked.
  String get _instructions {
    final release = appVersion == null ? '' : ' $appVersion';
    return 'These tools belong to FireRaccoon$release, a client for the '
        'Firefly III personal-finance ledger. They read and write that '
        'ledger, not FireRaccoon itself. Call get_capabilities first: it '
        'names this app and its version, lists every tool and which of them '
        'write, and reports live whether the ledger is reachable and as whom. '
        'A backend that is missing, unreachable, or behind a proxy sign-in is '
        'reported as a described state by every tool rather than raised as a '
        'failure, so read the code field before concluding anything is broken.';
  }

  Future<Map<String, Object?>> _call(
    Object id,
    Map<String, Object?> params,
    AgentIdentity? identity,
  ) async {
    final toolName = params['name'] as String?;
    final args =
        (params['arguments'] as Map?)?.cast<String, Object?>() ?? const {};
    final tool = tools.where((t) => t.name == toolName).firstOrNull;
    if (tool == null) {
      return _err(id, -32602, 'Unknown tool: $toolName');
    }
    if (tool.writes && !(identity?.canWrite ?? false)) {
      return _toolResult(id, {
        'ok': false,
        'code': 'forbidden',
        'error':
            '${tool.name} needs write access. This agent key is bound to '
            '${identity == null ? 'no account' : '${identity.personName} '
                      '(${identity.role})'}.',
      }, isError: true);
    }
    try {
      final result = await tool.run(args);
      return _toolResult(id, result, isError: result['ok'] == false);
    } on Object catch (e) {
      return _toolResult(id, {
        'ok': false,
        'code': 'tool_error',
        'error': '$e',
      }, isError: true);
    }
  }

  Map<String, Object?> _toolResult(
    Object id,
    Map<String, Object?> structured, {
    required bool isError,
  }) => _ok(id, {
    'content': [
      {
        'type': 'text',
        'text': const JsonEncoder.withIndent('  ').convert(structured),
      },
    ],
    'structuredContent': structured,
    'isError': isError,
  });

  Map<String, Object?> _ok(Object id, Map<String, Object?> result) => {
    'jsonrpc': '2.0',
    'id': id,
    'result': result,
  };

  Map<String, Object?> _err(Object id, int code, String message) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  };
}
