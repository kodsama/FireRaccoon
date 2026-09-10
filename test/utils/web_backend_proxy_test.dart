import 'package:fireraccoon/utils/web_backend_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backendIsProxied', () {
    test('is false off the web whatever the deployment says', () {
      // The proxy is a web-only arrangement: it exists because a browser
      // cannot reach the server's own network, and a desktop build has no
      // such problem. Server mode alone must not reroute a native client.
      expect(backendIsProxied(serverMode: true), isFalse);
      expect(backendIsProxied(serverMode: false), isFalse);
    });
  });

  group('resolveBackendUrlForHttp', () {
    test('hands back the configured URL when nothing is proxying', () {
      // Local mode, and every native build: the client dials Firefly itself,
      // so the address it was given is the address it uses.
      for (final url in const [
        'https://firefly.example',
        'http://Firefly-III:8080',
        'https://firefly.example/subpath',
        'not a url at all',
        '',
      ]) {
        expect(resolveBackendUrlForHttp(url, proxied: false), url);
      }
    });
  });
}
