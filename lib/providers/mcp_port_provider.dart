import 'dart:async';
import 'dart:math';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart';

/// Default base port when a static fallback is needed.
///
/// Placed in the IANA dynamic/private range (RFC 6335: 49152–65535) so it never
/// collides with registered services or popular dev proxies like 8787.
const kDefaultMcpBasePort = 52872;

/// Range for randomly generated MCP base ports.
const kMinDynamicMcpBasePort = 49152;
const kMaxDynamicMcpBasePort = 65535 - kMcpPortRange;

/// How many ports it will try before giving up.
///
/// The server walks up from the base until one binds, so a port taken by
/// something else costs a restart rather than a configuration change. The range
/// is named here because the settings screen and the docs both quote it.
const kMcpPortRange = 10;

/// Below 1024 needs privileges nobody should be granting a finance client, and
/// the range has to fit under the ceiling.
const kMinMcpBasePort = 1024;
const kMaxMcpBasePort = 65535 - kMcpPortRange;

int normalizeMcpBasePort(int value) =>
    value.clamp(kMinMcpBasePort, kMaxMcpBasePort);

int generateRandomMcpBasePort([Random? random]) {
  final r = random ?? Random();
  return kMinDynamicMcpBasePort +
      r.nextInt(kMaxDynamicMcpBasePort - kMinDynamicMcpBasePort + 1);
}

/// The base port the MCP server binds from.
///
/// Configurable because the default range can be taken by something else on the
/// machine, and an agent is configured with a port number: the server has to be
/// able to move somewhere predictable rather than wherever the walk happens to
/// land.
class McpBasePortNotifier extends Notifier<int> {
  static const _prefsKey = 'mcpBasePort';
  static final _log = AppLogger.scoped('providers.mcpPort');

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getInt(_prefsKey);
    // 8787 was the old colliding default; migrate away to a random dynamic port.
    if (stored == null || stored == 8787) {
      final generated = generateRandomMcpBasePort();
      unawaited(prefs.setInt(_prefsKey, generated));
      _log.info('Assigned random MCP base port: $generated');
      return generated;
    }
    final value = normalizeMcpBasePort(stored);
    _log.finer('Loaded MCP base port preference: $value');
    return value;
  }

  Future<void> setBasePort(int value) async {
    final normalized = normalizeMcpBasePort(value);
    if (normalized == state) return;
    state = normalized;
    await ref.read(sharedPreferencesProvider).setInt(_prefsKey, normalized);
    _log.info('Updated MCP base port to $normalized');
  }

  /// Resets to a fresh random port in the dynamic range.
  Future<void> reset([Random? random]) async {
    final fresh = generateRandomMcpBasePort(random);
    state = fresh;
    await ref.read(sharedPreferencesProvider).setInt(_prefsKey, fresh);
    _log.info('MCP base port reset to random port $fresh');
  }
}

final mcpBasePortProvider = NotifierProvider<McpBasePortNotifier, int>(
  McpBasePortNotifier.new,
);
