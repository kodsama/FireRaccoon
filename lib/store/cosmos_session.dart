/// A Cosmos Cloud reverse-proxy session.
///
/// Cosmos gates a protected route on one cookie, `jwttoken`, minted by its own
/// `/cosmos/oauth2/detect-callback` at the end of the OIDC login. The proxy
/// strips that cookie before forwarding upstream, so it never reaches Firefly:
/// it gets a request past the door and nothing more. The Firefly token still
/// travels in `Authorization`, which Cosmos leaves alone.
class CosmosSession {
  const CosmosSession({
    required this.host,
    required this.cookie,
    required this.obtainedAt,
  });

  /// The cookie Cosmos gates a route on. Named here rather than discovered,
  /// because it is the only one that matters and capturing a whole jar would
  /// mean storing every unrelated cookie a login page happened to set.
  static const cookieName = 'jwttoken';

  /// Host of the protected route, not of the Cosmos login. A session for
  /// `firefly.example` says nothing about `other.example`, so the host is what
  /// decides whether the cookie is sent.
  final String host;

  final String cookie;
  final DateTime obtainedAt;

  /// The header value a request carries.
  String get cookieHeader => '$cookieName=$cookie';

  Map<String, String> toJson() => {
    'host': host,
    'cookie': cookie,
    'obtained_at': obtainedAt.toIso8601String(),
  };

  /// Null for anything that does not parse, so a store written by a version
  /// that shaped this differently is treated as no session rather than
  /// stopping the app from starting.
  static CosmosSession? fromJson(Map<String, Object?> json) {
    final host = json['host'];
    final cookie = json['cookie'];
    final obtainedAt = DateTime.tryParse('${json['obtained_at']}');
    if (host is! String || host.isEmpty) return null;
    if (cookie is! String || cookie.isEmpty) return null;
    if (obtainedAt == null) return null;
    return CosmosSession(host: host, cookie: cookie, obtainedAt: obtainedAt);
  }

  /// Whether this session is the one to use for [url].
  ///
  /// Host match only. A session is minted per route, and sending it anywhere
  /// else would hand a Cosmos credential to a server that never asked for one.
  bool appliesTo(Uri url) => url.host.toLowerCase() == host.toLowerCase();
}
