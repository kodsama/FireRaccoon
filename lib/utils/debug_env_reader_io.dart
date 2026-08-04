import 'dart:io';

/// Reads a local `.env` file (from the working directory) and returns its
/// key/value pairs. Used only as a desktop debug fallback; the file is
/// gitignored and never bundled as a Flutter asset.
Future<Map<String, String>> readDebugEnvFile([String path = '.env']) async {
  final file = File(path);
  if (!await file.exists()) return const {};
  return parseDotEnv(await file.readAsString());
}

/// Parses `KEY=VALUE` lines, ignoring blanks and `#` comments and stripping
/// matching surrounding quotes from values.
Map<String, String> parseDotEnv(String contents) {
  final result = <String, String>{};
  for (final rawLine in contents.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    if (key.isNotEmpty) result[key] = value;
  }
  return result;
}
