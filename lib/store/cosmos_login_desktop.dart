import 'dart:async';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cosmos_login.dart';
import 'cosmos_session.dart';

final _log = AppLogger.scoped('store.cosmosLoginLinux');

/// Cosmos sign-in on Linux, where there is no inappwebview implementation.
///
/// The window this opens is webkit2gtk, which the Linux build already links
/// through flutter_web_auth_2, so it costs no new system dependency. Cookies
/// come back as a whole jar rather than one lookup, and only `jwttoken` for
/// the route host is kept: the rest belongs to whatever pages the login went
/// through and is none of the app's business.
class DesktopCosmosLogin implements CosmosLogin {
  const DesktopCosmosLogin({this.timeout = const Duration(minutes: 5)});

  final Duration timeout;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  @override
  Future<CosmosSession?> signIn(BuildContext context, Uri routeUrl) async {
    if (!await WebviewWindow.isWebviewAvailable()) {
      _log.warning('No system web view available for Cosmos sign-in');
      return null;
    }

    final completer = Completer<CosmosSession?>();
    final window = await WebviewWindow.create(
      configuration: CreateConfiguration(title: 'Sign in to Cosmos'),
    );

    Future<void> checkForCookie() async {
      if (completer.isCompleted) return;
      final cookie = await _readSessionCookie(window, routeUrl);
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

    window
      ..setOnUrlRequestCallback((_) {
        // Every navigation is a chance the cookie has appeared. False lets the
        // request proceed: the flow is Cosmos's to run, not ours to intercept.
        checkForCookie();
        return false;
      })
      ..onClose.whenComplete(() {
        if (!completer.isCompleted) {
          _log.info('Cosmos sign-in window closed before it finished');
          completer.complete(null);
        }
      })
      ..launch(routeUrl.toString());

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _log.warning('Cosmos sign-in abandoned after $timeout');
          return null;
        },
      );
    } finally {
      window.close();
    }
  }

  Future<String?> _readSessionCookie(Webview window, Uri routeUrl) async {
    final host = routeUrl.host.toLowerCase();
    for (final cookie in await window.getAllCookies()) {
      if (cookie.name != CosmosSession.cookieName) continue;
      // A cookie set for `.example.com` covers `firefly.example.com`, which is
      // how Cosmos scopes one when the route and the login share a domain.
      final domain = cookie.domain.toLowerCase().replaceFirst(
        RegExp(r'^\.'),
        '',
      );
      if (host == domain || host.endsWith('.$domain')) {
        return cookie.value.isEmpty ? null : cookie.value;
      }
    }
    return null;
  }
}
