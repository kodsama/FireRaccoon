import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';

const _usage = '''
fireraccoon_mcp: MCP server for FireRaccoon

  --tcp [--port N]   serve on localhost TCP (default 8787) instead of stdio
  schema             emit the JSON tool catalog and exit

Credentials (a FireRaccoon account, never a Firefly III token):
  FIRERACCOON_URL       base URL of the FireRaccoon server
  FIRERACCOON_API_KEY   agent key issued in Settings under MCP

The key inherits its person's role: viewers get read-only tools. Firefly III
credentials stay on the server, which proxies calls through /api/firefly.
''';

/// Entry point for the FireRaccoon MCP server.
Future<void> main(List<String> args) async {
  final url = Platform.environment['FIRERACCOON_URL']?.trim() ?? '';
  final key = Platform.environment['FIRERACCOON_API_KEY']?.trim() ?? '';

  if (args.contains('schema') || args.contains('--schema')) {
    stdout.writeln(
      JsonEncoder.withIndent('  ').convert(
        buildMcpSchema(
          target: url.isEmpty || key.isEmpty
              ? null
              : FireflyTarget(baseUrl: '$url/api/firefly', bearer: key),
        ),
      ),
    );
    return;
  }

  if (url.isEmpty || key.isEmpty) {
    stderr.write(_usage);
    exitCode = 64;
    return;
  }

  final authenticator = BackendAuthenticator(baseUrl: url);
  final identity = await authenticator.authenticate(key);
  if (identity == null) {
    stderr.writeln(
      'FIRERACCOON_API_KEY was rejected by $url. Check the key is current and '
      'the server is reachable and unlocked.',
    );
    exitCode = 77;
    return;
  }
  stderr.writeln(
    'Authenticated as ${identity.personName} (${identity.role}); '
    'write access: ${identity.canWrite}',
  );

  McpServer serverFor(String bearer, AgentIdentity caller) {
    return McpServer(
      tools: buildTools(
        target: FireflyTarget(
          baseUrl: authenticator.fireflyProxyBase,
          bearer: bearer,
        ),
        identity: caller,
      ),
    );
  }

  if (args.contains('--tcp')) {
    final port = _intAfter(args, '--port') ?? 8787;
    await serveTcp(
      // Each connection's own key becomes its Firefly bearer, so the backend
      // stays the authority on what that key may do.
      server: (caller, agentKey) => serverFor(agentKey, caller),
      authenticator: authenticator,
      port: port,
      onLog: stderr.writeln,
    );
    stderr.writeln('fireraccoon MCP server ready (tcp). Ctrl-C to stop.');
    await Completer<void>().future;
  } else {
    await serveStdio(serverFor(key, identity), identity: identity);
  }
}

int? _intAfter(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i < 0 || i + 1 >= args.length) return null;
  return int.tryParse(args[i + 1]);
}
