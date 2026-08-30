import 'dart:convert';
import 'dart:io';

import 'package:fireraccoon_app_backend/fireraccoon_app_backend.dart';
import 'package:fireraccoon_app_backend/src/crypto/passwords.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers/test_store.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fireraccoon_store_');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  test('creates and unlocks store with DATA_PASSWORD', () async {
    final created = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    await created.writeJson('state', {'hello': 'world'});

    final unlocked = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final raw = await unlocked.readJson('state');
    expect(raw, isA<Map<Object?, Object?>>());
    expect((raw! as Map<Object?, Object?>)['hello'], 'world');
  });

  test('wrong password fails unlock without wiping data', () async {
    final created = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    await created.writeJson('state', {'secret': 'value'});

    expect(
      () => openTestStore(dataDirPath: tmp.path, password: 'wrong-password'),
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
    final sealed = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final repo = StateRepository(
      sealed,
      passwordIterations: kTestPbkdf2Iterations,
    );
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
    final sealed = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
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
    final sealed = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
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
    final sealed = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
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
        environment: {'FIRERACCOON_MODE': 'local', 'DATA_PASSWORD': 'x'},
      ),
      throwsA(isA<StateError>()),
    );

    final locked = ServerConfig.fromEnvironment(
      environment: {
        'FIRERACCOON_MODE': 'server',
        'DATA_DIR': tmp.path,
        'PORT': '9090',
      },
    );
    expect(locked.mode, FireraccoonMode.server);
    expect(locked.dataPassword, isNull);
    expect(locked.port, 9090);
  });

  test('starts locked then unlocks via API', () async {
    final server = await openTestServer(
      ServerConfig(
        mode: FireraccoonMode.server,
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
    final server = await openTestServer(
      ServerConfig(
        mode: FireraccoonMode.server,
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
    final restarted = await openTestServer(
      ServerConfig(
        mode: FireraccoonMode.server,
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
    final server = await openTestServer(
      ServerConfig(
        mode: FireraccoonMode.server,
        dataDir: tmp.path,
        dataPassword: 'correct-horse',
        port: 0,
        webRoot: tmp.path,
      ),
    );
    expect(server.isStoreLocked, isFalse);
    expect(SealedStore.exists(tmp.path), isTrue);

    final restarted = await openTestServer(
      ServerConfig(
        mode: FireraccoonMode.server,
        dataDir: tmp.path,
        dataPassword: 'correct-horse',
        port: 0,
        webRoot: tmp.path,
      ),
    );
    expect(restarted.isStoreLocked, isFalse);
  });

  test('a store reopens at the cost it was sealed with', () async {
    // The header records the iteration count and unlock now reads it. Deriving
    // with a different count fails as an authentication error and surfaces as
    // "wrong password", so raising this default used to lock every existing
    // store out permanently and blame the user's password for it.
    final created = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
      iterations: 900,
    );
    final repo = StateRepository(created);
    await repo.load();
    await repo.setup(
      adminName: 'Alex',
      adminPassword: 'Password1!',
      fireflyUrl: 'https://firefly.example',
      fireflyToken: 'ff-token-secret',
    );

    final header =
        jsonDecode(
              await File(path.join(tmp.path, 'store.header')).readAsString(),
            )
            as Map<String, dynamic>;
    expect(header['iterations'], 900);

    // Reopened with the production default, which must be ignored in favour of
    // the header.
    final reopened = await SealedStore.open(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
    );
    final again = StateRepository(reopened);
    await again.load();
    expect(again.state.firefly.token, 'ff-token-secret');
  });

  test('an incomplete auth import is refused, not silently dropped', () async {
    final sealed = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
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
    final admin = await repo.login(name: 'Alex', password: 'Password1!');

    final server = await openTestServer(
      ServerConfig(
        mode: FireraccoonMode.server,
        dataDir: tmp.path,
        dataPassword: 'correct-horse-battery',
        port: 0,
        webRoot: tmp.path,
      ),
    );

    // A hash with no salt cannot log anyone in. Accepting the request and
    // dropping the entry reported success for an import that did not happen.
    final response = await server.handler(
      Request(
        'PUT',
        Uri.parse('http://localhost/api/state/people'),
        headers: {'x-fireraccoon-session': admin.token},
        body: jsonEncode({
          'people': [
            {'id': 'p9', 'name': 'Imported'},
          ],
          'authImports': {
            'p9': {'passwordHash': 'abc'},
          },
        }),
      ),
    );

    expect(response.statusCode, 400);
    final body = jsonDecode(await response.readAsString()) as Map;
    expect(body['error'], contains('salt'));
  });

  test(
    'a malformed avatar body is a bad request, not a server error',
    () async {
      final sealed = await openTestStore(
        dataDirPath: tmp.path,
        password: 'correct-horse-battery',
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
      final admin = await repo.login(name: 'Alex', password: 'Password1!');
      final person = repo.personForSession(admin.token)!['id'] as String;

      final server = await openTestServer(
        ServerConfig(
          mode: FireraccoonMode.server,
          dataDir: tmp.path,
          dataPassword: 'correct-horse-battery',
          port: 0,
          webRoot: tmp.path,
        ),
      );

      // A caller sending the wrong shape is the caller's mistake; a 500 says it
      // was the server's, and every sibling PUT already answers 400.
      final response = await server.handler(
        Request(
          'PUT',
          Uri.parse('http://localhost/api/avatars/$person'),
          headers: {'x-fireraccoon-session': admin.token},
          body: '"just a string"',
        ),
      );

      expect(response.statusCode, 400);
    },
  );

  test('every sensitive route refuses the wrong credential', () async {
    // app_server.dart holds every auth gate in the product and was the least
    // covered file in the repo, which is how one route kept admin access for
    // agent keys while its neighbour refused them.
    final sealed = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
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
    final admin = await repo.login(name: 'Alex', password: 'Password1!');
    final key = await repo.issueAgentKey(
      sessionToken: admin.token,
      label: 'Claude',
    );

    final server = await openTestServer(
      ServerConfig(
        mode: FireraccoonMode.server,
        dataDir: tmp.path,
        dataPassword: 'correct-horse-battery',
        port: 0,
        webRoot: tmp.path,
      ),
    );

    Future<int> status(
      String method,
      String path, {
      String? session,
      Object? body,
    }) async {
      final response = await server.handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          headers: {'x-fireraccoon-session': ?session},
          body: body == null ? null : jsonEncode(body),
        ),
      );
      return response.statusCode;
    }

    const sensitive = [
      ('GET', '/api/state/backup-secrets', null),
      ('PUT', '/api/state/firefly', {'url': 'https://x.test'}),
      ('PUT', '/api/state/people', {'people': <Object?>[]}),
      ('PUT', '/api/state/classifications', {'a': 'b'}),
    ];

    for (final (method, path, body) in sensitive) {
      expect(
        await status(method, path, body: body),
        anyOf(401, 403),
        reason: '$method $path with no credential',
      );
      expect(
        await status(method, path, session: 'not-a-real-token', body: body),
        anyOf(401, 403),
        reason: '$method $path with a bogus token',
      );
      expect(
        await status(method, path, session: key.secret, body: body),
        403,
        reason: '$method $path with an agent key',
      );
      // Not 200: these bodies are placeholders and a handler may reject the
      // shape. What matters is that the admin session gets past the gate,
      // so the guard refuses a credential rather than everything.
      expect(
        await status(method, path, session: admin.token, body: body),
        isNot(anyOf(401, 403)),
        reason: '$method $path with the admin session',
      );
    }

    // Issuing is refused for agent keys too, so one leaked key cannot mint
    // more and outlive its own revocation.
    expect(
      await status(
        'POST',
        '/api/agent-keys',
        session: key.secret,
        body: {'label': 'more'},
      ),
      403,
    );
    // Reading the ledger identity is what an agent key is for.
    expect(await status('GET', '/api/me', session: key.secret), 200);
  });

  test('an admin agent key cannot read the PAT or password hashes', () async {
    final sealed = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
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
    final login = await repo.login(name: 'Alex', password: 'Password1!');
    final issued = await repo.issueAgentKey(
      sessionToken: login.token,
      label: 'Claude',
    );

    final server = await openTestServer(
      ServerConfig(
        mode: FireraccoonMode.server,
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
        headers: {'x-fireraccoon-session': issued.secret},
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
        headers: {'x-fireraccoon-session': issued.secret},
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
        headers: {'x-fireraccoon-session': login.token},
      ),
    );
    expect(asPerson.statusCode, 200);
  });

  test('backup-secrets is admin-only and returns PAT', () async {
    final sealed = await openTestStore(
      dataDirPath: tmp.path,
      password: 'correct-horse-battery',
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
    final login = await repo.login(name: 'Alex', password: 'Password1!');

    final server = await openTestServer(
      ServerConfig(
        mode: FireraccoonMode.server,
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
        headers: {'x-fireraccoon-session': login.token},
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

  test('a header asking for a nonsense count is refused', () async {
    // The header sits next to the ciphertext, so this is not a defence against
    // someone editing it: they already hold the file. What it catches is a count
    // that is nonsense, quietly deriving a weak key and opening as if fine.
    final dir = await Directory.systemTemp.createTemp('fireraccoon-floor');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    await SealedStore.open(
      dataDirPath: dir.path,
      password: 'Store-Password1!',
      iterations: kTestPbkdf2Iterations,
    );

    final headerFile = File(path.join(dir.path, 'store.header'));
    final header =
        jsonDecode(await headerFile.readAsString()) as Map<String, dynamic>;
    header['iterations'] = 1;
    await headerFile.writeAsString(jsonEncode(header));

    await expectLater(
      SealedStore.open(dataDirPath: dir.path, password: 'Store-Password1!'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('below the'),
        ),
      ),
    );
  });
}
