import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../deployment/deployment_providers.dart';
import 'data_providers.dart';
import 'server_session_provider.dart';

/// Directory local-mode backups are written to, resolved once at startup.
///
/// Overridden in `main`, because the path comes from a platform channel and a
/// provider that reaches for one lazily would leave the first read of a backup
/// list waiting on it.
final backupsDirectoryProvider = Provider<String?>((ref) => null);

/// Where this deployment keeps backups, or null when it cannot keep any.
///
/// Server mode reaches the sealed DATA_DIR over HTTP, so every client of one
/// server sees the same backups. Local mode writes files beside the app's own
/// data. The web build in local mode has neither, and says so rather than
/// offering a button that writes nothing.
final backupStoreProvider = Provider<BackupStore?>((ref) {
  if (ref.watch(deploymentConfigProvider).isServer) {
    final session = ref.watch(serverSessionProvider.notifier);
    final client = session.client;
    final token = ref.watch(serverSessionProvider).value?.token;
    if (client == null || token == null || token.isEmpty) return null;
    return RemoteBackupStore(
      baseUrl: client.baseUrl,
      headers: {'x-fireraccoon-session': token},
    );
  }
  final directory = ref.watch(backupsDirectoryProvider);
  if (directory == null || directory.isEmpty) return null;
  return FileBackupStore(directory);
});

/// Takes and reads backups, or null while there is no connection or nowhere to
/// put one.
final backupServiceProvider = Provider<BackupService?>((ref) {
  final api = ref.watch(apiServiceProvider);
  final store = ref.watch(backupStoreProvider);
  if (api == null || store == null) return null;
  return BackupService(api, store);
});

/// What a backup is doing right now, for a screen that has to stay honest about
/// a read that walks a whole ledger.
class BackupProgress {
  const BackupProgress({required this.running, this.stage});

  static const idle = BackupProgress(running: false);

  final bool running;

  /// The part being read, as [BackupService.create] reports it.
  final String? stage;
}

/// The backups this FireRaccoon holds.
class BackupsNotifier extends AsyncNotifier<List<BackupManifest>> {
  static final _log = AppLogger.scoped('providers.backups');

  final _progress = ValueNotifier<BackupProgress>(BackupProgress.idle);

  ValueListenable<BackupProgress> get progress => _progress;

  @override
  Future<List<BackupManifest>> build() async {
    final service = ref.watch(backupServiceProvider);
    if (service == null) return const [];
    return service.list();
  }

  /// Takes a backup and puts it at the top of the list.
  ///
  /// Errors are thrown rather than folded into the state: the list of backups
  /// that already exist is still true, and a failed attempt is the caller's to
  /// report.
  Future<BackupManifest> create() async {
    final service = ref.read(backupServiceProvider);
    if (service == null) {
      throw StateError('Backups are unavailable in this deployment');
    }
    _progress.value = const BackupProgress(running: true);
    try {
      final manifest = await service.create(
        onStage: (stage) =>
            _progress.value = BackupProgress(running: true, stage: stage),
      );
      _log.info(
        'Backup ${manifest.id} written: ${manifest.totalBytes} bytes, '
        'complete=${manifest.complete}',
      );
      state = AsyncData([manifest, ...state.value ?? const []]);
      return manifest;
    } finally {
      _progress.value = BackupProgress.idle;
    }
  }

  Future<void> delete(String backupId) async {
    final service = ref.read(backupServiceProvider);
    if (service == null) return;
    await service.delete(backupId);
    _log.info('Backup $backupId deleted');
    state = AsyncData([
      for (final manifest in state.value ?? const <BackupManifest>[])
        if (manifest.id != backupId) manifest,
    ]);
  }

  /// One file out of a backup, for handing it to something else.
  Future<String?> file(String backupId, String fileName) async {
    final service = ref.read(backupServiceProvider);
    if (service == null) return null;
    return service.file(backupId, fileName);
  }

  Future<void> refresh() async {
    final service = ref.read(backupServiceProvider);
    if (service == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(service.list);
  }
}

final backupsProvider =
    AsyncNotifierProvider<BackupsNotifier, List<BackupManifest>>(
      BackupsNotifier.new,
    );
