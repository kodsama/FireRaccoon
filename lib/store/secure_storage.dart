import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _log = AppLogger.scoped('store.secureStorage');

/// macOS asks for the legacy login keychain instead of the data protection one.
/// `kSecUseDataProtectionKeychain` requires the application-identifier
/// entitlement, which only signs with a development certificate; debug builds
/// are ad-hoc signed and CI produces an unsigned release, so neither has it.
/// Requesting it fails every write with errSecMissingEntitlement (-34018). The
/// login keychain is reachable once the app is unsandboxed, which is what the
/// debug entitlements already arrange.
const MacOsOptions _macOptions = MacOsOptions(
  usesDataProtectionKeychain: false,
);

/// The one keychain item every secret lives in.
const String kConsolidatedSecretsKey = 'fireraccoon.secrets.v1';

/// The secure storage every FireRaccoon secret goes through.
///
/// Keeps every secret inside one keychain item rather than one item per key.
/// macOS evaluates a login-keychain item's access control per item, and neither
/// an ad-hoc signed debug build nor the unsigned release carries a stable code
/// identity for that list to trust, so each distinct item read during startup
/// raised its own password prompt: about a dozen of them before the window
/// appeared, every launch. One item is one prompt.
///
/// The read surface is unchanged, so callers still work in keys and know
/// nothing about this.
///
/// Reads go to the keychain every time until [prime] is called, which the app
/// does once at startup. Priming is explicit rather than automatic so that a
/// process which swaps the backing store under it, which is what every test
/// does between cases, is never served the previous store's secrets.
class ConsolidatedSecureStorage extends FlutterSecureStorage {
  ConsolidatedSecureStorage() : super(mOptions: _macOptions);

  Map<String, String>? _secrets;
  bool _primed = false;

  /// Reads the one item once and answers from memory thereafter.
  ///
  /// Call at startup, before anything hydrates. Without this every read is its
  /// own keychain trip, which is correct but asks again each time.
  ///
  /// Never throws. A locked keychain, a denied prompt or a missing entitlement
  /// leaves the store unprimed, so reads go back to asking per call and each
  /// provider reports its own failure as it did before. This is an optimisation,
  /// and an optimisation that can stop the app starting is worse than the cost
  /// it saves.
  Future<void> prime() async {
    if (_primed) return;
    try {
      final blob = await super.read(key: kConsolidatedSecretsKey);
      _secrets = blob != null ? _decode(blob) : await _migrate();
      _primed = true;
    } on PlatformException catch (error, stackTrace) {
      _log.warning('Keychain unavailable while priming', error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _log.warning('Secure storage plugin missing', error, stackTrace);
    }
  }

  /// Drops the in-memory copy so the next read goes to the keychain again.
  @visibleForTesting
  void invalidateCache() {
    _secrets = null;
    _loadingForMutation = null;
    _primed = false;
  }

  /// Keys written one per item before consolidation, folded into the item on
  /// first use.
  ///
  /// Named rather than discovered: [FlutterSecureStorage.readAll] fails with
  /// errSecParam on macOS in this plugin version, because its own query
  /// validation refuses a result limit together with returning data, so a
  /// migration built on it cannot read anything at all. Anything missing from
  /// this list is left where it is rather than lost, and its owner keeps
  /// reading it as before.
  static const List<String> _legacyKeys = [
    // Firefly connection.
    'serverUrl',
    'apiToken',
    'authMode',
    'allowInsecure',
    'serverSessionToken',
    // People, and the names they had before.
    'people_auth_v1',
    'people_session_id',
    'people_last_user_id',
    'app_users_v1',
    'app_users_session_id',
    'app_users_last_user_id',
    // Agent keys and view preferences.
    'agent_keys_v1',
    'globalViewMode',
    'tightRowsColumns',
  ];

  Future<Map<String, String>> _load() async {
    final cached = _secrets;
    if (_primed && cached != null) return cached;
    return _read();
  }

  /// In flight while the first mutation is still reading the item.
  ///
  /// Finding the map missing and then reading it is two steps, and concurrent
  /// mutations all pass the first before any finishes the second, so each would
  /// build its own map and sharing would buy nothing. They join one read.
  Future<Map<String, String>>? _loadingForMutation;

  /// The one map every mutation adds its key to.
  ///
  /// A write rewrites the whole item, so the copy it starts from decides what
  /// survives. Two writes each holding their own copy cannot both live: the one
  /// that persists last writes a blob that never saw the other's key. Sharing a
  /// single map means every persist serialises whatever has been added so far,
  /// so a write adds a key instead of replacing the store. A lock would do it
  /// too, and would deadlock the process for good the first time a keychain call
  /// failed to answer.
  ///
  /// A read that answered nothing because the item would not decode must not be
  /// mistaken for a store holding nothing: persisting that is how one unreadable
  /// byte takes every other secret with it. Failing one write beats losing all
  /// of them.
  Future<Map<String, String>> _loadForMutation() {
    final cached = _secrets;
    if (cached != null) return Future.value(cached);
    return _loadingForMutation ??= _readForMutation()
        .then((map) => _secrets = map)
        .whenComplete(() => _loadingForMutation = null);
  }

  Future<Map<String, String>> _readForMutation() async {
    final raw = await super.read(key: kConsolidatedSecretsKey);
    if (raw == null) return <String, String>{};
    final decoded = _tryDecode(raw);
    if (decoded == null) {
      throw StateError(
        'The FireRaccoon secrets item exists but could not be read. Refusing to '
        'overwrite it, because that would discard every secret it holds.',
      );
    }
    return decoded;
  }

  /// One keychain call, the same cost as a read was before consolidation.
  ///
  /// Deliberately does not migrate. Folding the old items in walks every legacy
  /// key, and doing that per read turned one platform call into fourteen: slow,
  /// and enough extra async gaps that a provider could be disposed before its
  /// load returned. Migration belongs to [prime], which runs once at startup.
  Future<Map<String, String>> _read() async {
    final raw = await super.read(key: kConsolidatedSecretsKey);
    return raw != null ? _decode(raw) : <String, String>{};
  }

  /// First run after consolidation, or a genuinely empty keychain.
  ///
  /// The blob is written before a single old item is removed, so an interrupted
  /// migration leaves the originals to be found again on the next run. One key
  /// that will not read does not sink the rest: it stays where it is.
  Future<Map<String, String>> _migrate() async {
    final legacy = <String, String>{};
    for (final key in _legacyKeys) {
      try {
        final value = await super.read(key: key);
        if (value != null) legacy[key] = value;
      } on PlatformException catch (error) {
        _log.warning('Leaving $key where it is: $error');
      }
    }
    if (legacy.isEmpty) return <String, String>{};

    await _persist(legacy);
    for (final key in legacy.keys) {
      try {
        await super.delete(key: key);
      } on PlatformException catch (error) {
        // Harmless: the value is in the blob, and this item is now ignored.
        _log.warning('Old item $key left behind: $error');
      }
    }
    _log.info('Consolidated ${legacy.length} secrets into one keychain item');
    return legacy;
  }

  /// No secrets rather than a crash, for an item that will not parse.
  ///
  /// A half-written or hand-edited item must not stop the app starting: the
  /// login flow already handles having nothing, and it can be signed back in.
  /// Throwing here would leave no way in at all.
  Map<String, String> _decode(String raw) =>
      _tryDecode(raw) ?? <String, String>{};

  /// The item's contents, or null when it will not parse.
  ///
  /// Reads still treat that as no secrets, per [_decode]: the login flow copes
  /// with having nothing and can be signed into again, where throwing would
  /// leave no way in at all. Mutations need the difference, so they get it here.
  Map<String, String>? _tryDecode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    return <String, String>{
      for (final entry in decoded.entries)
        if (entry.value is String) '${entry.key}': entry.value as String,
    };
  }

  Future<void> _persist(Map<String, String> secrets) =>
      super.write(key: kConsolidatedSecretsKey, value: jsonEncode(secrets));

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final value = (await _load())[key];
    if (value != null || _primed) return value;
    // Not consolidated yet, so look where this key used to live. One extra
    // call, and only for a key the item does not hold.
    return super.read(key: key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if ((await _load()).containsKey(key)) return true;
    if (_primed) return false;
    return super.containsKey(key: key);
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map<String, String>.from(await _load());

  /// A null [value] deletes, matching [FlutterSecureStorage.write].
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) return delete(key: key);
    final secrets = await _loadForMutation();
    if (secrets[key] == value) return;
    secrets[key] = value;
    await _persist(secrets);
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final secrets = await _loadForMutation();
    if (secrets.remove(key) == null) return;
    await _persist(secrets);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_primed) _secrets = <String, String>{};
    await super.deleteAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

final ConsolidatedSecureStorage appSecureStorage = ConsolidatedSecureStorage();
