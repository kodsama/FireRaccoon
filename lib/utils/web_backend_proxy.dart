// coverage:ignore-file — platform channel / conditional import shim
import 'package:flutter/foundation.dart';

const _proxiedWebHost = 'cash-api.kodsama.com';
const _webProxyPath = '/firefly';

/// Returns the effective backend URL used by HTTP clients.
///
/// On web, requests to hosts without matching CORS policy can be routed through
/// our same-origin Nginx proxy path.
String resolveBackendUrlForHttp(String configuredUrl) {
  if (!kIsWeb) return configuredUrl;

  final uri = Uri.tryParse(configuredUrl);
  if (uri == null) return configuredUrl;
  if (uri.host != _proxiedWebHost) return configuredUrl;

  return '${Uri.base.origin}$_webProxyPath';
}
