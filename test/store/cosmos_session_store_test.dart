import 'package:fireraccoon/store/cosmos_session.dart';
import 'package:fireraccoon/store/cosmos_session_store.dart';
import 'package:fireraccoon/store/secure_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> backing;

  setUp(() {
    backing = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      backing,
    );
  });

  CosmosSessionStore store() =>
      CosmosSessionStore(storage: const FlutterSecureStorage());

  final session = CosmosSession(
    host: 'firefly.example',
    cookie: 'jwt-value',
    obtainedAt: DateTime.utc(2026, 9, 8),
  );

  test('a saved session comes back', () async {
    await store().save(session);

    final restored = await store().load();

    expect(restored!.host, 'firefly.example');
    expect(restored.cookie, 'jwt-value');
  });

  test('nothing saved is no session', () async {
    expect(await store().load(), isNull);
  });

  test('a cleared session is gone', () async {
    await store().save(session);
    await store().clear();

    expect(await store().load(), isNull);
  });

  test('a value that will not decode is no session, not a crash', () async {
    await const FlutterSecureStorage().write(
      key: kCosmosSessionStorageKey,
      value: 'not json',
    );

    expect(await store().load(), isNull);
  });

  test('the key is one the consolidated store folds in', () {
    // The consolidated item migrates a named list of legacy keys. A key
    // missing from that list is one that stays stranded outside the item and
    // raises its own keychain prompt for the life of the install.
    expect(
      ConsolidatedSecureStorage.legacyKeysForTest,
      contains(kCosmosSessionStorageKey),
    );
  });
}
