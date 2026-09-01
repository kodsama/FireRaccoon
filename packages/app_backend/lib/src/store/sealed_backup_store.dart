import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import '../crypto/sealed_store.dart';

/// Backups inside the sealed DATA_DIR, beside the rest of a server's state.
///
/// A backup is a copy of someone's whole ledger, so it is sealed like anything
/// else here rather than left readable next to it. Each part is its own file so
/// a restore can read the snapshot without decrypting the CSVs with it.
class SealedBackupStore implements BackupStore {
  const SealedBackupStore(this._store);

  static const String directory = 'backups';

  final SealedStore _store;

  /// What an id and the parts inside it are allowed to be.
  ///
  /// The sealed store refuses a path that climbs out of DATA_DIR, but names
  /// arriving from an agent are checked here too: the store's own guard is
  /// about its root, and this is about the shape FireRaccoon writes.
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.+-]+$');
  static final RegExp _filePattern = RegExp(
    r'^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$',
  );

  String _path(String backupId, String fileName) {
    if (!_idPattern.hasMatch(backupId) || backupId.contains('..')) {
      throw ArgumentError('invalid backup id: $backupId');
    }
    if (!_filePattern.hasMatch(fileName) || fileName.contains('..')) {
      throw ArgumentError('invalid backup file: $fileName');
    }
    return '$directory/$backupId/$fileName';
  }

  @override
  Future<void> put(String backupId, String fileName, List<int> bytes) =>
      _store.write(_path(backupId, fileName), bytes);

  @override
  Future<List<int>?> get(String backupId, String fileName) =>
      _store.read(_path(backupId, fileName));

  @override
  Future<List<String>> listBackupIds() async {
    // Copied before sorting: an empty listing comes back as a const list.
    final ids = [...await _store.listDirectories(directory)];
    ids.sort((a, b) => b.compareTo(a));
    return ids;
  }

  @override
  Future<void> deleteBackup(String backupId) {
    if (!_idPattern.hasMatch(backupId) || backupId.contains('..')) {
      throw ArgumentError('invalid backup id: $backupId');
    }
    return _store.deleteDirectory('$directory/$backupId');
  }
}
