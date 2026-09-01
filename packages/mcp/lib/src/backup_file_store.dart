import 'dart:io';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:path/path.dart' as p;

/// Backups as plain directories under [root], one per backup.
///
/// Plain files rather than an archive so a person can open a backup in a file
/// browser, read the manifest and hand the CSVs to something else. Local mode
/// keeps them beside the app's own data; server mode seals them instead, which
/// is what [RemoteBackupStore] reaches.
class FileBackupStore implements BackupStore {
  FileBackupStore(this.root);

  final String root;

  /// What a backup id and the parts inside it are allowed to be.
  ///
  /// Ids and file names arrive from agents. Validated rather than escaped: a
  /// name that climbs out of the root is the one mistake a store handed
  /// arbitrary strings must not make, and the set of names FireRaccoon writes is
  /// small enough to name exactly.
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.+-]+$');
  static final RegExp _filePattern = RegExp(
    r'^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$',
  );

  Directory _backupDir(String backupId) {
    if (!_idPattern.hasMatch(backupId) || backupId.contains('..')) {
      throw ArgumentError('invalid backup id: $backupId');
    }
    return Directory(p.join(root, backupId));
  }

  File _fileFor(String backupId, String fileName) {
    if (!_filePattern.hasMatch(fileName) || fileName.contains('..')) {
      throw ArgumentError('invalid backup file: $fileName');
    }
    return File(
      p.join(_backupDir(backupId).path, p.joinAll(fileName.split('/'))),
    );
  }

  @override
  Future<void> put(String backupId, String fileName, List<int> bytes) async {
    final file = _fileFor(backupId, fileName);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<int>?> get(String backupId, String fileName) async {
    final file = _fileFor(backupId, fileName);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<List<String>> listBackupIds() async {
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    final ids = <String>[];
    await for (final entry in dir.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final id = p.basename(entry.path);
      // A directory without a manifest is a backup that never finished, or
      // something else entirely; either way there is nothing to report about it.
      if (!File(p.join(entry.path, kBackupManifestFile)).existsSync()) continue;
      ids.add(id);
    }
    ids.sort((a, b) => b.compareTo(a));
    return ids;
  }

  @override
  Future<void> deleteBackup(String backupId) async {
    final dir = _backupDir(backupId);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}
