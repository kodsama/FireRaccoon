/// Web / no-`dart:io` platforms: never reads anything. A `.env` fallback must
/// not exist on web, where bundled files are publicly served.
Future<Map<String, String>> readDebugEnvFile([String path = '.env']) async =>
    const {};
