import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin HTTP client for FireRacoon server-mode APIs.
class RemoteServerClient {
  RemoteServerClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.sessionToken,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? sessionToken;

  Uri _uri(String path) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base$path');
  }

  Map<String, String> _headers({bool jsonBody = false}) {
    return {
      if (jsonBody) 'content-type': 'application/json; charset=utf-8',
      'accept': 'application/json',
      if (sessionToken != null && sessionToken!.isNotEmpty)
        'x-fireracoon-session': sessionToken!,
    };
  }

  Future<Map<String, dynamic>> getCapabilities() async {
    final response = await _http.get(
      _uri('/api/capabilities'),
      headers: _headers(),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> unlockStore({
    required String password,
    String? confirmPassword,
  }) async {
    final response = await _http.post(
      _uri('/api/store/unlock'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({
        'password': password,
        'confirmPassword': ?confirmPassword,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> setup({
    required String adminName,
    required String adminPassword,
    required String fireflyUrl,
    required String fireflyToken,
    bool allowInsecure = false,
  }) async {
    final response = await _http.post(
      _uri('/api/setup'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({
        'adminName': adminName,
        'adminPassword': adminPassword,
        'fireflyUrl': fireflyUrl,
        'fireflyToken': fireflyToken,
        'allowInsecure': allowInsecure,
      }),
    );
    final body = _decode(response);
    sessionToken = body['sessionToken'] as String? ?? sessionToken;
    return body;
  }

  Future<Map<String, dynamic>> login({
    required String name,
    required String password,
  }) async {
    final response = await _http.post(
      _uri('/api/login'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({'name': name, 'password': password}),
    );
    final body = _decode(response);
    sessionToken = body['sessionToken'] as String? ?? sessionToken;
    return body;
  }

  Future<void> logout() async {
    await _http.post(_uri('/api/logout'), headers: _headers());
    sessionToken = null;
  }

  Future<Map<String, dynamic>> fetchState() async {
    final response = await _http.get(_uri('/api/state'), headers: _headers());
    return _decode(response);
  }

  /// Admin-only Firefly PAT + salted password hashes for settings backup.
  Future<Map<String, dynamic>> fetchBackupSecrets() async {
    final response = await _http.get(
      _uri('/api/state/backup-secrets'),
      headers: _headers(),
    );
    return _decode(response);
  }

  Future<void> putUndo(Map<String, dynamic> undo) async {
    final response = await _http.put(
      _uri('/api/state/undo'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(undo),
    );
    _decode(response);
  }

  Future<void> putFirefly({
    required String url,
    String? token,
    bool allowInsecure = false,
  }) async {
    final response = await _http.put(
      _uri('/api/state/firefly'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({
        'url': url,
        'token': ?token,
        'allowInsecure': allowInsecure,
      }),
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> putPeople({
    required List<Map<String, dynamic>> people,
    required Object accountOwnerships,
    required bool requirePasswordLogin,
    Map<String, String> passwordUpdates = const {},
    Map<String, Map<String, String>> authImports = const {},
  }) async {
    final response = await _http.put(
      _uri('/api/state/people'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({
        'people': people,
        'accountOwnerships': accountOwnerships,
        'requirePasswordLogin': requirePasswordLogin,
        if (passwordUpdates.isNotEmpty) 'passwordUpdates': passwordUpdates,
        if (authImports.isNotEmpty) 'authImports': authImports,
      }),
    );
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> fetchAgentKeys() async {
    final response = await _http.get(
      _uri('/api/agent-keys'),
      headers: _headers(),
    );
    final body = _decode(response);
    return [
      for (final raw in (body['keys'] as List? ?? const []))
        if (raw is Map) raw.cast<String, dynamic>(),
    ];
  }

  /// Issues an MCP agent key. The returned `secret` is the only time the server
  /// will ever hand it over.
  Future<Map<String, dynamic>> issueAgentKey({required String label}) async {
    final response = await _http.post(
      _uri('/api/agent-keys'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({'label': label}),
    );
    return _decode(response);
  }

  /// Reads back the secret of a key this session owns. Throws
  /// [RemoteServerException] with 404 when it is not the caller's, or predates
  /// secrets being retained.
  Future<String> fetchAgentKeySecret(String keyId) async {
    final response = await _http.get(
      _uri('/api/agent-keys/$keyId/secret'),
      headers: _headers(),
    );
    return _decode(response)['secret'] as String? ?? '';
  }

  /// Deletes a revoked key's record. Revoking is [revokeAgentKey]; this clears
  /// it from the list afterwards.
  Future<void> forgetAgentKey(String keyId) async {
    final response = await _http.delete(
      _uri('/api/agent-keys/$keyId/record'),
      headers: _headers(),
    );
    _decode(response);
  }

  Future<void> revokeAgentKey(String keyId) async {
    final response = await _http.delete(
      _uri('/api/agent-keys/$keyId'),
      headers: _headers(),
    );
    _decode(response);
  }

  /// Same-origin Firefly BFF base used by [FireflyApiService].
  String get fireflyProxyBase => '${_uri('/api/firefly')}';

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Expected JSON object from ${response.request?.url}');
    }
    if (response.statusCode >= 400) {
      throw RemoteServerException(
        message:
            decoded['error'] as String? ??
            'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
        body: decoded,
      );
    }
    return decoded;
  }
}

class RemoteServerException implements Exception {
  RemoteServerException({
    required this.message,
    required this.statusCode,
    this.body = const {},
  });

  final String message;
  final int statusCode;
  final Map<String, dynamic> body;

  bool get storeLocked =>
      body['code'] == 'store_locked' || body['storeLocked'] == true;

  @override
  String toString() => message;
}
