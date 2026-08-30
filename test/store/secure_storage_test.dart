import 'dart:convert';

import 'package:fireraccoon/store/secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> keychain;
  late ConsolidatedSecureStorage storage;

  setUp(() {
    keychain = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      keychain,
    );
    storage = ConsolidatedSecureStorage();
  });

  /// Keys the keychain actually holds, which is what decides how many password
  /// prompts macOS raises.
  Iterable<String> items() => keychain.keys;

  Map<String, String> blob() =>
      (jsonDecode(keychain[kConsolidatedSecretsKey]!) as Map).cast();

  group('ConsolidatedSecureStorage', () {
    test('refuses to write over an item it could not read', () async {
      // Every write rewrites the whole item. Starting from "nothing" because the
      // item would not parse persists a store holding one key, and the other
      // secrets are gone with no way back.
      keychain[kConsolidatedSecretsKey] = '{"apiToken":"tok",TRUNCATED';

      await expectLater(
        storage.write(key: 'globalViewMode', value: 'compact'),
        throwsA(isA<StateError>()),
      );

      // The damaged item is left exactly as it was, for a human to look at.
      expect(keychain[kConsolidatedSecretsKey], '{"apiToken":"tok",TRUNCATED');
    });

    test('a read still treats an unparseable item as no secrets', () async {
      // Reads must not throw: the login flow copes with having nothing and can
      // be signed into again, where throwing would leave no way in at all.
      keychain[kConsolidatedSecretsKey] = 'not json at all';

      expect(await storage.read(key: 'apiToken'), isNull);
    });

    test('concurrent writes all survive', () async {
      // Read, add one key, write the whole item back. Two of those at once each
      // start from their own copy, and the loser's key never reaches the item.
      await Future.wait([
        storage.write(key: 'apiToken', value: 'tok'),
        storage.write(key: 'serverUrl', value: 'https://firefly.test'),
        storage.write(key: 'authMode', value: 'token'),
        storage.write(key: 'allowInsecure', value: 'false'),
        storage.write(key: 'globalViewMode', value: 'compact'),
      ]);

      expect(blob(), {
        'apiToken': 'tok',
        'serverUrl': 'https://firefly.test',
        'authMode': 'token',
        'allowInsecure': 'false',
        'globalViewMode': 'compact',
      });
    });

    test('keeps every secret in one keychain item', () async {
      // The whole point: macOS evaluates access control per item, so a secret
      // per item is a password prompt per secret at startup.
      await storage.write(key: 'apiToken', value: 'tok');
      await storage.write(key: 'serverUrl', value: 'https://firefly.test');
      await storage.write(key: 'globalViewMode', value: 'compact');

      expect(items(), [kConsolidatedSecretsKey]);
      expect(blob(), {
        'apiToken': 'tok',
        'serverUrl': 'https://firefly.test',
        'globalViewMode': 'compact',
      });
    });

    test('reads back what it wrote', () async {
      await storage.write(key: 'apiToken', value: 'tok');

      expect(await storage.read(key: 'apiToken'), 'tok');
      expect(await storage.read(key: 'missing'), isNull);
      expect(await storage.containsKey(key: 'apiToken'), isTrue);
      expect(await storage.containsKey(key: 'missing'), isFalse);
    });

    test('folds keys written before consolidation into the item', () async {
      // Upgrading must not look like a first run with no Firefly connection.
      keychain['apiToken'] = 'existing-token';
      keychain['serverUrl'] = 'https://old.test';
      keychain['globalViewMode'] = 'tight';
      keychain['agent_keys_v1'] = '[]';

      await storage.prime();

      expect(await storage.read(key: 'apiToken'), 'existing-token');
      expect(await storage.read(key: 'serverUrl'), 'https://old.test');
      expect(await storage.read(key: 'globalViewMode'), 'tight');
      expect(await storage.read(key: 'agent_keys_v1'), '[]');

      // And the originals are gone, so the prompts do not come back.
      expect(items(), [kConsolidatedSecretsKey]);
    });

    test('migrates before deleting, so an interruption loses nothing', () async {
      // The blob is written first; only then do the old items go. A failure in
      // between leaves the originals to be found on the next run.
      keychain['apiToken'] = 'tok';
      final store = ConsolidatedSecureStorage();

      await store.prime();

      expect(keychain.containsKey(kConsolidatedSecretsKey), isTrue);
      expect(blob()['apiToken'], 'tok');
    });

    test('an empty keychain stays empty rather than writing a blob', () async {
      await storage.prime();

      expect(await storage.read(key: 'apiToken'), isNull);
      expect(items(), isEmpty);
    });

    test('an unprimed read still finds a key not yet consolidated', () async {
      // Two calls: the item, then where the key used to live. Walking all
      // fourteen legacy keys per read turned one platform call into fourteen,
      // which was slow and left enough async gaps for a provider to be
      // disposed before its load returned. Migrating the lot is startup's job.
      keychain['apiToken'] = 'legacy';
      final platform = _CountingPlatform(keychain);
      FlutterSecureStoragePlatform.instance = platform;

      expect(await ConsolidatedSecureStorage().read(key: 'apiToken'), 'legacy');
      expect(platform.readCalls, 2);
    });

    test('a primed read never goes back to the old keys', () async {
      await storage.prime();
      keychain['apiToken'] = 'legacy';
      final platform = _CountingPlatform(keychain);
      FlutterSecureStoragePlatform.instance = platform;

      expect(await storage.read(key: 'apiToken'), isNull);
      expect(platform.readCalls, 0);
    });

    test('delete removes one secret and leaves the rest', () async {
      await storage.write(key: 'apiToken', value: 'tok');
      await storage.write(key: 'serverUrl', value: 'https://firefly.test');

      await storage.delete(key: 'apiToken');

      expect(await storage.read(key: 'apiToken'), isNull);
      expect(await storage.read(key: 'serverUrl'), 'https://firefly.test');
      expect(items(), [kConsolidatedSecretsKey]);
    });

    test('a null value deletes, as the wrapped API does', () async {
      await storage.write(key: 'apiToken', value: 'tok');

      await storage.write(key: 'apiToken', value: null);

      expect(await storage.read(key: 'apiToken'), isNull);
    });

    test('readAll reports the secrets, not the item holding them', () async {
      await storage.write(key: 'apiToken', value: 'tok');

      final all = await storage.readAll();

      expect(all, {'apiToken': 'tok'});
      expect(all.containsKey(kConsolidatedSecretsKey), isFalse);
    });

    test(
      'readAll hands back a copy, so a caller cannot edit the store',
      () async {
        await storage.write(key: 'apiToken', value: 'tok');

        (await storage.readAll())['apiToken'] = 'tampered';

        expect(await storage.read(key: 'apiToken'), 'tok');
      },
    );

    test('deleteAll clears the item and the memory of it', () async {
      await storage.write(key: 'apiToken', value: 'tok');

      await storage.deleteAll();

      expect(items(), isEmpty);
      expect(await storage.read(key: 'apiToken'), isNull);
    });

    test('survives a corrupt item instead of failing to start', () async {
      // A half-written or hand-edited item must not stop the app booting; it
      // reads as no secrets, which the login flow already handles.
      keychain[kConsolidatedSecretsKey] = 'not json at all';

      expect(await ConsolidatedSecureStorage().read(key: 'apiToken'), isNull);

      keychain[kConsolidatedSecretsKey] = '["a list"]';
      expect(await ConsolidatedSecureStorage().read(key: 'apiToken'), isNull);
    });

    test('ignores a non-string value inside the item', () async {
      keychain[kConsolidatedSecretsKey] = jsonEncode({
        'apiToken': 'tok',
        'weird': 42,
      });

      final store = ConsolidatedSecureStorage();
      expect(await store.read(key: 'apiToken'), 'tok');
      expect(await store.read(key: 'weird'), isNull);
    });

    test('rewriting the same value does not touch the keychain', () async {
      await storage.write(key: 'apiToken', value: 'tok');
      final written = keychain[kConsolidatedSecretsKey];

      await storage.write(key: 'apiToken', value: 'tok');

      expect(keychain[kConsolidatedSecretsKey], same(written));
    });

    test('an unprimed read goes to the keychain every time', () async {
      // The default, and what every test sees: nothing is remembered, so a
      // store whose backing map is swapped underneath never answers stale.
      await storage.write(key: 'apiToken', value: 'tok');
      keychain[kConsolidatedSecretsKey] = jsonEncode({'apiToken': 'changed'});

      expect(await storage.read(key: 'apiToken'), 'changed');
    });

    test('priming answers from memory, so startup asks once', () async {
      await storage.write(key: 'apiToken', value: 'tok');
      await storage.prime();

      keychain[kConsolidatedSecretsKey] = jsonEncode({'apiToken': 'changed'});

      // The keychain moved underneath and the primed copy stands, which is the
      // whole point: the app does not go back and ask again.
      expect(await storage.read(key: 'apiToken'), 'tok');

      storage.invalidateCache();
      expect(await storage.read(key: 'apiToken'), 'changed');
    });

    test('a write while primed is visible without another read', () async {
      await storage.prime();

      await storage.write(key: 'apiToken', value: 'tok');

      expect(await storage.read(key: 'apiToken'), 'tok');
      expect(blob()['apiToken'], 'tok');
    });

    test('a delete while primed does not resurrect the secret', () async {
      await storage.write(key: 'apiToken', value: 'tok');
      await storage.prime();

      await storage.delete(key: 'apiToken');

      expect(await storage.read(key: 'apiToken'), isNull);
    });

    test('does not migrate through readAll, which macOS refuses', () async {
      // readAll fails with errSecParam on macOS in this plugin version: its own
      // query validation rejects a result limit together with returning data.
      // A migration built on it reads nothing, and because every read falls
      // into the migration path, nothing in the app can read its secrets.
      keychain['apiToken'] = 'tok';
      final platform = _CountingPlatform(keychain);
      FlutterSecureStoragePlatform.instance = platform;

      final store = ConsolidatedSecureStorage();
      await store.prime();
      expect(await store.read(key: 'apiToken'), 'tok');

      expect(platform.readAllCalls, 0);
    });

    test('a key that will not read leaves the others alone', () async {
      keychain['apiToken'] = 'tok';
      keychain['globalViewMode'] = 'tight';
      FlutterSecureStoragePlatform.instance = _RefusingOnePlatform(
        keychain,
        refuseKey: 'globalViewMode',
      );

      final store = ConsolidatedSecureStorage();
      await store.prime();

      expect(await store.read(key: 'apiToken'), 'tok');
      // The unreadable one stays where it is rather than being dropped.
      expect(keychain.containsKey('globalViewMode'), isTrue);
    });

    test('priming survives a keychain that refuses', () async {
      // A locked keychain or a denied prompt must not stop the app starting.
      // Priming saves prompts; it is not a precondition for running.
      FlutterSecureStoragePlatform.instance = _RefusingPlatform();
      final store = ConsolidatedSecureStorage();

      await expectLater(store.prime(), completes);

      // Unprimed, so reads go back to asking, and the provider that asked
      // reports its own failure exactly as it did before.
      await expectLater(
        store.read(key: 'apiToken'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('priming twice reads once', () async {
      await storage.write(key: 'apiToken', value: 'tok');
      await storage.prime();
      keychain[kConsolidatedSecretsKey] = jsonEncode({'apiToken': 'changed'});

      await storage.prime();

      expect(await storage.read(key: 'apiToken'), 'tok');
    });
  });
}

/// A keychain that refuses every request, as a locked one or a denied prompt
/// does.
class _RefusingPlatform extends FlutterSecureStoragePlatform {
  Never _refuse() =>
      throw PlatformException(code: 'Unexpected security result');

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) => _refuse();

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) => _refuse();

  @override
  Future<void> deleteAll({required Map<String, String> options}) => _refuse();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) => _refuse();

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      _refuse();

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) => _refuse();
}

/// Counts readAll, which the migration must never use.
class _CountingPlatform extends TestFlutterSecureStoragePlatform {
  _CountingPlatform(super.data);

  int readAllCalls = 0;
  int readCalls = 0;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    readCalls++;
    return super.read(key: key, options: options);
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) {
    readAllCalls++;
    return super.readAll(options: options);
  }
}

/// Refuses one key and serves the rest, as an item whose access is denied does.
class _RefusingOnePlatform extends TestFlutterSecureStoragePlatform {
  _RefusingOnePlatform(super.data, {required this.refuseKey});

  final String refuseKey;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    if (key == refuseKey) {
      throw PlatformException(code: 'Unexpected security result');
    }
    return super.read(key: key, options: options);
  }
}
