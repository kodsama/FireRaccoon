// coverage:ignore-file — platform channel / conditional import shim
/// Web / no-`dart:io` platforms: persistence is a no-op stub.
Future<String> jsonStoreSupportPath(String fileName) async => fileName;

Future<String> jsonStoreDocumentsPath(String fileName) async => fileName;

Future<bool> jsonStoreExists(String path) async => false;

Future<String?> jsonStoreRead(String path) async => null;

Future<void> jsonStoreWrite(String path, String contents) async {}
