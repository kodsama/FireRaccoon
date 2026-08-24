import 'dart:io';

import 'package:fireracoon_app_backend/fireracoon_app_backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers/test_store.dart';

void main() {
  late Directory tmp;
  const storePassword = 'Store-Password1!';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fireracoon-proxy');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// A server with one signed-in admin and a recording upstream.
  Future<({AppServer app, String session, List<Uri> asked})> ready({
    Map<String, String> upstreamHeaders = const {
      'content-type': 'application/vnd.api+json',
    },
  }) async {
    final asked = <Uri>[];
    final client = MockClient((request) async {
      asked.add(request.url);
      return http.Response('{"data":[]}', 200, headers: upstreamHeaders);
    });
    final app = AppServer(
      config: ServerConfig(
        mode: FireracoonMode.server,
        dataDir: tmp.path,
        dataPassword: storePassword,
        port: 0,
        webRoot: tmp.path,
      ),
      httpClient: client,
      passwordIterations: kTestPbkdf2Iterations,
      storeIterations: kTestPbkdf2Iterations,
    );
    await app.unlockStore(
      password: storePassword,
      confirmPassword: storePassword,
    );
    await app.repository.setup(
      adminName: 'Alex',
      adminPassword: 'Password1!',
      fireflyUrl: 'https://firefly.example',
      fireflyToken: 'ff-token-secret',
    );
    final login = await app.repository.login(
      name: 'Alex',
      password: 'Password1!',
    );
    return (app: app, session: login.token, asked: asked);
  }

  Future<Response> proxy(
    AppServer app,
    String session,
    String path, {
    String method = 'GET',
  }) async {
    return await app.handler(
      Request(
        method,
        Uri.parse('http://localhost/api/firefly/$path'),
        headers: {'x-fireracoon-session': session},
      ),
    );
  }

  test('an API path is proxied through', () async {
    final (app: app, session: session, asked: asked) = await ready();

    final response = await proxy(app, session, 'api/v1/accounts?limit=2');

    expect(response.statusCode, 200);
    expect(asked.single.toString(), contains('/api/v1/accounts'));
    expect(asked.single.queryParameters['limit'], '2');
  });

  test('a path outside the API is refused', () async {
    // The token this attaches is the installation's own, so an unrestricted
    // path would reach any address on the Firefly host carrying it.
    final (app: app, session: session, asked: asked) = await ready();

    final response = await proxy(app, session, 'login');

    expect(response.statusCode, 404);
    expect(asked, isEmpty);
  });

  test('a traversal out of the API is refused', () async {
    final (app: app, session: session, asked: asked) = await ready();

    final response = await proxy(app, session, 'api/../../secrets');

    expect(response.statusCode, 404);
    expect(asked, isEmpty);
  });

  test('an upstream cookie is not passed on', () async {
    // Firefly's cookies belong to Firefly. Forwarded, they land scoped to this
    // origin, where they mean nothing and can collide with the session cookie
    // this server sets.
    final (app: app, session: session, asked: _) = await ready(
      upstreamHeaders: const {
        'content-type': 'application/vnd.api+json',
        'set-cookie': 'firefly_session=upstream-value; Path=/',
      },
    );

    final response = await proxy(app, session, 'api/v1/accounts');

    expect(response.statusCode, 200);
    expect(response.headers.containsKey('set-cookie'), isFalse);
  });

  test('an unauthenticated caller reaches nothing', () async {
    final (app: app, session: _, asked: asked) = await ready();

    final response = await app.handler(
      Request('GET', Uri.parse('http://localhost/api/firefly/api/v1/accounts')),
    );

    expect(response.statusCode, 401);
    expect(asked, isEmpty);
  });

  test('every place a session can arrive is checked the same way', () async {
    // The header and the cookie were returned exactly as presented while only a
    // bearer was resolved, so what this helper meant depended on which header
    // the token arrived in.
    final (app: app, session: session, asked: asked) = await ready();

    Future<int> statusWith(Map<String, String> headers) async {
      final response = await app.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/api/firefly/api/v1/accounts'),
          headers: headers,
        ),
      );
      return response.statusCode;
    }

    // A real session works from all three.
    expect(await statusWith({'x-fireracoon-session': session}), 200);
    expect(await statusWith({'authorization': 'Bearer $session'}), 200);
    expect(await statusWith({'cookie': 'fireracoon_session=$session'}), 200);

    // An invented one works from none of them.
    expect(await statusWith({'x-fireracoon-session': 'not-a-session'}), 401);
    expect(await statusWith({'authorization': 'Bearer not-a-session'}), 401);
    expect(
      await statusWith({'cookie': 'fireracoon_session=not-a-session'}),
      401,
    );

    // Only the six that carried a real session reached upstream.
    expect(asked, hasLength(3));
  });
}
