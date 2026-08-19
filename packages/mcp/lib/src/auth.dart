import 'dart:convert';

import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:http/http.dart' as http;

/// Verifies the FireRacoon agent key an MCP client presents on `initialize`.
///
/// The desktop app resolves keys against its local store; server mode delegates
/// to the backend, which owns both the keys and the Firefly PAT.
abstract class McpAuthenticator {
  Future<AgentIdentity?> authenticate(String key);
}

/// Resolves keys against an in-process snapshot of the key store.
///
/// The desktop app keeps people and keys in secure storage and restarts the MCP
/// isolate with a fresh snapshot whenever either changes, so a revoked key
/// stops working and its live connections drop with the old isolate.
class SnapshotAuthenticator implements McpAuthenticator {
  SnapshotAuthenticator({required this.keys, required this.people});

  final List<AgentKey> keys;
  final List<AgentKeyPerson> people;

  @override
  Future<AgentIdentity?> authenticate(String key) async {
    return resolveAgentKey(
      key,
      keys: keys,
      person: (id) => people.where((p) => p.id == id).firstOrNull,
    );
  }
}

/// Accepts one fixed identity, for transports whose trust boundary is the
/// process itself: a stdio client already holds the key in its environment, so
/// challenging it again would prove nothing.
class FixedIdentityAuthenticator implements McpAuthenticator {
  const FixedIdentityAuthenticator(this.identity);

  final AgentIdentity identity;

  @override
  Future<AgentIdentity?> authenticate(String key) async => identity;
}

/// Asks a FireRacoon backend to resolve a key, since in server mode the backend
/// owns both the key store and the Firefly PAT.
class BackendAuthenticator implements McpAuthenticator {
  BackendAuthenticator({required String baseUrl, http.Client? client})
    : baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Firefly base URL for tools: the BFF proxy, which attaches the PAT.
  String get fireflyProxyBase => '$baseUrl/api/firefly';

  @override
  Future<AgentIdentity?> authenticate(String key) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('$baseUrl/api/me'),
            headers: {
              'Authorization': 'Bearer ${key.trim()}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
    } on Object {
      return null;
    }
    if (response.statusCode != 200) return null;

    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      return null;
    }
    if (body is! Map) return null;
    final person = (body['person'] as Map?)?.cast<String, Object?>();
    final id = person?['id'] as String?;
    if (person == null || id == null) return null;

    return AgentIdentity(
      keyId: body['agentKeyId'] as String? ?? '',
      personId: id,
      personName: person['name'] as String? ?? '',
      role: person['role'] as String? ?? 'viewer',
    );
  }
}

/// Pulls the agent key out of `initialize` params. Client implementations differ
/// on where they put a bearer, so all three documented shapes are read.
String? extractAgentKey(Map<String, Object?> params) {
  final direct = params['apiKey'] ?? params['api_key'];
  if (direct is String && direct.isNotEmpty) return direct;
  final auth = params['authentication'];
  if (auth is Map) {
    final token = auth['token'] ?? auth['apiKey'] ?? auth['api_key'];
    if (token is String && token.isNotEmpty) return token;
  }
  return null;
}
