import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  AuthSettings({
    this.serverUrl = '',
    this.apiToken = '',
    this.authMode = AuthMode.token,
    this.allowInsecure = false,
    this.isHydrated = false,
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
        other.isHydrated == isHydrated;
  }

  @override
  int get hashCode =>
      Object.hash(serverUrl, apiToken, authMode, allowInsecure, isHydrated);
}

/// Loads debug-only fallback credentials (see [loadDebugEnvCredentials]).
typedef DebugEnvLoader = Future<Map<String, String>> Function();

class AuthNotifier extends Notifier<AuthSettings> {
  AuthNotifier({
    FlutterSecureStorage? storage,
    http.Client? httpClient,
    DebugEnvLoader? debugEnvLoader,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _httpClient = httpClient ?? http.Client(),
       _debugEnvLoader = debugEnvLoader ?? loadDebugEnvCredentials;

  final FlutterSecureStorage _storage;
  final http.Client _httpClient;
  final DebugEnvLoader _debugEnvLoader;
  final _log = AppLogger.scoped('providers.auth');

  @override
  AuthSettings build() {
    _loadFromStorage();
    _log.finer('Auth notifier initialized; loading persisted settings');
    return AuthSettings();
  }

  /// Credentials live exclusively in platform secure storage (Keychain on
  /// desktop, encrypted browser storage on web), entered via Settings.
  Future<void> _loadFromStorage() async {
    var url = '';
    var token = '';
    var mode = 'token';
    var insecure = 'false';

    try {
      url = await _storage.read(key: 'serverUrl') ?? '';
      token = await _storage.read(key: 'apiToken') ?? '';
      mode = await _storage.read(key: 'authMode') ?? 'token';
      insecure = await _storage.read(key: 'allowInsecure') ?? 'false';
    } on Object catch (error, stackTrace) {
      // Secure storage can be unavailable in development (e.g. a macOS
      // Keychain entitlement problem). Don't fail hydration — fall through to
      // the debug .env fallback below.
      _log.warning(
        'Secure storage unavailable; trying debug .env fallback',
        error,
        stackTrace,
      );
    }

    if (url.isEmpty || token.isEmpty) {
      final env = await _debugEnvLoader();
      if (env.isNotEmpty) {
        if (url.isEmpty) url = env['FIREFLY_URL'] ?? '';
        if (token.isEmpty) token = env['FIREFLY_TOKEN'] ?? '';
        final envInsecure = env['FIREFLY_ALLOW_INSECURE'];
        if (envInsecure != null) insecure = envInsecure;
        _log.info('Applied debug .env credential fallback');
      }
    }

    final next = AuthSettings(
      serverUrl: url,
      apiToken: token,
      authMode: mode == 'oauth2' ? AuthMode.oauth2 : AuthMode.token,
      allowInsecure: insecure == 'true',
      isHydrated: true,
    );
    if (!ref.mounted) return;
    if (next != state) {
      state = next;
    }
    _log.info('Auth settings hydrated');
  }

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
