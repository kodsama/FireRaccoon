import 'package:flutter/foundation.dart' show kDebugMode;

import 'debug_env_reader_stub.dart'
    if (dart.library.io) 'debug_env_reader_io.dart'
    as reader;

/// DEBUG-ONLY, desktop-only credential fallback.
///
/// When platform secure storage is unavailable (e.g. a macOS Keychain
/// entitlement problem during development), FireRacoon falls back to a local
/// `.env` file with `FIREFLY_URL` / `FIREFLY_TOKEN`. This returns an empty map
/// in release builds and on web: the file is read through `dart:io` and is
/// never a bundled Flutter asset, so it can never be served from a published
/// web build. `.env` is gitignored.
Future<Map<String, String>> loadDebugEnvCredentials([
  String path = '.env',
]) async {
  if (!kDebugMode) return const {};
  return reader.readDebugEnvFile(path);
}
