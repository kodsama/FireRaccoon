import 'package:fireracoon_mcp/fireracoon_mcp.dart';
import 'package:test/test.dart';

void main() {
  test('buildMcpSchema includes tool catalog and auth', () {
    final schema = buildMcpSchema();
    expect(schema['tool'], 'fireracoon');
    expect(schema['protocolVersion'], mcpProtocolVersion);
    expect(schema['tools'], isA<List<Object?>>());
    expect((schema['tools'] as List<Object?>).length, mcpToolNames().length);
  });

  test('schema tool names match get_capabilities output', () async {
    final tool = buildTools().firstWhere((t) => t.name == 'get_capabilities');
    final result = await tool.run({});
    final names =
        ((result['tools'] as List<Object?>).map((name) => '$name').toList()
          ..sort());
    expect(names, mcpToolNames()..sort());
  });
}
