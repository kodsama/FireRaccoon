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

  group('restore', () {
    Future<String> takeBackup(MockClient client) async {
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({});
      return (created['backup']! as Map)['id']! as String;
    }

    test('plans without writing anything', () async {
      final client = fireflyMockClient();
      final id = await takeBackup(client);

      final result = await _tool(
        'restore_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id});

      expect(result['ok'], isTrue);
      expect(result['dry_run'], isTrue);
      // Nothing moved between the backup and the plan, so there is nothing to
      // put back.
      expect((result['plan']! as Map)['steps'], isEmpty);
      expect(result['next'], contains('already matches'));
    });

    test('writing needs both flags', () async {
      final client = fireflyMockClient();
      final id = await takeBackup(client);

      final result = await _tool(
        'restore_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id, 'dry_run': false});

      expect(result['code'], 'bad_input');
      expect(result['error'], contains('confirm'));
    });

    test('takes a fresh backup before it writes', () async {
      final client = fireflyMockClient();
      final id = await takeBackup(client);

      final result = await _tool(
        'restore_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id, 'dry_run': false, 'confirm': true});

      expect(result['ok'], isTrue);
      expect(result['backup_taken_first'], isNot(id));
      expect(await store.listBackupIds(), hasLength(2));
    });

    test('refuses a backup taken from another ledger', () async {
      final client = fireflyMockClient();
      final id = await takeBackup(client);
      final manifest =
          jsonDecode(utf8.decode((await store.get(id, kBackupManifestFile))!))
              as Map<String, Object?>;
      manifest['owner'] = {'id': '99', 'email': 'someone@else.test'};
      await store.put(
        id,
        kBackupManifestFile,
        utf8.encode(jsonEncode(manifest)),
      );

      final result = await _tool(
        'restore_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id});

      expect(result['ok'], isFalse);
      expect(result['code'], 'wrong_ledger');
      expect(result['error'], contains('someone@else.test'));
    });

    test('refuses what it cannot find, and says what it needs', () async {
      final client = fireflyMockClient();
      final tool = _tool('restore_backup', client: client, backups: store);
      final id = await takeBackup(client);
      await store.put(id, kBackupSnapshotFile, utf8.encode('not json'));

      expect((await tool.run({'backup_id': ''}))['code'], 'bad_input');
      expect((await tool.run({'backup_id': 'nope'}))['code'], 'not_found');
      final broken = await tool.run({'backup_id': id});
      expect(broken['code'], 'not_found');
      expect(broken['error'], contains('no snapshot'));
    });

    test('is refused where there is nowhere to keep a backup', () async {
      final result = await _tool(
        'restore_backup',
        client: fireflyMockClient(),
      ).run({'backup_id': 'b1'});

      expect(result['code'], 'unavailable');
    });

    test('putting a lost transaction back is one create', () async {
      final client = fireflyMockClient();
      final id = await takeBackup(client);
      // The ledger loses a transaction after the backup was taken.
      final snapshot =
          jsonDecode(utf8.decode((await store.get(id, kBackupSnapshotFile))!))
              as Map<String, Object?>;
      (snapshot['transactions']! as List).add({
        'id': '99',
        'group_title': null,
        'splits': [
          {
            'type': 'withdrawal',
            'date': '2026-01-15T00:00:00.000',
            'amount': 12.5,
            'description': 'Lost row',
            'source_id': '5',
            'destination_name': 'Store',
            'currency_code': 'EUR',
            'tags': <String>[],
          },
        ],
      });
      await store.put(
        id,
        kBackupSnapshotFile,
        utf8.encode(jsonEncode(snapshot)),
      );

      final planned = await _tool(
        'restore_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id});

      final steps = (planned['plan']! as Map)['steps']! as List<Object?>;
      expect(steps, hasLength(1));
      expect((steps.single! as Map)['action'], 'create');
      expect((steps.single! as Map)['label'], 'Lost row');
    });

    test('a long plan is reported to a ceiling, counted whole', () async {
      final client = fireflyMockClient();
      final id = await takeBackup(client);
      final snapshot =
          jsonDecode(utf8.decode((await store.get(id, kBackupSnapshotFile))!))
              as Map<String, Object?>;
      for (var i = 0; i < 5; i++) {
        (snapshot['transactions']! as List).add({
          'id': 'lost-$i',
          'splits': [
            {
              'type': 'withdrawal',
              'date': '2026-01-15T00:00:00.000',
              'amount': 1.0,
              'description': 'Row $i',
              'source_id': '5',
              'destination_name': 'Store',
              'currency_code': 'EUR',
              'tags': <String>[],
            },
          ],
        });
      }
      await store.put(
        id,
        kBackupSnapshotFile,
        utf8.encode(jsonEncode(snapshot)),
      );

      final planned = await _tool(
        'restore_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id, 'max_steps_reported': 2});

      final plan = planned['plan']! as Map<String, Object?>;
      expect(plan['steps'], hasLength(2));
      expect(plan['steps_truncated'], 3);
      expect((plan['counts_by_action']! as Map)['create'], 5);
    });

    test('a restore is gated on write access', () {
      final names = [
        for (final tool in buildTools(target: _target))
          if (tool.writes) tool.name,
      ];

      expect(names, contains('restore_backup'));
    });

    test('a step Firefly refuses is reported, not swallowed', () async {
      final client = fireflyMockClient(failingWrites: {'/api/v1/transactions'});
      final id = await takeBackup(client);
      final snapshot =
          jsonDecode(utf8.decode((await store.get(id, kBackupSnapshotFile))!))
              as Map<String, Object?>;
      (snapshot['transactions']! as List).add({
        'id': '99',
        'splits': [
          {
            'type': 'withdrawal',
            'date': '2026-01-15T00:00:00.000',
            'amount': 12.5,
            'description': 'Lost row',
            'source_id': '5',
            'destination_name': 'Store',
            'currency_code': 'EUR',
            'tags': <String>[],
          },
        ],
      });
      await store.put(
        id,
        kBackupSnapshotFile,
        utf8.encode(jsonEncode(snapshot)),
      );

      final result = await _tool(
        'restore_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id, 'dry_run': false, 'confirm': true});

      expect(result['ok'], isTrue);
      expect(result['failed'], 1);
      expect(result['applied'], 0);
      final failure = (result['failures']! as List).single! as Map;
      expect(failure['error'], contains('500'));
      expect(failure['label'], 'Lost row');
    });
  });
  group('sealed backups', () {
    test('a password seals everything but the manifest', () async {
      final client = fireflyMockClient();
      final result = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({'password': 'a good password'});

      final backup = result['backup']! as Map<String, Object?>;
      expect(backup['encrypted'], isTrue);
      final id = backup['id']! as String;
      expect(
        File('${root.path}/$id/manifest.json').readAsStringSync(),
        contains('"encrypted": true'),
      );
      expect(
        File('${root.path}/$id/snapshot.json').readAsBytesSync().take(4),
        kSealedBackupMagic,
      );
    });

    test('reading one back needs the password', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({'password': 'a good password'});
      final id = (created['backup']! as Map)['id']! as String;
      final tool = _tool('get_backup', client: client, backups: store);

      final without = await tool.run({'backup_id': id, 'file': 'csv/tags.csv'});
      final wrong = await tool.run({
        'backup_id': id,
        'file': 'csv/tags.csv',
        'password': 'nope',
      });
      final right = await tool.run({
        'backup_id': id,
        'file': 'csv/tags.csv',
        'password': 'a good password',
      });

      expect(without['code'], 'password_required');
      expect(wrong['code'], 'password_required');
      expect(wrong['error'], contains('does not open'));
      expect(right['contents'], contains('tags'));
      // The manifest still reads without one, or a list would be useless.
      expect(
        (await tool.run({'backup_id': id}))['backup'],
        isA<Map<String, Object?>>(),
      );
    });

    test('restoring a sealed backup asks for the password', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({'password': 'a good password'});
      final id = (created['backup']! as Map)['id']! as String;
      final tool = _tool('restore_backup', client: client, backups: store);

      final without = await tool.run({'backup_id': id});
      final with_ = await tool.run({
        'backup_id': id,
        'password': 'a good password',
      });

      expect(without['code'], 'password_required');
      expect(with_['ok'], isTrue);
      expect((with_['plan']! as Map)['steps'], isEmpty);
    });

    test('a restore seals the backup it takes first the same way', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({'password': 'a good password'});
      final id = (created['backup']! as Map)['id']! as String;

      final restored =
          await _tool('restore_backup', client: client, backups: store).run({
            'backup_id': id,
            'password': 'a good password',
            'dry_run': false,
            'confirm': true,
          });

      final safety = restored['backup_taken_first']! as String;
      expect(
        File('${root.path}/$safety/snapshot.json').readAsBytesSync().take(4),
        kSealedBackupMagic,
      );
    });
  });

  group('verify', () {
    test('a fresh backup is intact and matches the ledger', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({});
      final id = (created['backup']! as Map)['id']! as String;

      final result = await _tool(
        'verify_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id});

      expect(result['ok'], isTrue);
      expect((result['integrity']! as Map)['intact'], isTrue);
      expect(result['matches'], isTrue);
      expect(result['same_ledger'], isTrue);
      expect(result['encrypted'], isFalse);
    });

    test('a file that changed on disk is reported', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({});
      final id = (created['backup']! as Map)['id']! as String;
      File('${root.path}/$id/csv/tags.csv').writeAsStringSync('tampered');

      final result = await _tool(
        'verify_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id, 'compare_ledger': false});

      final integrity = result['integrity']! as Map;
      expect(integrity['intact'], isFalse);
      expect((integrity['problems']! as List).single, contains('csv/tags.csv'));
      expect(result['matches'], isNull);
    });

    test('a ledger that moved on is counted row by row', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({});
      final id = (created['backup']! as Map)['id']! as String;
      final snapshotFile = File('${root.path}/$id/snapshot.json');
      final snapshot =
          jsonDecode(snapshotFile.readAsStringSync()) as Map<String, Object?>;
      (snapshot['categories']! as List).add({'id': '404', 'name': 'Gone'});
      snapshotFile.writeAsStringSync(jsonEncode(snapshot));

      final result = await _tool(
        'verify_backup',
        client: client,
        backups: store,
      ).run({'backup_id': id});

      expect(result['matches'], isFalse);
      final differences = result['differences']! as Map;
      expect((differences['counts_by_action']! as Map)['create'], 1);
      expect(((differences['rows']! as List).single as Map)['label'], 'Gone');
    });

    test('a sealed backup is verified with its password', () async {
      final client = fireflyMockClient();
      final created = await _tool(
        'create_backup',
        client: client,
        backups: store,
      ).run({'password': 'a good password'});
      final id = (created['backup']! as Map)['id']! as String;
      final tool = _tool('verify_backup', client: client, backups: store);

      final wrong = await tool.run({'backup_id': id, 'password': 'nope'});
      final right = await tool.run({
        'backup_id': id,
        'password': 'a good password',
      });

      expect((wrong['integrity']! as Map)['intact'], isFalse);
      expect(right['matches'], isTrue);
      expect(right['encrypted'], isTrue);
    });

    test('refuses what it cannot find, and needs an id', () async {
      final client = fireflyMockClient();
      final tool = _tool('verify_backup', client: client, backups: store);

      expect((await tool.run({'backup_id': ''}))['code'], 'bad_input');
      expect((await tool.run({'backup_id': 'nope'}))['code'], 'not_found');
      expect(
        (await _tool(
          'verify_backup',
          client: client,
        ).run({'backup_id': 'b1'}))['code'],
        'unavailable',
      );
    });
  });
}
