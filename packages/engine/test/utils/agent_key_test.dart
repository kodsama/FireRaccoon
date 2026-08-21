import 'package:fireracoon_engine/utils/agent_key.dart';
import 'package:test/test.dart';

const _person = AgentKeyPerson(id: 'p1', name: 'Ada', role: 'user');

AgentKeyPerson? _lookup(String id) => id == 'p1' ? _person : null;

IssuedAgentKey _issue({
  String personId = 'p1',
  String label = 'Claude Desktop',
  String id = 'k1',
}) {
  return issueAgentKey(
    personId: personId,
    label: label,
    id: id,
    now: DateTime.utc(2026, 1, 2, 3, 4, 5),
  );
}

void main() {
  group('issueAgentKey', () {
    test('tags the secret and records a matching digest', () {
      final issued = _issue();

      expect(issued.secret, startsWith(kAgentKeyTag));
      expect(issued.record.hash, hashAgentKey(issued.secret));
      expect(issued.record.hash, isNot(contains(issued.secret)));
      expect(issued.record.displayPrefix, hasLength(kAgentKeyDisplayLength));
      expect(
        issued.secret,
        contains(issued.record.displayPrefix),
        reason: 'display prefix must identify the key it came from',
      );
    });

    test('mints a distinct secret every call', () {
      final secrets = {for (var i = 0; i < 50; i++) _issue().secret};

      expect(secrets, hasLength(50));
    });

    test('starts active with no usage recorded', () {
      final record = _issue().record;

      expect(record.isActive, isTrue);
      expect(record.revokedAt, isNull);
      expect(record.lastUsedAt, isNull);
    });
  });

  group('resolveAgentKey', () {
    test('grants the bound person identity for a valid secret', () {
      final issued = _issue();

      final identity = resolveAgentKey(
        issued.secret,
        keys: [issued.record],
        person: _lookup,
      );

      expect(identity, isNotNull);
      expect(identity!.keyId, 'k1');
      expect(identity.personId, 'p1');
      expect(identity.personName, 'Ada');
      expect(identity.role, 'user');
    });

    test('tolerates surrounding whitespace from copy-pasted config', () {
      final issued = _issue();

      final identity = resolveAgentKey(
        '  ${issued.secret}\n',
        keys: [issued.record],
        person: _lookup,
      );

      expect(identity, isNotNull);
    });

    test('rejects a revoked key', () {
      final issued = _issue();
      final revoked = issued.record.copyWith(revokedAt: DateTime.utc(2026, 2));

      final identity = resolveAgentKey(
        issued.secret,
        keys: [revoked],
        person: _lookup,
      );

      expect(identity, isNull);
    });

    test('rejects a secret that matches no stored key', () {
      final stored = _issue().record;
      final other = _issue(id: 'k2').secret;

      expect(resolveAgentKey(other, keys: [stored], person: _lookup), isNull);
    });

    test('rejects null, empty, and untagged secrets', () {
      final stored = _issue().record;

      for (final secret in [null, '', 'not-a-key', 'Bearer abc']) {
        expect(
          resolveAgentKey(secret, keys: [stored], person: _lookup),
          isNull,
          reason: 'secret "$secret" must not authenticate',
        );
      }
    });

    test('rejects a key whose person was deleted', () {
      final issued = _issue(personId: 'ghost');

      final identity = resolveAgentKey(
        issued.secret,
        keys: [issued.record],
        person: _lookup,
      );

      expect(identity, isNull);
    });

    test('finds the key regardless of its position in the store', () {
      final target = _issue(id: 'k3');
      final keys = [
        _issue(id: 'k1').record,
        _issue(id: 'k2').record,
        target.record,
      ];

      final identity = resolveAgentKey(
        target.secret,
        keys: keys,
        person: _lookup,
      );

      expect(identity?.keyId, 'k3');
    });
  });

  group('shouldRecordAgentKeyUse', () {
    final at = DateTime.utc(2026, 5, 1, 12);

    test('records the first use', () {
      expect(shouldRecordAgentKeyUse(null, at), isTrue);
    });

    test('skips a use inside the throttle interval', () {
      expect(
        shouldRecordAgentKeyUse(at.subtract(const Duration(seconds: 1)), at),
        isFalse,
      );
      expect(
        shouldRecordAgentKeyUse(
          at.subtract(kAgentKeyUsageInterval - const Duration(seconds: 1)),
          at,
        ),
        isFalse,
      );
    });

    test('records a use once the interval has elapsed', () {
      expect(
        shouldRecordAgentKeyUse(at.subtract(kAgentKeyUsageInterval), at),
        isTrue,
      );
      expect(
        shouldRecordAgentKeyUse(at.subtract(const Duration(hours: 3)), at),
        isTrue,
      );
    });

    test('refuses a stamp that would move backwards', () {
      expect(
        shouldRecordAgentKeyUse(at, at.subtract(const Duration(hours: 1))),
        isFalse,
      );
      expect(shouldRecordAgentKeyUse(at, at), isFalse);
    });
  });

  group('AgentIdentity.canWrite', () {
    test('admins and users write, viewers do not', () {
      AgentIdentity identity(String role) =>
          AgentIdentity(keyId: 'k', personId: 'p', personName: 'n', role: role);

      expect(identity('admin').canWrite, isTrue);
      expect(identity('user').canWrite, isTrue);
      expect(identity('viewer').canWrite, isFalse);
      expect(identity('').canWrite, isFalse);
    });
  });

  group('secret retention', () {
    test('a fresh key carries its secret', () {
      final issued = _issue();

      expect(issued.record.secret, issued.secret);
      expect(issued.record.hash, hashAgentKey(issued.secret));
    });

    test('the full record keeps the secret, the public one drops it', () {
      final issued = _issue();

      expect(issued.record.toJson()['secret'], issued.secret);
      final public = issued.record.toPublicJson();
      expect(public.containsKey('secret'), isFalse);
      expect(public.containsKey('hash'), isFalse);
      expect(public.toString(), isNot(contains(issued.secret)));
    });

    test('copyWith preserves the secret', () {
      final issued = _issue();

      final touched = issued.record.copyWith(lastUsedAt: DateTime.utc(2026, 6));

      expect(touched.secret, issued.secret);
    });

    test('a record with no secret still authenticates', () {
      final issued = _issue();
      final json = issued.record.toJson().cast<String, Object?>()
        ..remove('secret');

      final restored = AgentKey.fromJson(json);

      expect(restored!.secret, isNull);
      expect(
        resolveAgentKey(issued.secret, keys: [restored], person: _lookup),
        isNotNull,
        reason: 'the digest, not the secret, is what authenticates',
      );
    });

    test('an empty stored secret reads back as absent', () {
      final issued = _issue();
      final json = issued.record.toJson().cast<String, Object?>()
        ..['secret'] = '';

      expect(AgentKey.fromJson(json)!.secret, isNull);
    });
  });

  group('serialization', () {
    test('round-trips through toJson/fromJson', () {
      final record = _issue().record.copyWith(
        lastUsedAt: DateTime.utc(2026, 3, 4),
      );

      final restored = AgentKey.fromJson(
        record.toJson().cast<String, Object?>(),
      );

      expect(restored, isNotNull);
      expect(restored!.id, record.id);
      expect(restored.personId, record.personId);
      expect(restored.label, record.label);
      expect(restored.hash, record.hash);
      expect(restored.displayPrefix, record.displayPrefix);
      expect(restored.createdAt, record.createdAt);
      expect(restored.lastUsedAt, record.lastUsedAt);
      expect(restored.revokedAt, isNull);
    });

    test('a restored record still authenticates its original secret', () {
      final issued = _issue();

      final restored = AgentKey.fromJson(
        issued.record.toJson().cast<String, Object?>(),
      );

      expect(
        resolveAgentKey(issued.secret, keys: [restored!], person: _lookup),
        isNotNull,
      );
    });

    test('fromJson returns null on records missing required fields', () {
      for (final json in <Map<String, Object?>>[
        {'personId': 'p1', 'hash': 'h', 'createdAt': '2026-01-01T00:00:00Z'},
        {'id': 'k1', 'hash': 'h', 'createdAt': '2026-01-01T00:00:00Z'},
        {'id': 'k1', 'personId': 'p1', 'createdAt': '2026-01-01T00:00:00Z'},
        {'id': 'k1', 'personId': 'p1', 'hash': 'h'},
        {'id': 'k1', 'personId': 'p1', 'hash': 'h', 'createdAt': 'nonsense'},
      ]) {
        expect(AgentKey.fromJson(json), isNull, reason: '$json');
      }
    });

    test('public json omits the digest', () {
      final public = _issue().record.toPublicJson();

      expect(public.containsKey('hash'), isFalse);
      expect(public['displayPrefix'], isNotEmpty);
      expect(public['active'], isTrue);
    });
  });
}
