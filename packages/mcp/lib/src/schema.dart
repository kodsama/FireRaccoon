import 'tools.dart';

const mcpSchemaVersion = '1.0.0';
const mcpProtocolVersion = '2025-06-18';

/// Machine-readable MCP catalog for agent discovery (`fireracoon_mcp schema`).
Map<String, Object?> buildMcpSchema({
  String? defaultUrl,
  String? defaultToken,
}) {
  final tools = buildTools(defaultUrl: defaultUrl, defaultToken: defaultToken);
  return {
    'tool': 'fireracoon',
    'version': mcpSchemaVersion,
    'protocolVersion': mcpProtocolVersion,
    'openapi': 'openapi.yaml',
    'auth': {
      'env': ['FIREFLY_URL', 'FIREFLY_TOKEN', 'MCP_TOKEN'],
      'perCall': ['firefly_url', 'firefly_token'],
      'tcp': {
        'required': true,
        'param': 'initialize.params.mcpToken',
        'env': 'MCP_TOKEN',
      },
    },
    'transport': {
      'stdio': {'command': 'fireracoon_mcp'},
      'tcp': {
        'host': '127.0.0.1',
        'port': 8787,
        'portRange': '8787-8796',
        'auth': 'mcpToken',
      },
    },
    'surface': {
      'note':
          'Intentional agent subset of FireflyService. Bills, recurrences, '
          'piggy banks, search, and account prognosis remain UI-only unless '
          'added to buildTools().',
    },
    'session': [
      'initialize → notifications/initialized',
      'tools/list',
      'tools/call',
    ],
    'tools': [
      for (final tool in tools)
        {
          'name': tool.name,
          'description': tool.description,
          'inputSchema': tool.inputSchema,
        },
    ],
  };
}

/// Tool names exposed by [buildTools], sorted for stable comparisons.
List<String> mcpToolNames({String? defaultUrl, String? defaultToken}) {
  return buildTools(
    defaultUrl: defaultUrl,
    defaultToken: defaultToken,
  ).map((tool) => tool.name).toList()..sort();
}
