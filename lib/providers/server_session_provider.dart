import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../store/secure_storage.dart';

import '../deployment/deployment_providers.dart';
import '../store/remote_server_client.dart';
import 'auth_provider.dart';

const _kServerSessionKey = 'serverSessionToken';

class ServerSession {
  const ServerSession({
    required this.token,
    required this.proxyBase,
    this.setupRequired = false,
    this.storeLocked = false,
    this.storeExists = false,
    this.person,
  });

  final String token;
  final String proxyBase;
  final bool setupRequired;
  final bool storeLocked;
  final bool storeExists;
  final Map<String, dynamic>? person;

  bool get isAuthenticated => token.isNotEmpty && person != null;
}

typedef RemoteServerClientFactory = RemoteServerClient Function(String baseUrl);

class ServerSessionNotifier extends AsyncNotifier<ServerSession?> {
  ServerSessionNotifier({
    FlutterSecureStorage? storage,
    RemoteServerClientFactory? clientFactory,
  }) : _storage = storage ?? appSecureStorage,
       _clientFactory =
           clientFactory ?? ((base) => RemoteServerClient(baseUrl: base));

  final FlutterSecureStorage _storage;
  final RemoteServerClientFactory _clientFactory;

  RemoteServerClient? _client;

  RemoteServerClient? get client => _client;

  @override
  Future<ServerSession?> build() async {
    final deployment = ref.watch(deploymentConfigProvider);
    if (!deployment.isServer) {
      return null;
    }

    final base = deployment.apiBase.isNotEmpty
        ? deployment.apiBase
        : (Uri.base.hasScheme &&
                  (Uri.base.scheme == 'http' || Uri.base.scheme == 'https')
              ? Uri.base.origin
              : '');
    _client = _clientFactory(base.isEmpty ? 'http://127.0.0.1' : base);

    final saved = await _storage.read(key: _kServerSessionKey);
    if (saved != null && saved.isNotEmpty) {
      _client!.sessionToken = saved;
      try {
        final state = await _client!.fetchState();
        final session = ServerSession(
          token: saved,
          proxyBase: _client!.fireflyProxyBase,
          setupRequired: state['setupRequired'] == true,
          storeLocked: state['storeLocked'] == true,
          storeExists: state['storeExists'] == true,
          person: (state['me'] as Map?)?.cast<String, dynamic>(),
        );
        if (session.storeLocked) {
          await _storage.delete(key: _kServerSessionKey);
          _client!.sessionToken = null;
          _applyAuth(session);
          return session;
        }
        _applyAuth(session);
        return session;
      } on RemoteServerException catch (error) {
        await _storage.delete(key: _kServerSessionKey);
        _client!.sessionToken = null;
        if (error.storeLocked) {
          final session = ServerSession(
            token: '',
            proxyBase: _client!.fireflyProxyBase,
            setupRequired: error.body['setupRequired'] == true,
            storeLocked: true,
            storeExists: error.body['storeExists'] == true,
          );
          _applyAuth(session);
          return session;
        }
      } on Object {
        await _storage.delete(key: _kServerSessionKey);
        _client!.sessionToken = null;
      }
    }

    try {
      final caps = await _client!.getCapabilities();
      final locked = caps['storeLocked'] == true;
      final exists = caps['storeExists'] == true;
      final setupRequired = caps['setupRequired'] == true;
      final session = ServerSession(
        token: '',
        proxyBase: _client!.fireflyProxyBase,
        setupRequired: setupRequired,
        storeLocked: locked,
        storeExists: exists,
      );
      _applyAuth(session);
      return session;
    } on Object {
      // Backend unreachable — leave unauthenticated.
    }

    _applyAuth(null);
    return null;
  }

  void _applyAuth(ServerSession? session) {
    final auth = ref.read(authProvider.notifier);
    if (session == null) {
      auth.applyServerSession(url: '', token: '');
      return;
    }
    if (session.setupRequired && !session.isAuthenticated) {
      auth.applyServerSession(url: '', token: '');
      return;
    }
    if (session.isAuthenticated) {
      auth.applyServerSession(url: session.proxyBase, token: session.token);
    } else {
      auth.applyServerSession(url: '', token: '');
    }
  }

  Future<void> unlockStore({
    required String password,
    String? confirmPassword,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Server client not ready');
    }
    await client.unlockStore(
      password: password,
      confirmPassword: confirmPassword,
    );
    final caps = await client.getCapabilities();
    final session = ServerSession(
      token: '',
      proxyBase: client.fireflyProxyBase,
      setupRequired: caps['setupRequired'] == true,
      storeLocked: caps['storeLocked'] == true,
      storeExists: caps['storeExists'] == true,
    );
    state = AsyncData(session);
    _applyAuth(session);
  }

  Future<void> setup({
    required String adminName,
    required String adminPassword,
    required String fireflyUrl,
    required String fireflyToken,
    required String dataPassword,
    bool allowInsecure = false,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Server client not ready');
    }
    final body = await client.setup(
      adminName: adminName,
      adminPassword: adminPassword,
      dataPassword: dataPassword,
      fireflyUrl: fireflyUrl,
      fireflyToken: fireflyToken,
      allowInsecure: allowInsecure,
    );
    final token = body['sessionToken'] as String? ?? '';
    await _storage.write(key: _kServerSessionKey, value: token);
    final session = ServerSession(
      token: token,
      proxyBase: client.fireflyProxyBase,
      setupRequired: false,
      person: (body['person'] as Map?)?.cast<String, dynamic>(),
    );
    state = AsyncData(session);
    _applyAuth(session);
  }

  Future<void> login({required String name, required String password}) async {
    final client = _client;
    if (client == null) {
      throw StateError('Server client not ready');
    }
    final body = await client.login(name: name, password: password);
    final token = body['sessionToken'] as String? ?? '';
    await _storage.write(key: _kServerSessionKey, value: token);
    final session = ServerSession(
      token: token,
      proxyBase: client.fireflyProxyBase,
      setupRequired: false,
      person: (body['person'] as Map?)?.cast<String, dynamic>(),
    );
    state = AsyncData(session);
    _applyAuth(session);
  }

  Future<void> logout() async {
    try {
      await _client?.logout();
    } on Object {
      // ignore
    }
    await _storage.delete(key: _kServerSessionKey);
    state = const AsyncData(null);
    _applyAuth(null);
  }
}

final serverSessionProvider =
    AsyncNotifierProvider<ServerSessionNotifier, ServerSession?>(
      ServerSessionNotifier.new,
    );
