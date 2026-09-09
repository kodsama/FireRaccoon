import 'package:flutter/widgets.dart';

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
  /// person closed it without finishing.
  ///
  /// Takes a context because the flow is hosted inside the app on every
  /// platform that can: a window of its own brought a native toolbar that
  /// crashes in its own layout pass, and a second NSWindow whose closing told
  /// AppKit the app was done.
  Future<CosmosSession?> signIn(BuildContext context, Uri routeUrl);

  /// Mints a route session without showing anybody anything, or null when
  /// Cosmos wants a person after all.
  ///
  /// A route session runs out long before the Cosmos login behind it does, so
  /// the usual renewal is Cosmos redirecting through its own authorize
  /// endpoint and straight back, with nothing to type. Doing that in the
  /// background is the difference between an app that reconnects itself and
  /// one that puts up a sign-in button for a password nobody needs to enter.
  ///
  /// [staleCookie] is the value Cosmos has just refused. The web view keeps its
  /// own copy of it, and a route Cosmos declines to open sets no new one, so
  /// reading the jar afterwards hands back the dead cookie unless it is known
  /// which one that was.
  Future<CosmosSession?> renew(Uri routeUrl, {String? staleCookie});
}

/// The answer on a platform with no web view, and on web, where the browser
/// carries the cookie itself and there is nothing for the app to hold.
class UnsupportedCosmosLogin implements CosmosLogin {
  const UnsupportedCosmosLogin();

  @override
  bool get isSupported => false;

  @override
  Future<CosmosSession?> signIn(BuildContext context, Uri routeUrl) async =>
      null;

  @override
  Future<CosmosSession?> renew(Uri routeUrl, {String? staleCookie}) async =>
      null;
}

/// Raised when the sign-in window could not be opened at all.
///
/// Distinct from a person closing it: nothing was shown, so there is nothing
/// for them to have decided, and the app has to say so rather than resetting
/// the button and looking like it ignored the click.
class CosmosLoginUnavailable implements Exception {
  const CosmosLoginUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'The Cosmos sign-in window would not open: $reason';
}
