import 'dart:convert';
import 'dart:io';

import 'package:fireracoon_app_backend/fireracoon_app_backend.dart';
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
}
