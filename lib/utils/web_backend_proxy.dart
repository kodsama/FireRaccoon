// coverage:ignore-file — kIsWeb only ever takes one branch per platform
import 'package:flutter/foundation.dart';

/// Same-origin route FireRaccoon's own server proxies through to Firefly III.
///
/// Registered by the app backend as `/api/firefly/<path>`, so a client asks for
/// `<origin>/api/firefly/api/v1/about` and the server makes the real call.
const _serverProxyPath = '/api/firefly';

/// Whether Firefly is dialled by FireRaccoon's server rather than by this app.
///
/// Only ever true for a web build in server mode, where the page was served by
/// the very process that holds the credentials and proxies the API.
bool backendIsProxied({required bool serverMode}) => kIsWeb && serverMode;

/// The backend URL an HTTP client in this process should actually ask.
///
/// When the server is doing the dialling this is always its own origin, whatever
/// the configured URL says. Matching one known hostname instead, which is what
/// this did, meant every other address was fetched by the browser directly, and
/// a backend on the server's own network cannot be reached that way at all: a
/// container name does not resolve in a browser, and a plain-http address is
/// blocked as mixed content on an https page long before DNS is consulted. The
/// configured URL is still what the server is told to call; it just stops being
/// something this process tries to open a socket to.
String resolveBackendUrlForHttp(String configuredUrl, {required bool proxied}) {
  if (!proxied) return configuredUrl;
  return '${Uri.base.origin}$_serverProxyPath';
}
