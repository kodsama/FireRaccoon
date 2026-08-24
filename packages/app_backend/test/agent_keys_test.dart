import 'dart:convert';
import 'dart:io';

import 'package:fireracoon_app_backend/fireracoon_app_backend.dart';
import 'package:fireracoon_engine/utils/agent_key.dart' as keys;
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
    tmp = await Directory.systemTemp.createTemp('fireracoon_keys_');
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
      mode: FireracoonMode.server,
      dataDir: tmp.path,
      dataPassword: _password,
      port: 0,
      webRoot: tmp.path,
    ),
  );

  group('StateRepository agent keys', () {
    test('an issued key authenticates as its person', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');

      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Desktop',
      );

      final identity = repo.identityForAgentKey(issued.secret);
      expect(identity, isNotNull);
      expect(identity!.personName, 'Alex');
      expect(identity.role, 'admin');
      expect(identity.canWrite, isTrue);
      expect(repo.personForSession(issued.secret)?['name'], 'Alex');
      expect(repo.canWrite(issued.secret), isTrue);
      expect(repo.isAdmin(issued.secret), isTrue);
    });

    test('the secret is retained but never written in the clear', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Desktop',
      );

      // Kept so its owner can read it back, but the file on disk is sealed.
      expect(repo.state.agentKeys.single['secret'], issued.secret);
      final onDisk = await File('${tmp.path}/state.enc').readAsString();
      expect(
        onDisk.contains(issued.secret),
        isFalse,
        reason: 'the sealed store must not leak the secret as plaintext',
      );
      // The digest is still what authentication compares against.
      expect(
        repo.state.agentKeys.single['hash'],
        keys.hashAgentKey(issued.secret),
      );
    });

    test('a listing never carries the secret or the digest', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Desktop',
      );

      final listed = repo.agentKeysFor(login.token).single;

      expect(listed.containsKey('secret'), isFalse);
      expect(listed.containsKey('hash'), isFalse);
      expect(listed.toString(), isNot(contains(issued.secret)));
    });

    test('an owner can read their own secret back', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Desktop',
      );

      expect(
        repo.agentKeySecret(
          sessionToken: login.token,
          keyId: issued.key['id'] as String,
        ),
        issued.secret,
      );
    });

    test('an admin cannot read another person\'s secret', () async {
      final repo = await repository();
      final adminLogin = await repo.login(name: 'Alex', password: 'Password1!');
      await repo.replacePeopleConfig(
        people: [
          _person(adminLogin.person['id'] as String, 'Alex', role: 'admin'),
          _person('person_sam', 'Sam'),
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
        passwordUpdates: const {'person_sam': 'Password2!'},
      );
      final samLogin = await repo.login(name: 'Sam', password: 'Password2!');
      final samKey = await repo.issueAgentKey(
        sessionToken: samLogin.token,
        label: 'sam agent',
      );

      // Administering someone does not extend to reading their credentials.
      expect(
        repo.agentKeySecret(
          sessionToken: adminLogin.token,
          keyId: samKey.key['id'] as String,
        ),
        isNull,
      );
      expect(repo.isAdmin(adminLogin.token), isTrue);
    });

    test('an agent key cannot read any secret, including its own', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Desktop',
      );

      // Otherwise one leaked key enumerates the rest of its person's keys.
      expect(
        repo.agentKeySecret(
          sessionToken: issued.secret,
          keyId: issued.key['id'] as String,
        ),
        isNull,
      );
    });

    test('reading a secret refuses unknown keys and unknown callers', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Desktop',
      );

      expect(
        repo.agentKeySecret(sessionToken: login.token, keyId: 'nope'),
        isNull,
      );
      expect(
        repo.agentKeySecret(
          sessionToken: null,
          keyId: issued.key['id'] as String,
        ),
        isNull,
      );
    });

    test('a key stored without a secret cannot be revealed', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'legacy',
      );

      // Simulates a record written before secrets were retained.
      repo.state.agentKeys.single.remove('secret');
      await repo.save();

      expect(
        repo.agentKeySecret(
          sessionToken: login.token,
          keyId: issued.key['id'] as String,
        ),
        isNull,
      );
      // It must still authenticate: the digest is untouched.
      expect(repo.identityForAgentKey(issued.secret), isNotNull);
    });

    test('key material stays out of the admin settings backup', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Desktop',
      );

      final secrets = repo.backupSecretsForAdmin().toString();

      expect(secrets, isNot(contains(issued.secret)));
      expect(secrets, isNot(contains(keys.hashAgentKey(issued.secret))));
      expect(secrets, isNot(contains(issued.key['id'] as String)));
    });

    test('key material stays out of the client state snapshot', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Desktop',
      );

      final snapshot = repo
          .snapshotForClient(sessionToken: login.token)
          .toString();

      expect(snapshot, isNot(contains(issued.secret)));
      expect(snapshot, isNot(contains(keys.hashAgentKey(issued.secret))));
    });

    test('a viewer key resolves without write access', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      await repo.replacePeopleConfig(
        people: [
          _person(login.person['id'] as String, 'Alex', role: 'admin'),
          _person('person_val', 'Val', role: 'viewer'),
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
        passwordUpdates: const {'person_val': 'Password2!'},
      );
      final valLogin = await repo.login(name: 'Val', password: 'Password2!');

      final issued = await repo.issueAgentKey(
        sessionToken: valLogin.token,
        label: 'read-only agent',
      );

      expect(repo.identityForAgentKey(issued.secret)!.canWrite, isFalse);
      expect(repo.canWrite(issued.secret), isFalse);
    });

    test('a revoked key stops resolving', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'temporary',
      );
      final keyId = issued.key['id'] as String;

      final revoked = await repo.revokeAgentKey(
        sessionToken: login.token,
        keyId: keyId,
      );

      expect(revoked, isTrue);
      expect(repo.identityForAgentKey(issued.secret), isNull);
      expect(repo.personForSession(issued.secret), isNull);
    });

    test('revocation survives a reload', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'temporary',
      );
      await repo.revokeAgentKey(
        sessionToken: login.token,
        keyId: issued.key['id'] as String,
      );

      final reopened = StateRepository(
        await openTestStore(dataDirPath: tmp.path, password: _password),
      );
      await reopened.load();

      expect(reopened.identityForAgentKey(issued.secret), isNull);
    });

    test('a key survives a reload when it was not revoked', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'persistent',
      );

      final reopened = StateRepository(
        await openTestStore(dataDirPath: tmp.path, password: _password),
      );
      await reopened.load();

      expect(reopened.identityForAgentKey(issued.secret)?.personName, 'Alex');
    });

    test('a non-admin cannot revoke someone else\'s key', () async {
      final repo = await repository();
      final adminLogin = await repo.login(name: 'Alex', password: 'Password1!');
      await repo.replacePeopleConfig(
        people: [
          _person(adminLogin.person['id'] as String, 'Alex', role: 'admin'),
          _person('person_sam', 'Sam'),
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
        passwordUpdates: const {'person_sam': 'Password2!'},
      );
      final samLogin = await repo.login(name: 'Sam', password: 'Password2!');
      final adminKey = await repo.issueAgentKey(
        sessionToken: adminLogin.token,
        label: 'admin agent',
      );

      final revoked = await repo.revokeAgentKey(
        sessionToken: samLogin.token,
        keyId: adminKey.key['id'] as String,
      );

      expect(revoked, isFalse);
      expect(repo.identityForAgentKey(adminKey.secret), isNotNull);
    });

    test('an admin can revoke anyone\'s key', () async {
      final repo = await repository();
      final adminLogin = await repo.login(name: 'Alex', password: 'Password1!');
      await repo.replacePeopleConfig(
        people: [
          _person(adminLogin.person['id'] as String, 'Alex', role: 'admin'),
          _person('person_sam', 'Sam'),
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
        passwordUpdates: const {'person_sam': 'Password2!'},
      );
      final samLogin = await repo.login(name: 'Sam', password: 'Password2!');
      final samKey = await repo.issueAgentKey(
        sessionToken: samLogin.token,
        label: 'sam agent',
      );

      final revoked = await repo.revokeAgentKey(
        sessionToken: adminLogin.token,
        keyId: samKey.key['id'] as String,
      );

      expect(revoked, isTrue);
      expect(repo.identityForAgentKey(samKey.secret), isNull);
    });

    test('listing scopes to the caller unless they are admin', () async {
      final repo = await repository();
      final adminLogin = await repo.login(name: 'Alex', password: 'Password1!');
      await repo.replacePeopleConfig(
        people: [
          _person(adminLogin.person['id'] as String, 'Alex', role: 'admin'),
          _person('person_sam', 'Sam'),
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
        passwordUpdates: const {'person_sam': 'Password2!'},
      );
      final samLogin = await repo.login(name: 'Sam', password: 'Password2!');
      await repo.issueAgentKey(
        sessionToken: adminLogin.token,
        label: 'admin agent',
      );
      await repo.issueAgentKey(
        sessionToken: samLogin.token,
        label: 'sam agent',
      );

      expect(repo.agentKeysFor(adminLogin.token), hasLength(2));
      final samKeys = repo.agentKeysFor(samLogin.token);
      expect(samKeys, hasLength(1));
      expect(samKeys.single['label'], 'sam agent');
      expect(samKeys.single.containsKey('hash'), isFalse);
    });

    test(
      'an unauthenticated caller lists nothing and issues nothing',
      () async {
        final repo = await repository();

        expect(repo.agentKeysFor(null), isEmpty);
        expect(repo.agentKeysFor('frcn_not-a-key'), isEmpty);
        await expectLater(
          repo.issueAgentKey(sessionToken: null, label: 'nope'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('an empty label is refused', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');

      await expectLater(
        repo.issueAgentKey(sessionToken: login.token, label: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('touchAgentKey records the first use', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'Claude Desktop',
      );
      expect(repo.agentKeysFor(login.token).single['lastUsedAt'], isNull);

      final at = DateTime.utc(2026, 5, 1, 12);
      await repo.touchAgentKey(issued.secret, now: at);

      expect(
        repo.agentKeysFor(login.token).single['lastUsedAt'],
        at.toIso8601String(),
      );
    });

    test('touchAgentKey throttles writes inside the interval', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'chatty agent',
      );
      final first = DateTime.utc(2026, 5, 1, 12);
      await repo.touchAgentKey(issued.secret, now: first);

      await repo.touchAgentKey(
        issued.secret,
        now: first.add(const Duration(seconds: 5)),
      );

      expect(
        repo.agentKeysFor(login.token).single['lastUsedAt'],
        first.toIso8601String(),
      );
    });

    test('touchAgentKey advances once the interval elapses', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'agent',
      );
      final first = DateTime.utc(2026, 5, 1, 12);
      await repo.touchAgentKey(issued.secret, now: first);

      final later = first.add(const Duration(hours: 2));
      await repo.touchAgentKey(issued.secret, now: later);

      expect(
        repo.agentKeysFor(login.token).single['lastUsedAt'],
        later.toIso8601String(),
      );
    });

    test('a recorded use survives a reload', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'agent',
      );
      final at = DateTime.utc(2026, 5, 1, 12);
      await repo.touchAgentKey(issued.secret, now: at);

      final reopened = StateRepository(
        await openTestStore(dataDirPath: tmp.path, password: _password),
      );
      await reopened.load();

      expect(
        reopened.state.agentKeys.single['lastUsedAt'],
        at.toIso8601String(),
      );
    });

    test(
      'touchAgentKey ignores a session token, unknown and revoked keys',
      () async {
        final repo = await repository();
        final login = await repo.login(name: 'Alex', password: 'Password1!');
        final issued = await repo.issueAgentKey(
          sessionToken: login.token,
          label: 'agent',
        );
        final at = DateTime.utc(2026, 5, 1, 12);

        await repo.touchAgentKey(null, now: at);
        await repo.touchAgentKey(login.token, now: at);
        await repo.touchAgentKey('frcn_made-up', now: at);
        expect(repo.agentKeysFor(login.token).single['lastUsedAt'], isNull);

        await repo.revokeAgentKey(
          sessionToken: login.token,
          keyId: issued.key['id'] as String,
        );
        await repo.touchAgentKey(issued.secret, now: at);

        expect(repo.agentKeysFor(login.token).single['lastUsedAt'], isNull);
      },
    );

    test('forgetAgentKey drops a revoked record', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'discard',
      );
      final keyId = issued.key['id'] as String;
      await repo.revokeAgentKey(sessionToken: login.token, keyId: keyId);

      final forgotten = await repo.forgetAgentKey(
        sessionToken: login.token,
        keyId: keyId,
      );

      expect(forgotten, isTrue);
      expect(repo.state.agentKeys, isEmpty);
      expect(repo.agentKeysFor(login.token), isEmpty);
    });

    test('forgetAgentKey refuses a key that is still live', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'live',
      );

      final forgotten = await repo.forgetAgentKey(
        sessionToken: login.token,
        keyId: issued.key['id'] as String,
      );

      expect(forgotten, isFalse);
      expect(repo.identityForAgentKey(issued.secret), isNotNull);
    });

    test('a non-admin cannot forget someone else\'s key', () async {
      final repo = await repository();
      final adminLogin = await repo.login(name: 'Alex', password: 'Password1!');
      await repo.replacePeopleConfig(
        people: [
          _person(adminLogin.person['id'] as String, 'Alex', role: 'admin'),
          _person('person_sam', 'Sam'),
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
        passwordUpdates: const {'person_sam': 'Password2!'},
      );
      final samLogin = await repo.login(name: 'Sam', password: 'Password2!');
      final adminKey = await repo.issueAgentKey(
        sessionToken: adminLogin.token,
        label: 'admin agent',
      );
      final keyId = adminKey.key['id'] as String;
      await repo.revokeAgentKey(sessionToken: adminLogin.token, keyId: keyId);

      expect(
        await repo.forgetAgentKey(sessionToken: samLogin.token, keyId: keyId),
        isFalse,
      );
      expect(repo.state.agentKeys, hasLength(1));
    });

    test('forgetting refuses unknown keys and unknown callers', () async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      final issued = await repo.issueAgentKey(
        sessionToken: login.token,
        label: 'discard',
      );
      final keyId = issued.key['id'] as String;
      await repo.revokeAgentKey(sessionToken: login.token, keyId: keyId);

      expect(
        await repo.forgetAgentKey(sessionToken: login.token, keyId: 'nope'),
        isFalse,
      );
      expect(
        await repo.forgetAgentKey(sessionToken: null, keyId: keyId),
        isFalse,
      );
      expect(repo.state.agentKeys, hasLength(1));
    });

    test('deleting a person prunes their keys', () async {
      final repo = await repository();
      final adminLogin = await repo.login(name: 'Alex', password: 'Password1!');
      await repo.replacePeopleConfig(
        people: [
          _person(adminLogin.person['id'] as String, 'Alex', role: 'admin'),
          _person('person_sam', 'Sam'),
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
        passwordUpdates: const {'person_sam': 'Password2!'},
      );
      final samLogin = await repo.login(name: 'Sam', password: 'Password2!');
      final samKey = await repo.issueAgentKey(
        sessionToken: samLogin.token,
        label: 'sam agent',
      );

      await repo.replacePeopleConfig(
        people: [
          _person(adminLogin.person['id'] as String, 'Alex', role: 'admin'),
        ],
        accountOwnerships: const [],
        requirePasswordLogin: true,
      );
      await repo.pruneAgentKeys();

      expect(repo.state.agentKeys, isEmpty);
      expect(repo.identityForAgentKey(samKey.secret), isNull);
    });
  });

  group('agent key HTTP surface', () {
    Future<({AppServer server, String session})> ready() async {
      final repo = await repository();
      final login = await repo.login(name: 'Alex', password: 'Password1!');
      return (server: await server(), session: login.token);
    }

    Future<Map<String, dynamic>> body(Response response) async =>
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;

    test('POST issues a key and returns the secret exactly once', () async {
      final (server: app, session: session) = await ready();

      final created = await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/agent-keys'),
          body: jsonEncode({'label': 'Claude Desktop'}),
          headers: {
            'content-type': 'application/json',
            'x-fireracoon-session': session,
          },
        ),
      );
      expect(created.statusCode, 201);
      final createdBody = await body(created);
      final secret = createdBody['secret'] as String;
      expect(secret, startsWith('frcn_'));
      expect((createdBody['key'] as Map).containsKey('hash'), isFalse);

      final listed = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/agent-keys'),
          headers: {'x-fireracoon-session': session},
        ),
      );
      final keys = (await body(listed))['keys'] as List<Object?>;
      expect(keys, hasLength(1));
      expect(
        (keys.single as Map<String, dynamic>).containsKey('secret'),
        isFalse,
      );
    });

    test('the key works as a Bearer on /api/me', () async {
      final (server: app, session: session) = await ready();
      final created = await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/agent-keys'),
          body: jsonEncode({'label': 'Claude Desktop'}),
          headers: {
            'content-type': 'application/json',
            'x-fireracoon-session': session,
          },
        ),
      );
      final createdBody = await body(created);
      final secret = createdBody['secret'] as String;

      final me = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'authorization': 'Bearer $secret'},
        ),
      );

      expect(me.statusCode, 200);
      final meBody = await body(me);
      expect((meBody['person'] as Map)['name'], 'Alex');
      expect(meBody['agentKeyId'], (createdBody['key'] as Map)['id']);
    });

    test('an unknown key is rejected on /api/me', () async {
      final (server: app, session: _) = await ready();

      final me = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'authorization': 'Bearer frcn_totally-made-up'},
        ),
      );

      expect(me.statusCode, 401);
    });

    test('a revoked key is rejected on /api/me', () async {
      final (server: app, session: session) = await ready();
      final created = await body(
        await app.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/agent-keys'),
            body: jsonEncode({'label': 'temporary'}),
            headers: {
              'content-type': 'application/json',
              'x-fireracoon-session': session,
            },
          ),
        ),
      );
      final secret = created['secret'] as String;
      final keyId = (created['key'] as Map)['id'];

      final revoke = await app.handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/agent-keys/$keyId'),
          headers: {'x-fireracoon-session': session},
        ),
      );
      expect(revoke.statusCode, 200);

      final me = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'authorization': 'Bearer $secret'},
        ),
      );
      expect(me.statusCode, 401);
    });

    test('revoking an unknown key is a 404', () async {
      final (server: app, session: session) = await ready();

      final revoke = await app.handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/agent-keys/nope'),
          headers: {'x-fireracoon-session': session},
        ),
      );

      expect(revoke.statusCode, 404);
    });

    test('an agent key cannot mint more agent keys', () async {
      final (server: app, session: session) = await ready();
      final created = await body(
        await app.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/agent-keys'),
            body: jsonEncode({'label': 'first'}),
            headers: {
              'content-type': 'application/json',
              'x-fireracoon-session': session,
            },
          ),
        ),
      );

      final escalation = await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/agent-keys'),
          body: jsonEncode({'label': 'second'}),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer ${created['secret']}',
          },
        ),
      );

      expect(escalation.statusCode, 403);
    });

    test('listing and issuing require authentication', () async {
      final (server: app, session: _) = await ready();

      final listed = await app.handler(
        Request('GET', Uri.parse('http://localhost/api/agent-keys')),
      );
      expect(listed.statusCode, 401);

      final created = await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/agent-keys'),
          body: jsonEncode({'label': 'nope'}),
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(created.statusCode, 401);
    });

    test('using a key over HTTP stamps lastUsedAt', () async {
      final (server: app, session: session) = await ready();
      final created = await body(
        await app.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/agent-keys'),
            body: jsonEncode({'label': 'Claude Desktop'}),
            headers: {
              'content-type': 'application/json',
              'x-fireracoon-session': session,
            },
          ),
        ),
      );
      final secret = created['secret'] as String;
      final keyId = (created['key'] as Map)['id'];
      expect((created['key'] as Map)['lastUsedAt'], isNull);

      await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'authorization': 'Bearer $secret'},
        ),
      );

      final listed = await body(
        await app.handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/agent-keys'),
            headers: {'x-fireracoon-session': session},
          ),
        ),
      );
      final key = (listed['keys'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((k) => k['id'] == keyId);
      expect(key['lastUsedAt'], isNotNull);
      expect(
        DateTime.parse(key['lastUsedAt'] as String).isAfter(
          DateTime.parse(
            key['createdAt'] as String,
          ).subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('a session-authenticated request stamps nothing', () async {
      final (server: app, session: session) = await ready();
      final created = await body(
        await app.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/agent-keys'),
            body: jsonEncode({'label': 'unused agent'}),
            headers: {
              'content-type': 'application/json',
              'x-fireracoon-session': session,
            },
          ),
        ),
      );

      await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'x-fireracoon-session': session},
        ),
      );

      final listed = await body(
        await app.handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/agent-keys'),
            headers: {'x-fireracoon-session': session},
          ),
        ),
      );
      expect((listed['keys'] as List).single['lastUsedAt'], isNull);
      expect((created['key'] as Map)['lastUsedAt'], isNull);
    });

    test('a rejected key leaves no usage trace', () async {
      final (server: app, session: session) = await ready();
      final created = await body(
        await app.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/agent-keys'),
            body: jsonEncode({'label': 'revoked agent'}),
            headers: {
              'content-type': 'application/json',
              'x-fireracoon-session': session,
            },
          ),
        ),
      );
      final secret = created['secret'] as String;
      await app.handler(
        Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/agent-keys/${(created['key'] as Map)['id']}',
          ),
          headers: {'x-fireracoon-session': session},
        ),
      );

      await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/me'),
          headers: {'authorization': 'Bearer $secret'},
        ),
      );

      final listed = await body(
        await app.handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/agent-keys'),
            headers: {'x-fireracoon-session': session},
          ),
        ),
      );
      expect((listed['keys'] as List).single['lastUsedAt'], isNull);
    });

    test('an owner can GET their secret back', () async {
      final (server: app, session: session) = await ready();
      final created = await body(
        await app.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/agent-keys'),
            body: jsonEncode({'label': 'Claude Desktop'}),
            headers: {
              'content-type': 'application/json',
              'x-fireracoon-session': session,
            },
          ),
        ),
      );
      final keyId = (created['key'] as Map)['id'];

      final revealed = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/agent-keys/$keyId/secret'),
          headers: {'x-fireracoon-session': session},
        ),
      );

      expect(revealed.statusCode, 200);
      expect((await body(revealed))['secret'], created['secret']);
    });

    test('an agent key cannot GET a secret', () async {
      final (server: app, session: session) = await ready();
      final created = await body(
        await app.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/agent-keys'),
            body: jsonEncode({'label': 'Claude Desktop'}),
            headers: {
              'content-type': 'application/json',
              'x-fireracoon-session': session,
            },
          ),
        ),
      );
      final keyId = (created['key'] as Map)['id'];

      final revealed = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/agent-keys/$keyId/secret'),
          headers: {'authorization': 'Bearer ${created['secret']}'},
        ),
      );

      expect(revealed.statusCode, 404);
    });

    test('reading a secret requires a session', () async {
      final (server: app, session: session) = await ready();
      final created = await body(
        await app.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/agent-keys'),
            body: jsonEncode({'label': 'Claude Desktop'}),
            headers: {
              'content-type': 'application/json',
              'x-fireracoon-session': session,
            },
          ),
        ),
      );
      final keyId = (created['key'] as Map)['id'];

      final revealed = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/agent-keys/$keyId/secret'),
        ),
      );

      expect(revealed.statusCode, 401);
    });

    test('an unknown key id reveals nothing', () async {
      final (server: app, session: session) = await ready();

      final revealed = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/agent-keys/nope/secret'),
          headers: {'x-fireracoon-session': session},
        ),
      );

      expect(revealed.statusCode, 404);
    });

    test('DELETE on the record clears a revoked key', () async {
      final (server: app, session: session) = await ready();
      final created = await body(
        await app.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/api/agent-keys'),
            body: jsonEncode({'label': 'discard'}),
            headers: {
              'content-type': 'application/json',
              'x-fireracoon-session': session,
            },
          ),
        ),
      );
      final keyId = (created['key'] as Map)['id'];

      // Live keys are not forgettable: revoking is the separate first step.
      final tooSoon = await app.handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/agent-keys/$keyId/record'),
          headers: {'x-fireracoon-session': session},
        ),
      );
      expect(tooSoon.statusCode, 404);

      await app.handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/agent-keys/$keyId'),
          headers: {'x-fireracoon-session': session},
        ),
      );
      final forgotten = await app.handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/agent-keys/$keyId/record'),
          headers: {'x-fireracoon-session': session},
        ),
      );

      expect(forgotten.statusCode, 200);
      expect((await body(forgotten))['keys'], isEmpty);
    });

    test('forgetting a record requires a session', () async {
      final (server: app, session: _) = await ready();

      final forgotten = await app.handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/agent-keys/whatever/record'),
        ),
      );

      expect(forgotten.statusCode, 401);
    });

    test('an empty label is a 400', () async {
      final (server: app, session: session) = await ready();

      final created = await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/agent-keys'),
          body: jsonEncode({'label': ''}),
          headers: {
            'content-type': 'application/json',
            'x-fireracoon-session': session,
          },
        ),
      );

      expect(created.statusCode, 400);
    });
  });
}
