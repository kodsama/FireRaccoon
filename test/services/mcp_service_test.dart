@Timeout(Duration(seconds: 30))
library;

import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/services/mcp_service.dart';
import 'package:fireracoon/l10n/app_localizations_en.dart';

const _url = 'http://localhost:8080';
const _token = 'test-token';

void _sendNonMapMessage(SendPort sendPort) {
  sendPort.send('not-a-map');
}

Future<Isolate> _spawnWithNonMapMessage(
  void Function(McpIsolateConfig) entry,
  McpIsolateConfig message, {
  String? debugName,
}) {
  return Isolate.spawn<SendPort>(
    _sendNonMapMessage,
    message.send,
    debugName: debugName,
  );
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

void main() {
  test('start binds localhost port then stop tears down', () async {
    final service = McpService();
    addTearDown(service.stop);

    expect(service.running, isFalse);
    expect(service.authToken, isNull);
    await service.start(
      fireflyUrl: _url,
      fireflyToken: _token,
      basePort: 18800,
    );
    await _waitUntil(() => service.running || service.error != null);

    expect(service.error, isNull, reason: service.error);
    expect(service.port, inInclusiveRange(18800, 18809));
    expect(service.authToken, isNotEmpty);

    await service.stop();
    expect(service.running, isFalse);
    expect(service.port, isNull);
  });

  test('start is idempotent while already starting', () async {
    final service = McpService();
    addTearDown(service.stop);

    await service.start(
      fireflyUrl: _url,
      fireflyToken: _token,
      basePort: 18820,
    );
    await service.start(
      fireflyUrl: _url,
      fireflyToken: _token,
      basePort: 18820,
    );
    await _waitUntil(() => service.running);

    expect(service.running, isTrue);
    await service.stop();
  });

  test('reports error when every port in range is taken', () async {
    const base = 18840;
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
    await service.start(fireflyUrl: _url, fireflyToken: _token, basePort: base);
    await _waitUntil(() => service.error != null);

    expect(service.running, isFalse);
    expect(service.error, contains('no free port'));
  });

  test('missing credentials sets error without spawning', () async {
    final service = McpService();
    await service.start(fireflyUrl: '', fireflyToken: '');
    expect(service.error, contains('credentials'));
    expect(service.running, isFalse);
  });

  test('dispose stops running server', () async {
    final service = McpService();
    await service.start(
      fireflyUrl: _url,
      fireflyToken: _token,
      basePort: 18860,
    );
    await _waitUntil(() => service.running);
    service.dispose();
    expect(service.running, isFalse);
  });

  test('spawn failure sets error and notifies listeners', () async {
    var notified = false;
    final service = McpService(
      spawn: (_, _, {debugName}) => throw StateError('boom'),
    );
    addTearDown(service.dispose);
    service.addListener(() => notified = true);

    await service.start(
      fireflyUrl: _url,
      fireflyToken: _token,
      basePort: 18900,
    );

    expect(service.error, contains('boom'));
    expect(notified, isTrue);
    expect(service.running, isFalse);
  });

  test('mcpStatusLabel reports starting, failed and running', () async {
    final l10n = AppLocalizationsEn();
    final service = McpService();
    addTearDown(service.stop);

    expect(mcpStatusLabel(l10n, service), l10n.mcpStatusStarting);

    await service.start(fireflyUrl: '', fireflyToken: '');
    expect(mcpStatusLabel(l10n, service), contains('Failed'));

    await service.start(
      fireflyUrl: _url,
      fireflyToken: _token,
      basePort: 18920,
    );
    await _waitUntil(() => service.running || service.error != null);
    expect(mcpStatusLabel(l10n, service), contains('Running'));
  });

  test('ignores non-map isolate messages', () async {
    final service = McpService(spawn: _spawnWithNonMapMessage);
    addTearDown(service.stop);

    await service.start(
      fireflyUrl: _url,
      fireflyToken: _token,
      basePort: 18940,
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(service.error, isNull);
    expect(service.running, isFalse);
  });
}
