import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:http/http.dart' as http;

/// Raised when a reverse proxy in front of Firefly III turned a request away.
///
/// A [FireflyApiException] so the engine's send loop rethrows it untouched
/// rather than retrying, and [unreachable] because that is what happened: the
/// request stopped at the proxy, and reporting it as a Firefly III that refused
/// something sends an agent after a token that is perfectly fine.
class ProxySignInRequiredException extends FireflyApiException {
  ProxySignInRequiredException(this.host)
    : super(
        'A Cosmos Cloud route in front of $host did not let the request '
        'through. The session it wants is held by the FireRaccoon app.',
        unreachable: true,
      );

  final String host;

  @override
  String toString() => message;
}

/// Whether a response is a Cosmos Cloud route turning the caller away to sign
/// in.
///
/// Recognised by the two paths Cosmos itself builds, matched on the path rather
/// than anywhere in the string, and the OpenID form must carry the
/// auto-provisioned `__route_` client. This decides whether an agent is told to
/// sign in or told the server is down, so a substring match would send it after
/// the wrong thing.
bool isProxyLoginRedirect(int statusCode, Map<String, String> headers) {
  if (statusCode < 300 || statusCode >= 400) return false;
  final location = headers['location'] ?? headers['Location'] ?? '';
  if (location.isEmpty) return false;
  final target = Uri.tryParse(location);
  if (target == null) return false;
  if (target.path == '/cosmos-ui/login') return true;
  if (target.path != '/cosmos-ui/openid') return false;
  return (target.queryParameters['client_id'] ?? '').startsWith('__route_');
}

/// Raised when the server address answers, but nothing there is Firefly III.
///
/// A proxy that wants a credential redirects; one that answers this has no
/// route to Firefly at all, and no session creates one. Told apart so an agent
/// is not sent after a sign-in that cannot help.
class ProxyNoRouteException extends FireflyApiException {
  ProxyNoRouteException(this.host)
    : super(
        'Something answers at $host, but it did not route the request to '
        'Firefly III.',
        unreachable: true,
      );

  final String host;

  @override
  String toString() => message;
}

/// Whether a response is a proxy declining to route at all.
///
/// Cosmos redirects a caller it wants to authenticate, and falls through to
/// Go's own `http.NotFound` for a host it has no route for, writing nineteen
/// bytes of plain text. Firefly III answers `/api/v1` with JSON, including its
/// own 404s, so plain text on that path is already something other than
/// Firefly talking.
bool isProxyNotRouted(
  int statusCode,
  Map<String, String> headers,
  String body,
) {
  if (statusCode != 404) return false;
  final contentType = headers['content-type'] ?? headers['Content-Type'] ?? '';
  if (!contentType.toLowerCase().startsWith('text/plain')) return false;
  return body.trim() == goNotFound;
}

/// What Go's `http.NotFound` writes, which is Cosmos's answer for a route it
/// will not serve this caller.
const goNotFound = '404 page not found';

/// Carries the app's proxy session on every request, and reports the proxy's
/// answers about itself as its own, rather than as Firefly III answers.
///
/// Installed whether or not there is a cookie to send: the case worth naming is
/// the one where the server has no session at all.
class ProxyGateClient extends http.BaseClient {
  ProxyGateClient(this._inner, this._cookie);

  final http.Client _inner;
  final String? _cookie;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final cookie = _cookie;
    if (cookie != null && cookie.isNotEmpty) {
      final existing = request.headers['Cookie'] ?? request.headers['cookie'];
      request.headers['Cookie'] = existing == null || existing.isEmpty
          ? cookie
          : '$existing; $cookie';
    }
    final response = await _inner.send(request);
    if (isProxyLoginRedirect(response.statusCode, response.headers)) {
      throw ProxySignInRequiredException(request.url.host);
    }
    if (!_worthReading(response)) return response;

    final body = await response.stream.toBytes();
    final text = utf8.decode(body, allowMalformed: true);
    if (!isProxyNotRouted(response.statusCode, response.headers, text)) {
      // Somebody else's small text 404. Hand back an identical response, since
      // reading the stream to look at it is the one thing that consumed it.
      return http.StreamedResponse(
        Stream.value(body),
        response.statusCode,
        contentLength: body.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    }
    throw ProxyNoRouteException(request.url.host);
  }

  @override
  void close() => _inner.close();
}

/// Whether buffering a response is worth it to see what the proxy wrote.
///
/// Checked before reading rather than after, because buffering everything to
/// look for nineteen bytes would undo the streaming the client does.
bool _worthReading(http.StreamedResponse response) {
  if (response.statusCode != 404) return false;
  final length = response.contentLength;
  if (length != null && length > 64) return false;
  final contentType = response.headers['content-type'] ?? '';
  return contentType.toLowerCase().startsWith('text/plain');
}
