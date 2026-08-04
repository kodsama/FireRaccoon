import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import '../services/mcp_service.dart';

final mcpServiceProvider = Provider<McpService>((ref) {
  final service = McpService();
  ref.onDispose(service.dispose);

  ref.listen(authProvider, (previous, next) {
    if (!mcpDesktopSupported) return;
    if (next.isValid) {
      service.start(fireflyUrl: next.serverUrl, fireflyToken: next.apiToken);
    } else {
      service.stop();
    }
  }, fireImmediately: true);

  return service;
});
