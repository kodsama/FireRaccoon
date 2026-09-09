import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../widgets/cosmos_login_dialog.dart';
import 'cosmos_login.dart';
import 'cosmos_session.dart';

/// Cosmos sign-in hosted in the app, on every platform inappwebview covers.
class WebviewCosmosLogin implements CosmosLogin {
  const WebviewCosmosLogin();

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
}
