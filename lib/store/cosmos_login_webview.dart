import 'dart:async';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'cosmos_login.dart';
import 'cosmos_session.dart';

final _log = AppLogger.scoped('store.cosmosLogin');

/// Cosmos sign-in through an in-app web view.
///
/// Cosmos runs its own authorization-code exchange and sets `jwttoken` on the
/// route host at the end of it, so the flow is not driven from here: the route
/// is opened, the person signs in, and the cookie is read out of the shared
/// cookie store once it appears. Watching for the cookie rather than for a
/// particular URL is what keeps this working through MFA, a password reset, or
/// any other page Cosmos decides to show on the way.
class WebviewCosmosLogin implements CosmosLogin {
  const WebviewCosmosLogin({this.timeout = const Duration(minutes: 5)});

  /// How long the window may stay open before the attempt is abandoned. A
  /// window nobody finishes must not leave a future hanging for the session.
  final Duration timeout;

  @override
  bool get isSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  @override
  Future<CosmosSession?> signIn(Uri routeUrl) async {
    final completer = Completer<CosmosSession?>();
    final manager = CookieManager.instance();

    // Start clean. A half-finished session left in the web view sends Cosmos
    // into resuming that one instead of running the authorize flow: it asks
    // for the second factor and then returns to its own dashboard, because the
    // redirect it resumed was never the one this app asked for.
    try {
      await manager.deleteAllCookies();
    } on Object catch (error) {
      _log.warning('Could not clear the sign-in web view first: $error');
    }

    // The cookie alone is not the finish line. Cosmos sets jwttoken before MFA
    // is satisfied and checks MFAState separately, so a cookie taken the
    // moment it appears is a half-finished session Cosmos will refuse, and
    // taking it closed the window while the person was still being asked for
    // their second factor.
    //
    // The flow is done when it comes back to the route's own host, which only
    // happens after Cosmos's detect-callback has run, which only happens after
    // the whole login including MFA.
    Future<void> checkForCookie(Uri? landedOn) async {
      if (completer.isCompleted) return;
      if (landedOn == null) return;
      if (landedOn.host.toLowerCase() != routeUrl.host.toLowerCase()) {
        _log.fine('Still signing in at ${landedOn.host}');
        return;
      }
      final cookie = await _readSessionCookie(manager, routeUrl);
      if (cookie == null || completer.isCompleted) return;
      _log.info('Cosmos session cookie captured for ${routeUrl.host}');
      completer.complete(
        CosmosSession(
          host: routeUrl.host,
          cookie: cookie,
          obtainedAt: DateTime.now().toUtc(),
        ),
      );
    }

    // Whether the window is already gone. Closing one that has closed itself
    // raises an Objective-C exception inside AppKit's layout pass, which no
    // Dart catch can see and which takes the process with it.
    var windowGone = false;

    _log.info('Opening the Cosmos sign-in window for ${routeUrl.host}');
    final InAppBrowser? controller;
    try {
      controller = await _openWindow(
        routeUrl,
        onNavigated: checkForCookie,
        onClosed: () {
          windowGone = true;
          if (!completer.isCompleted) {
            _log.info('Cosmos sign-in window closed before it finished');
            completer.complete(null);
          }
        },
      );
    } on Object catch (error, stackTrace) {
      // A window that will not open used to leave the button resetting itself
      // and nothing else happening, which reads as the app ignoring the click.
      _log.severe(
        'Could not open the Cosmos sign-in window',
        error,
        stackTrace,
      );
      throw CosmosLoginUnavailable('$error');
    }

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _log.warning('Cosmos sign-in abandoned after $timeout');
          return null;
        },
      );
    } finally {
      // Off this call stack. Closing the window from inside the navigation
      // callback that just fired tears the view down while AppKit is still
      // laying it out, which crashes rather than closes.
      await Future<void>.delayed(Duration.zero);
      if (windowGone) {
        _log.fine('Sign-in window already closed itself; leaving it alone');
      } else {
        try {
          await controller.close();
        } on Object catch (error) {
          _log.fine('Sign-in window would not close: $error');
        }
      }
    }
  }

  /// The route's `jwttoken`, or null while it is not there yet.
  Future<String?> _readSessionCookie(
    CookieManager manager,
    Uri routeUrl,
  ) async {
    final cookie = await manager.getCookie(
      url: WebUri.uri(routeUrl),
      name: CosmosSession.cookieName,
    );
    final value = cookie?.value;
    if (value == null) return null;
    final text = '$value';
    return text.isEmpty ? null : text;
  }

  Future<InAppBrowser> _openWindow(
    Uri routeUrl, {
    required Future<void> Function(Uri?) onNavigated,
    required void Function() onClosed,
  }) async {
    final browser = _CosmosSignInBrowser(
      onNavigated: onNavigated,
      onClosed: onClosed,
    );
    await browser.openUrlRequest(
      urlRequest: URLRequest(url: WebUri.uri(routeUrl)),
      settings: InAppBrowserClassSettings(
        browserSettings: InAppBrowserSettings(hideUrlBar: false),
        webViewSettings: InAppWebViewSettings(
          // Cosmos runs its own authorization-code exchange across two hosts
          // and finishes on a page that sets the cookie, so the window has to
          // be a browser rather than a viewer: it follows the redirects, keeps
          // third-party cookies, and runs the scripts on the login page.
          javaScriptEnabled: true,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
          useShouldOverrideUrlLoading: false,
        ),
      ),
    );
    return browser;
  }
}

class _CosmosSignInBrowser extends InAppBrowser {
  _CosmosSignInBrowser({required this.onNavigated, required this.onClosed});

  final Future<void> Function(Uri?) onNavigated;
  final void Function() onClosed;

  @override
  void onLoadStart(WebUri? url) => _log.fine('Sign-in window loading $url');

  @override
  void onLoadStop(WebUri? url) {
    _log.fine('Sign-in window loaded $url');
    onNavigated(url);
  }

  /// A window that opens on a blank page says nothing about why, and the URL
  /// bar still shows the address that failed, so the failure has to be logged
  /// from here or it is invisible.
  @override
  void onReceivedError(WebResourceRequest request, WebResourceError error) {
    _log.severe(
      'Sign-in window failed to load ${request.url}: '
      '${error.type} ${error.description}',
    );
  }

  @override
  void onReceivedHttpError(
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    _log.warning(
      'Sign-in window got HTTP ${response.statusCode} for ${request.url}',
    );
  }

  @override
  void onExit() => onClosed();
}
