/// Deployment mode for FireRaccoon (`FIRERACCOON_MODE`).
enum FireraccoonMode {
  local,
  server;

  static FireraccoonMode parse(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return switch (value) {
      'server' => FireraccoonMode.server,
      'local' || '' => FireraccoonMode.local,
      _ => FireraccoonMode.local,
    };
  }
}

/// Resolves mode from dart-define, optional runtime [configJson], then default local.
///
/// Precedence:
/// 1. `configJson['FIRERACCOON_MODE']` / `configJson['mode']` (Docker `/config.json`)
/// 2. `--dart-define=FIRERACCOON_MODE=...`
/// 3. `local`
FireraccoonMode resolveFireraccoonMode({Map<String, dynamic>? configJson}) {
  final fromConfig =
      configJson?['FIRERACCOON_MODE'] as String? ??
      configJson?['mode'] as String?;
  if (fromConfig != null && fromConfig.trim().isNotEmpty) {
    return FireraccoonMode.parse(fromConfig);
  }
  const fromDefine = String.fromEnvironment('FIRERACCOON_MODE');
  return FireraccoonMode.parse(fromDefine);
}
