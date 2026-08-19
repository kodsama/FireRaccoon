import 'dart:convert';

import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon_mcp/fireracoon_mcp.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

AgentKey _key({
  required String personId,
  String id = 'key-1',
  String secret = 'frcn_secret',
  DateTime? revokedAt,
}) => AgentKey(
  id: id,
  personId: personId,
  label: 'laptop',
  hash: hashAgentKey(secret),
  displayPrefix: secret.substring(0, kAgentKeyDisplayLength),
  createdAt: DateTime(2026, 1, 1),
  revokedAt: revokedAt,
);

const _alex = AgentKeyPerson(id: 'p1', name: 'Ada', role: 'admin');

void main() {
  group('SnapshotAuthenticator', () {
    test('resolves a live key to its person', () async {
      final auth = SnapshotAuthenticator(
        keys: [_key(personId: 'p1')],
        people: const [_alex],
      );

      final identity = await auth.authenticate('frcn_secret');

      expect(identity, isNotNull);
      expect(identity!.personName, 'Ada');
      expect(identity.role, 'admin');
      expect(identity.canWrite, isTrue);
    });

    test('refuses a revoked key', () async {
      final auth = SnapshotAuthenticator(
        keys: [_key(personId: 'p1', revokedAt: DateTime(2026, 2, 1))],
        people: const [_alex],
      );

      expect(await auth.authenticate('frcn_secret'), isNull);
    });

    test('refuses a key whose person is gone', () async {
      // A key outliving its owner would otherwise authenticate as nobody and
      // fall through to the default role.
      final auth = SnapshotAuthenticator(
        keys: [_key(personId: 'deleted')],
        people: const [_alex],
      );

      expect(await auth.authenticate('frcn_secret'), isNull);
    });

    test('refuses an unknown secret', () async {
      final auth = SnapshotAuthenticator(
        keys: [_key(personId: 'p1')],
        people: const [_alex],
      );

      expect(await auth.authenticate('frcn_wrong'), isNull);
      expect(await auth.authenticate(''), isNull);
    });

    test('a viewer resolves without write access', () async {
      final auth = SnapshotAuthenticator(
        keys: [_key(personId: 'p2')],
        people: const [AgentKeyPerson(id: 'p2', name: 'Guest', role: 'viewer')],
      );

      final identity = await auth.authenticate('frcn_secret');

      expect(identity!.canWrite, isFalse);
    });
  });

  group('FixedIdentityAuthenticator', () {
    test('accepts whatever it is given', () async {
      // Stdio's trust boundary is the process: the client was handed the key in
      // its own environment, so re-challenging it proves nothing.
      const identity = AgentIdentity(
        keyId: 'k',
        personId: 'p1',
        personName: 'Ada',
        role: 'admin',
      );
      const auth = FixedIdentityAuthenticator(identity);

      expect(await auth.authenticate('anything'), same(identity));
      expect(await auth.authenticate(''), same(identity));
    });
  });

  group('BackendAuthenticator', () {
    BackendAuthenticator withResponse(
      http.Response response, {
      List<http.Request>? record,
      String baseUrl = 'https://fireracoon.test',
    }) => BackendAuthenticator(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        record?.add(request);
        return response;
      }),
    );

    test('resolves the person the backend reports', () async {
      final requests = <http.Request>[];
      final auth = withResponse(
        http.Response(
          jsonEncode({
            'agentKeyId': 'key-9',
            'person': {'id': 'p1', 'name': 'Ada', 'role': 'admin'},
          }),
          200,
        ),
        record: requests,
      );

      final identity = await auth.authenticate('  frcn_secret  ');

      expect(identity!.personId, 'p1');
      expect(identity.keyId, 'key-9');
      expect(identity.role, 'admin');
      // The key is trimmed before it becomes a bearer, or a pasted trailing
      // newline reads as a different key.
      expect(requests.single.headers['Authorization'], 'Bearer frcn_secret');
      expect(requests.single.url.path, '/api/me');
    });

    test('trims a trailing slash off the base URL', () {
      final auth = BackendAuthenticator(baseUrl: 'https://fireracoon.test/');

      expect(auth.baseUrl, 'https://fireracoon.test');
      expect(auth.fireflyProxyBase, 'https://fireracoon.test/api/firefly');
    });

    test('defaults an unnamed role to viewer', () async {
      // Read-only is the safe default when the backend omits the role.
      final auth = withResponse(
        http.Response(
          jsonEncode({
            'person': {'id': 'p1'},
          }),
          200,
        ),
      );

      final identity = await auth.authenticate('frcn_secret');

      expect(identity!.role, 'viewer');
      expect(identity.canWrite, isFalse);
      expect(identity.personName, '');
    });

    test('refuses a non-200', () async {
      final auth = withResponse(http.Response('nope', 401));

      expect(await auth.authenticate('frcn_secret'), isNull);
    });

    test('refuses a body that is not JSON', () async {
      final auth = withResponse(http.Response('<html>down</html>', 200));

      expect(await auth.authenticate('frcn_secret'), isNull);
    });

    test('refuses JSON that is not an object', () async {
      final auth = withResponse(http.Response('["nope"]', 200));

      expect(await auth.authenticate('frcn_secret'), isNull);
    });

    test('refuses a body with no person', () async {
      final auth = withResponse(http.Response(jsonEncode({'ok': true}), 200));

      expect(await auth.authenticate('frcn_secret'), isNull);
    });

    test('refuses a person with no id', () async {
      final auth = withResponse(
        http.Response(
          jsonEncode({
            'person': {'name': 'Nameless'},
          }),
          200,
        ),
      );

      expect(await auth.authenticate('frcn_secret'), isNull);
    });

    test('refuses when the backend is unreachable', () async {
      // A backend that is down must not authenticate anyone.
      final auth = BackendAuthenticator(
        baseUrl: 'https://fireracoon.test',
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );

      expect(await auth.authenticate('frcn_secret'), isNull);
    });
  });

  group('extractAgentKey', () {
    test('reads every documented placement', () {
      expect(extractAgentKey({'apiKey': 'a'}), 'a');
      expect(extractAgentKey({'api_key': 'b'}), 'b');
      expect(
        extractAgentKey({
          'authentication': {'token': 'c'},
        }),
        'c',
      );
      expect(
        extractAgentKey({
          'authentication': {'apiKey': 'd'},
        }),
        'd',
      );
      expect(
        extractAgentKey({
          'authentication': {'api_key': 'e'},
        }),
        'e',
      );
    });

    test('prefers the top-level key over the nested one', () {
      expect(
        extractAgentKey({
          'apiKey': 'top',
          'authentication': {'token': 'nested'},
        }),
        'top',
      );
    });

    test('returns null when there is no key to find', () {
      expect(extractAgentKey({}), isNull);
      expect(extractAgentKey({'apiKey': ''}), isNull);
      expect(extractAgentKey({'apiKey': 42}), isNull);
      expect(extractAgentKey({'authentication': 'bearer xyz'}), isNull);
      expect(
        extractAgentKey({
          'authentication': {'token': 7},
        }),
        isNull,
      );
    });
  });
}

/// Stands in for a transport failure without depending on dart:io in a test
/// that otherwise needs none.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
