import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../store/secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:http/http.dart' as http;
import '../utils/debug_env_credentials.dart';
import '../utils/web_backend_proxy.dart';

enum AuthMode { token, oauth2 }

class AuthSettings {
  final String serverUrl;
  final String apiToken;
  final AuthMode authMode;
  final bool allowInsecure;

  /// False until persisted credentials (or env fallbacks) have been read once.
  final bool isHydrated;

  /// True when the credential read failed, as against answering and holding
  /// nothing.
  ///
  /// A locked keychain and a keychain with no credentials in it both left this
  /// object empty, so a machine whose keychain had not been unlocked yet was
  /// told to open Settings and connect a server it had already connected to.
  final bool storageUnavailable;

  AuthSettings({
    this.serverUrl = '',
    this.apiToken = '',
    this.authMode = AuthMode.token,
    this.allowInsecure = false,
    this.isHydrated = false,
    this.storageUnavailable = false,
  });

  bool get isValid => serverUrl.isNotEmpty && apiToken.isNotEmpty;

  /// Value equality so redundant hydration writes do not re-notify listeners
  /// (a spurious notify recreates apiServiceProvider and refetches every
  /// startup endpoint).
  @override
  bool operator ==(Object other) {
    return other is AuthSettings &&
        other.serverUrl == serverUrl &&
        other.apiToken == apiToken &&
        other.authMode == authMode &&
        other.allowInsecure == allowInsecure &&
        other.isHydrated == isHydrated &&
        other.storageUnavailable == storageUnavailable;
  }

  @override
  int get hashCode => Object.hash(
    serverUrl,
    apiToken,
    authMode,
    allowInsecure,
    isHydrated,
    storageUnavailable,
  );
}

/// How long the credential read is given to answer at all.
///
/// A keychain prompt can sit unanswered for as long as nobody types into it,
/// and a read that never returns is neither a success nor a failure. Without a
/// deadline the app waits on it forever, with a spinner and nothing to say.
/// Answering late is covered by the connection poll, which reads again.
@visibleForTesting
const Duration kCredentialReadTimeout = Duration(seconds: 5);

/// Loads debug-only fallback credentials (see [loadDebugEnvCredentials]).
typedef DebugEnvLoader = Future<Map<String, String>> Function();

class AuthNotifier extends Notifier<AuthSettings> {
  AuthNotifier({
    FlutterSecureStorage? storage,
    http.Client? httpClient,
    DebugEnvLoader? debugEnvLoader,
    Duration readTimeout = kCredentialReadTimeout,
    // An initializing formal would name this parameter privately, and a private
    // name cannot be passed from the tests that set it.
    // ignore: prefer_initializing_formals
  }) : _readTimeout = readTimeout,
       _storage = storage ?? appSecureStorage,
       _httpClient = httpClient ?? http.Client(),
       _debugEnvLoader = debugEnvLoader ?? loadDebugEnvCredentials;

  final FlutterSecureStorage _storage;
  final http.Client _httpClient;
  final DebugEnvLoader _debugEnvLoader;
  final Duration _readTimeout;
  final _log = AppLogger.scoped('providers.auth');

  /// Deadlines currently running, so they die with the notifier rather than
  /// outliving it.
  final Set<Timer> _deadlines = {};

  @override
  AuthSettings build() {
    ref.onDispose(() {
      for (final deadline in _deadlines) {
        deadline.cancel();
      }
      _deadlines.clear();
    });
    _loadFromStorage();
    _log.finer('Auth notifier initialized; loading persisted settings');
    return AuthSettings();
  }

  /// Runs [read] with a deadline, answering null if it does not finish in time
  /// or fails.
  ///
  /// A keychain prompt nobody types into never returns, and neither does the
  /// read waiting on it. `Future.timeout` would do this, but the timer it hides
  /// cannot be cancelled, so it outlives the notifier that started it.
  Future<T?> _withDeadline<T>(Future<T> Function() read, String what) {
    final settled = Completer<T?>();
    void finish(T? value) {
      if (!settled.isCompleted) settled.complete(value);
    }

    final deadline = Timer(_readTimeout, () {
      _log.warning('$what did not answer within $_readTimeout');
      finish(null);
    });
    _deadlines.add(deadline);

    read().then(
      finish,
      onError: (Object error, StackTrace stackTrace) {
        _log.warning('$what would not answer', error, stackTrace);
        finish(null);
      },
    );

    return settled.future.whenComplete(() {
      deadline.cancel();
      _deadlines.remove(deadline);
    });
  }

  /// Credentials live exclusively in platform secure storage (Keychain on
  /// desktop, encrypted browser storage on web), entered via Settings.
  ///
  /// A keychain that has not been unlocked fails the read rather than answering
  /// that it holds nothing, and the two used to be indistinguishable here. The
  /// failure settled as "no credentials", so every screen said to go and connect
  /// a server that was already connected, and nothing read the keychain again
  /// once its password had been typed. A read that does not answer now says so
  /// instead of passing for an empty one, and the connection poll reads again.
  Future<void> _loadFromStorage() async {
    final stored = await _readStoredCredentials();
    if (!ref.mounted) return;

    var next =
        stored ?? AuthSettings(isHydrated: true, storageUnavailable: true);
    if (!next.isValid) {
      next = await _fillFromEnv(next);
      if (!ref.mounted) return;
    }

    if (next != state) state = next;
    _log.info(
      'Auth settings hydrated '
      '(valid=${next.isValid}, storageUnavailable=${next.storageUnavailable})',
    );
  }

  /// The stored credentials, or null if the keychain did not answer.
  ///
  /// A locked keychain, a denied prompt and a missing entitlement all fail the
  /// read, and a prompt left untouched never returns at all. None of the three
  /// means "there are no credentials".
  Future<AuthSettings?> _readStoredCredentials() =>
      _withDeadline(_readAllCredentials, 'Secure storage');

  Future<AuthSettings> _readAllCredentials() async {
    final url = await _storage.read(key: 'serverUrl') ?? '';
    final token = await _storage.read(key: 'apiToken') ?? '';
    final mode = await _storage.read(key: 'authMode') ?? 'token';
    final insecure = await _storage.read(key: 'allowInsecure') ?? 'false';
    return AuthSettings(
      serverUrl: url,
      apiToken: token,
      authMode: mode == 'oauth2' ? AuthMode.oauth2 : AuthMode.token,
      allowInsecure: insecure == 'true',
      isHydrated: true,
    );
  }

  /// Fills whatever [partial] is missing from the debug `.env` fallback.
  ///
  /// Deadlined like the keychain read: this one reads a file, and hydration that
  /// waits on any unbounded call is hydration that can never finish.
  Future<AuthSettings> _fillFromEnv(AuthSettings partial) async {
    final env = await _withDeadline(_debugEnvLoader, 'Debug .env fallback');
    if (env == null || env.isEmpty) return partial;

    final envInsecure = env['FIREFLY_ALLOW_INSECURE'];
    _log.info('Applied debug .env credential fallback');
    return AuthSettings(
      serverUrl: partial.serverUrl.isEmpty
          ? env['FIREFLY_URL'] ?? ''
          : partial.serverUrl,
      apiToken: partial.apiToken.isEmpty
          ? env['FIREFLY_TOKEN'] ?? ''
          : partial.apiToken,
      authMode: partial.authMode,
      allowInsecure: envInsecure != null
          ? envInsecure == 'true'
          : partial.allowInsecure,
      isHydrated: true,
      storageUnavailable: partial.storageUnavailable,
    );
  }

  /// Reads the credentials again, for when the keychain has since been unlocked.
  Future<void> retryCredentialRead() => _loadFromStorage();

  Future<void> saveSettings(String url, String token, bool insecure) async {
    await applyImportedCredentials(
      serverUrl: url,
      apiToken: token,
      authMode: AuthMode.token,
      allowInsecure: insecure,
    );
  }

  /// Restores Firefly connection fields from a settings backup.
  Future<void> applyImportedCredentials({
    required String serverUrl,
    required String apiToken,
    AuthMode authMode = AuthMode.token,
    bool allowInsecure = false,
  }) async {
    // Apply in memory first so the session works even if persistence fails.
    state = AuthSettings(
      serverUrl: serverUrl,
      apiToken: apiToken,
      authMode: authMode,
      allowInsecure: allowInsecure,
      isHydrated: true,
    );
    try {
      await _storage.write(key: 'serverUrl', value: serverUrl);
      await _storage.write(key: 'apiToken', value: apiToken);
      await _storage.write(
        key: 'authMode',
        value: authMode == AuthMode.oauth2 ? 'oauth2' : 'token',
      );
      await _storage.write(
        key: 'allowInsecure',
        value: allowInsecure ? 'true' : 'false',
      );
      _log.info('Auth settings saved and applied');
    } on Object catch (error, stackTrace) {
      // Secure storage may be unavailable in development (e.g. macOS Keychain
      // entitlement issues). Keep the in-memory credentials for this session
      // and surface a non-fatal warning instead of crashing the save flow.
      _log.warning(
        'Credentials applied for this session but could not be persisted to '
        'secure storage. Use a .env fallback for development if this recurs.',
        error,
        stackTrace,
      );
    }
  }

  Future<bool> testConnection(String url, String token, bool insecure) async {
    final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    if (!insecure && baseUrl.startsWith('http://')) {
      throw Exception('Insecure HTTP connections are disabled.');
    }
    final requestBaseUrl = resolveBackendUrlForHttp(baseUrl);

    _log.fine('Testing Firefly connection endpoint');
    // Two bounded attempts: a stalled request must not hang the status
    // indicator, and a single transient blip must not flap it to unreachable.
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _httpClient
            .get(
              Uri.parse('$requestBaseUrl/api/v1/about'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) return true;
        _log.warning('Connection test returned HTTP ${response.statusCode}');
        if (response.statusCode < 500) return false;
      } on Object catch (error, stackTrace) {
        _log.warning(
          'Connection test failed (attempt $attempt/2): $error',
          error,
          stackTrace,
        );
      }
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return false;
  }

  Future<void> authenticateOAuth(
    String url,
    String clientId,
    bool insecure,
  ) async {
    final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    if (!insecure && baseUrl.startsWith('http://')) {
      throw Exception('Insecure HTTP connections are disabled.');
    }

    _log.info('Starting OAuth authentication flow');
    final authorizationEndpoint = Uri.parse('$baseUrl/oauth/authorize');
    final tokenEndpoint = Uri.parse('$baseUrl/oauth/token');
    final redirectUrl = Uri.parse('fireracoon://oauth-callback');

    final grant = oauth2.AuthorizationCodeGrant(
      clientId,
      authorizationEndpoint,
      tokenEndpoint,
    );

    final authorizationUrl = grant.getAuthorizationUrl(redirectUrl);

    final result = await FlutterWebAuth2.authenticate(
      url: authorizationUrl.toString(),
      callbackUrlScheme: 'fireracoon',
    );

    final client = await grant.handleAuthorizationResponse(
      Uri.parse(result).queryParameters,
    );

    final token = client.credentials.accessToken;

    await _storage.write(key: 'serverUrl', value: baseUrl);
    await _storage.write(key: 'apiToken', value: token);
    await _storage.write(key: 'authMode', value: 'oauth2');
    await _storage.write(
      key: 'allowInsecure',
      value: insecure ? 'true' : 'false',
    );

    state = AuthSettings(
      serverUrl: baseUrl,
      apiToken: token,
      authMode: AuthMode.oauth2,
      allowInsecure: insecure,
      isHydrated: true,
    );
    _log.info('OAuth authentication completed successfully');
  }

  Future<void> clearSettings() async {
    await _storage.delete(key: 'serverUrl');
    await _storage.delete(key: 'apiToken');
    await _storage.delete(key: 'authMode');
    await _storage.delete(key: 'allowInsecure');
    state = AuthSettings(isHydrated: true);
    _log.info('Auth settings cleared');
  }

  /// Server-mode bridge: session token acts as the API bearer against the BFF.
  void applyServerSession({required String url, required String token}) {
    state = AuthSettings(
      serverUrl: url,
      apiToken: token,
      authMode: AuthMode.token,
      allowInsecure: true,
      isHydrated: true,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthSettings>(
  () => AuthNotifier(),
);
