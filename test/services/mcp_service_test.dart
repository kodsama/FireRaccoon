@Timeout(Duration(seconds: 30))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon/services/mcp_service.dart';
import 'package:fireracoon/l10n/app_localizations_en.dart';

const _url = 'http://localhost:8080';
const _token = 'test-token';

const _people = [
  AgentKeyPerson(id: 'p1', name: 'Ada', role: 'admin'),
  AgentKeyPerson(id: 'p2', name: 'Grace', role: 'viewer'),
];

IssuedAgentKey _issue({String personId = 'p1', String id = 'k1'}) {
  return issueAgentKey(
    personId: personId,
    label: 'agent $id',
    id: id,
    now: DateTime.utc(2026, 1, 1),
  );
}

void _sendNonMapMessage(SendPort sendPort) {
  sendPort.send('not-a-map');
}

/// Reports a bound port, lingers long enough for the service to observe it as
/// running, then exits. Stands in for a crash without needing a test-only hook
/// in production code.
///
/// No control port is sent, so shutdown falls back to the kill path.
Future<void> _readyThenExit(SendPort sendPort) async {
  sendPort.send(const {'ready': 19001});
  await Future<void>.delayed(const Duration(milliseconds: 400));
}

Future<Isolate> _spawnWithNonMapMessage(
  void Function(McpIsolateConfig) entry,
  McpIsolateConfig message, {
  String? debugName,
  SendPort? onExit,
  SendPort? onError,
}) {
  return Isolate.spawn<SendPort>(
    _sendNonMapMessage,
    message.send,
    debugName: debugName,
    onExit: onExit,
    onError: onError,
  );
}

/// Counts spawns while delegating to the real server entry.
class _CountingSpawner {
  var spawns = 0;

  Future<Isolate> call(
    void Function(McpIsolateConfig) entry,
    McpIsolateConfig message, {
    String? debugName,
    SendPort? onExit,
    SendPort? onError,
  }) {
    spawns++;
    return Isolate.spawn(
      entry,
      message,
      debugName: debugName,
      onExit: onExit,
      onError: onError,
    );
  }
}

/// First spawn dies after reporting ready; later spawns run the real entry.
class _CrashOnceSpawner {
  var spawns = 0;

  Future<Isolate> call(
    void Function(McpIsolateConfig) entry,
    McpIsolateConfig message, {
    String? debugName,
    SendPort? onExit,
    SendPort? onError,
  }) {
    spawns++;
    if (spawns == 1) {
      return Isolate.spawn<SendPort>(
        _readyThenExit,
        message.send,
        debugName: debugName,
        onExit: onExit,
        onError: onError,
      );
    }
    return Isolate.spawn(
      entry,
      message,
      debugName: debugName,
      onExit: onExit,
      onError: onError,
    );
  }
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Runs one `initialize` against the live port and returns its response.
Future<Map<String, Object?>> _initialize(int port, String? apiKey) async {
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    port,
  ).timeout(const Duration(seconds: 5));
  try {
    final response = utf8.decoder
        .bind(socket)
        .transform(const LineSplitter())
        .firstWhere((line) => line.trim().isNotEmpty)
        .timeout(const Duration(seconds: 5));
    socket.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': '2025-06-18', 'apiKey': ?apiKey},
      }),
    );
    await socket.flush();
    return jsonDecode(await response) as Map<String, Object?>;
  } finally {
    socket.destroy();
  }
}

Map<String, Object?> _fireracoonBlock(Map<String, Object?> response) {
  return (response['result'] as Map<String, Object?>)['fireracoon']
      as Map<String, Object?>;
}

void main() {
  test('sync binds localhost port then stop tears down', () async {
    final service = McpService();
    addTearDown(service.stop);
    final issued = _issue();

    expect(service.running, isFalse);
    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [issued.record],
      people: _people,
      basePort: 18800,
    );
    await _waitUntil(() => service.running || service.error != null);

    expect(service.error, isNull, reason: service.error);
    expect(service.port, inInclusiveRange(18800, 18809));
    expect(service.needsAgentKey, isFalse);

    await service.stop();
    expect(service.running, isFalse);
    expect(service.port, isNull);
  });

  test('an issued key authenticates and reports its account', () async {
    final service = McpService();
    addTearDown(service.stop);
    final issued = _issue();

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [issued.record],
      people: _people,
      basePort: 18810,
    );
    await _waitUntil(() => service.running || service.error != null);
    expect(service.error, isNull, reason: service.error);

    final fireracoon = _fireracoonBlock(
      await _initialize(service.port!, issued.secret),
    );

    expect(fireracoon['write_access'], isTrue);
    expect(
      (fireracoon['account'] as Map<String, Object?>)['person_name'],
      'Ada',
    );
  });

  test('a key bound to a viewer gets no write access', () async {
    final service = McpService();
    addTearDown(service.stop);
    final issued = _issue(personId: 'p2', id: 'k2');

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [issued.record],
      people: _people,
      basePort: 18815,
    );
    await _waitUntil(() => service.running || service.error != null);
    expect(service.error, isNull, reason: service.error);

    final fireracoon = _fireracoonBlock(
      await _initialize(service.port!, issued.secret),
    );

    expect(fireracoon['write_access'], isFalse);
    expect((fireracoon['account'] as Map<String, Object?>)['role'], 'viewer');
  });

  test('an unknown key is refused', () async {
    final service = McpService();
    addTearDown(service.stop);

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [_issue().record],
      people: _people,
      basePort: 18825,
    );
    await _waitUntil(() => service.running || service.error != null);
    expect(service.error, isNull, reason: service.error);

    final response = await _initialize(service.port!, _issue(id: 'k9').secret);

    expect((response['error'] as Map<String, Object?>)['code'], -32000);
  });

  test('a revoked key stops working after the next sync', () async {
    final service = McpService();
    addTearDown(service.stop);
    final issued = _issue();

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [issued.record],
      people: _people,
      basePort: 18830,
    );
    await _waitUntil(() => service.running || service.error != null);
    expect(service.error, isNull, reason: service.error);
    expect(
      (await _initialize(service.port!, issued.secret))['result'],
      isNotNull,
    );

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [issued.record.copyWith(revokedAt: DateTime.utc(2026, 6))],
      people: _people,
      basePort: 18830,
    );

    // The only remaining key was revoked, so there is nothing left to admit.
    expect(service.running, isFalse);
    expect(service.needsAgentKey, isTrue);
  });

  test('sync is a no-op when nothing the isolate captured changed', () async {
    final service = McpService();
    addTearDown(service.stop);
    final issued = _issue();

    Future<void> apply() => service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [issued.record],
      people: _people,
      basePort: 18840,
    );

    await apply();
    await _waitUntil(() => service.running);
    final port = service.port;

    await apply();
    await apply();

    expect(service.running, isTrue);
    expect(service.port, port);
  });

  test('sync restarts when a key is added', () async {
    final service = McpService();
    addTearDown(service.stop);
    final first = _issue();
    final second = _issue(personId: 'p2', id: 'k2');

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [first.record],
      people: _people,
      basePort: 18850,
    );
    await _waitUntil(() => service.running);

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [first.record, second.record],
      people: _people,
      basePort: 18850,
    );
    await _waitUntil(() => service.running);

    expect(service.error, isNull, reason: service.error);
    expect(
      (await _initialize(service.port!, second.secret))['result'],
      isNotNull,
    );
  });

  test('concurrent syncs spawn one isolate, not one each', () async {
    final spawner = _CountingSpawner();
    final service = McpService(spawn: spawner.call);
    addTearDown(service.stop);
    final issued = _issue();

    Future<void> apply() => service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [issued.record],
      people: _people,
      basePort: 18995,
    );

    // What happens on app start: several providers fire at once, so a second
    // pass lands while the first is still awaiting its spawn.
    await Future.wait([apply(), apply(), apply()]);
    await _waitUntil(() => service.running || service.error != null);

    expect(service.error, isNull, reason: service.error);
    expect(
      spawner.spawns,
      1,
      reason: 'a duplicate isolate would orphan whichever bound first',
    );
    expect(service.port, 18995);

    // stop() must leave nothing listening behind.
    await service.stop();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await expectLater(
      Socket.connect(
        InternetAddress.loopbackIPv4,
        18995,
        timeout: const Duration(seconds: 2),
      ),
      throwsA(isA<SocketException>()),
    );
  });

  group('usage reporting', () {
    test('a connecting agent reports its key as used', () async {
      final service = McpService();
      addTearDown(service.stop);
      final issued = _issue();
      final used = <(String, DateTime)>[];
      service.onKeyUsed = (id, at) => used.add((id, at));

      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [issued.record],
        people: _people,
        basePort: 18950,
      );
      await _waitUntil(() => service.running || service.error != null);
      expect(service.error, isNull, reason: service.error);

      await _initialize(service.port!, issued.secret);
      await _waitUntil(() => used.isNotEmpty);

      expect(used, hasLength(1));
      expect(used.single.$1, 'k1');
      expect(used.single.$2.isUtc, isTrue);
    });

    test('a chatty agent is throttled to one report', () async {
      final service = McpService();
      addTearDown(service.stop);
      final issued = _issue();
      final used = <String>[];
      service.onKeyUsed = (id, _) => used.add(id);

      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [issued.record],
        people: _people,
        basePort: 18955,
      );
      await _waitUntil(() => service.running || service.error != null);
      expect(service.error, isNull, reason: service.error);

      for (var i = 0; i < 4; i++) {
        await _initialize(service.port!, issued.secret);
      }
      await _waitUntil(() => used.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(used, hasLength(1));
    });

    test('a rejected key reports nothing', () async {
      final service = McpService();
      addTearDown(service.stop);
      final used = <String>[];
      service.onKeyUsed = (id, _) => used.add(id);

      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [_issue().record],
        people: _people,
        basePort: 18960,
      );
      await _waitUntil(() => service.running || service.error != null);
      expect(service.error, isNull, reason: service.error);

      await _initialize(service.port!, _issue(id: 'k9').secret);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(used, isEmpty);
    });

    test('a snapshot with a recent stamp suppresses a fresh report', () async {
      final service = McpService();
      addTearDown(service.stop);
      final issued = _issue();
      final used = <String>[];
      service.onKeyUsed = (id, _) => used.add(id);

      // Restarting the isolate must not re-report a use the store already has.
      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [issued.record.copyWith(lastUsedAt: DateTime.now().toUtc())],
        people: _people,
        basePort: 18965,
      );
      await _waitUntil(() => service.running || service.error != null);
      expect(service.error, isNull, reason: service.error);

      await _initialize(service.port!, issued.secret);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(used, isEmpty);
    });

    test('a stamp change alone does not restart the server', () async {
      final service = McpService();
      addTearDown(service.stop);
      final issued = _issue();

      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [issued.record],
        people: _people,
        basePort: 18970,
      );
      await _waitUntil(() => service.running);
      final port = service.port;

      // What recordUsage feeds back must not bounce the isolate, or a working
      // agent would keep killing its own connection.
      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [issued.record.copyWith(lastUsedAt: DateTime.now().toUtc())],
        people: _people,
        basePort: 18970,
      );

      expect(service.running, isTrue);
      expect(service.port, port);
    });
  });

  group('isolate death', () {
    test('a dead isolate stops being advertised as running', () async {
      final spawner = _CrashOnceSpawner();
      final service = McpService(spawn: spawner.call);
      addTearDown(service.stop);

      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [_issue().record],
        people: _people,
        basePort: 18980,
      );
      await _waitUntil(() => service.running);
      expect(service.running, isTrue, reason: 'precondition');

      await _waitUntil(() => service.error != null);

      expect(service.running, isFalse);
      expect(service.port, isNull);
      expect(service.error, contains('stopped unexpectedly'));
    });

    test('the next sync brings a dead server back', () async {
      final spawner = _CrashOnceSpawner();
      final service = McpService(spawn: spawner.call);
      addTearDown(service.stop);
      final issued = _issue();

      Future<void> apply() => service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [issued.record],
        people: _people,
        basePort: 18985,
      );

      await apply();
      await _waitUntil(() => service.error != null);
      expect(service.running, isFalse, reason: 'precondition');

      // The snapshot has not changed, so this only rebuilds because the crash
      // cleared the fingerprint. Otherwise the server stays down for good.
      await apply();
      await _waitUntil(() => service.running || service.error != null);

      expect(service.error, isNull, reason: service.error);
      expect(service.running, isTrue);
      expect(spawner.spawns, 2);
      expect(
        (await _initialize(service.port!, issued.secret))['result'],
        isNotNull,
      );
    });

    test('a deliberate stop is not reported as a crash', () async {
      final service = McpService();
      final issued = _issue();

      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [issued.record],
        people: _people,
        basePort: 18990,
      );
      await _waitUntil(() => service.running);

      await service.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(service.running, isFalse);
      expect(service.error, isNull);
    });
  });

  test('reports error when every port in range is taken', () async {
    const base = 18860;
    final blockers = <ServerSocket>[];
    for (var port = base; port < base + 10; port++) {
      blockers.add(await ServerSocket.bind(InternetAddress.loopbackIPv4, port));
    }
    addTearDown(() async {
      for (final blocker in blockers) {
        await blocker.close();
      }
    });

    final service = McpService();
    addTearDown(service.stop);
    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [_issue().record],
      people: _people,
      basePort: base,
    );
    await _waitUntil(() => service.error != null);

    expect(service.running, isFalse);
    expect(service.error, contains('no free port'));
  });

  test('missing credentials sets error without spawning', () async {
    final service = McpService();

    await service.sync(
      fireflyUrl: '',
      fireflyToken: '',
      agentKeys: [_issue().record],
      people: _people,
    );

    expect(service.error, contains('credentials'));
    expect(service.running, isFalse);
    expect(service.needsAgentKey, isFalse);
  });

  test('no agent keys keeps the server down and says so', () async {
    final service = McpService();

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: const [],
      people: _people,
      basePort: 18880,
    );

    expect(service.running, isFalse);
    expect(service.error, isNull);
    expect(service.needsAgentKey, isTrue);
  });

  test('an unreadable key store is not reported as an empty one', () async {
    final service = McpService();

    // Both cases arrive here with no keys, and telling someone they have none
    // when the keychain refused sends them off to reissue a key they still
    // have.
    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: const [],
      people: _people,
      agentKeysError: 'Keychain error -34018: entitlement missing',
      basePort: 18881,
    );

    expect(service.running, isFalse);
    expect(service.needsAgentKey, isFalse);
    expect(service.error, contains('-34018'));
  });

  test('dispose stops running server', () async {
    final service = McpService();
    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [_issue().record],
      people: _people,
      basePort: 18890,
    );
    await _waitUntil(() => service.running);
    service.dispose();
    expect(service.running, isFalse);
  });

  test('spawn failure sets error and notifies listeners', () async {
    var notified = false;
    final service = McpService(
      spawn: (_, _, {debugName, onExit, onError}) => throw StateError('boom'),
    );
    addTearDown(service.dispose);
    service.addListener(() => notified = true);

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [_issue().record],
      people: _people,
      basePort: 18900,
    );

    expect(service.error, contains('boom'));
    expect(notified, isTrue);
    expect(service.running, isFalse);
  });

  test(
    'mcpStatusLabel reports starting, failed, keyless and running',
    () async {
      final l10n = AppLocalizationsEn();
      final service = McpService();
      addTearDown(service.stop);

      expect(mcpStatusLabel(l10n, service), l10n.mcpStatusStarting);

      await service.sync(
        fireflyUrl: '',
        fireflyToken: '',
        agentKeys: const [],
        people: _people,
      );
      expect(mcpStatusLabel(l10n, service), contains('Failed'));

      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: const [],
        people: _people,
        basePort: 18910,
      );
      expect(mcpStatusLabel(l10n, service), l10n.mcpStatusNoKeys);

      await service.sync(
        fireflyUrl: _url,
        fireflyToken: _token,
        agentKeys: [_issue().record],
        people: _people,
        basePort: 18920,
      );
      await _waitUntil(() => service.running || service.error != null);
      expect(mcpStatusLabel(l10n, service), contains('Running'));
    },
  );

  test('ignores non-map isolate messages', () async {
    final service = McpService(spawn: _spawnWithNonMapMessage);
    addTearDown(service.stop);

    await service.sync(
      fireflyUrl: _url,
      fireflyToken: _token,
      agentKeys: [_issue().record],
      people: _people,
      basePort: 18940,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // The junk string is discarded. That isolate also finishes, which is
    // reported: a healthy one never exits.
    expect(service.running, isFalse);
    expect(service.error, contains('stopped unexpectedly'));
  });
}
