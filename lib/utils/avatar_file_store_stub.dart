// coverage:ignore-file — platform channel / conditional import shim
import 'dart:typed_data';

Future<void> avatarFileWrite(String fileName, Uint8List bytes) async {}

Future<Uint8List?> avatarFileRead(String fileName) async => null;

Future<void> avatarFileDelete(String fileName) async {}
