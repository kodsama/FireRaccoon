// coverage:ignore-file — platform channel / conditional import shim
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> jsonStoreSupportPath(String fileName) async {
  final dir = await getApplicationSupportDirectory();
  return '${dir.path}/$fileName';
}

Future<String> jsonStoreDocumentsPath(String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/$fileName';
}

Future<bool> jsonStoreExists(String path) async => File(path).exists();

Future<String?> jsonStoreRead(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> jsonStoreWrite(String path, String contents) async {
  await File(path).writeAsString(contents, flush: true);
}
