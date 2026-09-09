import 'package:fireraccoon_mcp/fireraccoon_mcp.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers/firefly_mock.dart';

const _target = FireflyTarget(baseUrl: fireflyBaseUrl, bearer: fireflyToken);

/// Answers every request the way a proxy with no route to Firefly does.
MockClient _unroutedClient() => MockClient(
  (_) async => http.Response(
    '404 page not found\n',
    404,
    headers: {'content-type': 'text/plain; charset=utf-8'},
  ),
);

/// Answers every request the way Cosmos answers one it wants a sign-in for.
MockClient _gatedClient() => MockClient(
  (_) async => http.Response(
    '',
    302,
    headers: {
      'location': 'https://cosmos.test/cosmos-ui/openid?client_id=__route_App',
    },
  ),
);

void main() {
  group('isProxyNotRouted', () {
    test('Cosmos hides a route behind Go\'s own plain-text 404', () {
      // A gated route does not redirect an unauthenticated caller, it stops
      // existing. Read as an answer, this said Firefly refused every request.
      expect(
        isProxyNotRouted(404, {
          'content-type': 'text/plain; charset=utf-8',
        }, '404 page not found\n'),
        isTrue,
      );
    });

    test('Firefly\'s own 404 is JSON and never counts', () {
      expect(
        isProxyNotRouted(404, {
          'content-type': 'application/json',
        }, '{"message":"Resource not found"}'),
        isFalse,
      );
    });

    test('another text 404 is somebody else\'s business', () {
      expect(
        isProxyNotRouted(404, {'content-type': 'text/plain'}, 'no such thing'),
        isFalse,
      );
      expect(
        isProxyNotRouted(200, {
          'content-type': 'text/plain',
        }, '404 page not found'),
        isFalse,
      );
    });
  });

  group('ProxyGateClient', () {
    test('sends the proxy session the app holds', () async {
      String? sent;
      final client = ProxyGateClient(
        MockClient((request) async {
          sent = request.headers['Cookie'];
          return http.Response('{}', 200);
        }),
        'jwttoken=value',
      );

      await client.get(Uri.parse('$fireflyBaseUrl/api/v1/about'));

      expect(sent, 'jwttoken=value');
    });

    test('keeps a cookie the caller already set', () async {
      String? sent;
      final client = ProxyGateClient(
        MockClient((request) async {
          sent = request.headers['Cookie'];
          return http.Response('{}', 200);
        }),
        'jwttoken=value',
      );

      await client.get(
        Uri.parse('$fireflyBaseUrl/api/v1/about'),
        headers: {'Cookie': 'other=1'},
      );

      expect(sent, 'other=1; jwttoken=value');
    });

    test('a proxy with no route to Firefly says so, not sign in', () async {
      // No credential fixes this and no session creates the route, so an
      // agent told to sign in goes round a loop that cannot help.
      final client = ProxyGateClient(_unroutedClient(), null);

      await expectLater(
        client.get(Uri.parse('$fireflyBaseUrl/api/v1/about')),
        throwsA(isA<ProxyNoRouteException>()),
      );
    });

    test('a redirect to the Cosmos sign-in asks for a sign-in', () async {
      final client = ProxyGateClient(_gatedClient(), null);

      await expectLater(
        client.get(Uri.parse('$fireflyBaseUrl/api/v1/about')),
        throwsA(isA<ProxySignInRequiredException>()),
      );
    });

    test('a text 404 that is not the proxy comes back whole', () async {
      // Looking at the body is the one thing that consumes the stream.
      final client = ProxyGateClient(
        MockClient(
          (_) async => http.Response(
            'nope',
            404,
            headers: {'content-type': 'text/plain'},
          ),
        ),
        null,
      );

      final response = await client.get(Uri.parse('$fireflyBaseUrl/x'));

      expect(response.statusCode, 404);
      expect(response.body, 'nope');
    });

    test('closing it closes the client it wraps', () {
      var closed = 0;
      ProxyGateClient(_ClosingClient(() => closed++), null).close();
      expect(closed, 1);
    });
  });

  group('a Cosmos route with no session', () {
    test(
      'check_connection names the sign-in rather than a dead server',
      () async {
        final tool = buildTools(
          target: _target,
          httpClient: _gatedClient(),
        ).firstWhere((t) => t.name == 'check_connection');

        final result = await tool.run({});

        // "backend_unreachable" sent agents off to restart a server that was
        // running perfectly well behind a door nobody had opened.
        expect(result['ok'], isFalse);
        expect(result['code'], 'proxy_sign_in_required');
        expect(result['proxy'], 'cosmos');
        expect(result['configured'], isTrue);
        expect(result['connected'], isFalse);
        expect(result['error'], contains('Cosmos'));
      },
    );

    test('capabilities carries the same state', () async {
      final tool = buildTools(
        target: _target,
        httpClient: _gatedClient(),
      ).firstWhere((t) => t.name == 'get_capabilities');

      final result = await tool.run({});
      final backend = result['backend'] as Map<String, Object?>;

      expect(backend['code'], 'proxy_sign_in_required');
      expect(backend['proxy'], 'cosmos');
    });

    test('an ordinary tool describes the door instead of failing', () async {
      final tool = buildTools(
        target: _target,
        httpClient: _gatedClient(),
      ).firstWhere((t) => t.name == 'get_accounts');

      final result = await tool.run({});

      expect(result['ok'], isFalse);
      expect(result['code'], 'proxy_sign_in_required');
      expect(result['backend_url'], fireflyBaseUrl);
      expect(result['remedy'], contains('Cosmos SSO'));
    });
  });

  group('an address that answers without routing to Firefly', () {
    test('check_connection points at the address, not a sign-in', () async {
      final tool = buildTools(
        target: _target,
        httpClient: _unroutedClient(),
      ).firstWhere((t) => t.name == 'check_connection');

      final result = await tool.run({});

      expect(result['ok'], isFalse);
      expect(result['code'], 'proxy_no_route');
      expect(result['configured'], isTrue);
      expect(result['connected'], isFalse);
      expect(result['reason'], contains('did not route'));
      // Nothing about signing in: no credential fixes a route that is absent.
      expect(result['proxy'], isNull);
    });

    test('an ordinary tool says the same', () async {
      final tool = buildTools(
        target: _target,
        httpClient: _unroutedClient(),
      ).firstWhere((t) => t.name == 'get_accounts');

      final result = await tool.run({});

      expect(result['code'], 'proxy_no_route');
      expect(result['remedy'], contains('running behind'));
    });
  });
}

class _ClosingClient extends http.BaseClient {
  _ClosingClient(this._onClose);

  final void Function() _onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 200);

  @override
  void close() => _onClose();
}
