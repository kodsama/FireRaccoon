import 'package:http/http.dart' as http;

import 'cosmos_session.dart';

/// Adds the Cosmos route cookie to requests bound for the protected host.
///
/// Wraps rather than replaces the inner client, so the engine keeps its own
/// retry and timeout behaviour and knows nothing about Cosmos.
class CosmosSessionClient extends http.BaseClient {
  CosmosSessionClient({
    required this._inner,
    required this._session,
    this.onSessionExpired,
  });

  final http.Client _inner;

  /// Read per request rather than captured, so a sign-in or a sign-out during
  /// the life of one client is picked up by the next call.
  final CosmosSession? Function() _session;

  /// Called when Cosmos answers by sending the caller to its login page, which
  /// is what an expired or revoked session looks like from here.
  final void Function()? onSessionExpired;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final session = _session();
    if (session != null && session.appliesTo(request.url)) {
      final existing = request.headers['cookie'] ?? request.headers['Cookie'];
      request.headers['Cookie'] = existing == null || existing.isEmpty
          ? session.cookieHeader
          : '$existing; ${session.cookieHeader}';
    }
    final response = await _inner.send(request);
    if (isCosmosLoginRedirect(response.statusCode, response.headers)) {
      onSessionExpired?.call();
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

/// Whether a response is Cosmos turning the caller away to sign in again.
///
/// A 302 to Cosmos's own login or OpenID path is the only thing a gated route
/// answers with when the cookie is gone. Firefly never redirects an API call
/// there, so this cannot be confused with an answer from the ledger.
bool isCosmosLoginRedirect(int statusCode, Map<String, String> headers) {
  if (statusCode < 300 || statusCode >= 400) return false;
  final location = headers['location'] ?? headers['Location'] ?? '';
  if (location.isEmpty) return false;
  return location.contains('/cosmos-ui/openid') ||
      location.contains('/cosmos-ui/login');
}
