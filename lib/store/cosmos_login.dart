import 'cosmos_session.dart';

/// Signs in to Cosmos and comes back with the route's session cookie.
///
/// The login itself needs a person: only Cosmos's own
/// `/cosmos/oauth2/detect-callback` mints `jwttoken`, and it does so at the end
/// of an interactive OIDC flow. So this opens the route in a web view, lets
/// Cosmos run its own PKCE exchange, and reads the one cookie back out.
///
/// An interface because the web view differs per platform and web needs none at
/// all: a browser already holds the cookie and sends it with every request.
abstract interface class CosmosLogin {
  /// True where this build can actually run the flow.
  bool get isSupported;

  /// Opens [routeUrl] and returns the session Cosmos set, or null when the
  /// person closed the window without finishing.
  Future<CosmosSession?> signIn(Uri routeUrl);
}

/// The answer on a platform with no web view, and on web, where the browser
/// carries the cookie itself and there is nothing for the app to hold.
class UnsupportedCosmosLogin implements CosmosLogin {
  const UnsupportedCosmosLogin();

  @override
  bool get isSupported => false;

  @override
  Future<CosmosSession?> signIn(Uri routeUrl) async => null;
}
