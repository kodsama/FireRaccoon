import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cosmos_session.dart';
import 'cosmos_sign_in_required_exception.dart';
import 'no_route_to_firefly_exception.dart';

/// Adds the Cosmos route cookie to requests bound for the protected host, and
/// turns Cosmos's own refusals into a state the app can act on.
///
/// Wraps rather than replaces the inner client, so the engine keeps its own
/// retry and timeout behaviour and knows nothing about Cosmos.
class CosmosSessionClient extends http.BaseClient {
  CosmosSessionClient({
    required this._inner,
    required this._session,
    this.onGateRejected,
    this.onGateAccepted,
    this.onSessionRolledForward,
  });

  final http.Client _inner;

  /// Read per request rather than captured, so a sign-in or a sign-out during
  /// the life of one client is picked up by the next call.
  final CosmosSession? Function() _session;

  /// Called with the address Cosmos refused to route, which is what a missing,
  /// expired or revoked session looks like from here.
  final void Function(Uri url)? onGateRejected;

  /// Called when an answer came from behind the door rather than from the door
  /// itself, which is the only proof a session works.
  ///
  /// Fires per request, so whatever is hooked here has to be cheap.
  final void Function()? onGateAccepted;

  /// Called with the cookie Cosmos has just replaced the session with.
  ///
  /// Cosmos gives a route session fourteen days and re-issues it as soon as
  /// the token is a day old, on any request through the route. A browser
  /// therefore stays signed in for months: it takes the new cookie every time,
  /// so the fortnight never runs down. Keeping the value captured at sign-in
  /// and discarding every `Set-Cookie` after it made this app the one client
  /// that expired on schedule.
  final void Function(String cookie)? onSessionRolledForward;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Redirects are followed here rather than by the client underneath,
    // because a Cosmos gate is a redirect. Followed silently, the only thing
    // that ever came back was the sign-in page as a perfectly successful 200,
    // and the app reported a wrong address for a server that was simply
    // waiting to be signed in to.
    var current = request;
    for (var hop = 0; ; hop++) {
      final response = await _sendOnce(current);
      final next = hop < _maxRedirects ? _redirectOf(current, response) : null;
      if (next == null) return response;
      current = next;
    }
  }

  Future<http.StreamedResponse> _sendOnce(http.BaseRequest request) async {
    final session = _session();
    if (session != null && session.appliesTo(request.url)) {
      final existing = request.headers['cookie'] ?? request.headers['Cookie'];
      request.headers['Cookie'] = existing == null || existing.isEmpty
          ? session.cookieHeader
          : '$existing; ${session.cookieHeader}';
    }
    if (request is http.Request) request.followRedirects = false;
    final response = await _inner.send(request);
    if (isCosmosLoginRedirect(response.statusCode, response.headers)) {
      onGateRejected?.call(request.url);
      throw CosmosSignInRequiredException(request.url.host);
    }
    if (!_mightBeUnrouted(response)) {
      onGateAccepted?.call();
      _noteRolledForwardSession(session, response.headers);
      return response;
    }

    final body = await response.stream.toBytes();
    if (utf8.decode(body, allowMalformed: true).trim() != _goNotFound) {
      // Someone else's small text 404, which means Firefly answered it. Hand
      // back an identical response, since reading the stream to look at it is
      // the one thing that consumed it.
      onGateAccepted?.call();
      _noteRolledForwardSession(session, response.headers);
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
    // Not a sign-in. A proxy asking who you are redirects; one that answers
    // this has no route to Firefly at all, and no credential creates one.
    // Offering a sign-in here sent people round a loop that could not help.
    throw NoRouteToFireflyException(request.url.host);
  }

  /// The next request in a redirect chain, or null when there is not one.
  ///
  /// A body that cannot be replayed is not followed: only [http.Request] keeps
  /// its bytes, and everything the engine sends is one.
  http.Request? _redirectOf(
    http.BaseRequest request,
    http.StreamedResponse response,
  ) {
    if (response.statusCode < 300 || response.statusCode >= 400) return null;
    if (request is! http.Request) return null;
    final location = response.headers['location'] ?? '';
    if (location.isEmpty) return null;
    final target = request.url.resolve(location);
    final next = http.Request(request.method, target)
      ..followRedirects = false
      ..persistentConnection = request.persistentConnection
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    if (target.host.toLowerCase() != request.url.host.toLowerCase()) {
      // The Firefly token and the route cookie belong to the server they were
      // issued for. Carrying them across a redirect would hand a credential to
      // whatever host the answer pointed at.
      next.headers
        ..remove('Authorization')
        ..remove('authorization')
        ..remove('Cookie')
        ..remove('cookie');
    }
    return next;
  }

  void _noteRolledForwardSession(
    CosmosSession? session,
    Map<String, String> headers,
  ) {
    final report = onSessionRolledForward;
    if (session == null || report == null) return;
    final setCookie = headers['set-cookie'] ?? headers['Set-Cookie'];
    if (setCookie == null) return;
    final value = _routeCookie.firstMatch(setCookie)?.group(1);
    // An empty value is Cosmos clearing the cookie, which is the end of a
    // session rather than a new one. The next request meets the door and the
    // gate says so; there is nothing to keep here.
    if (value == null || value.isEmpty || value == session.cookie) return;
    report(value);
  }

  @override
  void close() => _inner.close();
}

/// Read out of a folded `Set-Cookie` header rather than parsed properly.
///
/// Several of them arrive joined by commas, and a cookie's own expiry date
/// carries a comma, so splitting on one loses the value. The value itself
/// cannot contain one: a JWT is base64url text and dots.
final _routeCookie = RegExp('${CosmosSession.cookieName}=([^;,\\s]*)');

/// What Go's `http.NotFound` writes, which is what Cosmos falls back to for a
/// host it has no route for.
const _goNotFound = '404 page not found';

/// Enough for the hops a proxy legitimately makes, and few enough that a loop
/// ends rather than hanging the request.
const _maxRedirects = 5;

/// Whether a response is worth reading to see if a proxy wrote [_goNotFound].
///
/// Firefly III answers `/api/v1` with JSON, always, including its own 404s, so
/// a short `text/plain` body is already something other than Firefly talking.
/// Checked before reading rather than after, because buffering every response
/// to look for nineteen bytes would undo the streaming the client does.
bool _mightBeUnrouted(http.StreamedResponse response) {
  if (response.statusCode != 404) return false;
  final length = response.contentLength;
  if (length != null && length > 64) return false;
  final contentType = response.headers['content-type'] ?? '';
  return contentType.toLowerCase().startsWith('text/plain');
}

/// Whether a response is Cosmos turning the caller away to sign in.
///
/// Recognised by the two paths Cosmos itself builds: `performLogin` sends a
/// gated route to `/cosmos-ui/openid` with the auto-provisioned
/// `client_id=__route_<name>`, and `LoggedInOnlyWithRedirect` sends it to
/// `/cosmos-ui/login?notlogged=1`.
///
/// Matched on the path segment rather than anywhere in the string, and the
/// OpenID form must also carry that `__route_` client, because this decides
/// whether someone is told to sign in or told their address is wrong. A
/// substring match would call any redirect whose URL happened to contain the
/// text a Cosmos gate, and send them off to sign in to something that is not
/// there.
bool isCosmosLoginRedirect(int statusCode, Map<String, String> headers) {
  if (statusCode < 300 || statusCode >= 400) return false;
  final location = headers['location'] ?? headers['Location'] ?? '';
  if (location.isEmpty) return false;
  final target = Uri.tryParse(location);
  if (target == null) return false;
  if (target.path == '/cosmos-ui/login') return true;
  if (target.path != '/cosmos-ui/openid') return false;
  final clientId = target.queryParameters['client_id'] ?? '';
  return clientId.startsWith('__route_');
}
