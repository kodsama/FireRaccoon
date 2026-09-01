// coverage:ignore-file — platform channel / conditional import shim
import 'backup_directory_stub.dart'
    if (dart.library.io) 'backup_directory_io.dart'
    as directory;

/// Where local-mode backups are kept, or null where nothing can keep them.
///
/// Null on the web, which has no directory to write a multi-megabyte ledger
/// copy into. Server mode does not use this at all: its backups live in the
/// sealed DATA_DIR and are reached over HTTP.
Future<String?> resolveBackupsDirectory() =>
    directory.resolveBackupsDirectory();
