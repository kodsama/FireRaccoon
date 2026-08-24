import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../store/secure_storage.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../fun_modes/fun_mode.dart';
import '../deployment/deployment_providers.dart';
import '../models/app_user_models.dart';
import '../models/people_migration.dart';
import '../models/people_models.dart';
import '../models/settings_bundle.dart';
import '../services/biometric_auth.dart';
import '../utils/avatar_file_store.dart';
import '../utils/password_policy.dart';
import '../utils/person_permissions.dart' as permissions;
import 'data_providers.dart';
import 'locale_provider.dart';
import 'server_session_provider.dart';
import 'theme_provider.dart';

const String kPeopleConfigPreferenceKey = 'fireracoon_people_config';
const String kPeopleAuthStorageKey = 'people_auth_v1';
const String kPeopleSessionKey = 'people_session_id';
const String kPeopleLastUserKey = 'people_last_user_id';

/// Legacy keys — read once for migration, then deleted.
const String _kLegacyAppUsersStorageKey = 'app_users_v1';
const String _kLegacyAppUsersSessionKey = 'app_users_session_id';
const String _kLegacyAppUsersLastUserKey = 'app_users_last_user_id';

/// Bundled raccoon avatar preset ids (files under `assets/avatars/`).
/// Photos from Wikimedia Commons (CC / public domain wildlife shots).
const List<String> kAvatarPresets = [
  'raccoon_1',
  'raccoon_2',
  'raccoon_3',
  'raccoon_4',
];

String avatarPresetAssetPath(String presetId) => 'assets/avatars/$presetId.png';

const int kAvatarMinBytes = 10 * 1024;
const int kAvatarMaxBytes = 5 * 1024 * 1024;
const int kAvatarStoredEdge = 256;

String _avatarPrefsKey(String personId) => 'fireracoon_avatar_$personId';

/// Downscales cropped avatars so web prefs and disk stay small.
Uint8List normalizeAvatarPng(Uint8List pngBytes) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) return pngBytes;
  final edge = decoded.width > decoded.height ? decoded.width : decoded.height;
  if (edge <= kAvatarStoredEdge) {
    return Uint8List.fromList(img.encodePng(decoded));
  }
  final resized = img.copyResize(
    decoded,
    width: kAvatarStoredEdge,
    height: kAvatarStoredEdge,
  );
  return Uint8List.fromList(img.encodePng(resized));
}

class ActivePersonFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setPersonFilter(String? personId) {
    state = personId;
  }

  void clearFilter() {
    state = null;
  }
}

final activePersonFilterProvider =
    NotifierProvider<ActivePersonFilterNotifier, String?>(
      ActivePersonFilterNotifier.new,
    );

/// Combined people list, ownership, password-login policy, and session.
class PeopleState {
  final AccountOwnershipConfig config;
  final bool requirePasswordLogin;
  final String? loggedInPersonId;
  final String? lastSessionPersonId;
  final bool isHydrated;

  const PeopleState({
    this.config = const AccountOwnershipConfig(),
    this.requirePasswordLogin = false,
    this.loggedInPersonId,
    this.lastSessionPersonId,
    this.isHydrated = false,
  });

  List<Person> get people => config.people;

  bool get isEnabled => people.isNotEmpty;

  Person? get currentPerson {
    final id = loggedInPersonId;
    if (id == null) return null;
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  Person? get lastSessionPerson {
    final id = lastSessionPersonId;
    if (id == null) return null;
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  bool get requiresLoginGate => isEnabled && currentPerson == null;

  bool get canUnlockWithBiometrics {
    final person = lastSessionPerson;
    return person != null && person.biometricsEnabled && person.hasPassword;
  }

  /// People who still need a password before password login can be enabled.
  List<Person> get peopleMissingPasswords =>
      people.where((p) => !p.hasPassword).toList();

  PeopleState copyWith({
    AccountOwnershipConfig? config,
    bool? requirePasswordLogin,
    String? loggedInPersonId,
    String? lastSessionPersonId,
    bool clearLoggedInPersonId = false,
    bool clearLastSessionPersonId = false,
    bool? isHydrated,
  }) {
    return PeopleState(
      config: config ?? this.config,
      requirePasswordLogin: requirePasswordLogin ?? this.requirePasswordLogin,
      loggedInPersonId: clearLoggedInPersonId
          ? null
          : (loggedInPersonId ?? this.loggedInPersonId),
      lastSessionPersonId: clearLastSessionPersonId
          ? null
          : (lastSessionPersonId ?? this.lastSessionPersonId),
      isHydrated: isHydrated ?? this.isHydrated,
    );
  }
}

class PeopleNotifier extends Notifier<PeopleState> {
  PeopleNotifier({FlutterSecureStorage? storage, BiometricAuth? biometricAuth})
    : _storage = storage ?? appSecureStorage,
      _biometricAuth = biometricAuth ?? LocalBiometricAuth();

  final FlutterSecureStorage _storage;
  final BiometricAuth _biometricAuth;
  final _log = AppLogger.scoped('providers.people');
  late SharedPreferences _prefs;

  /// Bumps on every local config write so a slow Firefly setPreference cannot
  /// overwrite a newer avatar/profile with an older payload.
  int _configWriteGeneration = 0;

  /// Plaintext passwords awaiting a successful server `putPeople` (server mode).
  final Map<String, String> _pendingServerPasswords = {};

  BiometricAuth get biometricAuth => _biometricAuth;

  bool get _isServerMode {
    if (!ref.mounted) return false;
    return ref.read(deploymentConfigProvider).isServer;
  }

  @override
  PeopleState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    ref.listen(themeProvider, (_, _) => _syncPreferencesFromApp());
    ref.listen(localeProvider, (_, _) => _syncPreferencesFromApp());
    ref.listen(activePersonFilterProvider, (_, _) => _syncPreferencesFromApp());
    ref.listen(serverSessionProvider, (previous, next) {
      final session = next.asData?.value;
      if (session == null || !session.isAuthenticated) return;
      final prev = previous?.asData?.value;
      if (prev?.token == session.token &&
          prev?.person?['id'] == session.person?['id'] &&
          state.people.isNotEmpty) {
        return;
      }
      unawaited(
        syncFromServerStore(loggedInPersonId: session.person?['id'] as String?),
      );
    });
    unawaited(_hydrate());
    return const PeopleState();
  }

  Future<void> _hydrate() async {
    var auth = const PeopleAuthStorage();
    String? sessionId;
    String? lastUserId;
    AppUsersStorage? legacyUsers;

    try {
      final authRaw = await _storage.read(key: kPeopleAuthStorageKey);
      if (authRaw != null && authRaw.isNotEmpty) {
        auth = PeopleAuthStorage.decode(authRaw);
      }

      final legacyRaw = await _storage.read(key: _kLegacyAppUsersStorageKey);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        legacyUsers = AppUsersStorage.decode(legacyRaw);
      }

      sessionId = await _storage.read(key: kPeopleSessionKey);
      lastUserId = await _storage.read(key: kPeopleLastUserKey);
      sessionId ??= await _storage.read(key: _kLegacyAppUsersSessionKey);
      lastUserId ??= await _storage.read(key: _kLegacyAppUsersLastUserKey);
    } on Object catch (error, stackTrace) {
      _log.warning(
        'Secure storage unavailable while loading people',
        error,
        stackTrace,
      );
    }

    lastUserId ??= sessionId;

    final localRaw = _prefs.getString(kPeopleConfigPreferenceKey);
    var config = localRaw == null || localRaw.isEmpty
        ? const AccountOwnershipConfig()
        : AccountOwnershipConfig.decode(localRaw, auth: auth);

    final migration = migrateAppUsersIntoPeople(
      existingPeople: config.people,
      legacyUsers: legacyUsers,
      existingAuth: auth,
    );

    if (migration.didMigrate ||
        (legacyUsers != null && legacyUsers.users.isNotEmpty)) {
      config = config.copyWith(people: migration.people);
      auth = migration.auth;
      // Server mode: sealed store is source of truth — never push local
      // hydrate repairs (default requirePasswordLogin: false would lock out).
      if (!_isServerMode) {
        await _persistConfig(config);
        await _persistAuth(auth);
      }
      try {
        await _storage.delete(key: _kLegacyAppUsersStorageKey);
        await _storage.delete(key: _kLegacyAppUsersSessionKey);
        await _storage.delete(key: _kLegacyAppUsersLastUserKey);
      } on Object catch (_) {}
    } else if (auth.byPersonId.isEmpty && config.people.isNotEmpty) {
      // Ownership-only people: seed auth defaults and promote an admin.
      final people = migration.people;
      config = config.copyWith(people: people);
      auth = migration.auth;
      if (!_isServerMode) {
        await _persistConfig(config);
        await _persistAuth(auth);
      }
    }

    // Recover from a prior bug that allowed deleting the last admin.
    if (config.people.isNotEmpty && !peopleHasAdmin(config.people)) {
      config = config.copyWith(people: ensureAtLeastOneAdmin(config.people));
      auth = PeopleAuthStorage(
        byPersonId: {
          for (final person in config.people) person.id: person.toAuthJson(),
        },
        requirePasswordLogin: auth.requirePasswordLogin,
      );
      if (!_isServerMode) {
        await _persistConfig(config);
        await _persistAuth(auth);
      }
    }

    final requirePasswordLogin = auth.requirePasswordLogin;
    final effectiveSessionId = requirePasswordLogin ? null : sessionId;

    if (!ref.mounted) return;
    state = PeopleState(
      config: config,
      requirePasswordLogin: requirePasswordLogin,
      loggedInPersonId: effectiveSessionId,
      lastSessionPersonId: lastUserId,
      isHydrated: true,
    );

    final current = state.currentPerson;
    if (current != null) {
      _applyPersonSession(current);
    }

    unawaited(_fetchRemote());
    if (_isServerMode) {
      final session = ref.read(serverSessionProvider).asData?.value;
      if (session != null && session.isAuthenticated) {
        unawaited(
          syncFromServerStore(
            loggedInPersonId: session.person?['id'] as String?,
          ),
        );
      }
    }
    _log.info('People hydrated: ${config.people.length} person(s)');
  }

  /// Loads people / ownership from the sealed server store (server mode).
  Future<void> syncFromServerStore({String? loggedInPersonId}) async {
    if (!_isServerMode) return;
    final client = ref.read(serverSessionProvider.notifier).client;
    if (client == null || client.sessionToken == null) return;
    try {
      final snap = await client.fetchState();
      await _applyServerPeopleSnapshot(
        snap,
        loggedInPersonId: loggedInPersonId,
      );
    } on Object catch (error, stackTrace) {
      _log.warning('Failed to sync people from server', error, stackTrace);
    }
  }

  Future<void> _applyServerPeopleSnapshot(
    Map<String, dynamic> snap, {
    String? loggedInPersonId,
  }) async {
    final rawPeople = snap['people'];
    if (rawPeople is! List) return;

    final people = <Person>[];
    for (final item in rawPeople) {
      if (item is Map<String, dynamic>) {
        people.add(Person.fromServerPublic(item));
      } else if (item is Map) {
        people.add(
          Person.fromServerPublic(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
      }
    }
    if (people.isEmpty) return;

    final ownerships = <String, AccountOwnership>{};
    final rawOwnerships = snap['accountOwnerships'];
    if (rawOwnerships is List) {
      for (final item in rawOwnerships) {
        if (item is! Map) continue;
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        final ownership = AccountOwnership.fromJson(map);
        if (ownership.accountId.isEmpty) continue;
        ownerships[ownership.accountId] = ownership;
      }
    } else if (rawOwnerships is Map) {
      for (final entry in rawOwnerships.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final map = value.map((k, v) => MapEntry(k.toString(), v));
        final ownership = AccountOwnership.fromJson({
          'accountId': map['accountId'] ?? entry.key.toString(),
          'personShares': map['personShares'] ?? const {},
        });
        ownerships[ownership.accountId] = ownership;
      }
    }

    final requirePasswordLogin = snap['requirePasswordLogin'] as bool? ?? true;
    final config = AccountOwnershipConfig(
      people: people,
      accountOwnerships: ownerships,
    );
    if (!ref.mounted) return;
    state = state.copyWith(
      config: config,
      requirePasswordLogin: requirePasswordLogin,
      loggedInPersonId: loggedInPersonId ?? state.loggedInPersonId,
      lastSessionPersonId: loggedInPersonId ?? state.lastSessionPersonId,
      isHydrated: true,
    );
    await _prefs.setString(kPeopleConfigPreferenceKey, config.encode());
    final current = state.currentPerson;
    if (current != null) {
      _applyPersonSession(current);
    }
    _log.info('People synced from server: ${people.length} person(s)');
  }

  Future<void> _fetchRemote() async {
    if (_isServerMode) return;
    try {
      final service = ref.read(apiServiceProvider);
      if (service == null) return;
      final remote = await service.getPreference(kPeopleConfigPreferenceKey);
      if (remote == null) return;
      final auth = PeopleAuthStorage(
        byPersonId: {for (final p in state.people) p.id: p.toAuthJson()},
        requirePasswordLogin: state.requirePasswordLogin,
      );
      final remoteConfig = remote is Map<String, dynamic>
          ? AccountOwnershipConfig.fromJson(remote, auth: auth)
          : AccountOwnershipConfig.decode(remote.toString(), auth: auth);

      // Keep local auth on matching ids; remote only updates profiles/ownership.
      final localById = {for (final p in state.people) p.id: p};
      final mergedPeople = remoteConfig.people.map((remotePerson) {
        final local = localById[remotePerson.id];
        if (local == null) return remotePerson;
        return remotePerson.copyWith(
          role: local.role,
          passwordHash: local.passwordHash,
          salt: local.salt,
          preferences: local.preferences,
          biometricsEnabled: local.biometricsEnabled,
        );
      }).toList();

      final merged = remoteConfig.copyWith(people: mergedPeople);
      if (!ref.mounted) return;
      state = state.copyWith(config: merged);
      await _prefs.setString(kPeopleConfigPreferenceKey, merged.encode());
    } catch (_) {
      // Offline / error: keep local.
    }
  }

  Future<void> _persistConfig(AccountOwnershipConfig config) async {
    final generation = ++_configWriteGeneration;
    await _prefs.setString(kPeopleConfigPreferenceKey, config.encode());
    if (!ref.mounted) return;
    if (_isServerMode) {
      await _persistConfigToServer(config);
      return;
    }
    try {
      final service = ref.read(apiServiceProvider);
      if (service == null) return;
      await service.setPreference(kPeopleConfigPreferenceKey, config.toJson());
      // A newer local write started while we awaited Firefly — do not leave
      // the remote on this older snapshot.
      if (!ref.mounted) return;
      if (generation != _configWriteGeneration) {
        final latest = state.config;
        await service.setPreference(
          kPeopleConfigPreferenceKey,
          latest.toJson(),
        );
      }
    } on Object catch (error, stackTrace) {
      // Local prefs already hold the config, so this only loses the Firefly
      // mirror. Still worth a line: silence here made an import look inert.
      _log.warning(
        'Failed to mirror people config to Firefly preferences',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _persistConfigToServer(AccountOwnershipConfig config) async {
    if (!ref.mounted) return;
    final client = ref.read(serverSessionProvider.notifier).client;
    if (client == null || client.sessionToken == null) {
      // Silently dropping the write here is how an import can look like it
      // worked and then lose everything on the next load.
      _log.severe(
        'Cannot persist people to server: '
        '${client == null ? "no client" : "no session"}. '
        '${config.people.length} person(s) stayed in memory only.',
      );
      return;
    }
    final passwordUpdates = Map<String, String>.from(_pendingServerPasswords);
    final authImports = <String, Map<String, String>>{};
    for (final person in config.people) {
      if (passwordUpdates.containsKey(person.id)) continue;
      if (!isPortablePasswordMaterial(
        passwordHash: person.passwordHash,
        salt: person.salt,
      )) {
        continue;
      }
      authImports[person.id] = {
        'passwordHash': person.passwordHash!,
        'salt': person.salt!,
      };
    }
    try {
      final snap = await client.putPeople(
        people: config.people
            .map(
              (p) => {
                ...p.toProfileJson(),
                'role': p.role.name,
                'createdAt': p.createdAtIso,
                'preferences': p.preferences.toJson(),
                'biometricsEnabled': p.biometricsEnabled,
              },
            )
            .toList(),
        accountOwnerships: config.accountOwnerships.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        requirePasswordLogin: state.requirePasswordLogin,
        passwordUpdates: passwordUpdates,
        authImports: authImports,
      );
      if (!ref.mounted) return;
      for (final id in passwordUpdates.keys) {
        _pendingServerPasswords.remove(id);
      }
      await _applyServerPeopleSnapshot(
        snap,
        loggedInPersonId: state.loggedInPersonId,
      );
    } on Object catch (error, stackTrace) {
      _log.warning('Failed to persist people to server', error, stackTrace);
    }
  }

  Future<void> _persistAuth(PeopleAuthStorage auth) async {
    try {
      await _storage.write(key: kPeopleAuthStorageKey, value: auth.encode());
    } on Object catch (error, stackTrace) {
      _log.warning('Failed to persist people auth', error, stackTrace);
    }
  }

  Future<void> _persistAuthFromState() async {
    await _persistAuth(
      PeopleAuthStorage(
        byPersonId: {for (final p in state.people) p.id: p.toAuthJson()},
        requirePasswordLogin: state.requirePasswordLogin,
      ),
    );
  }

  Future<void> _persistSession(String? personId) async {
    try {
      if (personId == null) {
        await _storage.delete(key: kPeopleSessionKey);
      } else {
        await _storage.write(key: kPeopleSessionKey, value: personId);
        await _storage.write(key: kPeopleLastUserKey, value: personId);
      }
    } on Object catch (error, stackTrace) {
      _log.warning('Failed to persist people session', error, stackTrace);
    }
  }

  Future<void> _persistLastPerson(String personId) async {
    try {
      await _storage.write(key: kPeopleLastUserKey, value: personId);
    } on Object catch (error, stackTrace) {
      _log.warning('Failed to persist last person id', error, stackTrace);
    }
  }

  Future<void> _setConfig(AccountOwnershipConfig config) async {
    if (!ref.mounted) return;
    state = state.copyWith(config: config);
    await _persistConfig(config);
    if (!ref.mounted) return;
    await _persistAuthFromState();
  }

  bool isNameTaken(String name, {String? excludingId}) {
    final normalized = name.trim().toLowerCase();
    return state.people.any(
      (person) =>
          person.id != excludingId && person.name.toLowerCase() == normalized,
    );
  }

  String _newPersonId() =>
      'person_${DateTime.now().microsecondsSinceEpoch}_${state.people.length}';

  /// Creates a person. First person in an empty list becomes admin.
  Future<Person> addPerson({
    required String name,
    required int colorValue,
    PersonRole? role,
    String? password,
    AvatarKind avatarKind = AvatarKind.none,
    String? avatarValue,
    PersonPreferences? preferences,
  }) async {
    if (isNameTaken(name)) {
      throw ArgumentError('Name is already taken.');
    }
    String? hash;
    String? salt;
    if (password != null && password.isNotEmpty) {
      if (!validatePasswordPolicy(password).isValid) {
        throw ArgumentError('Password does not meet the policy requirements.');
      }
      final hashed = await hashPassword(password);
      hash = hashed.hash;
      salt = hashed.salt;
    }

    final isFirst = state.people.isEmpty;
    final person = Person(
      id: _newPersonId(),
      name: name.trim(),
      colorValue: colorValue,
      avatarKind: avatarKind,
      avatarValue: avatarValue,
      role: role ?? (isFirst ? PersonRole.admin : PersonRole.user),
      passwordHash: hash,
      salt: salt,
      createdAtIso: DateTime.now().toIso8601String(),
      preferences: preferences ?? _seedPreferencesFromDevice(),
    );

    if (_isServerMode && password != null && password.isNotEmpty) {
      _pendingServerPasswords[person.id] = password;
    }

    final updated = state.config.copyWith(people: [...state.people, person]);
    await _setConfig(updated);

    if (isFirst) {
      await _activatePerson(person);
    }
    return person;
  }

  PersonPreferences _seedPreferencesFromDevice() {
    final theme = ref.read(themeProvider);
    final locale = ref.read(localeProvider);
    return PersonPreferences(
      themeModeName: theme.themeMode.name,
      funModeName: theme.funMode.name,
      localeCode: locale.languageCode,
    );
  }

  Future<void> updatePerson(Person updated) async {
    if (isNameTaken(updated.name, excludingId: updated.id)) {
      throw ArgumentError('Name is already taken.');
    }
    if (state.requirePasswordLogin && !updated.hasPassword) {
      throw StateError(
        'Cannot remove password while login with password is enabled.',
      );
    }
    final existing = state.people.where((p) => p.id == updated.id).firstOrNull;
    if (existing != null &&
        existing.role == PersonRole.admin &&
        updated.role != PersonRole.admin &&
        isSoleAdmin(state.people, updated.id)) {
      throw StateError('Cannot demote the only admin.');
    }
    final people = state.people
        .map((p) => p.id == updated.id ? updated : p)
        .toList();
    await _setConfig(state.config.copyWith(people: people));
  }

  Future<void> removePerson(String personId) async {
    if (isSoleAdmin(state.people, personId)) {
      throw StateError('Cannot delete the only admin.');
    }
    final updatedPeople = state.people.where((p) => p.id != personId).toList();
    final updatedOwnerships = <String, AccountOwnership>{};
    for (final entry in state.config.accountOwnerships.entries) {
      final newShares = Map<String, double>.from(entry.value.personShares);
      newShares.remove(personId);
      if (newShares.isNotEmpty) {
        final equalShare = 1.0 / newShares.length;
        for (final k in newShares.keys) {
          newShares[k] = equalShare;
        }
        updatedOwnerships[entry.key] = AccountOwnership(
          accountId: entry.key,
          personShares: newShares,
        );
      }
    }

    final wasCurrent = state.loggedInPersonId == personId;
    final wasLast = state.lastSessionPersonId == personId;

    state = state.copyWith(
      config: state.config.copyWith(
        people: updatedPeople,
        accountOwnerships: updatedOwnerships,
      ),
      clearLoggedInPersonId: wasCurrent,
      clearLastSessionPersonId: wasLast,
    );
    await _persistConfig(state.config);
    await _persistAuthFromState();
    if (wasCurrent) await _persistSession(null);
    if (wasLast) {
      try {
        await _storage.delete(key: kPeopleLastUserKey);
      } on Object catch (_) {}
    }
    await _deleteCustomAvatar(personId);

    if (ref.read(activePersonFilterProvider) == personId) {
      ref.read(activePersonFilterProvider.notifier).clearFilter();
    }
  }

  Future<void> setAccountOwners(
    String accountId, {
    List<String>? ownerIds,
    Map<String, double>? customShares,
  }) async {
    final updatedOwnerships = Map<String, AccountOwnership>.from(
      state.config.accountOwnerships,
    );

    if (customShares != null && customShares.isNotEmpty) {
      updatedOwnerships[accountId] = AccountOwnership(
        accountId: accountId,
        personShares: customShares,
      );
    } else if (ownerIds != null && ownerIds.isNotEmpty) {
      final equalShare = 1.0 / ownerIds.length;
      final shares = <String, double>{
        for (final id in ownerIds) id: equalShare,
      };
      updatedOwnerships[accountId] = AccountOwnership(
        accountId: accountId,
        personShares: shares,
      );
    } else {
      updatedOwnerships.remove(accountId);
    }

    await _setConfig(
      state.config.copyWith(accountOwnerships: updatedOwnerships),
    );
  }

  Future<Person?> login(String name, String password) async {
    final normalized = name.trim().toLowerCase();
    Person? match;
    for (final person in state.people) {
      if (person.name.toLowerCase() == normalized) {
        match = person;
        break;
      }
    }
    if (match == null || !match.hasPassword) return null;
    if (!await verifyPassword(
      password,
      hash: match.passwordHash!,
      salt: match.salt!,
    )) {
      return null;
    }
    await _activatePerson(match);
    return match;
  }

  Future<Person?> loginWithBiometrics({required String localizedReason}) async {
    final person = state.lastSessionPerson;
    if (person == null || !person.biometricsEnabled || !person.hasPassword) {
      return null;
    }
    final ok = await _biometricAuth.authenticate(
      localizedReason: localizedReason,
    );
    if (!ok) return null;
    await _activatePerson(person);
    return person;
  }

  /// Passwordless select when [PeopleState.requirePasswordLogin] is off.
  Future<Person?> selectPerson(String personId) async {
    if (state.requirePasswordLogin) return null;
    Person? match;
    for (final person in state.people) {
      if (person.id == personId) {
        match = person;
        break;
      }
    }
    if (match == null) return null;
    await _activatePerson(match);
    return match;
  }

  Future<void> _activatePerson(Person person) async {
    state = state.copyWith(
      loggedInPersonId: person.id,
      lastSessionPersonId: person.id,
      isHydrated: true,
    );
    await _persistSession(person.id);
    _applyPersonSession(person);
  }

  Future<bool> setBiometricsEnabled(
    String personId, {
    required bool enabled,
    required String localizedReason,
  }) async {
    final person = state.people.firstWhere(
      (p) => p.id == personId,
      orElse: () => throw ArgumentError('Person not found.'),
    );
    if (enabled) {
      if (!person.hasPassword) return false;
      if (!await _biometricAuth.isAvailable) return false;
      final ok = await _biometricAuth.authenticate(
        localizedReason: localizedReason,
      );
      if (!ok) return false;
    }
    await updatePerson(person.copyWith(biometricsEnabled: enabled));
    return true;
  }

  Future<void> logout() async {
    if (state.loggedInPersonId == null) return;
    final lastId = state.loggedInPersonId;
    state = state.copyWith(
      clearLoggedInPersonId: true,
      lastSessionPersonId: lastId,
    );
    await _persistSession(null);
    if (lastId != null) await _persistLastPerson(lastId);
  }

  Future<bool> changePassword(
    String personId, {
    required String oldPassword,
    required String newPassword,
  }) async {
    final person = state.people.firstWhere(
      (p) => p.id == personId,
      orElse: () => throw ArgumentError('Person not found.'),
    );
    if (!person.hasPassword) return false;
    // Server-hydrated people keep password material on the server; local
    // placeholders cannot verify the old password.
    if (!_isServerMode || person.salt != 'server') {
      if (!await verifyPassword(
        oldPassword,
        hash: person.passwordHash!,
        salt: person.salt!,
      )) {
        return false;
      }
    } else {
      final client = ref.read(serverSessionProvider.notifier).client;
      if (client == null) return false;
      final previousToken = client.sessionToken;
      try {
        await client.login(name: person.name, password: oldPassword);
      } on Object {
        return false;
      } finally {
        client.sessionToken = previousToken;
      }
    }
    if (!validatePasswordPolicy(newPassword).isValid) {
      throw ArgumentError('Password does not meet the policy requirements.');
    }
    final hashed = await hashPassword(newPassword);
    if (_isServerMode) {
      _pendingServerPasswords[personId] = newPassword;
    }
    await updatePerson(
      person.copyWith(passwordHash: hashed.hash, salt: hashed.salt),
    );
    return true;
  }

  /// Admin or self: set a password when none exists, or replace without old.
  Future<void> setPassword(String personId, String password) async {
    if (!validatePasswordPolicy(password).isValid) {
      throw ArgumentError('Password does not meet the policy requirements.');
    }
    final person = state.people.firstWhere(
      (p) => p.id == personId,
      orElse: () => throw ArgumentError('Person not found.'),
    );
    final hashed = await hashPassword(password);
    if (_isServerMode) {
      _pendingServerPasswords[personId] = password;
    }
    await updatePerson(
      person.copyWith(passwordHash: hashed.hash, salt: hashed.salt),
    );
  }

  Future<void> clearPassword(String personId) async {
    if (state.requirePasswordLogin) {
      throw StateError(
        'Cannot clear password while login with password is enabled.',
      );
    }
    final person = state.people.firstWhere(
      (p) => p.id == personId,
      orElse: () => throw ArgumentError('Person not found.'),
    );
    await updatePerson(
      person.copyWith(clearPassword: true, biometricsEnabled: false),
    );
  }

  /// Enables password login only when every person has a password.
  /// Returns the list of people still missing passwords (empty = success).
  Future<List<Person>> setRequirePasswordLogin(bool value) async {
    if (value) {
      final missing = state.peopleMissingPasswords;
      if (missing.isNotEmpty) return missing;
    }
    state = state.copyWith(requirePasswordLogin: value);
    await _persistAuthFromState();
    return const [];
  }

  Future<void> saveCustomAvatar(String personId, Uint8List pngBytes) async {
    if (pngBytes.isEmpty || pngBytes.length > kAvatarMaxBytes) {
      throw ArgumentError('Avatar is empty or exceeds 5 MB.');
    }
    final person = state.people.firstWhere(
      (p) => p.id == personId,
      orElse: () => throw ArgumentError('Person not found.'),
    );
    final normalized = normalizeAvatarPng(pngBytes);
    final fileName = '$personId.png';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPrefsKey(personId), base64Encode(normalized));
    // Also write to disk on native platforms for larger local caches.
    if (!kIsWeb) {
      await avatarFileWrite(fileName, normalized);
    }
    await updatePerson(
      person.copyWith(avatarKind: AvatarKind.custom, avatarValue: fileName),
    );
  }

  Future<void> setPresetAvatar(String personId, String presetId) async {
    if (!kAvatarPresets.contains(presetId)) {
      throw ArgumentError('Unknown avatar preset.');
    }
    final person = state.people.firstWhere(
      (p) => p.id == personId,
      orElse: () => throw ArgumentError('Person not found.'),
    );
    await _deleteCustomAvatar(personId);
    await updatePerson(
      person.copyWith(avatarKind: AvatarKind.preset, avatarValue: presetId),
    );
  }

  Future<void> clearAvatar(String personId) async {
    final person = state.people.firstWhere(
      (p) => p.id == personId,
      orElse: () => throw ArgumentError('Person not found.'),
    );
    await _deleteCustomAvatar(personId);
    await updatePerson(
      person.copyWith(avatarKind: AvatarKind.none, clearAvatarValue: true),
    );
  }

  /// Replaces people, ownership, and password-login policy from a settings
  /// import. Restores salted password hashes when present; custom avatars and
  /// biometrics are cleared (device-bound / not in the file).
  Future<void> importSettings({
    required List<Person> people,
    required Map<String, AccountOwnership> accountOwnerships,
    required bool requirePasswordLogin,
  }) async {
    final sanitized = ensureAtLeastOneAdmin(
      people.map((person) {
        final kind = person.avatarKind == AvatarKind.custom
            ? AvatarKind.none
            : person.avatarKind;
        final portable = isPortablePasswordMaterial(
          passwordHash: person.passwordHash,
          salt: person.salt,
        );
        return person.copyWith(
          clearPassword: !portable,
          biometricsEnabled: false,
          avatarKind: kind,
          clearAvatarValue: kind != AvatarKind.preset,
          avatarValue: kind == AvatarKind.preset ? person.avatarValue : null,
        );
      }).toList(),
    );

    final canRequire =
        requirePasswordLogin &&
        sanitized.isNotEmpty &&
        sanitized.every((p) => p.hasPassword);
    if (requirePasswordLogin && !canRequire) {
      _log.info(
        'Imported settings had login-with-password on; leaving it off '
        'because not every person has a portable password hash.',
      );
    }

    _log.info(
      'Importing ${sanitized.length} person(s) and '
      '${accountOwnerships.length} account ownership(s); '
      'serverMode=$_isServerMode',
    );

    final currentId = state.loggedInPersonId;
    final stillExists =
        currentId != null && sanitized.any((p) => p.id == currentId);

    state = state.copyWith(
      config: state.config.copyWith(
        people: sanitized,
        accountOwnerships: accountOwnerships,
      ),
      requirePasswordLogin: canRequire,
      clearLoggedInPersonId: !stillExists,
      isHydrated: true,
    );
    await _persistConfig(state.config);
    await _persistAuthFromState();
    if (!stillExists) {
      await _persistSession(null);
      ref.read(activePersonFilterProvider.notifier).clearFilter();
    } else {
      final current = state.currentPerson;
      if (current != null) _applyPersonSession(current);
    }
    _log.info('Import persisted; now holding ${state.people.length} person(s)');
  }

  Future<Uint8List?> resolveCustomAvatarBytes(Person person) async {
    if (person.avatarKind != AvatarKind.custom) return null;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_avatarPrefsKey(person.id));
    if (encoded != null && encoded.isNotEmpty) {
      return Uint8List.fromList(base64Decode(encoded));
    }
    if (person.avatarValue == null) return null;
    return avatarFileRead(person.avatarValue!);
  }

  Future<void> _deleteCustomAvatar(String personId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarPrefsKey(personId));
    await avatarFileDelete('$personId.png');
  }

  void _applyPersonSession(Person person) {
    final prefs = person.preferences;
    final themeModeName = prefs.themeModeName;
    if (themeModeName != null) {
      final mode = ThemeMode.values.firstWhere(
        (m) => m.name == themeModeName,
        orElse: () => ThemeMode.system,
      );
      ref.read(themeProvider.notifier).setThemeMode(mode);
    }
    final funModeName = prefs.funModeName;
    if (funModeName != null) {
      final mode = FunMode.values.firstWhere(
        (m) => m.name == funModeName,
        orElse: () => FunMode.none,
      );
      ref.read(themeProvider.notifier).setFunMode(mode);
    }
    final localeCode = prefs.localeCode;
    if (localeCode != null) {
      ref
          .read(localeProvider.notifier)
          .setLocale(AppLocale.fromCode(localeCode));
    }
    final filterId = prefs.personFilterId ?? person.id;
    ref.read(activePersonFilterProvider.notifier).setPersonFilter(filterId);
  }

  void _syncPreferencesFromApp() {
    if (!ref.mounted) return;
    final person = state.currentPerson;
    if (person == null) return;
    final theme = ref.read(themeProvider);
    final locale = ref.read(localeProvider);
    final personFilterId = ref.read(activePersonFilterProvider);
    final prefs = PersonPreferences(
      themeModeName: theme.themeMode.name,
      funModeName: theme.funMode.name,
      localeCode: locale.languageCode,
      personFilterId: personFilterId,
    );
    if (prefs == person.preferences) return;
    unawaited(() async {
      if (!ref.mounted) return;
      await updatePerson(person.copyWith(preferences: prefs));
    }());
  }
}

final peopleProvider = NotifierProvider<PeopleNotifier, PeopleState>(
  PeopleNotifier.new,
);

/// Back-compat alias used while widgets migrate off the old name.
final peopleSettingsProvider = Provider<AccountOwnershipConfig>((ref) {
  return ref.watch(peopleProvider).config;
});

final currentPersonProvider = Provider<Person?>((ref) {
  return ref.watch(peopleProvider).currentPerson;
});

final canWriteFinancialDataProvider = Provider<bool>((ref) {
  final state = ref.watch(peopleProvider);
  return permissions.canWriteFinancialData(
    peopleEnabled: state.isEnabled,
    role: state.currentPerson?.role,
  );
});

final canManagePeopleProvider = Provider<bool>((ref) {
  final state = ref.watch(peopleProvider);
  return permissions.canManagePeople(
    peopleEnabled: state.isEnabled,
    role: state.currentPerson?.role,
  );
});

final canManageFireflyConnectionProvider = Provider<bool>((ref) {
  final state = ref.watch(peopleProvider);
  return permissions.canManageFireflyConnection(
    peopleEnabled: state.isEnabled,
    role: state.currentPerson?.role,
  );
});

/// Accounts the filtered person has a stake in, at the balance the bank holds.
///
/// A jointly held account still contains all of its money, so that is what the
/// accounts, transactions and projection views report. Only the person's share
/// of it counts towards their net worth, which is what
/// [shareWeightedAccountsProvider] is for.
final ownedAccountsProvider = Provider<List<Account>>((ref) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  final config = ref.watch(peopleProvider).config;
  final activePersonId = ref.watch(activePersonFilterProvider);

  if (activePersonId == null) return accounts;

  return [
    for (final account in accounts)
      if (config.getOwnershipRatio(account.id, activePersonId) > 0.0) account,
  ];
});

/// The same accounts with each balance cut to the person's share of it.
///
/// Only for net worth and debt, where the question is how much of it is theirs.
/// Anywhere a balance is presented as the account's own, use
/// [ownedAccountsProvider]: showing half of a joint account as its balance
/// makes the account look like it holds money it does not.
final shareWeightedAccountsProvider = Provider<List<Account>>((ref) {
  final config = ref.watch(peopleProvider).config;
  final activePersonId = ref.watch(activePersonFilterProvider);
  final owned = ref.watch(ownedAccountsProvider);

  if (activePersonId == null) return owned;

  return [
    for (final account in owned)
      account.copyWith(
        currentBalance:
            account.currentBalance *
            config.getOwnershipRatio(account.id, activePersonId),
      ),
  ];
});

final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactions =
      ref.watch(transactionsProvider).asData?.value ?? const [];
  final config = ref.watch(peopleProvider).config;
  final activePersonId = ref.watch(activePersonFilterProvider);

  if (activePersonId == null) {
    return transactions;
  }

  return transactions.where((tx) {
    final sourceId = tx.sourceId;
    final destId = tx.destinationId;
    final sourceRatio = sourceId != null
        ? config.getOwnershipRatio(sourceId, activePersonId)
        : 0.0;
    final destRatio = destId != null
        ? config.getOwnershipRatio(destId, activePersonId)
        : 0.0;
    return sourceRatio > 0.0 || destRatio > 0.0;
  }).toList();
});
