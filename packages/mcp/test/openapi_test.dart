import 'dart:io';

import 'package:fireracoon_mcp/fireracoon_mcp.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

File _findOpenapiYaml() {
  var dir = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    final file = File('${dir.path}/openapi.yaml');
    if (file.existsSync()) return file;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('openapi.yaml not found from ${Directory.current.path}');
}

void main() {
  test('openapi x-mcp tools match buildTools catalog', () {
    final doc = loadYaml(_findOpenapiYaml().readAsStringSync()) as YamlMap;
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
}
