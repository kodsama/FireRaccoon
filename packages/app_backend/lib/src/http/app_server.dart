import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import '../config.dart';
import '../crypto/sealed_store.dart';
import '../store/state_repository.dart';

const _sessionCookie = 'fireracoon_session';
const _sessionHeader = 'x-fireracoon-session';
const _minDataPasswordLength = 10;

/// Builds and serves the FireRacoon server-mode HTTP API + static web UI.
///
/// When [DATA_PASSWORD] is unset, the process starts **locked** and the UI
/// collects the password via [POST /api/store/unlock] (create or unlock).
class AppServer {
  AppServer({required this.config, this._repository, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final ServerConfig config;
  StateRepository? _repository;
  final http.Client _http;

  StateRepository get repository {
    final repo = _repository;
    if (repo == null) {
      throw StateError('Encrypted store is locked');
    }
    return repo;
  }

  bool get isStoreLocked => _repository == null;

  bool get storeExists => SealedStore.exists(config.dataDir);

  /// Starts unlocked when [config.dataPassword] is set; otherwise locked until
  /// [unlockStore] is called from the UI.
  ///
  /// Env [DATA_PASSWORD] is treated as confirmed: empty [DATA_DIR] creates a
  /// new sealed store on boot (Docker first start).
  static Future<AppServer> open(ServerConfig config) async {
    final server = AppServer(config: config);
    final password = config.dataPassword;
    if (password != null && password.isNotEmpty) {
      await server.unlockStore(password: password, confirmPassword: password);
    }
    return server;
  }

  Future<void> unlockStore({
    required String password,
    String? confirmPassword,
  }) async {
    if (password.length < _minDataPasswordLength) {
      throw ArgumentError(
        'Password must be at least $_minDataPasswordLength characters',
      );
    }
    final exists = SealedStore.exists(config.dataDir);
    if (exists) {
      // Existing encrypted DATA_DIR: unlock only (no create).
    } else {
      // Empty DATA_DIR: create a new sealed store (require confirmation).
      if (confirmPassword == null || confirmPassword != password) {
        throw ArgumentError('Password confirmation does not match');
      }
    }
    final sealed = await SealedStore.open(
      dataDirPath: config.dataDir,
      password: password,
    );
    final repo = StateRepository(sealed);
    await repo.load();
    await repo.applyBootstrap(
      fireflyUrl: config.bootstrapFireflyUrl,
      fireflyToken: config.bootstrapFireflyToken,
    );
    _repository = repo;
  }

  Handler get handler {
    final api = Router()
      ..get('/api/capabilities', _capabilities)
      ..get('/config.json', _configJson)
      ..post('/api/store/unlock', _unlock)
      ..post('/api/setup', _setup)
      ..post('/api/login', _login)
      ..post('/api/logout', _logout)
      ..get('/api/me', _me)
      ..get('/api/state', _state)
      ..get('/api/state/backup-secrets', _backupSecrets)
      ..put('/api/state/device-prefs', _putDevicePrefs)
      ..put('/api/state/classifications', _putClassifications)
      ..put('/api/state/side-menu', _putSideMenu)
      ..put('/api/state/account-columns', _putAccountColumns)
      ..put('/api/state/transaction-columns', _putTransactionColumns)
      ..put('/api/state/view-mode', _putViewMode)
      ..put('/api/state/prognosis', _putPrognosis)
      ..put('/api/state/undo', _putUndo)
      ..put('/api/state/firefly', _putFirefly)
      ..put('/api/state/people', _putPeople)
      ..get('/api/agent-keys', _listAgentKeys)
      ..post('/api/agent-keys', _issueAgentKey)
      ..get('/api/agent-keys/<keyId>/secret', _revealAgentKey)
      ..delete('/api/agent-keys/<keyId>/record', _forgetAgentKey)
      ..delete('/api/agent-keys/<keyId>', _revokeAgentKey)
      ..get('/api/avatars/<personId>', _getAvatar)
      ..put('/api/avatars/<personId>', _putAvatar)
      ..all('/api/firefly/<path|.*>', _fireflyProxyTagged)
      ..all('/api/firefly', _fireflyProxyRoot);

    var cascade = Cascade().add(api.call);
    final webRoot = Directory(config.webRoot);
    if (webRoot.existsSync()) {
      cascade = cascade
          .add(
            createStaticHandler(
              config.webRoot,
              defaultDocument: 'index.html',
              listDirectories: false,
            ),
          )
          .add((request) async {
            final index = File(p.join(config.webRoot, 'index.html'));
            if (!index.existsSync()) {
              return Response.notFound('Not found');
            }
            return Response.ok(
              await index.readAsBytes(),
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          });
    }

    return Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_cors)
        .addMiddleware(_recordAgentKeyUse)
        .addHandler(cascade.handler);
  }

  Future<HttpServer> serve() {
    return shelf_io.serve(handler, InternetAddress.anyIPv4, config.port);
  }

  /// Stamps `lastUsedAt` on whichever agent key carried this request.
  ///
  /// One middleware rather than a call per handler, so the Firefly proxy counts
  /// as use too: a long-running agent that only reads should not look idle.
  /// Runs after the handler, so a rejected key leaves no trace.
  Middleware get _recordAgentKeyUse => (inner) {
    return (request) async {
      final response = await inner(request);
      if (isStoreLocked) return response;
      try {
        await repository.touchAgentKey(_session(request));
      } on Object {
        // A usage stamp is bookkeeping: never fail a served request over it.
      }
      return response;
    };
  };

  Middleware get _cors => (inner) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await inner(request);
      return response.change(headers: {...response.headers, ..._corsHeaders});
    };
  };

  static const _corsHeaders = {
    'access-control-allow-origin': '*',
    'access-control-allow-headers':
        'authorization, content-type, x-fireracoon-session',
    'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'access-control-expose-headers': 'set-cookie',
  };

  Map<String, Object?> get _storeStatus => {
    'storeLocked': isStoreLocked,
    'storeExists': storeExists,
    'setupRequired': isStoreLocked ? true : repository.state.setupRequired,
  };

  Response? _lockedResponse() {
    if (!isStoreLocked) return null;
    return _json({
      'ok': false,
      'error': 'Encrypted store is locked',
      'code': 'store_locked',
      ..._storeStatus,
    }, status: 503);
  }

  String? _session(Request request) {
    final repo = _repository;
    if (repo == null) return null;
    final header = request.headers[_sessionHeader];
    if (header != null && header.isNotEmpty) return header;
    final auth = request.headers['authorization'];
    if (auth != null && auth.toLowerCase().startsWith('bearer ')) {
      final token = auth.substring(7).trim();
      if (token.isNotEmpty && repo.personForSession(token) != null) {
        return token;
      }
    }
    final cookie = request.headers['cookie'];
    if (cookie == null) return null;
    for (final part in cookie.split(';')) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$_sessionCookie=')) {
        return trimmed.substring(_sessionCookie.length + 1);
      }
    }
    return null;
  }

  Response _json(
    Object? body, {
    int status = 200,
    Map<String, String>? headers,
  }) {
    return Response(
      status,
      body: const JsonEncoder.withIndent('  ').convert(body),
      headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
    );
  }

  Future<Response> _capabilities(Request request) async {
    return _json({'deployment': 'server', 'mode': 'server', ..._storeStatus});
  }

  Future<Response> _configJson(Request request) async {
    return _json({
      'FIRERACOON_MODE': 'server',
      'mode': 'server',
      ..._storeStatus,
    });
  }

  Future<Response> _unlock(Request request) async {
    if (!isStoreLocked) {
      return _json({'ok': true, 'alreadyUnlocked': true, ..._storeStatus});
    }
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final password = body['password'] as String? ?? '';
      final confirm = body['confirmPassword'] as String?;
      await unlockStore(password: password, confirmPassword: confirm);
      return _json({'ok': true, ..._storeStatus});
    } on ArgumentError catch (e) {
      return _json({'ok': false, 'error': e.message}, status: 400);
    } on StateError catch (e) {
      return _json({'ok': false, 'error': e.message}, status: 401);
    }
  }

  Future<Response> _setup(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    if (repository.state.people.isNotEmpty) {
      return _json({
        'ok': false,
        'error': 'Setup already completed',
      }, status: 409);
    }
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final person = await repository.setup(
        adminName: body['adminName'] as String? ?? '',
        adminPassword: body['adminPassword'] as String? ?? '',
        fireflyUrl: body['fireflyUrl'] as String? ?? '',
        fireflyToken: body['fireflyToken'] as String? ?? '',
        allowInsecure: body['allowInsecure'] as bool? ?? false,
      );
      final login = await repository.login(
        name: person['name'] as String,
        password: body['adminPassword'] as String,
      );
      return _json(
        {'ok': true, 'person': login.person, 'sessionToken': login.token},
        headers: {
          'set-cookie':
              '$_sessionCookie=${login.token}; Path=/; HttpOnly; SameSite=Lax',
        },
      );
    } on ArgumentError catch (e) {
      return _json({'ok': false, 'error': e.message}, status: 400);
    } on StateError catch (e) {
      return _json({'ok': false, 'error': e.message}, status: 409);
    }
  }

  Future<Response> _login(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final login = await repository.login(
        name: body['name'] as String? ?? '',
        password: body['password'] as String? ?? '',
      );
      return _json(
        {'ok': true, 'person': login.person, 'sessionToken': login.token},
        headers: {
          'set-cookie':
              '$_sessionCookie=${login.token}; Path=/; HttpOnly; SameSite=Lax',
        },
      );
    } on StateError catch (e) {
      return _json({'ok': false, 'error': e.message}, status: 401);
    }
  }

  Future<Response> _logout(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    await repository.logout(_session(request));
    return _json(
      {'ok': true},
      headers: {
        'set-cookie':
            '$_sessionCookie=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax',
      },
    );
  }

  Future<Response> _me(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final token = _session(request);
    final person = repository.personForSession(token);
    if (person == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    // MCP clients authenticate here to learn which account and role their key
    // grants before they start calling tools.
    final identity = repository.identityForAgentKey(token);
    return _json({
      'ok': true,
      'person': person,
      if (identity != null) 'agentKeyId': identity.keyId,
    });
  }

  Future<Response> _listAgentKeys(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (repository.personForSession(session) == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    return _json({'ok': true, 'keys': repository.agentKeysFor(session)});
  }

  Future<Response> _issueAgentKey(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (repository.personForSession(session) == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    // An agent key must not be able to mint more keys: that would turn one
    // leaked secret into permanent access no revocation could reach.
    if (repository.identityForAgentKey(session) != null) {
      return _json({
        'ok': false,
        'error': 'Agent keys cannot issue agent keys',
      }, status: 403);
    }
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final issued = await repository.issueAgentKey(
        sessionToken: session,
        label: body['label'] as String? ?? '',
      );
      // The only time the secret is ever readable.
      return _json({
        'ok': true,
        'key': issued.key,
        'secret': issued.secret,
      }, status: 201);
    } on ArgumentError catch (e) {
      return _json({'ok': false, 'error': e.message}, status: 400);
    } on StateError catch (e) {
      return _json({'ok': false, 'error': e.message}, status: 401);
    }
  }

  Future<Response> _revealAgentKey(Request request, String keyId) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (repository.personForSession(session) == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    final secret = repository.agentKeySecret(
      sessionToken: session,
      keyId: keyId,
    );
    if (secret == null) {
      // Same answer for "not yours", "no such key", and "issued before secrets
      // were kept": none of them should confirm another person's key exists.
      return _json({'ok': false, 'error': 'Not found'}, status: 404);
    }
    return _json({'ok': true, 'secret': secret});
  }

  /// Deletes a revoked key's record. Revoking is [_revokeAgentKey]; this is the
  /// separate step of clearing it from the list afterwards.
  Future<Response> _forgetAgentKey(Request request, String keyId) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (repository.personForSession(session) == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    final forgotten = await repository.forgetAgentKey(
      sessionToken: session,
      keyId: keyId,
    );
    if (!forgotten) {
      return _json({'ok': false, 'error': 'Not found'}, status: 404);
    }
    return _json({'ok': true, 'keys': repository.agentKeysFor(session)});
  }

  Future<Response> _revokeAgentKey(Request request, String keyId) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (repository.personForSession(session) == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    final revoked = await repository.revokeAgentKey(
      sessionToken: session,
      keyId: keyId,
    );
    if (!revoked) {
      return _json({'ok': false, 'error': 'Not found'}, status: 404);
    }
    return _json({'ok': true, 'keys': repository.agentKeysFor(session)});
  }

  Future<Response> _state(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (repository.state.setupRequired) {
      return _json({
        'ok': true,
        ...repository.snapshotForClient(sessionToken: session),
      });
    }
    if (repository.personForSession(session) == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    return _json({
      'ok': true,
      ...repository.snapshotForClient(sessionToken: session),
    });
  }

  /// Admin-only: Firefly PAT + salted password hashes for settings backup.
  Future<Response> _backupSecrets(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    final refused = _refuseAgentKey(session);
    if (refused != null) return refused;
    if (!repository.isAdmin(session)) {
      return _json({'ok': false, 'error': 'Forbidden'}, status: 403);
    }
    return _json({'ok': true, ...repository.backupSecretsForAdmin()});
  }

  /// Refuses a request carrying an agent key instead of a person's session.
  ///
  /// An agent key is a scoped credential for reading and writing the ledger.
  /// personForSession resolves one to its owner, so an admin's key satisfies
  /// isAdmin and would otherwise reach the material that lets its holder become
  /// the account: the Firefly token, other people's password hashes, and the
  /// settings that point the app at a different server. issueAgentKey already
  /// refuses keys for the same reason.
  Response? _refuseAgentKey(String? session) {
    if (session == null || repository.identityForAgentKey(session) == null) {
      return null;
    }
    return _json({
      'ok': false,
      'error': 'Agent keys cannot reach credentials or account settings',
    }, status: 403);
  }

  Future<Response> _requireAdminPut(
    Request request,
    Future<void> Function(Map<String, dynamic> body) apply,
  ) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    final refused = _refuseAgentKey(session);
    if (refused != null) return refused;
    if (!repository.isAdmin(session)) {
      return _json({'ok': false, 'error': 'Forbidden'}, status: 403);
    }
    final body = jsonDecode(await request.readAsString());
    if (body is! Map<String, dynamic>) {
      return _json({'ok': false, 'error': 'Expected JSON object'}, status: 400);
    }
    await apply(body);
    await repository.save();
    return _json({'ok': true});
  }

  Future<Response> _requireAuthPut(
    Request request,
    Future<void> Function(Map<String, dynamic> body) apply, {
    bool write = true,
  }) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (repository.personForSession(session) == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    if (write &&
        !repository.canWrite(session) &&
        !repository.isAdmin(session)) {
      return _json({'ok': false, 'error': 'Forbidden'}, status: 403);
    }
    final body = jsonDecode(await request.readAsString());
    if (body is! Map<String, dynamic>) {
      return _json({'ok': false, 'error': 'Expected JSON object'}, status: 400);
    }
    await apply(body);
    await repository.save();
    return _json({'ok': true});
  }

  Future<Response> _putDevicePrefs(Request request) =>
      _requireAuthPut(request, (body) async {
        repository.state.devicePrefs = body;
      }, write: false);

  Future<Response> _putClassifications(Request request) =>
      _requireAdminPut(request, (body) async {
        repository.state.classifications = body;
      });

  Future<Response> _putSideMenu(Request request) =>
      _requireAuthPut(request, (body) async {
        repository.state.sideMenu = body;
      }, write: false);

  Future<Response> _putAccountColumns(Request request) =>
      _requireAuthPut(request, (body) async {
        repository.state.accountColumns = body;
      }, write: false);

  Future<Response> _putTransactionColumns(Request request) =>
      _requireAuthPut(request, (body) async {
        repository.state.transactionColumns = body;
      }, write: false);

  Future<Response> _putViewMode(Request request) =>
      _requireAuthPut(request, (body) async {
        repository.state.viewMode = body;
      }, write: false);

  Future<Response> _putPrognosis(Request request) =>
      _requireAuthPut(request, (body) async {
        repository.state.prognosis = body;
      }, write: false);

  Future<Response> _putUndo(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (!repository.canWrite(session)) {
      return _json({'ok': false, 'error': 'Forbidden'}, status: 403);
    }
    final body = jsonDecode(await request.readAsString());
    if (body is! Map<String, dynamic>) {
      return _json({'ok': false, 'error': 'Expected JSON object'}, status: 400);
    }
    repository.state.undo = body;
    await repository.save();
    return _json({'ok': true});
  }

  Future<Response> _putFirefly(Request request) =>
      _requireAdminPut(request, (body) async {
        repository.state.firefly.url = body['url'] as String? ?? '';
        final token = body['token'] as String?;
        if (token != null && token.isNotEmpty) {
          repository.state.firefly.token = token;
        }
        repository.state.firefly.allowInsecure =
            body['allowInsecure'] as bool? ?? false;
      });

  Future<Response> _putPeople(Request request) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    final refused = _refuseAgentKey(session);
    if (refused != null) return refused;
    if (!repository.isAdmin(session)) {
      return _json({'ok': false, 'error': 'Forbidden'}, status: 403);
    }
    final body = jsonDecode(await request.readAsString());
    if (body is! Map<String, dynamic>) {
      return _json({'ok': false, 'error': 'Expected JSON object'}, status: 400);
    }
    final rawPeople = body['people'];
    if (rawPeople is! List) {
      return _json({
        'ok': false,
        'error': 'people must be a list',
      }, status: 400);
    }
    final people = <Map<String, dynamic>>[];
    for (final item in rawPeople) {
      if (item is Map<String, dynamic>) {
        people.add(item);
      } else if (item is Map) {
        people.add(item.map((k, v) => MapEntry(k.toString(), v)));
      }
    }

    final ownerships = <Map<String, dynamic>>[];
    final rawOwnerships = body['accountOwnerships'];
    if (rawOwnerships is List) {
      for (final item in rawOwnerships) {
        if (item is Map<String, dynamic>) {
          ownerships.add(item);
        } else if (item is Map) {
          ownerships.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    } else if (rawOwnerships is Map) {
      for (final entry in rawOwnerships.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          ownerships.add({
            'accountId': value['accountId'] ?? entry.key.toString(),
            'personShares': value['personShares'] ?? const <String, dynamic>{},
          });
        } else if (value is Map) {
          ownerships.add({
            'accountId': value['accountId'] ?? entry.key.toString(),
            'personShares': value['personShares'] ?? const <String, dynamic>{},
          });
        }
      }
    }

    final passwordUpdates = <String, String>{};
    final rawPasswords = body['passwordUpdates'];
    if (rawPasswords is Map) {
      for (final entry in rawPasswords.entries) {
        final value = entry.value;
        if (value is String && value.isNotEmpty) {
          passwordUpdates[entry.key.toString()] = value;
        }
      }
    }

    final authImports = <String, Map<String, String>>{};
    final rawAuthImports = body['authImports'];
    if (rawAuthImports is Map) {
      for (final entry in rawAuthImports.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final map = value.map((k, v) => MapEntry(k.toString(), v.toString()));
        final hash = map['passwordHash'] ?? '';
        final salt = map['salt'] ?? map['passwordSalt'] ?? '';
        // Forwarded even when incomplete so replacePeopleConfig can refuse it.
        // Dropping it here meant a person's password quietly failed to import
        // and the caller was told the request succeeded.
        authImports[entry.key.toString()] = {
          'passwordHash': hash,
          'salt': salt,
        };
      }
    }

    try {
      await repository.replacePeopleConfig(
        people: people,
        accountOwnerships: ownerships,
        requirePasswordLogin: body['requirePasswordLogin'] as bool? ?? true,
        passwordUpdates: passwordUpdates,
        authImports: authImports,
      );
      // A deleted person must not leave working agent keys behind.
      await repository.pruneAgentKeys();
    } on ArgumentError catch (error) {
      return _json({'ok': false, 'error': '${error.message}'}, status: 400);
    }
    return _json({
      'ok': true,
      ...repository.snapshotForClient(sessionToken: session),
    });
  }

  Future<Response> _getAvatar(Request request, String personId) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (repository.personForSession(session) == null &&
        !repository.state.setupRequired) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    final b64 = repository.state.avatars[personId];
    if (b64 == null) return Response.notFound('Not found');
    return _json({'ok': true, 'personId': personId, 'pngBase64': b64});
  }

  Future<Response> _putAvatar(Request request, String personId) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (!repository.isAdmin(session) &&
        repository.personForSession(session)?['id'] != personId) {
      return _json({'ok': false, 'error': 'Forbidden'}, status: 403);
    }
    // Every sibling PUT answers a malformed body with 400 through
    // _requireAuthPut. Casting here without one turned a bad request into a
    // 500, which reads as the server's fault.
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } on Object {
      return _json({'ok': false, 'error': 'Invalid JSON body'}, status: 400);
    }
    final b64 = body['pngBase64'] as String? ?? '';
    if (b64.isEmpty) {
      repository.state.avatars.remove(personId);
    } else {
      repository.state.avatars[personId] = b64;
    }
    await repository.save();
    return _json({'ok': true});
  }

  Future<Response> _fireflyProxyRoot(Request request) {
    return _proxyFirefly(request, '');
  }

  Future<Response> _fireflyProxyTagged(Request request, String path) {
    return _proxyFirefly(request, path);
  }

  Future<Response> _proxyFirefly(Request request, String path) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
    if (repository.personForSession(session) == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    final method = request.method.toUpperCase();
    final isWrite = method != 'GET' && method != 'HEAD' && method != 'OPTIONS';
    if (isWrite && !repository.canWrite(session)) {
      return _json({'ok': false, 'error': 'Forbidden'}, status: 403);
    }

    final conn = repository.state.firefly;
    if (conn.url.isEmpty || conn.token.isEmpty) {
      return _json({
        'ok': false,
        'error': 'Firefly connection not configured',
      }, status: 503);
    }

    final base = conn.url.endsWith('/')
        ? conn.url.substring(0, conn.url.length - 1)
        : conn.url;
    final suffix = path.startsWith('/') ? path : (path.isEmpty ? '' : '/$path');
    final query = request.url.query.isEmpty ? '' : '?${request.url.query}';
    final target = Uri.parse('$base$suffix$query');

    final headers = <String, String>{
      'authorization': 'Bearer ${conn.token}',
      'accept': request.headers['accept'] ?? 'application/vnd.api+json',
      if (request.headers['content-type'] != null)
        'content-type': request.headers['content-type']!,
    };

    final bodyBytes = await request.read().fold<List<int>>(
      <int>[],
      (prev, chunk) => prev..addAll(chunk),
    );

    final upstream = await _http.send(
      http.Request(method, target)
        ..headers.addAll(headers)
        ..bodyBytes = bodyBytes,
    );
    final responseBytes = await upstream.stream.toBytes();
    final responseHeaders = Map<String, String>.from(upstream.headers)
      ..remove('transfer-encoding')
      ..remove('content-encoding');
    return Response(
      upstream.statusCode,
      body: responseBytes,
      headers: responseHeaders,
    );
  }
}
