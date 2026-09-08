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

    Future<void> checkForCookie() async {
      if (completer.isCompleted) return;
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

    final controller = await _openWindow(
      routeUrl,
      onNavigated: checkForCookie,
      onClosed: () {
        if (!completer.isCompleted) {
          _log.info('Cosmos sign-in window closed before it finished');
          completer.complete(null);
        }
      },
    );

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _log.warning('Cosmos sign-in abandoned after $timeout');
          return null;
        },
      );
    } finally {
      await controller?.close();
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

  Future<InAppBrowser?> _openWindow(
    Uri routeUrl, {
    required Future<void> Function() onNavigated,
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
      ),
    );
    return browser;
  }
}

class _CosmosSignInBrowser extends InAppBrowser {
  _CosmosSignInBrowser({required this.onNavigated, required this.onClosed});

  final Future<void> Function() onNavigated;
  final void Function() onClosed;

  @override
  void onLoadStop(WebUri? url) => onNavigated();

  @override
  void onExit() => onClosed();
}
