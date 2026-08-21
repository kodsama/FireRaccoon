import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon_mcp/fireracoon_mcp.dart';

import '../l10n/app_localizations.dart';

typedef IsolateSpawner =
    Future<Isolate> Function(
      void Function(McpIsolateConfig) entry,
      McpIsolateConfig message, {
      String? debugName,
      SendPort? onExit,
      SendPort? onError,
    });

/// Runs the MCP server on localhost TCP in a worker isolate.
///
/// Agents authenticate with a FireRacoon agent key rather than a Firefly token:
/// the isolate gets a snapshot of the key digests and their people, and every
/// connection resolves to an account whose role decides whether write tools are
/// available. Because the snapshot is copied into the isolate, changing keys or
/// people means restarting it, which is also what makes a revocation drop the
/// connections that key had open.
class McpService extends ChangeNotifier {
  McpService({IsolateSpawner? spawn}) : _spawn = spawn ?? Isolate.spawn;
  static final _log = AppLogger.scoped('mcp.service');

  final IsolateSpawner _spawn;

  bool get running => _port != null;
  int? get port => _port;
  String? get error => _error;

  /// True when a Firefly connection exists but no agent key does, so there is
  /// nothing an agent could authenticate with yet.
  bool get needsAgentKey => _needsAgentKey;

  /// Notified when an agent key is used, so the key store can record it. The
  /// isolate throttles before reporting, so this fires rarely.
  void Function(String keyId, DateTime at)? onKeyUsed;

  int? _port;
  String? _error;
  bool _needsAgentKey = false;
  String? _fingerprint;
  Isolate? _isolate;
  ReceivePort? _receive;
  Future<void>? _queue;
  SendPort? _control;
  Completer<void>? _exited;
  bool _stopping = false;

  /// Brings the server in line with [agentKeys] and [people].
  ///
  /// Restarts the isolate when anything it captured has changed, and is a no-op
  /// otherwise, so this is safe to call on every provider rebuild.
  ///
  /// Calls are serialized. Several providers fire this at once, and a second
  /// pass landing during the first one's spawn would see a matching fingerprint
  /// but a still-null isolate, spawn a duplicate, and orphan whichever bound
  /// first: two servers listening, only one of them killable.
  Future<void> sync({
    required String fireflyUrl,
    required String fireflyToken,
    required List<AgentKey> agentKeys,
    required List<AgentKeyPerson> people,
    String? agentKeysError,
    int basePort = 8787,
  }) {
    final next = (_queue ?? Future<void>.value()).then(
      (_) => _sync(
        fireflyUrl: fireflyUrl,
        fireflyToken: fireflyToken,
        agentKeys: agentKeys,
        people: people,
        agentKeysError: agentKeysError,
        basePort: basePort,
      ),
    );
    // Swallowed on the queue only: the caller still sees the real failure.
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _sync({
    required String fireflyUrl,
    required String fireflyToken,
    required List<AgentKey> agentKeys,
    required List<AgentKeyPerson> people,
    required String? agentKeysError,
    required int basePort,
  }) async {
    final active = [
      for (final key in agentKeys)
        if (key.isActive) key,
    ];
    final next = _fingerprintOf(
      fireflyUrl: fireflyUrl,
      fireflyToken: fireflyToken,
      agentKeys: active,
      people: people,
    );
    if (next == _fingerprint && _isolate != null) {
      _log.finer('MCP sync ignored: nothing the isolate captured changed');
      return;
    }

    // Graceful, not a kill: a restart has to reclaim the same port number.
    await _shutdown();
    _fingerprint = next;

    if (fireflyUrl.isEmpty || fireflyToken.isEmpty) {
      _error = 'Firefly credentials not configured';
      _needsAgentKey = false;
      _log.warning('MCP start aborted: Firefly credentials missing');
      notifyListeners();
      return;
    }
    if (agentKeysError != null) {
      // A store that cannot be read is not a store with no keys in it. Saying
      // "no keys issued" for a keychain that refused sends someone off to
      // reissue a key they already have.
      _error = agentKeysError;
      _needsAgentKey = false;
      _log.severe('MCP start aborted: agent keys unreadable: $agentKeysError');
      notifyListeners();
      return;
    }
    if (active.isEmpty) {
      // Listening with no key admits nobody; stay down and say why.
      _error = null;
      _needsAgentKey = true;
      _log.info('MCP server idle: no agent keys issued');
      notifyListeners();
      return;
    }

    _error = null;
    _needsAgentKey = false;
    _log.info(
      'Starting MCP server isolate from base port $basePort '
      'with ${active.length} agent key(s)',
    );
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
          active,
          people,
        ),
        debugName: 'fireracoon-mcp-server',
        // A healthy isolate never finishes: the listening socket keeps its event
        // loop alive. So an exit always means it died, and without this the UI
        // would keep advertising a port nothing is bound to.
        //
        // Registered at spawn rather than afterwards, or an isolate that dies
        // immediately would exit before the listener existed and go unnoticed.
        onExit: _receive!.sendPort,
        onError: _receive!.sendPort,
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
    await _shutdown();
    _fingerprint = null;
    _needsAgentKey = false;
    notifyListeners();
  }

  /// Asks the worker to close its socket, then kills it.
  ///
  /// Killing outright does not promptly release the listening port, so the next
  /// start would find it taken and quietly move to the port above. Clients are
  /// configured with a port number, so it has to be the same one next time.
  Future<void> _shutdown() async {
    final isolate = _isolate;
    if (isolate == null) {
      _teardown();
      return;
    }
    _stopping = true;
    final control = _control;
    if (control != null) {
      final exited = Completer<void>();
      _exited = exited;
      control.send(const {'shutdown': true});
      await exited.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          _log.warning('MCP isolate did not close its socket in time');
        },
      );
    }
    _teardown();
    _stopping = false;
  }

  void _teardown() {
    _exited = null;
    _control = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receive?.close();
    _receive = null;
    _port = null;
  }

  void _onMessage(Object? message) {
    // Isolate.spawn's onExit port delivers null when the worker finishes.
    if (message == null) {
      // An exit we asked for is the shutdown completing, not a crash.
      if (_stopping) {
        _exited?.complete();
        _exited = null;
        return;
      }
      _isolateDown('MCP server stopped unexpectedly');
      return;
    }
    // onError delivers [error, stackTrace] as strings.
    if (message is List) {
      _isolateDown('${message.isEmpty ? 'unknown error' : message.first}');
      return;
    }
    if (message is! Map) {
      _log.finer('Ignored MCP isolate message with unsupported type');
      return;
    }
    if (message['ready'] is int) {
      _port = message['ready'] as int;
      _control = message['control'] as SendPort?;
      _error = null;
      _log.info('MCP server ready on port $_port');
      notifyListeners();
    } else if (message['usedKeyId'] is String) {
      final at = DateTime.tryParse(message['usedAt'] as String? ?? '');
      if (at == null) return;
      _log.finer('Agent key ${message['usedKeyId']} used at $at');
      onKeyUsed?.call(message['usedKeyId'] as String, at);
    } else if (message['error'] is String) {
      _error = message['error'] as String;
      _port = null;
      _log.severe('MCP isolate reported startup failure: $_error');
      notifyListeners();
    }
  }

  /// Records that the worker died, so the UI stops advertising a port nothing
  /// is bound to.
  ///
  /// The fingerprint is cleared as well: without that, the next [sync] would see
  /// an unchanged snapshot and decline to rebuild, leaving the server down for
  /// good. There is no automatic retry, because a failure that recurs on every
  /// spawn would spin; the next real change restarts it.
  void _isolateDown(String reason) {
    // A deliberate stop already tore the isolate down, and its exit message is
    // not news.
    if (_isolate == null) return;
    _isolate = null;
    _receive?.close();
    _receive = null;
    _port = null;
    // A worker that explained itself before dying keeps its own message: "no
    // free port" tells the reader what to do, "stopped unexpectedly" does not.
    _error ??= reason;
    _fingerprint = null;
    _log.severe('MCP isolate down: ${_error ?? reason}');
    notifyListeners();
  }

  static String _fingerprintOf({
    required String fireflyUrl,
    required String fireflyToken,
    required List<AgentKey> agentKeys,
    required List<AgentKeyPerson> people,
  }) {
    final keyPart = (agentKeys.map((key) => key.hash).toList()..sort()).join(
      ',',
    );
    final peoplePart = (people.map((p) => '${p.id}:${p.role}').toList()..sort())
        .join(',');
    return '$fireflyUrl|${fireflyToken.hashCode}|$keyPart|$peoplePart';
  }

  @override
  void dispose() {
    // Tear down without notifying: listeners are gone by definition here, and
    // ChangeNotifier rejects a notify after dispose.
    _teardown();
    super.dispose();
  }
}

class McpIsolateConfig {
  const McpIsolateConfig(
    this.send,
    this.basePort,
    this.fireflyUrl,
    this.fireflyToken,
    this.agentKeys,
    this.people,
  );

  final SendPort send;
  final int basePort;
  final String fireflyUrl;
  final String fireflyToken;
  final List<AgentKey> agentKeys;
  final List<AgentKeyPerson> people;
}

Future<void> _serverEntry(McpIsolateConfig cfg) async {
  final log = AppLogger.scoped('mcp.isolate');

  // Seeded from the snapshot so a restart does not re-report a use the store
  // already knows about. Only the main isolate can reach secure storage, so
  // usage crosses back over the SendPort.
  final reported = <String, DateTime>{
    for (final key in cfg.agentKeys) key.id: ?key.lastUsedAt,
  };
  void reportUse(AgentIdentity identity) {
    final now = DateTime.now().toUtc();
    if (!shouldRecordAgentKeyUse(reported[identity.keyId], now)) return;
    reported[identity.keyId] = now;
    cfg.send.send({
      'usedKeyId': identity.keyId,
      'usedAt': now.toIso8601String(),
    });
  }

  // Every agent shares the app's single Firefly connection; the key only
  // decides which tools that agent may call, and which person get_capabilities
  // reports it as. One server per connection is what carries that identity;
  // sharing one across all of them left every caller anonymous.
  McpServer serverFor(AgentIdentity identity) => McpServer(
    tools: buildTools(
      target: FireflyTarget(baseUrl: cfg.fireflyUrl, bearer: cfg.fireflyToken),
      identity: identity,
    ),
    onActivity: reportUse,
  );
  final authenticator = SnapshotAuthenticator(
    keys: cfg.agentKeys,
    people: cfg.people,
  );

  for (var port = cfg.basePort; port < cfg.basePort + 10; port++) {
    final ServerSocket socket;
    try {
      log.fine('Trying to bind MCP TCP server on port $port');
      socket = await serveTcp(
        server: (identity, _) => serverFor(identity),
        authenticator: authenticator,
        port: port,
      );
    } on Object catch (error) {
      log.warning('Failed to bind MCP server on port $port: $error');
      continue;
    }
    // Closing the socket here, rather than relying on the kill, is what frees
    // the port in time for the next start to claim the same number.
    final control = ReceivePort();
    control.listen((message) async {
      if (message is Map && message['shutdown'] == true) {
        await socket.close();
        control.close();
        log.info('MCP TCP server released port $port');
      }
    });
    cfg.send.send({'ready': port, 'control': control.sendPort});
    log.info('MCP TCP server bound on port $port');
    return;
  }
  log.severe('No free MCP port in ${cfg.basePort}..${cfg.basePort + 9}');
  cfg.send.send({
    'error': 'no free port in ${cfg.basePort}..${cfg.basePort + 9}',
  });
}

String mcpStatusLabel(AppLocalizations l10n, McpService service) {
  if (service.error != null) return l10n.mcpStatusFailed(service.error!);
  if (service.needsAgentKey) return l10n.mcpStatusNoKeys;
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
