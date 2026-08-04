// coverage:ignore-file — platform channel / conditional import shim
import 'json_file_store_stub.dart'
    if (dart.library.io) 'json_file_store_io.dart'
    as store;

/// Cross-platform JSON file helpers. On web, reads miss and writes are no-ops.
Future<String> jsonStoreSupportPath(String fileName) =>
    store.jsonStoreSupportPath(fileName);

Future<String> jsonStoreDocumentsPath(String fileName) =>
    store.jsonStoreDocumentsPath(fileName);

Future<bool> jsonStoreExists(String path) => store.jsonStoreExists(path);

Future<String?> jsonStoreRead(String path) => store.jsonStoreRead(path);

Future<void> jsonStoreWrite(String path, String contents) =>
    store.jsonStoreWrite(path, contents);
