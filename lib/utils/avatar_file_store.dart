// coverage:ignore-file — platform channel / conditional import shim
import 'dart:typed_data';

import 'avatar_file_store_stub.dart'
    if (dart.library.io) 'avatar_file_store_io.dart'
    as store;

Future<void> avatarFileWrite(String fileName, Uint8List bytes) =>
    store.avatarFileWrite(fileName, bytes);

Future<Uint8List?> avatarFileRead(String fileName) =>
    store.avatarFileRead(fileName);

Future<void> avatarFileDelete(String fileName) =>
    store.avatarFileDelete(fileName);
