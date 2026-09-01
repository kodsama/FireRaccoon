import 'dart:convert';
import 'dart:io';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers/firefly_mock.dart';

const _target = FireflyTarget(baseUrl: fireflyBaseUrl, bearer: fireflyToken);

McpTool _tool(
  String name, {
  required MockClient client,
  BackupStore? backups,
}) => buildTools(
  target: _target,
  httpClient: client,
  backups: backups,
).firstWhere((tool) => tool.name == name);

void main() {
  late Directory root;
  late FileBackupStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fireraccoon-backups');
    store = FileBackupStore(root.path);
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('file store', () {
    test('writes a backup as directories a person can open', () async {
      await store.put('b1', 'manifest.json', utf8.encode('{}'));
      await store.put('b1', 'csv/rules.csv', utf8.encode('id\n1\n'));

      expect(
        File('${root.path}/b1/csv/rules.csv').readAsStringSync(),
        'id\n1\n',
      );
      expect(utf8.decode((await store.get('b1', 'csv/rules.csv'))!), 'id\n1\n');
      expect(await store.get('b1', 'csv/missing.csv'), isNull);
    });

    test('lists only directories holding a manifest, newest first', () async {
      await store.put(
        '20260101T000000+0000',
        'manifest.json',
        utf8.encode('{}'),
      );
      await store.put(
        '20260901T000000+0000',
        'manifest.json',
        utf8.encode('{}'),
      );
      await store.put('half-written', 'snapshot.json', utf8.encode('{}'));
      File('${root.path}/loose.txt').writeAsStringSync('not a backup');

      expect(await store.listBackupIds(), [
        '20260901T000000+0000',
        '20260101T000000+0000',
      ]);
    });

    test('an empty root has nothing rather than failing', () async {
      expect(
        await FileBackupStore('${root.path}/never-created').listBackupIds(),
        isEmpty,
      );
    });

    test('refuses a name that climbs out of the root', () async {
      expect(
        () => store.put('../escape', 'manifest.json', const [1]),
        throwsArgumentError,
      );
      expect(
        () => store.put('b1', '../../escape.json', const [1]),
        throwsArgumentError,
      );
      expect(() => store.get('b1', 'csv/../../x'), throwsArgumentError);
      expect(() => store.deleteBackup('..'), throwsArgumentError);
    });

    test('deletes a backup whole, and shrugs at one that is gone', () async {
      await store.put('b1', 'manifest.json', utf8.encode('{}'));

      await store.deleteBackup('b1');
      await store.deleteBackup('b1');

      expect(await store.listBackupIds(), isEmpty);
    });
  });

  group('tools', () {
    test('create_backup writes the snapshot and every export', () async {
      final tool = _tool(
        'create_backup',
        client: fireflyMockClient(),
        backups: store,
      );

      final result = await tool.run({});

      expect(result['ok'], isTrue);
      final backup = result['backup']! as Map<String, Object?>;
      expect(backup['complete'], isTrue);
      expect(result['warning'], isNull);
      final id = backup['id']! as String;
      expect(File('${root.path}/$id/snapshot.json').existsSync(), isTrue);
      expect(File('${root.path}/$id/csv/rules.csv').existsSync(), isTrue);
      expect(backup['taken_at'], isA<String>());
      expect((backup['timezone']! as Map)['offset_minutes'], isA<int>());
    });

    test('create_backup says so when a data set is missing', () async {
      final tool = _tool(
        'create_backup',
        client: fireflyMockClient(failingExports: {'rules'}),
        backups: store,
      );

      final result = await tool.run({});

      expect(result['ok'], isTrue);
      expect(result['warning'], contains('entries[].error'));
      expect((result['backup']! as Map)['complete'], isFalse);
    });

    test('list_backups reports what is there, newest first', () async {
      final client = fireflyMockClient();
      await _tool('create_backup', client: client, backups: store).run({});
      await _tool('create_backup', client: client, backups: store).run({});

      final result = await _tool(
        'list_backups',
        client: client,
        backups: store,
      ).run({});

      expect(result['count'], 2);
      final backups = result['backups']! as List<Object?>;
      final ids = [for (final b in backups) (b! as Map)['id']];
      expect(ids.toSet(), hasLength(2));
    });

    test('get_backup answers with the manifest by default', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({});
      final id = (created['backup']! as Map)['id']! as String;

      final result = await _tool(
        'get_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id});

      expect((result['backup']! as Map)['id'], id);
      expect(result['contents'], isNull);
    });

    test('get_backup truncates a file at max_bytes', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({});
      final id = (created['backup']! as Map)['id']! as String;
      final tool = _tool('get_backup', client: client, backups: store);

      final whole = await tool.run({'backup_id': id, 'file': 'csv/tags.csv'});
      final clipped = await tool.run({
        'backup_id': id,
        'file': 'csv/tags.csv',
        'max_bytes': 4,
      });

      expect(whole['truncated'], isFalse);
      expect(whole['contents'], 'id,name\n1,tags\n');
      expect(clipped['truncated'], isTrue);
      expect(clipped['contents'], 'id,n');
      expect(clipped['bytes'], 15);
    });

    test('get_backup refuses what it cannot find', () async {
      final client = fireflyMockClient();
      final tool = _tool('get_backup', client: client, backups: store);
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({});
      final id = (created['backup']! as Map)['id']! as String;

      expect((await tool.run({'backup_id': ''}))['code'], 'bad_input');
      expect((await tool.run({'backup_id': 'nope'}))['code'], 'not_found');
      expect(
        (await tool.run({'backup_id': id, 'file': 'csv/nope.csv'}))['code'],
        'not_found',
      );
    });

    test('delete_backup removes it, and only when it exists', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({});
      final id = (created['backup']! as Map)['id']! as String;
      final tool = _tool('delete_backup', client: client, backups: store);

      expect((await tool.run({'backup_id': 'nope'}))['code'], 'not_found');
      expect((await tool.run({'backup_id': ''}))['code'], 'bad_input');
      expect((await tool.run({'backup_id': id}))['deleted'], isTrue);
      expect(Directory('${root.path}/$id').existsSync(), isFalse);
    });

    test(
      'every backup tool refuses when there is nowhere to keep one',
      () async {
        final client = fireflyMockClient();
        for (final name in [
          'create_backup',
          'list_backups',
          'get_backup',
          'delete_backup',
        ]) {
          final result = await _tool(
            name,
            client: client,
          ).run({'backup_id': 'b1'});
          expect(result['ok'], isFalse, reason: name);
          expect(result['code'], 'unavailable', reason: name);
        }
      },
    );

    test('taking a backup is gated on write access', () {
      final names = [
        for (final tool in buildTools(target: _target))
          if (tool.writes) tool.name,
      ];

      expect(names, containsAll(<String>['create_backup', 'delete_backup']));
      expect(names, isNot(contains('list_backups')));
      expect(names, isNot(contains('get_backup')));
    });
  });
}
