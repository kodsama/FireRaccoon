import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon_mcp/fireracoon_mcp.dart';

import '../l10n/app_localizations.dart';

typedef IsolateSpawner =
    Future<Isolate> Function(
      void Function(McpIsolateConfig) entry,
      McpIsolateConfig message, {
      String? debugName,
    });

/// Runs the MCP server on localhost TCP in a worker isolate.
class McpService extends ChangeNotifier {
  McpService({IsolateSpawner? spawn}) : _spawn = spawn ?? Isolate.spawn;
  static final _log = AppLogger.scoped('mcp.service');

  final IsolateSpawner _spawn;

  bool get running => _port != null;
  int? get port => _port;
  String? get error => _error;

  /// Shared secret required on TCP `initialize.params.mcpToken`.
  String? get authToken => _authToken;

  int? _port;
  String? _error;
  String? _authToken;
  Isolate? _isolate;
  ReceivePort? _receive;

  Future<void> start({
    required String fireflyUrl,
    required String fireflyToken,
    int basePort = 8787,
    String? authToken,
  }) async {
    if (_isolate != null) {
      _log.finer('MCP start ignored because isolate is already running');
      return;
    }
    if (fireflyUrl.isEmpty || fireflyToken.isEmpty) {
      _error = 'Firefly credentials not configured';
      _log.warning('MCP start aborted: Firefly credentials missing');
      notifyListeners();
      return;
    }
    _authToken = (authToken != null && authToken.isNotEmpty)
        ? authToken
        : _generateToken();
    _log.info('Starting MCP server isolate from base port $basePort');
    _error = null;
    _receive = ReceivePort();
    _receive!.listen(_onMessage);
    try {
      _isolate = await _spawn(
        _serverEntry,
        McpIsolateConfig(
          _receive!.sendPort,
          basePort,
          fireflyUrl,
          fireflyToken,
          _authToken!,
        ),
        debugName: 'fireracoon-mcp-server',
      );
      _log.fine('MCP isolate spawned');
    } on Object catch (e) {
      _log.severe('Failed to spawn MCP isolate', e);
      _error = '$e';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _log.info('Stopping MCP service');
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receive?.close();
    _receive = null;
    _port = null;
    _authToken = null;
    notifyListeners();
  }

  void _onMessage(Object? message) {
    if (message is! Map) {
      _log.finer('Ignored MCP isolate message with unsupported type');
      return;
    }
    if (message['ready'] is int) {
      _port = message['ready'] as int;
      _error = null;
      _log.info('MCP server ready on port $_port');
      notifyListeners();
    } else if (message['error'] is String) {
      _error = message['error'] as String;
      _port = null;
      _log.severe('MCP isolate reported startup failure: $_error');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class McpIsolateConfig {
  const McpIsolateConfig(
    this.send,
    this.basePort,
    this.fireflyUrl,
    this.fireflyToken,
    this.authToken,
  );

  final SendPort send;
  final int basePort;
  final String fireflyUrl;
  final String fireflyToken;
  final String authToken;
}

Future<void> _serverEntry(McpIsolateConfig cfg) async {
  final log = AppLogger.scoped('mcp.isolate');
  final server = McpServer(
    tools: buildTools(
      defaultUrl: cfg.fireflyUrl,
      defaultToken: cfg.fireflyToken,
    ),
  );

  for (var port = cfg.basePort; port < cfg.basePort + 10; port++) {
    try {
      log.fine('Trying to bind MCP TCP server on port $port');
      await serveTcp(server, port: port, authToken: cfg.authToken);
      cfg.send.send({'ready': port});
      log.info('MCP TCP server bound on port $port');
      return;
    } on Object catch (error) {
      log.warning('Failed to bind MCP server on port $port: $error');
      continue;
    }
  }
  log.severe('No free MCP port in ${cfg.basePort}..${cfg.basePort + 9}');
  cfg.send.send({
    'error': 'no free port in ${cfg.basePort}..${cfg.basePort + 9}',
  });
}

String mcpStatusLabel(AppLocalizations l10n, McpService service) {
  if (service.error != null) return l10n.mcpStatusFailed(service.error!);
  if (service.running) return l10n.mcpStatusRunning(service.port!);
  return l10n.mcpStatusStarting;
}

bool get mcpDesktopSupported {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };
}

String _generateToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
