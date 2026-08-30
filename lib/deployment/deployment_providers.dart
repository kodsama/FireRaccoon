import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'fireraccoon_mode.dart';

/// Resolved deployment mode for this app process.
final fireraccoonModeProvider = Provider<FireraccoonMode>((ref) {
  return ref.watch(deploymentConfigProvider).mode;
});

class DeploymentConfig {
  const DeploymentConfig({
    required this.mode,
    this.setupRequired = false,
    this.apiBase = '',
  });

  final FireraccoonMode mode;
  final bool setupRequired;
  final String apiBase;

  bool get isServer => mode == FireraccoonMode.server;
}

final deploymentConfigProvider = Provider<DeploymentConfig>((ref) {
  return const DeploymentConfig(mode: FireraccoonMode.local);
});

/// Loads `/config.json` (server mode) then falls back to dart-define.
Future<DeploymentConfig> loadDeploymentConfig({
  http.Client? client,
  Uri? configUri,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final uri = configUri ?? Uri.base.resolve('config.json');
    // Only attempt runtime config on web (Uri.base is the page origin).
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final response = await httpClient
          .get(uri)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          final mode = resolveFireraccoonMode(configJson: json);
          return DeploymentConfig(
            mode: mode,
            setupRequired: json['setupRequired'] == true,
            apiBase: uri.origin,
          );
        }
      }
    }
  } on Object {
    // Fall through to dart-define / local.
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }

  return DeploymentConfig(mode: resolveFireraccoonMode());
}
