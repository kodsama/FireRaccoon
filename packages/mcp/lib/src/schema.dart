import 'tools.dart';

const mcpSchemaVersion = '1.0.0';
const mcpProtocolVersion = '2025-06-18';

/// Machine-readable MCP catalog for agent discovery (`fireracoon_mcp schema`).
Map<String, Object?> buildMcpSchema({FireflyTarget? target}) {
  final tools = buildTools(
    target: target ?? const FireflyTarget.unconfigured(),
  );
  return {
    'tool': 'fireracoon',
    'version': mcpSchemaVersion,
    'protocolVersion': mcpProtocolVersion,
    'openapi': 'openapi.yaml',
    'auth': {
      'credential': 'FireRacoon agent key',
      'env': ['FIRERACOON_URL', 'FIRERACOON_API_KEY'],
      'tcp': {
        'required': true,
        'param': 'initialize.params.apiKey',
        'alternatives': [
          'initialize.params.api_key',
          'initialize.params.authentication.token',
        ],
      },
      'note':
          'Keys are issued per agent in FireRacoon Settings under MCP and '
          'inherit their person\'s role. Firefly III credentials are never '
          'accepted here: in server mode the backend holds the PAT and proxies '
          'through /api/firefly.',
    },
    'permissions': {
      'roles': {
        'admin': 'all tools',
        'user': 'all tools',
        'viewer': 'read-only tools',
      },
      'writeTools': [
        for (final tool in tools)
          if (tool.writes) tool.name,
      ]..sort(),
    },
    'transport': {
      'stdio': {'command': 'fireracoon_mcp'},
      'tcp': {
        'host': '127.0.0.1',
        'port': 8787,
        'portRange': '8787-8796',
        'auth': 'apiKey',
      },
    },
    'surface': {
      'note':
          'Accounts, transactions, budgets and their limits, categories, tags, '
          'bills, piggy banks, recurrences, currencies, search, reconciliation, '
          'and the on-device projection all have tools. The rich account '
          'prognosis behind the UI is the one engine capability with none. '
          'Read the tools list below rather than assuming a gap.',
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
          'writes': tool.writes,
        },
    ],
  };
}

/// Tool names exposed by [buildTools], sorted for stable comparisons.
List<String> mcpToolNames() {
  return buildTools(
    target: const FireflyTarget.unconfigured(),
  ).map((tool) => tool.name).toList()..sort();
}
