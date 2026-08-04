// coverage:ignore-file — platform channel / conditional import shim
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<File> _avatarFile(String fileName) async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/avatars/$fileName');
}

Future<void> avatarFileWrite(String fileName, Uint8List bytes) async {
  final file = await _avatarFile(fileName);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<Uint8List?> avatarFileRead(String fileName) async {
  final file = await _avatarFile(fileName);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> avatarFileDelete(String fileName) async {
  try {
    final file = await _avatarFile(fileName);
    if (await file.exists()) await file.delete();
  } on Object catch (_) {}
}
