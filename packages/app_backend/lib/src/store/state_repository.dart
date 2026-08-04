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

  Future<({String token, Map<String, dynamic> person})> login({
    required String name,
    required String password,
  }) async {
    final person = _state.people.cast<Map<String, dynamic>?>().firstWhere(
      (p) =>
          (p?['name'] as String?)?.toLowerCase() == name.trim().toLowerCase(),
      orElse: () => null,
    );
    if (person == null) {
      throw StateError('Invalid credentials');
    }
    final id = person['id'] as String;
    final auth = _state.authByPersonId[id] as Map<String, dynamic>?;
    final hash = auth?['passwordHash'] as String?;
    final salt = auth?['passwordSalt'] as String?;
    if (hash == null || salt == null) {
      throw StateError('Invalid credentials');
    }
    final ok = await verifyPassword(password: password, hash: hash, salt: salt);
    if (!ok) {
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

  Map<String, dynamic>? personForSession(String? sessionToken) {
    if (sessionToken == null || sessionToken.isEmpty) return null;
    final session = _state.sessions[hashSessionToken(sessionToken)];
    if (session is! Map) return null;
    final personId = session['personId'] as String?;
    if (personId == null) return null;
    final person = _state.people.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['id'] == personId,
      orElse: () => null,
    );
    if (person == null) return null;
    final auth = _state.authByPersonId[personId] as Map<String, dynamic>?;
    return _publicPerson(person, auth);
  }

  String? roleForSession(String? sessionToken) {
    return personForSession(sessionToken)?['role'] as String?;
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
