import 'dart:convert';
import 'dart:io';

import 'package:fireracoon_app_backend/fireracoon_app_backend.dart';
import 'package:fireracoon_app_backend/src/crypto/passwords.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fireracoon_store_');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  test('creates and unlocks store with DATA_PASSWORD', () async {
    final created = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    await created.writeJson('state', {'hello': 'world'});

    final unlocked = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final raw = await unlocked.readJson('state');
    expect(raw, isA<Map<Object?, Object?>>());
    expect((raw! as Map<Object?, Object?>)['hello'], 'world');
  });

  test('wrong password fails unlock without wiping data', () async {
    final created = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    await created.writeJson('state', {'secret': 'value'});

    expect(
      () => SealedStore.open(dataDirPath: tmp.path, password: 'wrong-password'),
      throwsA(isA<StateError>()),
    );

    final header = File('${tmp.path}/store.header');
    expect(header.existsSync(), isTrue);
    final enc = File('${tmp.path}/state.enc');
    expect(enc.existsSync(), isTrue);
    final encText = await enc.readAsString();
    expect(encText.contains('secret'), isFalse);
    expect(encText.contains('value'), isFalse);
  });

  test('repository setup login and snapshot round-trip', () async {
    final sealed = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final repo = StateRepository(sealed);
    await repo.load();

    expect(repo.state.setupRequired, isTrue);

    await repo.setup(
      adminName: 'Alex',
      adminPassword: 'Password1!',
      fireflyUrl: 'https://firefly.example',
      fireflyToken: 'ff-token-secret',
    );

    final login = await repo.login(name: 'Alex', password: 'Password1!');
    expect(login.person['role'], 'admin');
    expect(repo.isAdmin(login.token), isTrue);

    final snap = repo.snapshotForClient(sessionToken: login.token);
    expect(snap['setupRequired'], isFalse);
    expect((snap['firefly'] as Map)['configured'], isTrue);
    expect((snap['firefly'] as Map).containsKey('token'), isFalse);
    expect(snap['people'], hasLength(1));
    expect((snap['people'] as List).first['name'], 'Alex');

    await repo.replacePeopleConfig(
      people: [
        {
          'id': login.person['id'],
          'name': 'Alex',
          'colorValue': 0xFF1565C0,
          'avatarKind': 'none',
          'role': 'admin',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'preferences': <String, dynamic>{},
        },
        {
          'id': 'person_sam',
          'name': 'Sam',
          'colorValue': 0xFF2E7D32,
          'avatarKind': 'none',
          'role': 'user',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'preferences': <String, dynamic>{},
        },
      ],
      accountOwnerships: const [],
      requirePasswordLogin: true,
      passwordUpdates: const {'person_sam': 'Password2!'},
    );
    final samLogin = await repo.login(name: 'Sam', password: 'Password2!');
    expect(samLogin.person['role'], 'user');
    expect(
      repo.snapshotForClient(sessionToken: login.token)['people'],
      hasLength(2),
    );

    final enc = await File('${tmp.path}/state.enc').readAsString();
    expect(enc.contains('ff-token-secret'), isFalse);
    expect(enc.contains('Password1!'), isFalse);
  });

  test('replacePeopleConfig rejects stripping the last password', () async {
    final sealed = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final repo = StateRepository(sealed);
    await repo.load();
    await repo.setup(
      adminName: 'Alex',
      adminPassword: 'Password1!',
      fireflyUrl: 'https://firefly.example',
      fireflyToken: 'ff-token-secret',
    );
    final login = await repo.login(name: 'Alex', password: 'Password1!');
    final adminId = login.person['id'] as String;

    expect(
      () => repo.replacePeopleConfig(
        people: [
          {
            'id': 'person_unknown',
            'name': 'Stranger',
            'role': 'admin',
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'preferences': <String, dynamic>{},
          },
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('last remaining password'),
        ),
      ),
    );

    // Known id without passwordUpdates must keep the existing hash.
    await repo.replacePeopleConfig(
      people: [
        {
          'id': adminId,
          'name': 'Alex',
          'role': 'admin',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'preferences': <String, dynamic>{},
        },
      ],
      accountOwnerships: const [],
      requirePasswordLogin: false,
    );
    final stillWorks = await repo.login(name: 'Alex', password: 'Password1!');
    expect(stillWorks.person['id'], adminId);
    expect(repo.state.requirePasswordLogin, isFalse);
  });

  test('backupSecretsForAdmin exposes PAT and salted hashes', () async {
    final sealed = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final repo = StateRepository(sealed);
    await repo.load();
    await repo.setup(
      adminName: 'Alex',
      adminPassword: 'Password1!',
      fireflyUrl: 'https://firefly.example',
      fireflyToken: 'ff-token-secret',
    );
    final login = await repo.login(name: 'Alex', password: 'Password1!');
    final secrets = repo.backupSecretsForAdmin();
    expect(
      (secrets['firefly'] as Map<String, dynamic>)['token'],
      'ff-token-secret',
    );
    expect(
      (secrets['firefly'] as Map<String, dynamic>)['url'],
      'https://firefly.example',
    );
    final peopleAuth = secrets['peopleAuth'] as Map<String, dynamic>;
    final adminAuth = peopleAuth[login.person['id']] as Map<String, dynamic>;
    expect(adminAuth['passwordHash'], isNotEmpty);
    expect(adminAuth['salt'], isNotEmpty);
    expect(adminAuth['passwordHash'], isNot(equals('server')));
  });

  test('replacePeopleConfig accepts portable authImports', () async {
    final sealed = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final repo = StateRepository(sealed);
    await repo.load();
    await repo.setup(
      adminName: 'Alex',
      adminPassword: 'Password1!',
      fireflyUrl: 'https://firefly.example',
      fireflyToken: 'ff-token-secret',
    );
    final hashed = await hashPassword('Imported9!!');
    await repo.replacePeopleConfig(
      people: [
        {
          'id': 'person_imported',
          'name': 'Imported',
          'role': 'admin',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'preferences': <String, dynamic>{},
        },
      ],
      accountOwnerships: const [],
      requirePasswordLogin: true,
      authImports: {
        'person_imported': {'passwordHash': hashed.hash, 'salt': hashed.salt},
      },
    );
    final login = await repo.login(name: 'Imported', password: 'Imported9!!');
    expect(login.person['role'], 'admin');
  });

  test('ServerConfig allows missing password (UI unlock)', () {
    expect(
      () => ServerConfig.fromEnvironment(
        environment: {'FIRERACOON_MODE': 'local', 'DATA_PASSWORD': 'x'},
      ),
      throwsA(isA<StateError>()),
    );

    final locked = ServerConfig.fromEnvironment(
      environment: {
        'FIRERACOON_MODE': 'server',
        'DATA_DIR': tmp.path,
        'PORT': '9090',
      },
    );
    expect(locked.mode, FireracoonMode.server);
    expect(locked.dataPassword, isNull);
    expect(locked.port, 9090);
  });

  test('starts locked then unlocks via API', () async {
    final server = await AppServer.open(
      ServerConfig(
        mode: FireracoonMode.server,
        dataDir: tmp.path,
        port: 0,
        webRoot: tmp.path,
      ),
    );
    expect(server.isStoreLocked, isTrue);

    final caps = await server.handler(
      Request('GET', Uri.parse('http://localhost/api/capabilities')),
    );
    final capsBody =
        jsonDecode(await caps.readAsString()) as Map<String, dynamic>;
    expect(capsBody['storeLocked'], isTrue);
    expect(capsBody['storeExists'], isFalse);

    final unlock = await server.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/store/unlock'),
        body: jsonEncode({
          'password': 'correct-horse',
          'confirmPassword': 'correct-horse',
        }),
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(unlock.statusCode, 200);
    expect(server.isStoreLocked, isFalse);
    expect(SealedStore.exists(tmp.path), isTrue);
  });

  test('create requires confirm; unlock uses existing DATA_DIR', () async {
    final server = await AppServer.open(
      ServerConfig(
        mode: FireracoonMode.server,
        dataDir: tmp.path,
        port: 0,
        webRoot: tmp.path,
      ),
    );

    final missingConfirm = await server.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/store/unlock'),
        body: jsonEncode({'password': 'correct-horse'}),
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(missingConfirm.statusCode, 400);

    final created = await server.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/store/unlock'),
        body: jsonEncode({
          'password': 'correct-horse',
          'confirmPassword': 'correct-horse',
        }),
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(created.statusCode, 200);

    // Simulate restart: new process, same DATA_DIR, no env password.
    final restarted = await AppServer.open(
      ServerConfig(
        mode: FireracoonMode.server,
        dataDir: tmp.path,
        port: 0,
        webRoot: tmp.path,
      ),
    );
    expect(restarted.isStoreLocked, isTrue);
    expect(restarted.storeExists, isTrue);

    final unlock = await restarted.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/store/unlock'),
        body: jsonEncode({'password': 'correct-horse'}),
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(unlock.statusCode, 200);
    expect(restarted.isStoreLocked, isFalse);
  });

  test('DATA_PASSWORD creates store on empty DATA_DIR', () async {
    final server = await AppServer.open(
      ServerConfig(
        mode: FireracoonMode.server,
        dataDir: tmp.path,
        dataPassword: 'correct-horse',
        port: 0,
        webRoot: tmp.path,
      ),
    );
    expect(server.isStoreLocked, isFalse);
    expect(SealedStore.exists(tmp.path), isTrue);

    final restarted = await AppServer.open(
      ServerConfig(
        mode: FireracoonMode.server,
        dataDir: tmp.path,
        dataPassword: 'correct-horse',
        port: 0,
        webRoot: tmp.path,
      ),
    );
    expect(restarted.isStoreLocked, isFalse);
  });

  test('an admin agent key cannot read the PAT or password hashes', () async {
    final sealed = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final repo = StateRepository(sealed);
    await repo.load();
    await repo.setup(
      adminName: 'Alex',
      adminPassword: 'Password1!',
      fireflyUrl: 'https://firefly.example',
      fireflyToken: 'ff-token-secret',
    );
    final login = await repo.login(name: 'Alex', password: 'Password1!');
    final issued = await repo.issueAgentKey(
      sessionToken: login.token,
      label: 'Claude',
    );

    final server = await AppServer.open(
      ServerConfig(
        mode: FireracoonMode.server,
        dataDir: tmp.path,
        dataPassword: 'correct-horse-battery',
        port: 0,
        webRoot: tmp.path,
      ),
    );

    // personForSession resolves an agent key to its owner, so an admin's key
    // satisfies isAdmin. Without a guard it reads back the Firefly token and
    // every person's password hash, which turns one leaked agent key into the
    // credential the whole design exists to keep away from agents.
    final asAgent = await server.handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/state/backup-secrets'),
        headers: {'x-fireracoon-session': issued.secret},
      ),
    );
    expect(asAgent.statusCode, 403);
    final refused =
        jsonDecode(await asAgent.readAsString()) as Map<String, dynamic>;
    expect(refused['error'], contains('Agent keys'));

    // Writing the Firefly connection is the other half: an agent key that can
    // point the app at another server exfiltrates just as effectively.
    final writeFirefly = await server.handler(
      Request(
        'PUT',
        Uri.parse('http://localhost/api/state/firefly'),
        headers: {'x-fireracoon-session': issued.secret},
        body: jsonEncode({'url': 'https://attacker.test', 'token': 'stolen'}),
      ),
    );
    expect(writeFirefly.statusCode, 403);

    // The person's own session still works, so the guard refuses the
    // credential rather than the permission.
    final asPerson = await server.handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/state/backup-secrets'),
        headers: {'x-fireracoon-session': login.token},
      ),
    );
    expect(asPerson.statusCode, 200);
  });

  test('backup-secrets is admin-only and returns PAT', () async {
    final sealed = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final repo = StateRepository(sealed);
    await repo.load();
    await repo.setup(
      adminName: 'Alex',
      adminPassword: 'Password1!',
      fireflyUrl: 'https://firefly.example',
      fireflyToken: 'ff-token-secret',
    );
    final login = await repo.login(name: 'Alex', password: 'Password1!');

    final server = await AppServer.open(
      ServerConfig(
        mode: FireracoonMode.server,
        dataDir: tmp.path,
        dataPassword: 'correct-horse-battery',
        port: 0,
        webRoot: tmp.path,
      ),
    );

    final forbidden = await server.handler(
      Request('GET', Uri.parse('http://localhost/api/state/backup-secrets')),
    );
    expect(forbidden.statusCode, 403);

    final ok = await server.handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/state/backup-secrets'),
        headers: {'x-fireracoon-session': login.token},
      ),
    );
    expect(ok.statusCode, 200);
    final body = jsonDecode(await ok.readAsString()) as Map<String, dynamic>;
    expect(body['ok'], isTrue);
    expect(
      (body['firefly'] as Map<String, dynamic>)['token'],
      'ff-token-secret',
    );
    expect(body['peopleAuth'], isA<Map<String, dynamic>>());
  });
}
