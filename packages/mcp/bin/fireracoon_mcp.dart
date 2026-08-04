import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fireracoon_mcp/fireracoon_mcp.dart';

/// Entry point for the FireRacoon MCP server.
///
/// - Default: **stdio** transport (MCP clients spawn this binary)
/// - `--tcp [--port N]`: localhost TCP (default 8787); requires `MCP_TOKEN`
/// - `schema` / `--schema`: emit JSON tool catalog and exit
///
/// Credentials: `FIREFLY_URL` and `FIREFLY_TOKEN`, or per-tool arguments.
/// TCP auth: `MCP_TOKEN` (or `--mcp-token`), sent as `initialize.params.mcpToken`.
Future<void> main(List<String> args) async {
  if (args.contains('schema') || args.contains('--schema')) {
    final url = Platform.environment['FIREFLY_URL'];
    final token = Platform.environment['FIREFLY_TOKEN'];
    stdout.writeln(
      JsonEncoder.withIndent(
        '  ',
      ).convert(buildMcpSchema(defaultUrl: url, defaultToken: token)),
    );
    return;
  }

  final url = Platform.environment['FIREFLY_URL'];
  final token = Platform.environment['FIREFLY_TOKEN'];
  final server = McpServer(
    tools: buildTools(defaultUrl: url, defaultToken: token),
  );

  if (args.contains('--tcp')) {
    final port = _intAfter(args, '--port') ?? 8787;
    final mcpToken =
        _stringAfter(args, '--mcp-token') ??
        Platform.environment['MCP_TOKEN'] ??
        _generateToken();
    if (Platform.environment['MCP_TOKEN'] == null &&
        _stringAfter(args, '--mcp-token') == null) {
      stderr.writeln(
        'MCP_TOKEN not set; generated ephemeral token for this session:\n'
        '  $mcpToken\n'
        'Pass it as initialize.params.mcpToken (or set MCP_TOKEN next time).',
      );
    }
    await serveTcp(
      server,
      port: port,
      authToken: mcpToken,
      onLog: stderr.writeln,
    );
    stderr.writeln('fireracoon MCP server ready (tcp). Ctrl-C to stop.');
    await Completer<void>().future;
  } else {
    await serveStdio(server);
  }
}

int? _intAfter(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i < 0 || i + 1 >= args.length) return null;
  return int.tryParse(args[i + 1]);
}

String? _stringAfter(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}

String _generateToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
