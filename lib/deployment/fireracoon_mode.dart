/// Deployment mode for FireRacoon (`FIRERACOON_MODE`).
enum FireracoonMode {
  local,
  server;

  static FireracoonMode parse(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return switch (value) {
      'server' => FireracoonMode.server,
      'local' || '' => FireracoonMode.local,
      _ => FireracoonMode.local,
    };
  }
}

/// Resolves mode from dart-define, optional runtime [configJson], then default local.
///
/// Precedence:
/// 1. `configJson['FIRERACOON_MODE']` / `configJson['mode']` (Docker `/config.json`)
/// 2. `--dart-define=FIRERACOON_MODE=...`
/// 3. `local`
FireracoonMode resolveFireracoonMode({Map<String, dynamic>? configJson}) {
  final fromConfig =
      configJson?['FIRERACOON_MODE'] as String? ??
      configJson?['mode'] as String?;
  if (fromConfig != null && fromConfig.trim().isNotEmpty) {
    return FireracoonMode.parse(fromConfig);
  }
  const fromDefine = String.fromEnvironment('FIRERACOON_MODE');
  return FireracoonMode.parse(fromDefine);
}
