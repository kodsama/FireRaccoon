import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agent_keys_provider.dart';
import 'auth_provider.dart';
import 'backup_providers.dart';
import '../services/mcp_service.dart';
import '../store/agent_key_store.dart';

final mcpServiceProvider = Provider<McpService>((ref) {
  final service = McpService();
  ref.onDispose(service.dispose);

  // Usage stamps only move lastUsedAt, which the restart fingerprint ignores,
  // so recording one cannot bounce the server it came from.
  service.onKeyUsed = (keyId, at) {
    ref.read(agentKeysProvider.notifier).recordUsage(keyId, at);
  };

  // The server captures its key snapshot when it starts, so it has to be
  // re-synced whenever the connection, the keys, or the people behind them
  // change. sync() restarts only when something it captured actually moved.
  void apply() {
    if (!mcpDesktopSupported) return;
    final auth = ref.read(authProvider);
    if (!auth.isValid) {
      service.stop();
      return;
    }
    // localRecords is empty both when there are no keys and when the store
    // could not be read, so the provider's own error is what tells them apart.
    final keys = ref.read(agentKeysProvider);
    service.sync(
      fireflyUrl: auth.serverUrl,
      fireflyToken: auth.apiToken,
      agentKeys: ref.read(agentKeysProvider.notifier).localRecords,
      people: ref.read(agentKeyPeopleProvider),
      agentKeysError: keys.hasError
          ? describeAgentKeyFailure(keys.error!)
          : null,
      backupsDirectory: ref.read(backupsDirectoryProvider),
    );
  }

  ref.listen(authProvider, (_, _) => apply(), fireImmediately: true);
  ref.listen(agentKeysProvider, (_, _) => apply());
  ref.listen(agentKeyPeopleProvider, (_, _) => apply());

  return service;
});
