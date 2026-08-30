import 'dart:io';

/// Deployment mode selected by [FIRERACCOON_MODE].
enum FireraccoonMode {
  local,
  server;

  static FireraccoonMode parse(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return switch (value) {
      'server' => FireraccoonMode.server,
      'local' => FireraccoonMode.local,
      '' => FireraccoonMode.local,
      _ => throw FormatException(
        'FIRERACCOON_MODE must be "local" or "server", got "$raw"',
      ),
    };
  }
}

/// Runtime configuration for the app backend process.
class ServerConfig {
  ServerConfig({
    required this.mode,
    required this.dataDir,
    required this.port,
    required this.webRoot,
    this.dataPassword,
    this.bootstrapFireflyUrl,
    this.bootstrapFireflyToken,
    this.sessionSecret,
    this.allowedOrigins = const <String>[],
  });

  final FireraccoonMode mode;
  final String dataDir;

  /// Optional env password that creates or unlocks DATA_DIR on every boot so
  /// end users only enter their account password in the UI.
  final String? dataPassword;
  final int port;
  final String webRoot;
  final String? bootstrapFireflyUrl;
  final String? bootstrapFireflyToken;
  final String? sessionSecret;

  /// Origins allowed to call this API from a browser on another host.
  ///
  /// Empty by default, which is the common case: this process serves the web UI
  /// itself, so the UI is same-origin and needs no cross-origin permission at
  /// all. Set CORS_ALLOWED_ORIGINS when something else has to reach the API, for
  /// instance a Flutter web build running on its own dev port.
  final List<String> allowedOrigins;

  /// Reads config from process environment and optional CLI overrides.
  factory ServerConfig.fromEnvironment({
    Map<String, String>? environment,
    int? portOverride,
    String? webRootOverride,
  }) {
    final env = environment ?? Platform.environment;
    final mode = FireraccoonMode.parse(env['FIRERACCOON_MODE']);
    if (mode != FireraccoonMode.server) {
      throw StateError(
        'fireraccoon_server requires FIRERACCOON_MODE=server '
        '(got "${env['FIRERACCOON_MODE'] ?? ''}").',
      );
    }

    final dataDir = env['DATA_DIR']?.trim().isNotEmpty == true
        ? env['DATA_DIR']!.trim()
        : '/data';

    final port =
        portOverride ??
        int.tryParse(env['PORT'] ?? '') ??
        int.tryParse(env['FIRERACCOON_PORT'] ?? '') ??
        8080;

    final webRoot =
        webRootOverride ??
        (env['WEB_ROOT']?.trim().isNotEmpty == true
            ? env['WEB_ROOT']!.trim()
            : '/app/web');

    return ServerConfig(
      mode: mode,
      dataDir: dataDir,
      dataPassword: _nonEmpty(env['DATA_PASSWORD']),
      port: port,
      webRoot: webRoot,
      bootstrapFireflyUrl: _nonEmpty(env['FIREFLY_URL']),
      bootstrapFireflyToken: _nonEmpty(env['FIREFLY_TOKEN']),
      sessionSecret: _nonEmpty(env['APP_SESSION_SECRET']),
      allowedOrigins: (env['CORS_ALLOWED_ORIGINS'] ?? '')
          .split(',')
          .map((origin) => origin.trim())
          .where((origin) => origin.isNotEmpty)
          .toList(growable: false),
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
