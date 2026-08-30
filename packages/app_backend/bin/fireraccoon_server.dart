import 'dart:io';

import 'package:fireraccoon_app_backend/fireraccoon_app_backend.dart';

/// FireRaccoon server-mode entrypoint for Docker and local headful server runs.
///
/// Required env:
/// - `FIRERACCOON_MODE=server`
///
/// Recommended:
/// - `DATA_PASSWORD` — creates or unlocks encrypted `DATA_DIR` on every
///   boot so end users only enter their account password in the UI
///
/// Optional:
/// - `DATA_DIR` (default `/data`)
/// - `PORT` / `FIRERACCOON_PORT` (default `8080`)
/// - `WEB_ROOT` (default `/app/web`)
/// - `FIREFLY_URL` / `FIREFLY_TOKEN` bootstrap
Future<void> main(List<String> args) async {
  final portOverride = _intAfter(args, '--port');
  final webRootOverride = _stringAfter(args, '--web-root');
  final config = ServerConfig.fromEnvironment(
    portOverride: portOverride,
    webRootOverride: webRootOverride,
  );

  final hasEnvPassword =
      config.dataPassword != null && config.dataPassword!.isNotEmpty;
  stderr.writeln(
    hasEnvPassword
        ? 'Unlocking encrypted store at ${config.dataDir} with DATA_PASSWORD…'
        : 'DATA_PASSWORD unset; store at ${config.dataDir} stays locked '
              'until env is set (or one-time create / emergency unlock in UI)',
  );
  final server = await AppServer.open(config);
  final httpServer = await server.serve();
  stderr.writeln(
    'FireRaccoon server listening on '
    'http://${httpServer.address.host}:${httpServer.port}',
  );
  if (server.isStoreLocked) {
    stderr.writeln(
      'storeLocked=true storeExists=${server.storeExists} '
      '— set DATA_PASSWORD and restart for normal multi-user login',
    );
  } else {
    stderr.writeln(
      'storeUnlocked setupRequired=${server.repository.state.setupRequired}',
    );
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
