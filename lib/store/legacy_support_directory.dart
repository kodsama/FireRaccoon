// coverage:ignore-file — platform channel / conditional import shim
import 'legacy_support_directory_stub.dart'
    if (dart.library.io) 'legacy_support_directory_io.dart'
    as store;

/// Recovers the files a pre-rename install left in the old support directory:
/// the undo history, the custom avatars and any backups taken there.
Future<List<String>> adoptLegacySupportDirectory() =>
    store.adoptLegacySupportDirectory();
