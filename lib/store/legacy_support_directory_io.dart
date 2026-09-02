// coverage:ignore-file — platform channel / conditional import shim
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The same path, spelled the way it was before the rename.
///
/// The bundle identifier and the binary name are the only places FireRaccoon's
/// name reaches a support path, and both moved, so the old directory sits
/// beside the current one under the old spelling. A sandboxed container is
/// named for the identifier too, which is why every occurrence is replaced
/// rather than just the last segment.
String legacySupportPath(String path) =>
    path.replaceAll('fireraccoon', 'fireracoon');

/// Copies anything the old directory still holds that the current one does
/// not, and reports what it took, relative to the directory.
///
/// A file already in place is left alone: it is the one the app has been
/// writing to, and the stranded copy is older.
Future<List<String>> adoptLegacyFiles({
  required String from,
  required String to,
}) async {
  final source = Directory(from);
  if (!source.existsSync()) return const [];
  final adopted = <String>[];
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = entity.path.substring(from.length + 1);
    final target = File('$to/$relative');
    if (target.existsSync()) continue;
    await target.parent.create(recursive: true);
    await entity.copy(target.path);
    adopted.add(relative);
  }
  return adopted;
}

/// Reads the pre-rename support directory, wherever this platform put it.
Future<List<String>> adoptLegacySupportDirectory() async {
  final current = await getApplicationSupportDirectory();
  final legacy = legacySupportPath(current.path);
  if (legacy == current.path) return const [];
  return adoptLegacyFiles(from: legacy, to: current.path);
}
