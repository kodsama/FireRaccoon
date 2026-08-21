import 'dart:io';

import 'package:fireracoon_mcp/fireracoon_mcp.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

Directory _findRepoRoot() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    if (File('${dir.path}/openapi.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('openapi.yaml not found from ${Directory.current.path}');
}

YamlMap _loadOpenapi(Directory root) =>
    loadYaml(File('${root.path}/openapi.yaml').readAsStringSync()) as YamlMap;

/// `method path` for every route `AppServer` registers, with shelf_router's
/// `<name>` and `<name|regexp>` placeholders spelled the way OpenAPI spells
/// them.
Set<String> _servedRoutes(Directory root) {
  final source = File(
    '${root.path}/packages/app_backend/lib/src/http/app_server.dart',
  ).readAsStringSync();
  final registration = RegExp(r"\.\.(get|post|put|delete|all)\(\s*'([^']+)'");
  final placeholder = RegExp(r'<(\w+)(?:\|[^>]*)?>');
  return {
    for (final match in registration.allMatches(source))
      '${match[1]} '
          '${match[2]!.replaceAllMapped(placeholder, (m) => '{${m[1]}}')}',
  };
}

void main() {
  test('openapi x-mcp tools match buildTools catalog', () {
    final doc = _loadOpenapi(_findRepoRoot());
    final mcp = doc['x-mcp'] as YamlMap;
    final openapiTools = (mcp['tools'] as YamlMap).keys.cast<String>().toList()
      ..sort();

    final runtimeTools = mcpToolNames()..sort();
    expect(openapiTools, runtimeTools);
  });

  test('buildMcpSchema lists the same tool names', () {
    final schema = buildMcpSchema();
    final names =
        (schema['tools'] as List<Object?>)
            .map((tool) => (tool as Map<Object?, Object?>)['name'] as String)
            .toList()
          ..sort();
    expect(names, mcpToolNames()..sort());
  });

  // openapi.yaml once described 12 Firefly paths and none of the backend's own
  // routes. These two tests are what stops it drifting back.
  test('openapi documents every route app_server registers', () {
    final root = _findRepoRoot();
    final paths = _loadOpenapi(root)['paths'] as YamlMap;

    final undocumented = <String>[];
    for (final route in _servedRoutes(root)) {
      final method = route.split(' ').first;
      final item = paths[route.split(' ').last];
      if (item == null) {
        undocumented.add(route);
      } else if (method != 'all' && !(item as YamlMap).containsKey(method)) {
        // `all` registers every method at once, which no single OpenAPI
        // operation can state, so its path item is all there is to check.
        undocumented.add(route);
      }
    }

    expect(undocumented, isEmpty, reason: 'missing from openapi.yaml paths');
  });

  test('openapi documents no backend route app_server stopped serving', () {
    final root = _findRepoRoot();
    final served = {
      for (final route in _servedRoutes(root)) route.split(' ').last,
    };
    final stale = (_loadOpenapi(root)['paths'] as YamlMap).keys
        .cast<String>()
        // Firefly's own paths are documented here too and served elsewhere.
        .where((path) => !path.startsWith('/api/v1/'))
        .where((path) => !served.contains(path));

    expect(stale, isEmpty, reason: 'no longer served by app_server.dart');
  });
}
