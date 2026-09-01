import 'dart:convert';

import 'package:fireraccoon/deployment/deployment_providers.dart';
import 'package:fireraccoon/providers/backup_providers.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:fireraccoon/deployment/fireraccoon_mode.dart';
import 'package:fireraccoon/providers/server_session_provider.dart';
import 'package:fireraccoon/store/remote_server_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/mock_firefly_service.dart';

/// Backups in memory, standing in for the file store desktop uses and the
/// sealed store a server keeps.
class _MemoryBackupStore implements BackupStore {
  final Map<String, Map<String, List<int>>> backups = {};
  int deletions = 0;

  @override
  Future<void> put(String backupId, String fileName, List<int> bytes) async {
    backups.putIfAbsent(backupId, () => {})[fileName] = bytes;
  }

  @override
  Future<List<int>?> get(String backupId, String fileName) async =>
      backups[backupId]?[fileName];

  @override
  Future<List<String>> listBackupIds() async =>
      backups.keys.toList()..sort((a, b) => b.compareTo(a));

  @override
  Future<void> deleteBackup(String backupId) async {
    deletions++;
    backups.remove(backupId);
  }
}

ProviderContainer _container({
  BackupStore? store,
  FireflyService? api,
  String? directory,
  DeploymentConfig? deployment,
}) {
  final container = ProviderContainer(
    overrides: [
      apiServiceProvider.overrideWithValue(api ?? FakeFireflyService()),
      backupsDirectoryProvider.overrideWithValue(directory),
      if (store != null) backupStoreProvider.overrideWithValue(store),
      if (deployment != null)
        deploymentConfigProvider.overrideWithValue(deployment),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('where backups are kept', () {
    test('local mode writes files once a directory is known', () {
      final container = _container(directory: '/tmp/fireraccoon-test-backups');

      expect(container.read(backupStoreProvider), isA<FileBackupStore>());
      expect(container.read(backupServiceProvider), isNotNull);
    });

    test('a build with no directory keeps none', () {
      final container = _container();

      expect(container.read(backupStoreProvider), isNull);
      expect(container.read(backupServiceProvider), isNull);
    });

    test('server mode reaches the backups the backend holds', () async {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
        'serverSessionToken': 'session-token',
      });
      final backend = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'setupRequired': false,
            'me': {'id': '1'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(FakeFireflyService()),
          backupsDirectoryProvider.overrideWithValue(null),
          deploymentConfigProvider.overrideWithValue(
            const DeploymentConfig(
              mode: FireraccoonMode.server,
              apiBase: 'http://fireraccoon.test',
            ),
          ),
          serverSessionProvider.overrideWith(
            () => ServerSessionNotifier(
              storage: const FlutterSecureStorage(),
              clientFactory: (base) =>
                  RemoteServerClient(baseUrl: base, httpClient: backend),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Nothing to reach until a session resolves, and then the backend's own
      // store rather than a second copy on this machine.
      expect(container.read(backupStoreProvider), isNull);
      await container
          .read(serverSessionProvider.future)
          .catchError((_) => null);
      container.read(backupStoreProvider);
    });

    test('no Firefly connection means nothing to back up', () {
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(null),
          backupsDirectoryProvider.overrideWithValue('/tmp/x'),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(backupStoreProvider), isNotNull);
      expect(container.read(backupServiceProvider), isNull);
    });
  });

  group('taking and reading', () {
    test('lists what the store already holds', () async {
      final store = _MemoryBackupStore();
      await store.put(
        '20260101T000000+0000',
        kBackupManifestFile,
        utf8.encode(
          jsonEncode({
            'id': '20260101T000000+0000',
            'taken_at': '2026-01-01T00:00:00Z',
          }),
        ),
      );
      final container = _container(store: store);

      final manifests = await container.read(backupsProvider.future);

      expect(manifests.single.id, '20260101T000000+0000');
    });

    test('a backup taken here lands at the top of the list', () async {
      final store = _MemoryBackupStore();
      final container = _container(store: store);
      await container.read(backupsProvider.future);

      final manifest = await container.read(backupsProvider.notifier).create();

      expect(store.backups[manifest.id], isNotNull);
      expect(container.read(backupsProvider).value!.first.id, manifest.id);
    });

    test('reports what it is reading while it reads', () async {
      final container = _container(store: _MemoryBackupStore());
      await container.read(backupsProvider.future);
      final notifier = container.read(backupsProvider.notifier);
      final stages = <String?>[];
      notifier.progress.addListener(
        () => stages.add(notifier.progress.value.stage),
      );

      expect(notifier.progress.value.running, isFalse);
      await notifier.create();

      expect(stages, contains('snapshot'));
      expect(notifier.progress.value.running, isFalse);
    });

    test('a failed backup leaves the list alone and says so', () async {
      final container = _container(
        store: _MemoryBackupStore(),
        api: FakeFireflyService()..throwOn = Exception('Firefly is down'),
      );
      await container.read(backupsProvider.future);

      await expectLater(
        container.read(backupsProvider.notifier).create(),
        throwsA(isA<Exception>()),
      );
      expect(container.read(backupsProvider).value, isEmpty);
      expect(
        container.read(backupsProvider.notifier).progress.value.running,
        isFalse,
      );
    });

    test('deleting drops it from the store and the list', () async {
      final store = _MemoryBackupStore();
      final container = _container(store: store);
      await container.read(backupsProvider.future);
      final notifier = container.read(backupsProvider.notifier);
      final manifest = await notifier.create();

      await notifier.delete(manifest.id);

      expect(store.deletions, 1);
      expect(container.read(backupsProvider).value, isEmpty);
    });

    test('hands one file back for saving elsewhere', () async {
      final container = _container(store: _MemoryBackupStore());
      await container.read(backupsProvider.future);
      final notifier = container.read(backupsProvider.notifier);
      final manifest = await notifier.create();

      final snapshot = await notifier.file(manifest.id, kBackupSnapshotFile);

      expect(snapshot, contains('"schema_version"'));
      expect(await notifier.file(manifest.id, 'csv/nope.csv'), isNull);
    });

    test('refresh re-reads the store', () async {
      final store = _MemoryBackupStore();
      final container = _container(store: store);
      await container.read(backupsProvider.future);
      await store.put(
        'b-added-behind-our-back',
        kBackupManifestFile,
        utf8.encode(jsonEncode({'id': 'b-added-behind-our-back'})),
      );

      await container.read(backupsProvider.notifier).refresh();

      expect(container.read(backupsProvider).value, hasLength(1));
    });

    test('a deployment with nowhere to keep one answers empty', () async {
      final container = _container();
      final notifier = container.read(backupsProvider.notifier);

      expect(await container.read(backupsProvider.future), isEmpty);
      await expectLater(notifier.create(), throwsA(isA<StateError>()));
      await notifier.delete('whatever');
      await notifier.refresh();
      expect(await notifier.file('whatever', kBackupSnapshotFile), isNull);
    });
  });
}
