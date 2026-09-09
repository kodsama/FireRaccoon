import 'dart:async';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../widgets/cosmos_login_dialog.dart';
import 'cosmos_login.dart';
import 'cosmos_session.dart';

final _log = AppLogger.scoped('store.cosmosLoginWebview');

/// Cosmos sign-in hosted in the app, on every platform inappwebview covers.
class WebviewCosmosLogin implements CosmosLogin {
  const WebviewCosmosLogin({this.renewalTimeout = const Duration(seconds: 20)});

  /// How long a background renewal may run before the app stops waiting and
  /// asks a person instead. Short, because nothing on screen explains the wait.
  final Duration renewalTimeout;

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
  Future<CosmosSession?> signIn(BuildContext context, Uri routeUrl) async {
    // Start clean. A half-finished session left in the web view sends Cosmos
    // into resuming that one instead of running the authorize flow: it asks for
    // the second factor and then returns to its own dashboard, because the
    // redirect it resumed was never the one this app asked for.
    await CookieManager.instance().deleteAllCookies();
    if (!context.mounted) return null;
    return showCosmosLoginDialog(context: context, routeUrl: routeUrl);
  }

  @override
  Future<CosmosSession?> renew(Uri routeUrl, {String? staleCookie}) async {
    // Nothing is cleared here, unlike the sign-in. The Cosmos login this rides
    // on is exactly what was left behind last time, and wiping it would turn
    // every renewal into the password prompt this exists to avoid.
    final completer = Completer<CosmosSession?>();

    void finish(CosmosSession? session) {
      if (!completer.isCompleted) completer.complete(session);
    }

    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(routeUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        thirdPartyCookiesEnabled: true,
        sharedCookiesEnabled: true,
      ),
      onLoadStop: (_, url) async {
        if (completer.isCompleted || url == null) return;
        if (url.host.toLowerCase() != routeUrl.host.toLowerCase()) {
          _log.fine('Renewal is passing through ${url.host}');
          return;
        }
        // Back at the route, which is where the flow ends either way. What
        // decides it is whether Cosmos set a new cookie on the way: a route it
        // declines to open sets none, and the jar still holds the one that was
        // just refused, so a bare "is there a cookie" test hands the dead one
        // straight back and every request refuses it again.
        final cookie = await CookieManager.instance().getCookie(
          url: WebUri.uri(routeUrl),
          name: CosmosSession.cookieName,
        );
        final value = '${cookie?.value ?? ''}';
        if (value.isEmpty || value == staleCookie) {
          _log.info('Cosmos set no new session; the route stayed shut');
          finish(null);
          return;
        }
        finish(
          CosmosSession(
            host: routeUrl.host,
            cookie: value,
            obtainedAt: DateTime.now().toUtc(),
          ),
        );
      },
      onReceivedHttpError: (_, request, response) {
        // Cosmos hides a route it will not serve behind a 404 rather than a
        // redirect, so this is the ordinary way a renewal fails.
        if (request.url.host.toLowerCase() != routeUrl.host.toLowerCase()) {
          return;
        }
        _log.info('Cosmos answered the renewal ${response.statusCode}');
        finish(null);
      },
      onReceivedError: (_, request, error) {
        _log.fine('Renewal could not load ${request.url}: ${error.type}');
      },
    );

    await headless.run();
    try {
      return await completer.future.timeout(
        renewalTimeout,
        onTimeout: () {
          _log.info('Cosmos wanted more than a redirect; asking a person');
          return null;
        },
      );
    } finally {
      await headless.dispose();
    }
  }
}
