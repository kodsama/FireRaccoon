import 'dart:convert';

import 'package:fireracoon/deployment/deployment_providers.dart';
import 'package:fireracoon/deployment/fireracoon_mode.dart';
import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/providers/agent_keys_provider.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/people_providers.dart';
import 'package:fireracoon/providers/server_session_provider.dart';
import 'package:fireracoon/store/agent_key_store.dart';
import 'package:fireracoon/store/remote_server_client.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/static_people_notifier.dart';

Person _person(String id, String name, PersonRole role) =>
    testPerson(id, name, role: role);

/// Stands in for a server session that never reached the backend, so it holds no
/// client. Settings still renders the agent keys panel in that state.
class _UnreachableServerSession extends ServerSessionNotifier {
  @override
  Future<ServerSession?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStorage;

  setUp(() {
    secureStorage = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureStorage,
    );
  });

  ProviderContainer containerFor(List<Person> people) {
    final container = ProviderContainer(
      overrides: [
        peopleProvider.overrideWith(() => StaticPeopleNotifier(people)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AgentKeyStore', () {
    test('round-trips keys through secure storage', () async {
      final store = AgentKeyStore();
      final issued = issueAgentKey(
        personId: 'p1',
        label: 'Claude',
        id: 'k1',
        now: DateTime.utc(2026),
      );

      await store.save([issued.record]);
      final loaded = await store.load();

      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'k1');
      expect(loaded.single.hash, issued.record.hash);
    });

    test('stores the secret so its owner can read it back', () async {
      final store = AgentKeyStore();
      final issued = issueAgentKey(
        personId: 'p1',
        label: 'Claude',
        id: 'k1',
        now: DateTime.utc(2026),
      );

      await store.save([issued.record]);

      // The keychain is what protects this, and it already holds the Firefly
      // PAT, which grants strictly more than any agent key.
      expect(secureStorage[kAgentKeysStorageKey], contains(issued.secret));
      expect((await store.load()).single.secret, issued.secret);
    });

    test('survives corrupt or absent storage', () async {
      final store = AgentKeyStore();
      expect(await store.load(), isEmpty);

      secureStorage[kAgentKeysStorageKey] = 'not json';
      expect(await store.load(), isEmpty);

      secureStorage[kAgentKeysStorageKey] = '{"not":"a list"}';
      expect(await store.load(), isEmpty);

      secureStorage[kAgentKeysStorageKey] = '[{"id":"k1"}]';
      expect(await store.load(), isEmpty);
    });

    test('clear removes the keychain entry, not just its contents', () async {
      final store = AgentKeyStore();
      final issued = issueAgentKey(
        personId: 'p1',
        label: 'Claude',
        id: 'k1',
        now: DateTime.utc(2026),
      );
      await store.save([issued.record]);

      await store.clear();

      // Overwriting with an empty list would leave the slot behind; the secret
      // has to be gone from the keychain, not merely unreachable through load().
      expect(secureStorage.containsKey(kAgentKeysStorageKey), isFalse);
      expect(await store.load(), isEmpty);

      // Clearing again on an already empty store must stay quiet.
      await store.clear();
      expect(await store.load(), isEmpty);
    });
  });

  group('describeAgentKeyFailure', () {
    test('keeps the platform status code, which names the cause', () {
      // -34018 is a missing entitlement and -25300 a missing item; the app
      // logger records an error's type but never its text, so without the code
      // the reader is left guessing at the point they need to act.
      expect(
        describeAgentKeyFailure(
          PlatformException(code: '-34018', message: 'A required entitlement'),
        ),
        'Keychain error -34018: A required entitlement',
      );
    });

    test('a platform error with no message still reports its code', () {
      expect(
        describeAgentKeyFailure(PlatformException(code: '-25300')),
        'Keychain error -25300',
      );
    });

    test('anything else is reported as it prints', () {
      expect(
        describeAgentKeyFailure(StateError('no store')),
        contains('no store'),
      );
    });
  });

  group('agentKeysProvider', () {
    test('issues a key bound to the signed-in person', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);

      final secret = await container
          .read(agentKeysProvider.notifier)
          .issue('Claude Desktop');

      expect(secret, startsWith(kAgentKeyTag));
      final views = await container.read(agentKeysProvider.future);
      expect(views, hasLength(1));
      expect(views.single.label, 'Claude Desktop');
      expect(views.single.personId, 'p1');
      expect(views.single.isActive, isTrue);

      final records = container.read(agentKeysProvider.notifier).localRecords;
      expect(records.single.hash, hashAgentKey(secret));
    });

    test('an issued key resolves to its person and role', () async {
      final container = containerFor([
        _person('p1', 'Ada', PersonRole.admin),
        _person('p2', 'Grace', PersonRole.viewer),
      ]);
      await container.read(agentKeysProvider.future);
      final secret = await container
          .read(agentKeysProvider.notifier)
          .issue('Claude Desktop');

      final identity = resolveAgentKey(
        secret,
        keys: container.read(agentKeysProvider.notifier).localRecords,
        person: (id) => container
            .read(agentKeyPeopleProvider)
            .where((p) => p.id == id)
            .firstOrNull,
      );

      expect(identity, isNotNull);
      expect(identity!.personName, 'Ada');
      expect(identity.role, 'admin');
      expect(identity.canWrite, isTrue);
    });

    test('binds to the implicit owner when People are not set up', () async {
      final container = containerFor(const []);
      await container.read(agentKeysProvider.future);

      final secret = await container
          .read(agentKeysProvider.notifier)
          .issue('Claude Desktop');

      final views = await container.read(agentKeysProvider.future);
      expect(views.single.personId, kLocalAgentKeyOwnerId);

      // The app grants full access when nobody is configured, so the key does
      // too.
      final identity = resolveAgentKey(
        secret,
        keys: container.read(agentKeysProvider.notifier).localRecords,
        person: (id) => container
            .read(agentKeyPeopleProvider)
            .where((p) => p.id == id)
            .firstOrNull,
      );
      expect(identity!.canWrite, isTrue);
    });

    test('revoking marks the key inactive and keeps the record', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      final secret = await container
          .read(agentKeysProvider.notifier)
          .issue('temporary');
      final id = (await container.read(agentKeysProvider.future)).single.id;

      await container.read(agentKeysProvider.notifier).revoke(id);

      final views = await container.read(agentKeysProvider.future);
      expect(views, hasLength(1));
      expect(views.single.isActive, isFalse);
      expect(views.single.revokedAt, isNotNull);
      expect(
        resolveAgentKey(
          secret,
          keys: container.read(agentKeysProvider.notifier).localRecords,
          person: (_) =>
              const AgentKeyPerson(id: 'p1', name: 'Ada', role: 'admin'),
        ),
        isNull,
      );
    });

    test('revoking is idempotent', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      await container.read(agentKeysProvider.notifier).issue('temporary');
      final id = (await container.read(agentKeysProvider.future)).single.id;

      await container.read(agentKeysProvider.notifier).revoke(id);
      final first = (await container.read(agentKeysProvider.future)).single;
      await container.read(agentKeysProvider.notifier).revoke(id);
      final second = (await container.read(agentKeysProvider.future)).single;

      expect(second.revokedAt, first.revokedAt);
    });

    test('an empty label is refused', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);

      expect(
        () => container.read(agentKeysProvider.notifier).issue('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('recordUsage stamps and persists lastUsedAt', () async {
      final people = [_person('p1', 'Ada', PersonRole.admin)];
      final first = containerFor(people);
      await first.read(agentKeysProvider.future);
      await first.read(agentKeysProvider.notifier).issue('Claude Desktop');
      final id = (await first.read(agentKeysProvider.future)).single.id;
      expect(
        (await first.read(agentKeysProvider.future)).single.lastUsedAt,
        isNull,
      );

      final at = DateTime.utc(2026, 5, 1, 12);
      await first.read(agentKeysProvider.notifier).recordUsage(id, at);

      expect(
        (await first.read(agentKeysProvider.future)).single.lastUsedAt,
        at,
      );
      final reloaded = containerFor(people);
      expect(
        (await reloaded.read(agentKeysProvider.future)).single.lastUsedAt,
        at,
      );
    });

    test('recordUsage throttles inside the interval', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      await container.read(agentKeysProvider.notifier).issue('Claude Desktop');
      final id = (await container.read(agentKeysProvider.future)).single.id;
      final first = DateTime.utc(2026, 5, 1, 12);
      await container.read(agentKeysProvider.notifier).recordUsage(id, first);

      await container
          .read(agentKeysProvider.notifier)
          .recordUsage(id, first.add(const Duration(seconds: 5)));

      expect(
        (await container.read(agentKeysProvider.future)).single.lastUsedAt,
        first,
      );
    });

    test('recordUsage advances once the interval elapses', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      await container.read(agentKeysProvider.notifier).issue('Claude Desktop');
      final id = (await container.read(agentKeysProvider.future)).single.id;
      final first = DateTime.utc(2026, 5, 1, 12);
      await container.read(agentKeysProvider.notifier).recordUsage(id, first);

      final later = first.add(const Duration(hours: 2));
      await container.read(agentKeysProvider.notifier).recordUsage(id, later);

      expect(
        (await container.read(agentKeysProvider.future)).single.lastUsedAt,
        later,
      );
    });

    test('recordUsage normalizes a local timestamp to UTC', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      await container.read(agentKeysProvider.notifier).issue('Claude Desktop');
      final id = (await container.read(agentKeysProvider.future)).single.id;

      await container
          .read(agentKeysProvider.notifier)
          .recordUsage(id, DateTime(2026, 5, 1, 12));

      final stamp = (await container.read(
        agentKeysProvider.future,
      )).single.lastUsedAt;
      expect(stamp!.isUtc, isTrue);
    });

    test('recordUsage ignores an unknown key id', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      await container.read(agentKeysProvider.notifier).issue('Claude Desktop');

      await container
          .read(agentKeysProvider.notifier)
          .recordUsage('nope', DateTime.utc(2026, 5, 1));

      expect(
        (await container.read(agentKeysProvider.future)).single.lastUsedAt,
        isNull,
      );
    });

    test('a revoked key keeps the stamp it had when it stopped', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      await container.read(agentKeysProvider.notifier).issue('Claude Desktop');
      final id = (await container.read(agentKeysProvider.future)).single.id;
      final at = DateTime.utc(2026, 5, 1, 12);
      await container.read(agentKeysProvider.notifier).recordUsage(id, at);

      await container.read(agentKeysProvider.notifier).revoke(id);

      final view = (await container.read(agentKeysProvider.future)).single;
      expect(view.isActive, isFalse);
      expect(view.lastUsedAt, at);
    });

    test('revealSecret returns the key its owner created', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      final secret = await container
          .read(agentKeysProvider.notifier)
          .issue('Claude Desktop');
      final id = (await container.read(agentKeysProvider.future)).single.id;

      expect(
        await container.read(agentKeysProvider.notifier).revealSecret(id),
        secret,
      );
    });

    test('a revealed secret survives a rebuild', () async {
      final people = [_person('p1', 'Ada', PersonRole.admin)];
      final first = containerFor(people);
      await first.read(agentKeysProvider.future);
      final secret = await first
          .read(agentKeysProvider.notifier)
          .issue('Claude Desktop');
      final id = (await first.read(agentKeysProvider.future)).single.id;

      final second = containerFor(people);
      await second.read(agentKeysProvider.future);

      expect(
        await second.read(agentKeysProvider.notifier).revealSecret(id),
        secret,
      );
    });

    test('revealSecret returns null for an unknown key', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      await container.read(agentKeysProvider.notifier).issue('Claude Desktop');

      expect(
        await container.read(agentKeysProvider.notifier).revealSecret('nope'),
        isNull,
      );
    });

    test('views report whether a secret can be read back', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      await container.read(agentKeysProvider.notifier).issue('Claude Desktop');

      expect(
        (await container.read(agentKeysProvider.future)).single.hasSecret,
        isTrue,
      );
    });

    test('a stored record without a secret still authenticates', () async {
      final people = [_person('p1', 'Ada', PersonRole.admin)];
      final first = containerFor(people);
      await first.read(agentKeysProvider.future);
      final secret = await first
          .read(agentKeysProvider.notifier)
          .issue('legacy key');
      final record = first.read(agentKeysProvider.notifier).localRecords.single;

      // Rewrite storage the way an older version left it: digest, no secret.
      final json = record.toJson().cast<String, Object?>()..remove('secret');
      secureStorage[kAgentKeysStorageKey] = jsonEncode([json]);

      final second = containerFor(people);
      final views = await second.read(agentKeysProvider.future);

      expect(views.single.hasSecret, isFalse);
      expect(
        await second
            .read(agentKeysProvider.notifier)
            .revealSecret(views.single.id),
        isNull,
      );
      expect(
        resolveAgentKey(
          secret,
          keys: second.read(agentKeysProvider.notifier).localRecords,
          person: (_) =>
              const AgentKeyPerson(id: 'p1', name: 'Ada', role: 'admin'),
        ),
        isNotNull,
      );
    });

    test('revoked keys sort below active ones', () async {
      final people = [_person('p1', 'Ada', PersonRole.admin)];
      final container = containerFor(people);
      await container.read(agentKeysProvider.future);
      final notifier = container.read(agentKeysProvider.notifier);
      await notifier.issue('first');
      await notifier.issue('second');
      await notifier.issue('third');
      final ids = {
        for (final view in await container.read(agentKeysProvider.future))
          view.label: view.id,
      };

      // Revoke the middle one: it must drop to the bottom, not stay in place.
      await notifier.revoke(ids['second']!);

      final labels = (await container.read(
        agentKeysProvider.future,
      )).map((view) => view.label).toList();
      expect(labels, ['first', 'third', 'second']);

      // And the ordering survives a reload, not just the in-memory update.
      final reloaded = containerFor(people);
      expect(
        (await reloaded.read(
          agentKeysProvider.future,
        )).map((view) => view.label),
        ['first', 'third', 'second'],
      );
    });

    test('forget drops a revoked key entirely', () async {
      final people = [_person('p1', 'Ada', PersonRole.admin)];
      final container = containerFor(people);
      await container.read(agentKeysProvider.future);
      final notifier = container.read(agentKeysProvider.notifier);
      await notifier.issue('keep');
      await notifier.issue('discard');
      final ids = {
        for (final view in await container.read(agentKeysProvider.future))
          view.label: view.id,
      };
      await notifier.revoke(ids['discard']!);

      await notifier.forget(ids['discard']!);

      expect(
        (await container.read(
          agentKeysProvider.future,
        )).map((view) => view.label),
        ['keep'],
      );
      final reloaded = containerFor(people);
      expect(
        (await reloaded.read(agentKeysProvider.future)).map((v) => v.label),
        ['keep'],
      );
    });

    test('forget refuses an active key', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      final secret = await container
          .read(agentKeysProvider.notifier)
          .issue('live key');
      final id = (await container.read(agentKeysProvider.future)).single.id;

      await expectLater(
        container.read(agentKeysProvider.notifier).forget(id),
        throwsA(isA<StateError>()),
      );

      // Still present, and still working.
      expect(await container.read(agentKeysProvider.future), hasLength(1));
      expect(
        resolveAgentKey(
          secret,
          keys: container.read(agentKeysProvider.notifier).localRecords,
          person: (_) =>
              const AgentKeyPerson(id: 'p1', name: 'Ada', role: 'admin'),
        ),
        isNotNull,
      );
    });

    test('forget ignores an unknown key', () async {
      final container = containerFor([_person('p1', 'Ada', PersonRole.admin)]);
      await container.read(agentKeysProvider.future);
      await container.read(agentKeysProvider.notifier).issue('keep');

      await container.read(agentKeysProvider.notifier).forget('nope');

      expect(await container.read(agentKeysProvider.future), hasLength(1));
    });

    test('keys persist across a rebuild', () async {
      final people = [_person('p1', 'Ada', PersonRole.admin)];
      final first = containerFor(people);
      await first.read(agentKeysProvider.future);
      await first.read(agentKeysProvider.notifier).issue('Claude Desktop');

      final second = containerFor(people);
      final views = await second.read(agentKeysProvider.future);

      expect(views, hasLength(1));
      expect(views.single.label, 'Claude Desktop');
    });

    test('keys survive a build before people have hydrated', () async {
      final people = [_person('p1', 'Ada', PersonRole.admin)];
      final first = containerFor(people);
      await first.read(agentKeysProvider.future);
      final secret = await first
          .read(agentKeysProvider.notifier)
          .issue('Claude Desktop');

      // People load asynchronously and this provider builds first. Pruning in
      // that window used to see zero people and delete every key bound to a
      // real one, on every app start.
      final booting = ProviderContainer(
        overrides: [
          peopleProvider.overrideWith(
            () => StaticPeopleNotifier(people, isHydrated: false),
          ),
        ],
      );
      addTearDown(booting.dispose);
      final views = await booting.read(agentKeysProvider.future);

      expect(views, hasLength(1), reason: 'a boot must not destroy keys');
      expect(
        await booting
            .read(agentKeysProvider.notifier)
            .revealSecret(views.single.id),
        secret,
      );

      // Once people are really loaded the key still resolves to its owner.
      final ready = containerFor(people);
      expect((await ready.read(agentKeysProvider.future)), hasLength(1));
    });

    test('a settled but empty people list does not destroy keys', () async {
      final people = [_person('p1', 'Ada', PersonRole.admin)];
      final first = containerFor(people);
      await first.read(agentKeysProvider.future);
      final secret = await first
          .read(agentKeysProvider.notifier)
          .issue('Claude');

      // An app instance that has no data yet reports zero people as a settled
      // state, indistinguishable from "everyone was deleted". Pruning there
      // wiped every key, and pruning buys nothing anyway: resolveAgentKey
      // already refuses a key whose person is gone, while deleting it is the
      // only irreversible half of the pair.
      final blank = containerFor(const []);
      final views = await blank.read(agentKeysProvider.future);

      expect(views, hasLength(1), reason: 'an empty list is not a deletion');
      expect(
        await blank
            .read(agentKeysProvider.notifier)
            .revealSecret(views.single.id),
        secret,
      );

      // And the key still resolves once the real people list is back.
      expect(
        await containerFor(people).read(agentKeysProvider.future),
        hasLength(1),
      );
    });

    test('turning People on keeps a key issued before it', () async {
      final local = containerFor(const []);
      await local.read(agentKeysProvider.future);
      await local.read(agentKeysProvider.notifier).issue('Claude');

      // The key belongs to the device, not to anyone in the list, so adding the
      // first person must not read it as orphaned.
      final withPeople = containerFor([_person('p1', 'Ada', PersonRole.admin)]);

      expect(await withPeople.read(agentKeysProvider.future), hasLength(1));
    });

    test('issuing refuses when nobody is signed in', () async {
      // With People on, a key has to belong to someone. Falling back to the
      // device owner here would mint a key that answers as nobody and inherits
      // whatever role the implicit owner carries.
      final container = ProviderContainer(
        overrides: [
          peopleProvider.overrideWith(
            () => StaticPeopleNotifier([
              _person('p1', 'Ada', PersonRole.admin),
            ], signedIn: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(agentKeysProvider.future);

      await expectLater(
        container.read(agentKeysProvider.notifier).issue('Claude'),
        throwsA(isA<StateError>()),
      );
    });

    test('keys of a deleted person are pruned on rebuild', () async {
      final first = containerFor([
        _person('p1', 'Ada', PersonRole.admin),
        _person('p2', 'Grace', PersonRole.viewer),
      ]);
      await first.read(agentKeysProvider.future);
      await first.read(agentKeysProvider.notifier).issue('Ada agent');

      final second = containerFor([_person('p2', 'Grace', PersonRole.viewer)]);
      final views = await second.read(agentKeysProvider.future);

      expect(views, isEmpty);
      expect(second.read(agentKeysProvider.notifier).localRecords, isEmpty);
    });
  });

  group('AgentKeyView.fromPublicJson', () {
    test('reads a full server row', () {
      final view = AgentKeyView.fromPublicJson(const {
        'id': 'k1',
        'personId': 'p9',
        'label': 'Claude Desktop',
        'displayPrefix': 'fr_ab12',
        'createdAt': '2026-05-01T10:00:00.000Z',
        'lastUsedAt': '2026-05-02T11:00:00.000Z',
        'revokedAt': '2026-05-03T12:00:00.000Z',
        'hasSecret': false,
      });

      expect(view!.id, 'k1');
      expect(view.personId, 'p9');
      expect(view.label, 'Claude Desktop');
      expect(view.displayPrefix, 'fr_ab12');
      expect(view.createdAt, DateTime.utc(2026, 5, 1, 10));
      expect(view.lastUsedAt, DateTime.utc(2026, 5, 2, 11));
      expect(view.revokedAt, DateTime.utc(2026, 5, 3, 12));
      expect(view.hasSecret, isFalse);
      expect(view.isActive, isFalse);
    });

    test('assumes a listed key has a secret worth offering', () {
      final view = AgentKeyView.fromPublicJson(const {
        'id': 'k1',
        'createdAt': '2026-05-01T10:00:00.000Z',
      });

      // A listing never carries secrets, so absence of the flag cannot mean
      // "no secret": that would hide the reveal action on every server key.
      expect(view!.hasSecret, isTrue);
      expect(view.personId, isEmpty);
      expect(view.label, isEmpty);
      expect(view.displayPrefix, isEmpty);
      expect(view.lastUsedAt, isNull);
      expect(view.revokedAt, isNull);
      expect(view.isActive, isTrue);
    });

    test('rejects a row that cannot be identified or dated', () {
      // Settings keys its rows by id and sorts by creation, so a row missing
      // either is dropped rather than shown with invented values.
      expect(
        AgentKeyView.fromPublicJson(const {
          'createdAt': '2026-05-01T10:00:00.000Z',
        }),
        isNull,
      );
      expect(AgentKeyView.fromPublicJson(const {'id': 'k1'}), isNull);
      expect(
        AgentKeyView.fromPublicJson(const {
          'id': 'k1',
          'createdAt': 'nonsense',
        }),
        isNull,
      );
    });
  });

  group('agentKeysProvider in server mode', () {
    late List<String> calls;
    late List<String> payloads;

    setUp(() {
      calls = [];
      payloads = [];
    });

    Map<String, dynamic> remoteKey(
      String id, {
      String label = 'Claude',
      String personId = 'srv_person',
      String createdAt = '2026-05-01T10:00:00.000Z',
      String? lastUsedAt,
      String? revokedAt,
    }) => {
      'id': id,
      'personId': personId,
      'label': label,
      'displayPrefix': 'fr_$id',
      'createdAt': createdAt,
      'lastUsedAt': ?lastUsedAt,
      'revokedAt': ?revokedAt,
    };

    /// Container whose server session holds a client talking to [route]. The
    /// session state call is answered here so tests only stub agent-key routes.
    Future<ProviderContainer> serverContainer(
      Future<http.Response> Function(http.Request request) route,
    ) async {
      secureStorage['serverSessionToken'] = 'sess';
      final client = RemoteServerClient(
        baseUrl: 'http://example.test',
        sessionToken: 'sess',
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.body.isNotEmpty) payloads.add(request.body);
          if (request.url.path == '/api/state') {
            return http.Response(
              jsonEncode({
                'storeExists': true,
                'storeLocked': false,
                'setupRequired': false,
                'me': {'id': 'srv_person', 'name': 'Ada', 'role': 'admin'},
              }),
              200,
            );
          }
          return route(request);
        }),
      );
      final container = ProviderContainer(
        overrides: [
          deploymentConfigProvider.overrideWithValue(
            const DeploymentConfig(
              mode: FireracoonMode.server,
              apiBase: 'http://example.test',
            ),
          ),
          authProvider.overrideWith(
            () => AuthNotifier(storage: const FlutterSecureStorage()),
          ),
          serverSessionProvider.overrideWith(
            () => ServerSessionNotifier(
              storage: const FlutterSecureStorage(),
              clientFactory: (_) => client,
            ),
          ),
          peopleProvider.overrideWith(() => StaticPeopleNotifier(const [])),
        ],
      );
      addTearDown(container.dispose);
      // The session must finish building before the keys provider reads .client.
      await container.read(serverSessionProvider.future);
      calls.clear();
      payloads.clear();
      return container;
    }

    Future<ProviderContainer> clientlessContainer() async {
      final container = ProviderContainer(
        overrides: [
          deploymentConfigProvider.overrideWithValue(
            const DeploymentConfig(
              mode: FireracoonMode.server,
              apiBase: 'http://example.test',
            ),
          ),
          authProvider.overrideWith(
            () => AuthNotifier(storage: const FlutterSecureStorage()),
          ),
          serverSessionProvider.overrideWith(_UnreachableServerSession.new),
          peopleProvider.overrideWith(() => StaticPeopleNotifier(const [])),
        ],
      );
      addTearDown(container.dispose);
      await container.read(serverSessionProvider.future);
      return container;
    }

    Future<http.Response> Function(http.Request) listing(
      List<Map<String, dynamic>> Function() keys,
    ) => (request) async {
      if (request.method == 'GET' && request.url.path == '/api/agent-keys') {
        return http.Response(jsonEncode({'keys': keys()}), 200);
      }
      return http.Response(jsonEncode({'error': 'unstubbed'}), 500);
    };

    test('lists backend keys, active first, dropping bad rows', () async {
      final container = await serverContainer(
        listing(
          () => [
            remoteKey('k1', label: 'first'),
            remoteKey(
              'k2',
              label: 'revoked',
              revokedAt: '2026-05-02T10:00:00.000Z',
            ),
            remoteKey('k3', label: 'third'),
            const {'label': 'no id'},
          ],
        ),
      );

      final views = await container.read(agentKeysProvider.future);

      expect(views.map((view) => view.label), ['first', 'third', 'revoked']);
      expect(calls, ['GET /api/agent-keys']);
      // The backend owns the digests, so nothing reaches the local store and
      // the MCP isolate has no keys to resolve against on this side.
      expect(container.read(agentKeysProvider.notifier).localRecords, isEmpty);
      expect(secureStorage[kAgentKeysStorageKey], isNull);
    });

    test('keeps backend keys whose owner is unknown locally', () async {
      // Server mode has no local people list to prune against: pruning here
      // would wipe the whole panel, since every owner id looks orphaned.
      final container = await serverContainer(
        listing(() => [remoteKey('k1', personId: 'someone_else')]),
      );

      final views = await container.read(agentKeysProvider.future);

      expect(views.single.personId, 'someone_else');
    });

    test('lists nothing when the server client is not ready', () async {
      final container = await clientlessContainer();

      expect(await container.read(agentKeysProvider.future), isEmpty);
    });

    test('every server call refuses to run without a client', () async {
      final container = await clientlessContainer();
      final notifier = container.read(agentKeysProvider.notifier);
      await container.read(agentKeysProvider.future);

      // Silently falling back to the local store here would issue a key the
      // backend has never heard of, and reveal one it never authorized.
      await expectLater(notifier.issue('Claude'), throwsA(isA<StateError>()));
      await expectLater(
        notifier.revealSecret('k1'),
        throwsA(isA<StateError>()),
      );
      await expectLater(notifier.revoke('k1'), throwsA(isA<StateError>()));
      await expectLater(notifier.forget('k1'), throwsA(isA<StateError>()));
      expect(secureStorage[kAgentKeysStorageKey], isNull);
    });

    test('issue posts the trimmed label and reloads from the server', () async {
      final keys = <Map<String, dynamic>>[];
      final container = await serverContainer((request) async {
        if (request.method == 'POST' && request.url.path == '/api/agent-keys') {
          keys.add(remoteKey('k1', label: 'Claude Desktop'));
          return http.Response(jsonEncode({'secret': 'fr_live_secret'}), 200);
        }
        return listing(() => keys)(request);
      });
      await container.read(agentKeysProvider.future);
      calls.clear();

      final secret = await container
          .read(agentKeysProvider.notifier)
          .issue('  Claude Desktop  ');

      expect(secret, 'fr_live_secret');
      expect(jsonDecode(payloads.single), {'label': 'Claude Desktop'});
      // The list has to come back from the backend: the app cannot invent the
      // id or the prefix the server chose.
      expect(calls, ['POST /api/agent-keys', 'GET /api/agent-keys']);
      expect((await container.read(agentKeysProvider.future)).single.id, 'k1');
      expect(secureStorage[kAgentKeysStorageKey], isNull);
    });

    test('issue yields an empty secret when the server omits it', () async {
      final container = await serverContainer((request) async {
        if (request.method == 'POST' && request.url.path == '/api/agent-keys') {
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return listing(() => <Map<String, dynamic>>[])(request);
      });
      await container.read(agentKeysProvider.future);

      // Settings shows "copy this once" text, so an absent secret must read as
      // empty rather than crash the dialog.
      expect(await container.read(agentKeysProvider.notifier).issue('x'), '');
    });

    test('revealSecret returns what the backend hands back', () async {
      final container = await serverContainer((request) async {
        if (request.url.path == '/api/agent-keys/k1/secret') {
          return http.Response(jsonEncode({'secret': 'fr_stored'}), 200);
        }
        return listing(() => [remoteKey('k1')])(request);
      });
      await container.read(agentKeysProvider.future);

      expect(
        await container.read(agentKeysProvider.notifier).revealSecret('k1'),
        'fr_stored',
      );
    });

    test('revealSecret treats an empty secret as unavailable', () async {
      final container = await serverContainer((request) async {
        if (request.url.path == '/api/agent-keys/k1/secret') {
          return http.Response(jsonEncode({'secret': ''}), 200);
        }
        return listing(() => [remoteKey('k1')])(request);
      });
      await container.read(agentKeysProvider.future);

      // An empty string would otherwise be copied to the clipboard as if it
      // were the key.
      expect(
        await container.read(agentKeysProvider.notifier).revealSecret('k1'),
        isNull,
      );
    });

    test('revealSecret maps a 404 to no secret', () async {
      final container = await serverContainer((request) async {
        if (request.url.path == '/api/agent-keys/k1/secret') {
          return http.Response(jsonEncode({'error': 'not found'}), 404);
        }
        return listing(() => [remoteKey('k1')])(request);
      });
      await container.read(agentKeysProvider.future);

      // Keys issued before secrets were retained answer 404, which is a plain
      // "cannot be shown", not an error to raise at the person.
      expect(
        await container.read(agentKeysProvider.notifier).revealSecret('k1'),
        isNull,
      );
    });

    test('revealSecret rethrows a failure that is not a 404', () async {
      final container = await serverContainer((request) async {
        if (request.url.path == '/api/agent-keys/k1/secret') {
          return http.Response(jsonEncode({'error': 'forbidden'}), 403);
        }
        return listing(() => [remoteKey('k1')])(request);
      });
      await container.read(agentKeysProvider.future);

      // Swallowing this would show "no secret stored" for someone else's key
      // instead of admitting the request was refused.
      await expectLater(
        container.read(agentKeysProvider.notifier).revealSecret('k1'),
        throwsA(
          isA<RemoteServerException>().having(
            (error) => error.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('revoke deletes on the backend and takes its list back', () async {
      var revoked = false;
      final container = await serverContainer((request) async {
        if (request.method == 'DELETE' &&
            request.url.path == '/api/agent-keys/k1') {
          revoked = true;
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return listing(
          () => [
            remoteKey(
              'k1',
              revokedAt: revoked ? '2026-05-04T09:00:00.000Z' : null,
            ),
          ],
        )(request);
      });
      await container.read(agentKeysProvider.future);
      calls.clear();

      await container.read(agentKeysProvider.notifier).revoke('k1');

      expect(calls, ['DELETE /api/agent-keys/k1', 'GET /api/agent-keys']);
      final view = (await container.read(agentKeysProvider.future)).single;
      expect(view.isActive, isFalse);
      expect(view.revokedAt, DateTime.utc(2026, 5, 4, 9));
    });

    test('forget deletes the record, not the key', () async {
      var forgotten = false;
      final container = await serverContainer((request) async {
        if (request.method == 'DELETE' &&
            request.url.path == '/api/agent-keys/k1/record') {
          forgotten = true;
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return listing(
          () => forgotten
              ? <Map<String, dynamic>>[]
              : [remoteKey('k1', revokedAt: '2026-05-04T09:00:00.000Z')],
        )(request);
      });
      await container.read(agentKeysProvider.future);
      calls.clear();

      await container.read(agentKeysProvider.notifier).forget('k1');

      // The revoke route is /api/agent-keys/k1; hitting it here would revoke a
      // live key instead of clearing a dead one's record.
      expect(calls, [
        'DELETE /api/agent-keys/k1/record',
        'GET /api/agent-keys',
      ]);
      expect(await container.read(agentKeysProvider.future), isEmpty);
    });

    test('recordUsage leaves the backend stamp alone', () async {
      final container = await serverContainer(
        listing(
          () => [remoteKey('k1', lastUsedAt: '2026-05-01T11:00:00.000Z')],
        ),
      );
      await container.read(agentKeysProvider.future);
      calls.clear();

      await container
          .read(agentKeysProvider.notifier)
          .recordUsage('k1', DateTime.utc(2026, 5, 9, 15));

      // The backend sees the requests and stamps them itself, so the app must
      // neither call out nor overwrite what it was told.
      expect(calls, isEmpty);
      expect(
        (await container.read(agentKeysProvider.future)).single.lastUsedAt,
        DateTime.utc(2026, 5, 1, 11),
      );
      expect(secureStorage[kAgentKeysStorageKey], isNull);
    });
  });

  group('agentKeyPeopleProvider', () {
    test('maps configured people to their roles', () {
      final container = containerFor([
        _person('p1', 'Ada', PersonRole.admin),
        _person('p2', 'Grace', PersonRole.viewer),
      ]);

      final people = container.read(agentKeyPeopleProvider);

      expect(people.map((p) => p.id), ['p1', 'p2']);
      expect(people.map((p) => p.role), ['admin', 'viewer']);
    });

    test('offers an admin implicit owner when nobody is configured', () {
      final container = containerFor(const []);

      final people = container.read(agentKeyPeopleProvider);

      expect(people.single.id, kLocalAgentKeyOwnerId);
      expect(people.single.role, 'admin');
    });
  });
}
