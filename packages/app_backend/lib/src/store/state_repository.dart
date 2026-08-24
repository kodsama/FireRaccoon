import 'package:fireracoon_engine/utils/agent_key.dart' as keys;

import '../crypto/passwords.dart';
import '../crypto/sealed_store.dart';
import 'app_state.dart';

/// Loads and persists [AppState] through [SealedStore].
class StateRepository {
  StateRepository(this._store);

  static const statePath = 'state';

  final SealedStore _store;
  AppState _state = AppState();

  AppState get state => _state;
  SealedStore get store => _store;

  Future<void> load() async {
    final raw = await _store.readJson(statePath);
    if (raw is Map<String, dynamic>) {
      _state = AppState.fromJson(raw);
    } else if (raw is Map) {
      _state = AppState.fromJson(raw.map((k, v) => MapEntry(k.toString(), v)));
    } else {
      _state = AppState();
      await save();
    }
  }

  Future<void> save() => _store.writeJson(statePath, _state.toJson());

  Future<void> applyBootstrap({
    String? fireflyUrl,
    String? fireflyToken,
  }) async {
    var changed = false;
    if (fireflyUrl != null &&
        fireflyUrl.isNotEmpty &&
        _state.firefly.url.isEmpty) {
      _state.firefly.url = fireflyUrl;
      changed = true;
    }
    if (fireflyToken != null &&
        fireflyToken.isNotEmpty &&
        _state.firefly.token.isEmpty) {
      _state.firefly.token = fireflyToken;
      changed = true;
    }
    if (changed) await save();
  }

  Future<Map<String, dynamic>> setup({
    required String adminName,
    required String adminPassword,
    required String fireflyUrl,
    required String fireflyToken,
    bool allowInsecure = false,
  }) async {
    if (_state.people.isNotEmpty) {
      throw StateError('Setup already completed');
    }
    if (adminName.trim().isEmpty) {
      throw ArgumentError('adminName is required');
    }
    if (adminPassword.length < 10) {
      throw ArgumentError('adminPassword must be at least 10 characters');
    }
    if (fireflyUrl.trim().isEmpty || fireflyToken.trim().isEmpty) {
      throw ArgumentError('fireflyUrl and fireflyToken are required');
    }

    final id = newId();
    final password = await hashPassword(adminPassword);
    final person = <String, dynamic>{
      'id': id,
      'name': adminName.trim(),
      'colorValue': 0xFF1565C0,
      'avatarKind': 'none',
      'role': 'admin',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'preferences': <String, dynamic>{},
    };
    _state.people = [person];
    _state.authByPersonId[id] = {
      'role': 'admin',
      'passwordHash': password.hash,
      'passwordSalt': password.salt,
      'preferences': <String, dynamic>{},
      'biometricsEnabled': false,
    };
    _state.requirePasswordLogin = true;
    _state.firefly = FireflyConnection(
      url: fireflyUrl.trim(),
      token: fireflyToken.trim(),
      allowInsecure: allowInsecure,
    );
    await save();
    return person;
  }

  /// Admin-only backup payload: Firefly PAT + salted password hashes.
  ///
  /// Used by settings export so server mode can seal the same secrets blob as
  /// local mode. Never include this in the public `/api/state` snapshot.
  Map<String, dynamic> backupSecretsForAdmin() {
    final peopleAuth = <String, Map<String, String>>{};
    for (final entry in _state.authByPersonId.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final auth = raw.map((k, v) => MapEntry(k.toString(), v));
      final hash = auth['passwordHash'] as String?;
      final salt = auth['passwordSalt'] as String?;
      if (hash == null || hash.isEmpty || salt == null || salt.isEmpty) {
        continue;
      }
      peopleAuth[entry.key] = {'passwordHash': hash, 'salt': salt};
    }
    return {
      'firefly': {
        'url': _state.firefly.url,
        'token': _state.firefly.token,
        'allowInsecure': _state.firefly.allowInsecure,
      },
      'requirePasswordLogin': _state.requirePasswordLogin,
      'peopleAuth': peopleAuth,
    };
  }

  /// Replaces people profiles, ownerships, and optional password updates.
  ///
  /// Existing password hashes are kept unless [passwordUpdates] supplies a
  /// new plaintext password for that person id, or [authImports] supplies a
  /// portable hash/salt pair (settings import from local or another server).
  Future<void> replacePeopleConfig({
    required List<Map<String, dynamic>> people,
    required List<Map<String, dynamic>> accountOwnerships,
    required bool requirePasswordLogin,
    Map<String, String> passwordUpdates = const {},
    Map<String, Map<String, String>> authImports = const {},
  }) async {
    if (people.isEmpty) {
      throw ArgumentError('At least one person is required');
    }
    final previousAuth = Map<String, dynamic>.from(_state.authByPersonId);
    final nextAuth = <String, dynamic>{};
    final nextPeople = <Map<String, dynamic>>[];

    for (final raw in people) {
      final id = (raw['id'] as String?)?.trim() ?? '';
      final name = (raw['name'] as String?)?.trim() ?? '';
      if (id.isEmpty || name.isEmpty) {
        throw ArgumentError('Each person needs id and name');
      }
      final role = (raw['role'] as String?) ?? 'user';
      final prev = previousAuth[id];
      final prevMap = prev is Map
          ? prev.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};

      var passwordHash = prevMap['passwordHash'] as String?;
      var passwordSalt = prevMap['passwordSalt'] as String?;
      final plaintext = passwordUpdates[id];
      if (plaintext != null && plaintext.isNotEmpty) {
        if (plaintext.length < 10) {
          throw ArgumentError('Password must be at least 10 characters');
        }
        final hashed = await hashPassword(plaintext);
        passwordHash = hashed.hash;
        passwordSalt = hashed.salt;
      } else {
        final imported = authImports[id];
        if (imported != null) {
          final hash = imported['passwordHash']?.trim() ?? '';
          final salt =
              (imported['salt'] ?? imported['passwordSalt'])?.trim() ?? '';
          if (hash.isEmpty || salt.isEmpty) {
            throw ArgumentError(
              'authImports for $id needs passwordHash and salt',
            );
          }
          if (hash == 'server' || salt == 'server') {
            throw ArgumentError(
              'authImports cannot use server password placeholders',
            );
          }
          passwordHash = hash;
          passwordSalt = salt;
        }
      }

      nextPeople.add({
        'id': id,
        'name': name,
        'colorValue': raw['colorValue'] as int? ?? 0xFF1565C0,
        'avatarKind': raw['avatarKind'] as String? ?? 'none',
        if (raw['avatarValue'] != null) 'avatarValue': raw['avatarValue'],
        'role': role,
        'createdAt':
            raw['createdAt'] as String? ??
            raw['createdAtIso'] as String? ??
            DateTime.now().toUtc().toIso8601String(),
        'preferences':
            (raw['preferences'] as Map?)?.cast<String, dynamic>() ??
            (prevMap['preferences'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      });
      nextAuth[id] = {
        'role': role,
        'passwordHash': ?passwordHash,
        'passwordSalt': ?passwordSalt,
        'preferences':
            (raw['preferences'] as Map?)?.cast<String, dynamic>() ??
            (prevMap['preferences'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
        'biometricsEnabled':
            raw['biometricsEnabled'] as bool? ??
            prevMap['biometricsEnabled'] == true,
      };
    }

    if (!nextPeople.any((p) => p['role'] == 'admin')) {
      throw ArgumentError('At least one admin is required');
    }

    final previousHadPassword = previousAuth.values.any((value) {
      if (value is! Map) return false;
      return _authEntryHasPassword(
        value.map((k, v) => MapEntry(k.toString(), v)),
      );
    });
    final nextHasPassword = nextAuth.values.any((value) {
      if (value is! Map) return false;
      return _authEntryHasPassword(
        value.map((k, v) => MapEntry(k.toString(), v)),
      );
    });
    if (previousHadPassword && !nextHasPassword) {
      throw ArgumentError('Cannot remove the last remaining password');
    }
    if (requirePasswordLogin && !nextHasPassword) {
      throw ArgumentError('Password login requires at least one password');
    }

    _state.people = nextPeople;
    _state.peopleAuth = {
      'byPersonId': nextAuth,
      'requirePasswordLogin': requirePasswordLogin,
    };
    _state.accountOwnerships = accountOwnerships;
    await save();
  }

  static bool _authEntryHasPassword(Map<String, dynamic> auth) {
    final hash = auth['passwordHash'];
    final salt = auth['passwordSalt'];
    return hash is String &&
        hash.isNotEmpty &&
        salt is String &&
        salt.isNotEmpty;
  }

  /// Stand-ins so a login for a name nobody has still pays for a derivation.
  ///
  /// Any well-formed salt and hash will do: the comparison is meant to fail, and
  /// what matters is that it costs the same as a real one.
  static const String _absentPersonSalt = 'AAAAAAAAAAAAAAAAAAAAAA==';
  static const String _absentPersonHash =
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

  Future<({String token, Map<String, dynamic> person})> login({
    required String name,
    required String password,
  }) async {
    final person = _state.people.cast<Map<String, dynamic>?>().firstWhere(
      (p) =>
          (p?['name'] as String?)?.toLowerCase() == name.trim().toLowerCase(),
      orElse: () => null,
    );
    // A name nobody has answered before the derivation ran, and a real one
    // answered a second later, which told a caller which names exist. The
    // derivation happens either way now, against a throwaway hash when there is
    // nothing to check, so the two take the same time.
    final id = person?['id'] as String?;
    final auth = id == null
        ? null
        : _state.authByPersonId[id] as Map<String, dynamic>?;
    final hash = auth?['passwordHash'] as String?;
    final salt = auth?['passwordSalt'] as String?;
    final ok = await verifyPassword(
      password: password,
      hash: hash ?? _absentPersonHash,
      salt: salt ?? _absentPersonSalt,
    );
    if (person == null || hash == null || salt == null || !ok) {
      throw StateError('Invalid credentials');
    }

    final token = newSessionToken();
    final tokenHash = hashSessionToken(token);
    _state.sessions[tokenHash] = {
      'personId': id,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await save();
    return (token: token, person: _publicPerson(person, auth));
  }

  Future<void> logout(String? sessionToken) async {
    if (sessionToken == null || sessionToken.isEmpty) return;
    _state.sessions.remove(hashSessionToken(sessionToken));
    await save();
  }

  /// Resolves a bearer to its person. Accepts both credential kinds a client
  /// may hold: a browser/app session token, or an MCP agent key.
  Map<String, dynamic>? personForSession(String? sessionToken) {
    if (sessionToken == null || sessionToken.isEmpty) return null;
    final session = _state.sessions[hashSessionToken(sessionToken)];
    if (session is! Map) {
      final identity = identityForAgentKey(sessionToken);
      return identity == null ? null : _personById(identity.personId);
    }
    final personId = session['personId'] as String?;
    if (personId == null) return null;
    return _personById(personId);
  }

  String? roleForSession(String? sessionToken) {
    return personForSession(sessionToken)?['role'] as String?;
  }

  Map<String, dynamic>? _personById(String personId) {
    final person = _state.people.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['id'] == personId,
      orElse: () => null,
    );
    if (person == null) return null;
    final auth = _state.authByPersonId[personId] as Map<String, dynamic>?;
    return _publicPerson(person, auth);
  }

  List<keys.AgentKey> get _agentKeys => [
    for (final raw in _state.agentKeys) ?keys.AgentKey.fromJson(raw),
  ];

  keys.AgentKeyPerson? _keyPerson(String personId) {
    final person = _state.people.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['id'] == personId,
      orElse: () => null,
    );
    if (person == null) return null;
    return keys.AgentKeyPerson(
      id: personId,
      name: person['name'] as String? ?? '',
      role: person['role'] as String? ?? 'viewer',
    );
  }

  /// Identity an MCP agent key grants, or null when it is not a valid key.
  keys.AgentIdentity? identityForAgentKey(String? key) {
    return keys.resolveAgentKey(key, keys: _agentKeys, person: _keyPerson);
  }

  /// Keys visible to [sessionToken]: an admin sees every key, anyone else sees
  /// only the keys issued to them.
  List<Map<String, dynamic>> agentKeysFor(String? sessionToken) {
    final person = personForSession(sessionToken);
    if (person == null) return const [];
    final personId = person['id'] as String?;
    final all = isAdmin(sessionToken);
    return [
      for (final key in _agentKeys)
        if (all || key.personId == personId) key.toPublicJson().cast(),
    ];
  }

  /// Reveals the secret of [keyId], or null when it is not readable.
  ///
  /// Owner-only, deliberately narrower than [agentKeysFor]: an admin can see
  /// that someone else has a key and revoke it, but reading their credential is
  /// not part of administering them. Returns null for a key issued before
  /// secrets were retained, which has to be reissued instead.
  String? agentKeySecret({
    required String? sessionToken,
    required String keyId,
  }) {
    final person = personForSession(sessionToken);
    final personId = person?['id'] as String?;
    if (personId == null) return null;
    // An agent key must not be able to read any secret, including its own:
    // that would let one leaked key enumerate the rest of its person's keys.
    if (identityForAgentKey(sessionToken) != null) return null;
    for (final key in _agentKeys) {
      if (key.id == keyId && key.personId == personId) return key.secret;
    }
    return null;
  }

  /// Mints a key for the caller's own account. The secret is returned once here
  /// and stays readable afterwards through [agentKeySecret].
  Future<({String secret, Map<String, dynamic> key})> issueAgentKey({
    required String? sessionToken,
    required String label,
  }) async {
    final person = personForSession(sessionToken);
    final personId = person?['id'] as String?;
    if (personId == null) {
      throw StateError('Unauthorized');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError('label is required');
    }
    final issued = keys.issueAgentKey(
      personId: personId,
      label: label,
      id: newId(),
      now: DateTime.now().toUtc(),
    );
    _state.agentKeys.add(issued.record.toJson().cast<String, dynamic>());
    await save();
    return (
      secret: issued.secret,
      key: issued.record.toPublicJson().cast<String, dynamic>(),
    );
  }

  /// Revokes [keyId]. A person may revoke their own keys; admins may revoke any.
  Future<bool> revokeAgentKey({
    required String? sessionToken,
    required String keyId,
  }) async {
    final person = personForSession(sessionToken);
    final personId = person?['id'] as String?;
    if (personId == null) return false;
    final index = _state.agentKeys.indexWhere((raw) => raw['id'] == keyId);
    if (index < 0) return false;
    final owner = _state.agentKeys[index]['personId'] as String?;
    if (owner != personId && !isAdmin(sessionToken)) return false;
    if (_state.agentKeys[index]['revokedAt'] != null) return true;
    _state.agentKeys[index]['revokedAt'] = DateTime.now()
        .toUtc()
        .toIso8601String();
    await save();
    return true;
  }

  /// Records that [key] was just used, if it is a valid agent key.
  ///
  /// Throttled by [kAgentKeyUsageInterval]: a chatty agent would otherwise
  /// rewrite the encrypted store on every call. The in-memory record and the
  /// store wait for the interval together, so `/api/agent-keys` can report a
  /// stamp up to that interval old.
  Future<void> touchAgentKey(String? key, {DateTime? now}) async {
    final identity = identityForAgentKey(key);
    if (identity == null) return;
    final index = _state.agentKeys.indexWhere(
      (raw) => raw['id'] == identity.keyId,
    );
    if (index < 0) return;

    final at = (now ?? DateTime.now()).toUtc();
    final previous = DateTime.tryParse(
      _state.agentKeys[index]['lastUsedAt'] as String? ?? '',
    );
    if (!keys.shouldRecordAgentKeyUse(previous, at)) return;
    _state.agentKeys[index]['lastUsedAt'] = at.toIso8601String();
    await save();
  }

  /// Deletes a revoked key's record. A person may forget their own; admins may
  /// forget any.
  ///
  /// Revoked only: dropping a live key's record would revoke it as a side
  /// effect, and those are separate intentions.
  Future<bool> forgetAgentKey({
    required String? sessionToken,
    required String keyId,
  }) async {
    final person = personForSession(sessionToken);
    final personId = person?['id'] as String?;
    if (personId == null) return false;
    final index = _state.agentKeys.indexWhere((raw) => raw['id'] == keyId);
    if (index < 0) return false;
    final raw = _state.agentKeys[index];
    if (raw['personId'] != personId && !isAdmin(sessionToken)) return false;
    if (raw['revokedAt'] == null) return false;
    _state.agentKeys.removeAt(index);
    await save();
    return true;
  }

  /// Drops the keys of a person who no longer exists, so a recycled person id
  /// cannot inherit their agent access.
  Future<void> pruneAgentKeys() async {
    final ids = _state.people.map((p) => p['id']).toSet();
    final before = _state.agentKeys.length;
    _state.agentKeys.removeWhere((raw) => !ids.contains(raw['personId']));
    if (_state.agentKeys.length != before) await save();
  }

  bool canWrite(String? sessionToken) {
    final role = roleForSession(sessionToken);
    return role == 'admin' || role == 'user';
  }

  bool isAdmin(String? sessionToken) => roleForSession(sessionToken) == 'admin';

  Map<String, dynamic> snapshotForClient({String? sessionToken}) {
    final me = personForSession(sessionToken);
    return {
      'setupRequired': _state.setupRequired,
      'firefly': _state.firefly.toPublicJson(),
      'people': _state.people.map((p) {
        final auth = _state.authByPersonId[p['id']] as Map<String, dynamic>?;
        return _publicPerson(p, auth);
      }).toList(),
      'accountOwnerships': _state.accountOwnerships,
      'requirePasswordLogin': _state.requirePasswordLogin,
      'devicePrefs': _state.devicePrefs,
      'classifications': _state.classifications,
      'sideMenu': _state.sideMenu,
      'accountColumns': _state.accountColumns,
      'transactionColumns': _state.transactionColumns,
      'viewMode': _state.viewMode,
      'prognosis': _state.prognosis,
      'undo': _state.undo,
      'me': me,
      'avatars': _state.avatars.keys.toList(),
    };
  }

  Map<String, dynamic> _publicPerson(
    Map<String, dynamic> person,
    Map<String, dynamic>? auth,
  ) {
    return {
      ...person,
      'hasPassword':
          (auth?['passwordHash'] as String?)?.isNotEmpty == true &&
          (auth?['passwordSalt'] as String?)?.isNotEmpty == true,
      'preferences':
          auth?['preferences'] ?? person['preferences'] ?? <String, dynamic>{},
      'biometricsEnabled': auth?['biometricsEnabled'] == true,
    };
  }
}
