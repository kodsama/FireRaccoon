import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../l10n/l10n_extensions.dart';
import '../store/cosmos_session.dart';
import '../theme/app_theme.dart';

final _log = AppLogger.scoped('widgets.cosmosLoginDialog');

/// Runs the Cosmos sign-in inside the app rather than in a window of its own.
///
/// The plugin's InAppBrowser opens a native window with an NSToolbar, and that
/// toolbar crashes during its own layout pass: an uncaught
/// `-[__NSArrayM insertObject:atIndex:]` inside
/// `-[NSToolbarItemViewer configureForLayoutInDisplayMode:...]`, which no Dart
/// catch can see. Hosting the web view here avoids the toolbar, avoids a second
/// NSWindow whose closing told AppKit the app was finished, and leaves nothing
/// native to close afterwards.
Future<CosmosSession?> showCosmosLoginDialog({
  required BuildContext context,
  required Uri routeUrl,
}) {
  return showDialog<CosmosSession>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CosmosLoginDialog(routeUrl: routeUrl),
  );
}

class _CosmosLoginDialog extends StatefulWidget {
  const _CosmosLoginDialog({required this.routeUrl});

  final Uri routeUrl;

  @override
  State<_CosmosLoginDialog> createState() => _CosmosLoginDialogState();
}

class _CosmosLoginDialogState extends State<_CosmosLoginDialog> {
  String _address = '';
  bool _loading = true;
  bool _finishing = false;

  /// The cookie alone is not the finish line. Cosmos sets jwttoken before MFA
  /// is satisfied and checks MFAState separately, so the flow is done only when
  /// it comes back to the route's own host, which happens after its
  /// detect-callback has run, which happens after the whole login.
  Future<void> _checkForSession(WebUri? url) async {
    if (_finishing || url == null) return;
    setState(() {
      _address = url.toString();
      _loading = false;
    });
    if (url.host.toLowerCase() != widget.routeUrl.host.toLowerCase()) {
      _log.fine('Still signing in at ${url.host}');
      return;
    }
    final cookie = await CookieManager.instance().getCookie(
      url: WebUri.uri(widget.routeUrl),
      name: CosmosSession.cookieName,
    );
    final value = cookie?.value;
    if (value == null || '$value'.isEmpty) return;
    if (!mounted) return;
    _finishing = true;
    _log.info('Cosmos session cookie captured for ${widget.routeUrl.host}');
    Navigator.of(context).pop(
      CosmosSession(
        host: widget.routeUrl.host,
        cookie: '$value',
        obtainedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: size.width * 0.8,
        height: size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: colors.text2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // The address is shown because this asks for a password:
                      // nobody should type one into a page whose origin they
                      // cannot see.
                      _address.isEmpty ? '$widget.routeUrl' : _address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.text2),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.cancel,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri.uri(widget.routeUrl)),
                initialSettings: InAppWebViewSettings(
                  // Cosmos runs its own authorization-code exchange across two
                  // hosts and finishes on a page that sets the cookie, so this
                  // has to follow redirects, keep third-party cookies and run
                  // the scripts on the login page.
                  javaScriptEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  sharedCookiesEnabled: true,
                  transparentBackground: true,
                ),
                onLoadStart: (_, url) {
                  _log.fine('Sign-in loading $url');
                  if (mounted) setState(() => _loading = true);
                },
                onLoadStop: (_, url) => _checkForSession(url),
                onReceivedError: (_, request, error) => _log.severe(
                  'Sign-in failed to load ${request.url}: '
                  '${error.type} ${error.description}',
                ),
                onReceivedHttpError: (_, request, response) => _log.warning(
                  'Sign-in got HTTP ${response.statusCode} for ${request.url}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
