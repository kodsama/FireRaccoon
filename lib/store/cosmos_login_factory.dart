import 'package:flutter/foundation.dart';

import 'cosmos_login.dart';
import 'cosmos_login_webview.dart';

/// The sign-in this build can run.
///
/// Web gets none: a browser already holds the cookie and sends it with every
/// request, so there is nothing for the app to capture or store.
CosmosLogin resolveCosmosLogin() {
  if (kIsWeb) return const UnsupportedCosmosLogin();
  return const WebviewCosmosLogin();
}
