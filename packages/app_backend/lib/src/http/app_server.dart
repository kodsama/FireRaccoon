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
  static Future<AppServer> open(ServerConfig config) async {
    final server = AppServer(config: config);
    final password = config.dataPassword;
    if (password != null && password.isNotEmpty) {
      await server.unlockStore(password: password);
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
      ..put('/api/state/device-prefs', _putDevicePrefs)
      ..put('/api/state/classifications', _putClassifications)
      ..put('/api/state/side-menu', _putSideMenu)
      ..put('/api/state/account-columns', _putAccountColumns)
      ..put('/api/state/transaction-columns', _putTransactionColumns)
      ..put('/api/state/view-mode', _putViewMode)
      ..put('/api/state/prognosis', _putPrognosis)
      ..put('/api/state/undo', _putUndo)
      ..put('/api/state/firefly', _putFirefly)
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
        .addHandler(cascade.handler);
  }

  Future<HttpServer> serve() {
    return shelf_io.serve(handler, InternetAddress.anyIPv4, config.port);
  }

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
    final person = repository.personForSession(_session(request));
    if (person == null) {
      return _json({'ok': false, 'error': 'Unauthorized'}, status: 401);
    }
    return _json({'ok': true, 'person': person});
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

  Future<Response> _requireAdminPut(
    Request request,
    Future<void> Function(Map<String, dynamic> body) apply,
  ) async {
    final locked = _lockedResponse();
    if (locked != null) return locked;
    final session = _session(request);
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
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
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
