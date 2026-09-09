import 'package:flutter/foundation.dart';

import 'cosmos_login.dart';
import 'cosmos_login_desktop.dart';
import 'cosmos_login_webview.dart';

/// The sign-in this build can actually run.
///
/// Web gets none: a browser already holds the cookie and sends it with every
/// request, so there is nothing for the app to capture or store.
CosmosLogin resolveCosmosLogin() {
  if (kIsWeb) return const UnsupportedCosmosLogin();
  const webview = WebviewCosmosLogin();
  if (webview.isSupported) return webview;
  const desktop = DesktopCosmosLogin();
  if (desktop.isSupported) return desktop;
  return const UnsupportedCosmosLogin();
}
