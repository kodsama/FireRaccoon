import 'dart:convert';
import 'dart:io';

import 'package:fireraccoon_app_backend/fireraccoon_app_backend.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers/test_store.dart';

const _password = 'correct-horse-battery';

Map<String, dynamic> _person(String id, String name, {String role = 'user'}) =>
    {
      'id': id,
      'name': name,
      'colorValue': 0xFF1565C0,
      'avatarKind': 'none',
      'role': role,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'preferences': <String, dynamic>{},
    };

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fireraccoon_backups_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<StateRepository> repository() async {
    final sealed = await openTestStore(
      dataDirPath: tmp.path,
      password: _password,
    );
    final repo = StateRepository(
      sealed,
      passwordIterations: kTestPbkdf2Iterations,
    );
    await repo.load();
    await repo.setup(
      adminName: 'Alex',
      adminPassword: 'Password1!',
      fireflyUrl: 'https://firefly.example',
      fireflyToken: 'ff-token-secret',
    );
    return repo;
  }

  Future<AppServer> server() => openTestServer(
    ServerConfig(
      mode: FireraccoonMode.server,
      dataDir: tmp.path,
      dataPassword: _password,
      port: 0,
      webRoot: tmp.path,
    ),
  );

  Future<Map<String, dynamic>> body(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;

  group('sealed store', () {
    test('a backup round-trips through the seal', () async {
      final repo = await repository();
      final store = SealedBackupStore(repo.store);

      await store.put('b1', 'manifest.json', utf8.encode('{"id":"b1"}'));
      await store.put('b1', 'csv/rules.csv', utf8.encode('id\n1\n'));

      expect(
        utf8.decode((await store.get('b1', 'manifest.json'))!),
        '{"id":"b1"}',
      );
      expect(await store.listBackupIds(), ['b1']);
      // What lands on disk is ciphertext, not the ledger someone backed up.
      final onDisk = File(
        '${tmp.path}/backups/b1/manifest.json.enc',
      ).readAsStringSync();
      expect(onDisk, isNot(contains('"id":"b1"')));
    });

    test('lists newest first and forgets a deleted backup', () async {
      final repo = await repository();
      final store = SealedBackupStore(repo.store);
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

      expect(await store.listBackupIds(), [
        '20260901T000000+0000',
        '20260101T000000+0000',
      ]);

      await store.deleteBackup('20260101T000000+0000');
      expect(await store.listBackupIds(), ['20260901T000000+0000']);
      expect(await store.get('20260101T000000+0000', 'manifest.json'), isNull);
    });

    test('an empty store holds nothing rather than failing', () async {
      final repo = await repository();
      expect(await SealedBackupStore(repo.store).listBackupIds(), isEmpty);
    });

    test('refuses a name that climbs out of the backups directory', () async {
      final repo = await repository();
      final store = SealedBackupStore(repo.store);

      expect(
        () => store.put('../state', 'x.json', const [1]),
        throwsArgumentError,
      );
      expect(
        () => store.put('b1', '../../state', const [1]),
        throwsArgumentError,
      );
      expect(() => store.get('b1', 'csv/../../state'), throwsArgumentError);
      expect(() => store.deleteBackup('..'), throwsArgumentError);
    });
  });

  group('HTTP surface', () {
    Future<({AppServer server, String session})> ready() async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      return (server: await server(), session: login.token);
    }

    Future<Response> put(
      AppServer app,
      String session,
      String path,
      String contents,
    ) async => app.handler(
      Request(
        'PUT',
        Uri.parse('http://localhost$path'),
        body: contents,
        headers: {'x-fireraccoon-session': session},
      ),
    );

    test('a part put away comes back byte for byte', () async {
      final (server: app, session: session) = await ready();

      final stored = await put(
        app,
        session,
        '/api/backups/b1/files/csv/rules.csv',
        'id,name\n1,rules\n',
      );
      expect(stored.statusCode, 201);
      expect((await body(stored))['bytes'], 16);

      final read = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/backups/b1/files/csv/rules.csv'),
          headers: {'x-fireraccoon-session': session},
        ),
      );
      expect(read.statusCode, 200);
      expect(await read.readAsString(), 'id,name\n1,rules\n');
    });

    test('listing names the backups and deleting removes one', () async {
      final (server: app, session: session) = await ready();
      await put(app, session, '/api/backups/b1/files/manifest.json', '{}');
      await put(app, session, '/api/backups/b2/files/manifest.json', '{}');

      final listed = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/backups'),
          headers: {'x-fireraccoon-session': session},
        ),
      );
      expect((await body(listed))['backups'], ['b2', 'b1']);

      final deleted = await app.handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/backups/b1'),
          headers: {'x-fireraccoon-session': session},
        ),
      );
      expect((await body(deleted))['deleted'], isTrue);

      final again = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/backups'),
          headers: {'x-fireraccoon-session': session},
        ),
      );
      expect((await body(again))['backups'], ['b2']);
    });

    test('a part that was never stored is a 404', () async {
      final (server: app, session: session) = await ready();

      final response = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/backups/b1/files/manifest.json'),
          headers: {'x-fireraccoon-session': session},
        ),
      );

      expect(response.statusCode, 404);
    });

    test('a name outside the shape FireRaccoon writes is refused', () async {
      final (server: app, session: session) = await ready();

      final response = await put(
        app,
        session,
        '/api/backups/b1/files/..%2F..%2Fstate',
        'nope',
      );

      expect(response.statusCode, 400);
      expect(File('${tmp.path}/state.enc').readAsStringSync(), isNot('nope'));
    });

    test('an agent key reaches backups as its person', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Code',
      );
      final app = await server();

      final stored = await app.handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/backups/b1/files/manifest.json'),
          body: '{}',
          headers: {'authorization': 'Bearer ${issued.secret}'},
        ),
      );

      expect(stored.statusCode, 201);
    });

    test('a viewer may read backups but not write or remove one', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final admin = repo.state.people.first;
      await repo.replacePeopleConfig(
        people: [
          admin,
          _person('viewer-1', 'Robin', role: 'viewer'),
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
        passwordUpdates: const {'viewer-1': 'Password1!'},
      );
      final viewer = await repo.login(name: 'Robin', password: 'Password1!');
      final app = await server();

      final listed = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/backups'),
          headers: {'x-fireraccoon-session': viewer.token},
        ),
      );
      final stored = await put(
        app,
        viewer.token,
        '/api/backups/b1/files/manifest.json',
        '{}',
      );
      final deleted = await app.handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/backups/b1'),
          headers: {'x-fireraccoon-session': viewer.token},
        ),
      );

      expect(listed.statusCode, 200);
      expect(stored.statusCode, 403);
      expect(deleted.statusCode, 403);
      expect(login.token, isNotEmpty);
    });

    test('nothing is reachable without a credential', () async {
      final (server: app, session: _) = await ready();

      for (final request in [
        Request('GET', Uri.parse('http://localhost/api/backups')),
        Request(
          'GET',
          Uri.parse('http://localhost/api/backups/b1/files/manifest.json'),
        ),
        Request(
          'PUT',
          Uri.parse('http://localhost/api/backups/b1/files/manifest.json'),
          body: '{}',
        ),
        Request('DELETE', Uri.parse('http://localhost/api/backups/b1')),
      ]) {
        expect((await app.handler(request)).statusCode, 401);
      }
    });
  });
}
