import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart';

/// Where the MCP server starts looking for a free port.
const kDefaultMcpBasePort = 8787;

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
    if (stored == null) return kDefaultMcpBasePort;
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

  /// Back to the default, and out of the stored preferences entirely, so a
  /// later change of default is picked up rather than pinned by an old write.
  Future<void> reset() async {
    state = kDefaultMcpBasePort;
    await ref.read(sharedPreferencesProvider).remove(_prefsKey);
    _log.info('MCP base port reset to the default');
  }
}

final mcpBasePortProvider = NotifierProvider<McpBasePortNotifier, int>(
  McpBasePortNotifier.new,
);
