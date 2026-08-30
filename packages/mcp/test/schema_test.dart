import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:test/test.dart';

void main() {
  test('buildMcpSchema includes tool catalog and auth', () {
    final schema = buildMcpSchema();
    expect(schema['tool'], 'fireraccoon');
    expect(schema['protocolVersion'], mcpProtocolVersion);
    expect(schema['tools'], isA<List<Object?>>());
    expect((schema['tools'] as List<Object?>).length, mcpToolNames().length);
  });

  test('schema tool names match get_capabilities output', () async {
    final tool = buildTools(
      target: const FireflyTarget.unconfigured(),
    ).firstWhere((t) => t.name == 'get_capabilities');
    final result = await tool.run({});
    final names =
        ((result['tools'] as List<Object?>).map((name) => '$name').toList()
          ..sort());
    expect(names, mcpToolNames()..sort());
  });

  test('auth advertises account credentials, not Firefly ones', () {
    final auth = buildMcpSchema()['auth'] as Map<String, Object?>;

    expect(auth['env'], ['FIRERACCOON_URL', 'FIRERACCOON_API_KEY']);
    expect(
      (auth['tcp'] as Map<String, Object?>)['param'],
      'initialize.params.apiKey',
    );
    expect('${auth['note']}', contains('never'));
  });

  test('no schema anywhere accepts a Firefly credential argument', () {
    final encoded = buildMcpSchema().toString();

    expect(encoded, isNot(contains('firefly_url')));
    expect(encoded, isNot(contains('firefly_token')));
    expect(encoded, isNot(contains('FIREFLY_TOKEN')));
  });

  test('write tools are declared and match the tool flags', () {
    final schema = buildMcpSchema();
    final declared =
        ((schema['permissions'] as Map<String, Object?>)['writeTools']
                as List<Object?>)
            .cast<String>();
    final flagged = [
      for (final tool
          in (schema['tools'] as List<Object?>).cast<Map<String, Object?>>())
        if (tool['writes'] == true) tool['name'] as String,
    ]..sort();

    // Membership parity, not the order two lists happen to be built in.
    expect(declared, flagged);
    expect(declared, contains('delete_budget'));
    expect(declared, isNot(contains('get_accounts')));
  });

  test(
    'get_capabilities advertises the same write tools as the schema',
    () async {
      final tool = buildTools(
        target: const FireflyTarget.unconfigured(),
      ).firstWhere((t) => t.name == 'get_capabilities');
      final result = await tool.run({});

      expect(
        (result['write_tools'] as List<Object?>).cast<String>(),
        ((buildMcpSchema()['permissions'] as Map<String, Object?>)['writeTools']
                as List<Object?>)
            .cast<String>(),
      );
    },
  );
}
