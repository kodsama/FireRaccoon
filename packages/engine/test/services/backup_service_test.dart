import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../helpers/firefly_fixtures.dart';
import 'firefly_api_service_fetch_test.dart' show jsonHttpResponse;

/// Keeps backups in memory, newest first, like the stores that write files do.
class _MemoryBackupStore implements BackupStore {
  final Map<String, Map<String, List<int>>> backups = {};

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
    backups.remove(backupId);
  }
}

FireflyApiService _serviceWith(MockClient client) => FireflyApiService(
  serverUrl: 'https://firefly.test',
  apiToken: 'test-token',
  client: client,
  readRetryBaseDelayMs: 0,
);

/// Answers every read a backup makes: the entity walk, then the CSV exports.
MockClient _ledger({
  List<Uri>? record,
  Set<String> failingExports = const {},
  List<Map<String, Object?>>? transactions,
}) {
  return MockClient((request) async {
    record?.add(request.url);
    final path = request.url.path;
    if (path.contains('/data/export/')) {
      final dataset = request.url.pathSegments.last;
      if (failingExports.contains(dataset)) {
        return jsonHttpResponse('{"message":"no"}', status: 500);
      }
      return jsonHttpResponse('id,name\n1,$dataset\n');
    }
    if (path.endsWith('/about/user')) {
      return jsonHttpResponse(userBody());
    }
    if (path.endsWith('/accounts')) {
      // The walk asks per type; only the asset call has anything to answer.
      return jsonHttpResponse(
        request.url.queryParameters['type'] == 'asset'
            ? accountsBody()
            : {'data': <Object?>[]},
      );
    }
    if (path.endsWith('/transactions')) {
      return jsonHttpResponse(
        transactionsPageBody(
          items:
              transactions ??
              [
                transactionItem(id: '1', date: '2024-03-15'),
                transactionItem(id: '2', date: '2026-05-20'),
              ],
          total: 2,
        ),
      );
    }
    if (path.endsWith('/budgets')) {
      return jsonHttpResponse(budgetsBody());
    }
    return jsonHttpResponse({'data': <Object?>[]});
  });
}

void main() {
  group('naming', () {
    test('an id carries the date, the time and the offset', () {
      final id = backupIdFor(DateTime(2026, 9, 1, 22, 27, 36));
      expect(id, matches(RegExp(r'^20260901T222736[+-]\d{4}$')));
    });

    test('a UTC moment is named with a zero offset', () {
      expect(
        backupIdFor(DateTime.utc(2026, 9, 1, 20, 27, 36)),
        '20260901T202736+0000',
      );
    });

    test('a stamp keeps the offset RFC 3339 wants', () {
      expect(
        backupTimestampFor(DateTime.utc(2026, 9, 1, 20, 27, 36)),
        '2026-09-01T20:27:36Z',
      );
      expect(
        backupTimestampFor(DateTime(2026, 9, 1, 22, 27, 36)),
        matches(RegExp(r'^2026-09-01T22:27:36[+-]\d{2}:\d{2}$')),
      );
    });
  });

  group('manifest', () {
    test('survives a round trip through JSON', () {
      final manifest = BackupManifest(
        id: '20260901T222736+0200',
        takenAt: DateTime.utc(2026, 9, 1, 20, 27, 36),
        timeZoneName: 'CEST',
        timeZoneOffset: const Duration(hours: 2),
        counts: const {'accounts': 2},
        entries: const [
          BackupEntry(name: 'snapshot.json', bytes: 12),
          BackupEntry(name: 'csv/rules.csv', bytes: 30, rows: 2),
        ],
        covers: const ['snapshot.json'],
        excludes: const ['database'],
        ownerId: '1',
        ownerEmail: 'admin@local.test',
        transactionsFrom: DateTime.utc(2024, 3, 15),
        transactionsTo: DateTime.utc(2026, 5, 20),
      );

      final restored = BackupManifest.fromJson(manifest.toJson());

      expect(restored.id, manifest.id);
      expect(restored.takenAt, manifest.takenAt);
      expect(restored.timeZoneName, 'CEST');
      expect(restored.timeZoneOffset, const Duration(hours: 2));
      expect(restored.counts, {'accounts': 2});
      expect(restored.entries.map((e) => e.name), [
        'snapshot.json',
        'csv/rules.csv',
      ]);
      expect(restored.entries.last.rows, 2);
      expect(restored.ownerEmail, 'admin@local.test');
      expect(restored.transactionsFrom, DateTime.utc(2024, 3, 15));
      expect(restored.transactionsTo, DateTime.utc(2026, 5, 20));
      expect(restored.schemaVersion, kBackupSchemaVersion);
      expect(restored.complete, isTrue);
      expect(restored.totalBytes, 42);
    });

    test('reads an empty object without inventing values', () {
      final manifest = BackupManifest.fromJson(const {});

      expect(manifest.id, isEmpty);
      expect(manifest.counts, isEmpty);
      expect(manifest.entries, isEmpty);
      expect(manifest.covers, isEmpty);
      expect(manifest.excludes, isEmpty);
      expect(manifest.ownerId, isNull);
      expect(manifest.transactionsFrom, isNull);
      expect(manifest.schemaVersion, 0);
      expect(manifest.takenAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('a part that failed leaves the backup incomplete', () {
      final manifest = BackupManifest.fromJson({
        'entries': [
          {'name': 'snapshot.json', 'bytes': 10},
          {'name': 'csv/rules.csv', 'bytes': 0, 'error': 'HTTP 500'},
        ],
      });

      expect(manifest.complete, isFalse);
      expect(manifest.totalBytes, 10);
      expect(manifest.entries.last.ok, isFalse);
    });
  });

  group('create', () {
    test('writes the snapshot, every export and a manifest', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(_serviceWith(_ledger()), store);

      final manifest = await service.create(
        takenAt: DateTime.utc(2026, 9, 1, 20, 27, 36),
      );

      expect(manifest.id, '20260901T202736+0000');
      expect(store.backups.keys, [manifest.id]);
      expect(
        store.backups[manifest.id]!.keys,
        containsAll(<String>[
          'manifest.json',
          'snapshot.json',
          'csv/rules.csv',
          'csv/piggy-banks.csv',
          'csv/transactions.csv',
        ]),
      );
      expect(manifest.complete, isTrue);
      expect(manifest.counts['accounts'], 2);
      expect(manifest.counts['transactions'], 2);
      expect(manifest.ownerId, '1');
      expect(manifest.ownerEmail, 'admin@local.test');
      expect(manifest.covers, contains('csv/rules.csv'));
      expect(manifest.excludes, contains('attachments'));
      expect(manifest.totalBytes, greaterThan(0));
    });

    test('reads the whole ledger rather than the default lookback', () async {
      final urls = <Uri>[];
      final service = BackupService(
        _serviceWith(_ledger(record: urls)),
        _MemoryBackupStore(),
      );

      await service.create(takenAt: DateTime.utc(2026, 9, 1));

      final walk = urls.firstWhere(
        (u) => u.path.endsWith('/api/v1/transactions'),
      );
      expect(walk.queryParameters['start'], '1970-01-03');
      expect(walk.queryParameters['end'], '2038-01-15');
    });

    test('exports CSV over the window the ledger actually covers', () async {
      final urls = <Uri>[];
      final service = BackupService(
        _serviceWith(_ledger(record: urls)),
        _MemoryBackupStore(),
      );

      await service.create(takenAt: DateTime.utc(2026, 9, 1));

      final windows = urls
          .where((u) => u.path.endsWith('/data/export/transactions'))
          .map((u) => u.queryParameters['start'])
          .toList();
      expect(windows, ['2024-03-15', '2025-01-01', '2026-01-01']);
    });

    test('falls back to the current year when the ledger is empty', () async {
      final urls = <Uri>[];
      final service = BackupService(
        _serviceWith(_ledger(record: urls, transactions: const [])),
        _MemoryBackupStore(),
      );

      final manifest = await service.create(
        takenAt: DateTime.utc(2026, 9, 1, 12),
      );

      expect(manifest.transactionsFrom, DateTime.utc(2026));
      final windows = urls
          .where((u) => u.path.endsWith('/data/export/transactions'))
          .toList();
      expect(windows, hasLength(1));
    });

    test('stamps itself with now when no moment is given', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(_serviceWith(_ledger()), store);
      final before = DateTime.now();

      final manifest = await service.create();

      expect(manifest.takenAt.isBefore(before), isFalse);
      expect(manifest.id, backupIdFor(manifest.takenAt));
      expect(manifest.timeZoneOffset, DateTime.now().timeZoneOffset);
    });

    test('keeps the local zone in an empty ledger window', () async {
      final service = BackupService(
        _serviceWith(_ledger(transactions: const [])),
        _MemoryBackupStore(),
      );

      final manifest = await service.create(takenAt: DateTime(2026, 9, 1, 12));

      expect(manifest.transactionsFrom, DateTime(2026));
      expect(manifest.transactionsFrom!.isUtc, isFalse);
    });

    test(
      'never writes a second backup over one from the same second',
      () async {
        final store = _MemoryBackupStore();
        final service = BackupService(_serviceWith(_ledger()), store);
        final at = DateTime.utc(2026, 9, 1, 20, 27, 36);

        final first = await service.create(takenAt: at);
        final second = await service.create(takenAt: at);
        final third = await service.create(takenAt: at);

        expect(first.id, '20260901T202736+0000');
        expect(second.id, '20260901T202736+0000-2');
        expect(third.id, '20260901T202736+0000-3');
        expect(store.backups, hasLength(3));
      },
    );

    test('records an export that failed and keeps the backup', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(
        _serviceWith(_ledger(failingExports: {'rules'})),
        store,
      );

      final manifest = await service.create(takenAt: DateTime.utc(2026, 9, 1));

      final rules = manifest.entries.firstWhere(
        (e) => e.name == 'csv/rules.csv',
      );
      expect(rules.ok, isFalse);
      expect(rules.error, contains('500'));
      expect(rules.bytes, 0);
      expect(manifest.complete, isFalse);
      // The part that failed is absent rather than written empty.
      expect(store.backups[manifest.id]!.containsKey('csv/rules.csv'), isFalse);
      expect(store.backups[manifest.id]!.containsKey('snapshot.json'), isTrue);
    });

    test('reports what it is reading as it goes', () async {
      final stages = <String>[];
      final service = BackupService(
        _serviceWith(_ledger()),
        _MemoryBackupStore(),
      );

      await service.create(
        takenAt: DateTime.utc(2026, 9, 1),
        onStage: stages.add,
      );

      expect(stages.first, 'owner');
      expect(stages, contains('snapshot'));
      expect(stages, contains('csv:rules'));
    });
  });

  group('reading back', () {
    test('lists what the store holds, newest first', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(_serviceWith(_ledger()), store);
      await service.create(takenAt: DateTime.utc(2026, 1, 1));
      await service.create(takenAt: DateTime.utc(2026, 9, 1));

      final manifests = await service.list();

      expect(manifests.map((m) => m.id), [
        '20260901T000000+0000',
        '20260101T000000+0000',
      ]);
    });

    test('orders by the moment taken, not by the name', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(_serviceWith(_ledger()), store);
      // Named 00:30 in a zone two hours ahead, so it sorts first by name and
      // second by the instant it actually happened.
      await service.create(
        takenAt: DateTime.parse('2026-09-02T00:30:00+02:00').toUtc(),
      );
      await service.create(
        takenAt: DateTime.parse('2026-09-01T23:45:00+01:00').toUtc(),
      );

      final manifests = await service.list();

      expect(manifests.first.takenAt, DateTime.utc(2026, 9, 1, 22, 45));
    });

    test('skips a backup whose manifest cannot be read', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(_serviceWith(_ledger()), store);
      await service.create(takenAt: DateTime.utc(2026, 9, 1));
      store.backups['broken'] = {
        'manifest.json': utf8.encode('not json at all'),
      };
      store.backups['listy'] = {'manifest.json': utf8.encode('[1,2,3]')};
      store.backups['empty'] = {};

      final manifests = await service.list();

      expect(manifests.map((m) => m.id), ['20260901T000000+0000']);
    });

    test('reads the snapshot a restore needs', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(_serviceWith(_ledger()), store);
      final manifest = await service.create(takenAt: DateTime.utc(2026, 9, 1));

      final snapshot = await service.snapshot(manifest.id);

      expect(snapshot!['schema_version'], kDataExportSchemaVersion);
      expect((snapshot['accounts'] as List), hasLength(2));
    });

    test('answers nothing for a snapshot that is missing or broken', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(_serviceWith(_ledger()), store);

      expect(await service.snapshot('nope'), isNull);
      store.backups['bad'] = {'snapshot.json': utf8.encode('{oops')};
      expect(await service.snapshot('bad'), isNull);
      store.backups['listy'] = {'snapshot.json': utf8.encode('[]')};
      expect(await service.snapshot('listy'), isNull);
      expect(await service.read('nope'), isNull);
    });

    test('hands back one file, or nothing when it is not there', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(_serviceWith(_ledger()), store);
      final manifest = await service.create(takenAt: DateTime.utc(2026, 9, 1));

      expect(await service.file(manifest.id, 'csv/tags.csv'), contains('tags'));
      expect(await service.file(manifest.id, 'csv/nope.csv'), isNull);
    });

    test('deletes a backup whole', () async {
      final store = _MemoryBackupStore();
      final service = BackupService(_serviceWith(_ledger()), store);
      final manifest = await service.create(takenAt: DateTime.utc(2026, 9, 1));

      await service.delete(manifest.id);

      expect(store.backups, isEmpty);
      expect(await service.list(), isEmpty);
    });
  });
}
