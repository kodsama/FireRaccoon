import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agent_keys_provider.dart';
import 'app_info_provider.dart';
import 'auth_provider.dart';
import 'backup_providers.dart';
import 'cosmos_session_provider.dart';
import 'mcp_port_provider.dart';
import '../services/mcp_service.dart';
import '../store/agent_key_store.dart';

final mcpServiceProvider = Provider<McpService>((ref) {
  final service = McpService();
  // Tearing the container down disposes the service and can still fire the
  // listeners below, and apply() would then stop a service that is already
  // gone, which a ChangeNotifier asserts on.
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    service.dispose();
  });

  // Usage stamps only move lastUsedAt, which the restart fingerprint ignores,
  // so recording one cannot bounce the server it came from.
  service.onKeyUsed = (keyId, at) {
    ref.read(agentKeysProvider.notifier).recordUsage(keyId, at);
  };

  // The server captures its key snapshot when it starts, so it has to be
  // re-synced whenever the connection, the keys, or the people behind them
  // change. sync() restarts only when something it captured actually moved.
  void apply() {
    if (disposed || !mcpDesktopSupported) return;
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
      // Null on the first pass and real once the platform answers, which is
      // one restart of a server nothing has connected to yet.
      appVersion: ref.read(packageInfoProvider).asData?.value.version,
      // The session belongs to the app, and an agent reaching a gated route
      // needs the same one rather than a sign-in of its own.
      proxyCookie: ref.read(cosmosSessionProvider)?.cookieHeader,
      basePort: ref.read(mcpBasePortProvider),
    );
  }

  ref.listen(authProvider, (_, _) => apply(), fireImmediately: true);
  ref.listen(agentKeysProvider, (_, _) => apply());
  ref.listen(agentKeyPeopleProvider, (_, _) => apply());
  ref.listen(packageInfoProvider, (_, _) => apply());
  ref.listen(cosmosSessionProvider, (_, _) => apply());
  ref.listen(mcpBasePortProvider, (_, _) => apply());

  return service;
});
