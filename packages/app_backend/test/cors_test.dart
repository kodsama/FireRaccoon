import 'dart:io';

import 'package:fireracoon_app_backend/fireracoon_app_backend.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers/test_store.dart';

void main() {
  late Directory tmp;
  const storePassword = 'Store-Password1!';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fireracoon-cors');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<AppServer> ready({List<String> allowedOrigins = const []}) async {
    return openTestServer(
      ServerConfig(
        mode: FireracoonMode.server,
        dataDir: tmp.path,
        dataPassword: storePassword,
        port: 0,
        webRoot: tmp.path,
        allowedOrigins: allowedOrigins,
      ),
    );
  }

  Future<Response> capabilities(AppServer app, {String? origin}) async {
    return await app.handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/capabilities'),
        headers: {'origin': ?origin},
      ),
    );
  }

  test('an unconfigured origin is told nothing', () async {
    // No header is how a browser is told "not allowed". This used to answer
    // every origin with a wildcard.
    final app = await ready();

    final response = await capabilities(app, origin: 'https://evil.example');

    expect(response.statusCode, 200);
    expect(
      response.headers.containsKey('access-control-allow-origin'),
      isFalse,
    );
  });

  test('a configured origin is named, not wildcarded', () async {
    // Named rather than '*', because a wildcard forbids credentials and an
    // allowed origin needs the session cookie to be any use.
    final app = await ready(allowedOrigins: const ['http://localhost:5000']);

    final response = await capabilities(app, origin: 'http://localhost:5000');

    expect(
      response.headers['access-control-allow-origin'],
      'http://localhost:5000',
    );
    expect(response.headers['access-control-allow-credentials'], 'true');
    expect(response.headers['vary'], contains('origin'));
  });

  test('a preflight from an unconfigured origin permits nothing', () async {
    final app = await ready(allowedOrigins: const ['http://localhost:5000']);

    final response = await app.handler(
      Request(
        'OPTIONS',
        Uri.parse('http://localhost/api/login'),
        headers: const {'origin': 'https://evil.example'},
      ),
    );

    expect(
      response.headers.containsKey('access-control-allow-origin'),
      isFalse,
    );
    expect(
      response.headers.containsKey('access-control-allow-methods'),
      isFalse,
    );
  });

  test('a same-origin caller is unaffected', () async {
    // The common case: this process serves the web UI, so the UI is same-origin
    // and sends no Origin header at all.
    final app = await ready();

    final response = await capabilities(app);

    expect(response.statusCode, 200);
    expect(
      response.headers.containsKey('access-control-allow-origin'),
      isFalse,
    );
  });
}
