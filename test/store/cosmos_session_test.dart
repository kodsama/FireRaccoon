import 'dart:convert';

import 'package:fireraccoon/store/cosmos_login.dart';
import 'package:fireraccoon/store/cosmos_session.dart';
import 'package:fireraccoon/store/cosmos_session_client.dart';
import 'package:fireraccoon/store/cosmos_sign_in_required_exception.dart';
import 'package:fireraccoon/store/no_route_to_firefly_exception.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

CosmosSession _session({String host = 'firefly.example'}) => CosmosSession(
  host: host,
  cookie: 'jwt-value',
  obtainedAt: DateTime.utc(2026, 9, 8),
);

void main() {
  group('CosmosSession', () {
    test('carries only the cookie Cosmos gates on', () {
      expect(CosmosSession.cookieName, 'jwttoken');
      expect(_session().cookieHeader, 'jwttoken=jwt-value');
    });

    test('a session belongs to one host', () {
      final session = _session();
      expect(
        session.appliesTo(Uri.parse('https://firefly.example/api')),
        isTrue,
      );
      // Case is not part of a hostname's identity.
      expect(
        session.appliesTo(Uri.parse('https://FIREFLY.EXAMPLE/api')),
        isTrue,
      );
      // A Cosmos credential handed to a server that never asked for one is a
      // credential leak, so anything else is refused.
      expect(
        session.appliesTo(Uri.parse('https://other.example/api')),
        isFalse,
      );
    });

    test('survives a round trip through the store', () {
      final restored = CosmosSession.fromJson(
        jsonDecode(jsonEncode(_session().toJson())) as Map<String, Object?>,
      );

      expect(restored!.host, 'firefly.example');
      expect(restored.cookie, 'jwt-value');
      expect(restored.obtainedAt, DateTime.utc(2026, 9, 8));
    });

    test('a shape it does not recognise is no session, not a crash', () {
      // A store written by a version that shaped this differently must not stop
      // the app from starting.
      expect(CosmosSession.fromJson(const {}), isNull);
      expect(CosmosSession.fromJson(const {'host': '', 'cookie': 'c'}), isNull);
      expect(CosmosSession.fromJson(const {'host': 'h', 'cookie': ''}), isNull);
      expect(
        CosmosSession.fromJson(const {
          'host': 'h',
          'cookie': 'c',
          'obtained_at': 'not a date',
        }),
        isNull,
      );
    });
  });

  group('when the sign-in is finished', () {
    // Cosmos sets jwttoken before MFA is satisfied and checks MFAState
    // separately, so the cookie appearing is not the finish line. Taking it
    // early saved a session Cosmos would refuse, and closed the window while
    // the person was still being asked for a second factor.
    bool finished(Uri landedOn, Uri routeUrl) =>
        landedOn.host.toLowerCase() == routeUrl.host.toLowerCase();

    final route = Uri.parse('https://cash.example');

    test('not while still on the identity provider', () {
      expect(
        finished(Uri.parse('https://cosmos.example/cosmos-ui/login'), route),
        isFalse,
      );
      expect(
        finished(Uri.parse('https://cosmos.example/cosmos-ui/openid'), route),
        isFalse,
      );
    });

    test('yes once it comes back to the route it started from', () {
      // Only Cosmos's own detect-callback brings it back here, and that runs
      // after the whole login.
      expect(
        finished(
          Uri.parse(
            'https://cash.example/cosmos/oauth2/detect-callback?code=x',
          ),
          route,
        ),
        isTrue,
      );
      expect(finished(Uri.parse('https://cash.example/'), route), isTrue);
    });
  });

  group('CosmosSessionClient', () {
    test('sends the cookie to the protected host', () async {
      String? sent;
      final client = CosmosSessionClient(
        inner: MockClient((request) async {
          sent = request.headers['Cookie'];
          return http.Response('{}', 200);
        }),
        session: _session,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(sent, 'jwttoken=jwt-value');
    });

    test('sends it nowhere else', () async {
      String? sent;
      final client = CosmosSessionClient(
        inner: MockClient((request) async {
          sent = request.headers['Cookie'];
          return http.Response('{}', 200);
        }),
        session: _session,
      );

      await client.get(Uri.parse('https://other.example/api/v1/about'));

      expect(sent, isNull);
    });

    test('keeps a cookie the caller already set', () async {
      String? sent;
      final client = CosmosSessionClient(
        inner: MockClient((request) async {
          sent = request.headers['Cookie'];
          return http.Response('{}', 200);
        }),
        session: _session,
      );

      await client.get(
        Uri.parse('https://firefly.example/api/v1/about'),
        headers: {'Cookie': 'other=1'},
      );

      expect(sent, 'other=1; jwttoken=jwt-value');
    });

    test('reads the session per request, not once at construction', () async {
      // A sign-in or a sign-out during the life of one client has to be picked
      // up by the next call, or the app keeps using a session it has dropped.
      CosmosSession? current;
      final sent = <String?>[];
      final client = CosmosSessionClient(
        inner: MockClient((request) async {
          sent.add(request.headers['Cookie']);
          return http.Response('{}', 200);
        }),
        session: () => current,
      );

      await client.get(Uri.parse('https://firefly.example/a'));
      current = _session();
      await client.get(Uri.parse('https://firefly.example/b'));

      expect(sent, [null, 'jwttoken=jwt-value']);
    });

    test(
      'a redirect to the Cosmos login is a shut door, not an answer',
      () async {
        var rejected = 0;
        final client = CosmosSessionClient(
          inner: MockClient(
            (_) async => http.Response(
              '',
              302,
              headers: {
                'location':
                    'https://cosmos.example/cosmos-ui/openid'
                    '?client_id=__route_Firefly-III',
              },
            ),
          ),
          session: _session,
          onGateRejected: (_) => rejected++,
        );

        await expectLater(
          client.get(Uri.parse('https://firefly.example/api/v1/about')),
          throwsA(isA<CosmosSignInRequiredException>()),
        );
        expect(rejected, 1);
      },
    );

    test('a plain 404 is no route to Firefly, not a sign-in', () async {
      // A proxy that wants a credential redirects. One that answers with
      // Go's own http.NotFound has no route to Firefly at all, so no sign-in
      // helps: offering one sent people round a loop that could not work.
      var rejected = 0;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '404 page not found\n',
            404,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          ),
        ),
        session: _session,
        onGateRejected: (_) => rejected++,
      );

      await expectLater(
        client.get(Uri.parse('https://firefly.example/api/v1/about')),
        throwsA(
          isA<NoRouteToFireflyException>().having(
            (e) => e.host,
            'host',
            'firefly.example',
          ),
        ),
      );
      // Not reported to the gate: there is no session to renew for a route
      // that is not there.
      expect(rejected, isZero);
    });

    test('somebody else\'s small text 404 is handed back untouched', () async {
      var rejected = 0;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            'no such account',
            404,
            headers: {'content-type': 'text/plain'},
          ),
        ),
        session: _session,
        onGateRejected: (_) => rejected++,
      );

      final response = await client.get(
        Uri.parse('https://firefly.example/api/v1/about'),
      );

      // Looking at the body is the one thing that consumes the stream, so a
      // response that turns out not to be Cosmos has to come back whole.
      expect(response.statusCode, 404);
      expect(response.body, 'no such account');
      expect(rejected, isZero);
    });

    test('Firefly\'s own JSON 404 is never read as a shut door', () async {
      var rejected = 0;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '{"message":"Resource not found"}',
            404,
            headers: {'content-type': 'application/json'},
          ),
        ),
        session: _session,
        onGateRejected: (_) => rejected++,
      );

      final response = await client.get(
        Uri.parse('https://firefly.example/api/v1/accounts/9999'),
      );

      expect(response.statusCode, 404);
      expect(rejected, isZero);
    });

    test('a Cosmos gate is seen rather than followed', () async {
      // The client underneath follows redirects by default, and a Cosmos gate
      // is a redirect. Followed, the only thing that ever came back was the
      // sign-in page as a perfectly successful 200, so the app reported a
      // wrong address for a server waiting to be signed in to.
      final requested = <Uri>[];
      final client = CosmosSessionClient(
        inner: MockClient((request) async {
          requested.add(request.url);
          if (request.url.host == 'firefly.example') {
            return http.Response(
              '',
              302,
              headers: {
                'location':
                    'https://cosmos.example/cosmos-ui/openid'
                    '?client_id=__route_Firefly-III',
              },
            );
          }
          return http.Response('<html>sign in</html>', 200);
        }),
        session: _session,
      );

      await expectLater(
        client.get(Uri.parse('https://firefly.example/api/v1/about')),
        throwsA(isA<CosmosSignInRequiredException>()),
      );
      // Stopped at the gate: the sign-in page was never fetched.
      expect(requested, [Uri.parse('https://firefly.example/api/v1/about')]);
    });

    test('an ordinary redirect is still followed', () async {
      final requested = <Uri>[];
      final client = CosmosSessionClient(
        inner: MockClient((request) async {
          requested.add(request.url);
          if (request.url.path == '/api/v1/about') {
            return http.Response(
              '',
              301,
              headers: {'location': '/api/v1/about/'},
            );
          }
          return http.Response('{}', 200);
        }),
        session: _session,
      );

      final response = await client.get(
        Uri.parse('https://firefly.example/api/v1/about'),
      );

      expect(response.statusCode, 200);
      expect(requested.last.path, '/api/v1/about/');
    });

    test('credentials do not travel across a redirect to another host', () async {
      // Following one with the headers intact would hand the Firefly token and
      // the route cookie to whatever host the answer pointed at.
      final headers = <Map<String, String>>[];
      final client = CosmosSessionClient(
        inner: MockClient((request) async {
          headers.add(Map.of(request.headers));
          if (request.url.host == 'firefly.example') {
            return http.Response(
              '',
              302,
              headers: {'location': 'https://elsewhere.example/somewhere'},
            );
          }
          return http.Response('{}', 200);
        }),
        session: _session,
      );

      await client.get(
        Uri.parse('https://firefly.example/api/v1/about'),
        headers: {'Authorization': 'Bearer firefly-token'},
      );

      expect(headers.first['Cookie'], 'jwttoken=jwt-value');
      expect(headers.last.containsKey('Authorization'), isFalse);
      expect(headers.last.containsKey('Cookie'), isFalse);
    });

    test('a redirect loop ends rather than hanging the request', () async {
      var hops = 0;
      final client = CosmosSessionClient(
        inner: MockClient((request) async {
          hops++;
          return http.Response('', 302, headers: {'location': '/round/$hops'});
        }),
        session: _session,
      );

      final response = await client.get(
        Uri.parse('https://firefly.example/api/v1/about'),
      );

      expect(response.statusCode, 302);
      expect(hops, 6);
    });

    test('an ordinary answer is not mistaken for a shut door', () async {
      var rejected = 0;
      final client = CosmosSessionClient(
        inner: MockClient((_) async => http.Response('{}', 200)),
        session: _session,
        onGateRejected: (_) => rejected++,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(rejected, isZero);
    });

    test('the address Cosmos refused is what gets reported', () async {
      // It is the door to renew, and reading it back out of the credentials
      // instead closed a loop Riverpod refused outright.
      Uri? refused;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://cosmos.example/cosmos-ui/openid'
                  '?client_id=__route_Firefly-III',
            },
          ),
        ),
        session: _session,
        onGateRejected: (url) => refused = url,
      );

      await expectLater(
        client.get(Uri.parse('https://firefly.example/api/v1/about')),
        throwsA(isA<CosmosSignInRequiredException>()),
      );
      expect(refused, Uri.parse('https://firefly.example/api/v1/about'));
    });

    test('the cookie Cosmos rolls forward replaces the one in hand', () async {
      // Cosmos gives a route session fourteen days and re-issues it once the
      // token is a day old. A browser stays signed in for months because it
      // takes the new cookie every time; keeping the one captured at sign-in
      // made this the one client that expired on schedule.
      String? rolled;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '{}',
            200,
            headers: {
              'set-cookie':
                  'jwttoken=fresh-value; Path=/; Expires=Wed, 23 Sep 2026 '
                  '10:00:00 GMT; HttpOnly',
            },
          ),
        ),
        session: _session,
        onSessionRolledForward: (cookie) => rolled = cookie,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(rolled, 'fresh-value');
    });

    test('the same cookie coming back is not a new session', () async {
      String? rolled;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '{}',
            200,
            headers: {'set-cookie': 'jwttoken=jwt-value; Path=/'},
          ),
        ),
        session: _session,
        onSessionRolledForward: (cookie) => rolled = cookie,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(rolled, isNull);
    });

    test('Cosmos clearing the cookie is not a session to keep', () async {
      // That is a sign-out. The next request meets the door and the gate says
      // so; storing an empty cookie would just send an empty one forever.
      String? rolled;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '{}',
            200,
            headers: {'set-cookie': 'jwttoken=; Path=/; Max-Age=0'},
          ),
        ),
        session: _session,
        onSessionRolledForward: (cookie) => rolled = cookie,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(rolled, isNull);
    });

    test('somebody else\'s cookie is not the route session', () async {
      String? rolled;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '{}',
            200,
            headers: {'set-cookie': 'XSRF-TOKEN=abc; Path=/'},
          ),
        ),
        session: _session,
        onSessionRolledForward: (cookie) => rolled = cookie,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(rolled, isNull);
    });

    test('no session in hand means nothing to roll forward', () async {
      String? rolled;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '{}',
            200,
            headers: {'set-cookie': 'jwttoken=fresh-value; Path=/'},
          ),
        ),
        session: () => null,
        onSessionRolledForward: (cookie) => rolled = cookie,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(rolled, isNull);
    });

    test('an answer from behind the door is reported as one', () async {
      // The only proof a session works, and the one thing that lets the app
      // try another quiet renewal when this session runs out in its turn.
      var accepted = 0;
      final client = CosmosSessionClient(
        inner: MockClient((_) async => http.Response('{}', 200)),
        session: _session,
        onGateAccepted: () => accepted++,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(accepted, 1);
    });

    test('a shut door is never reported as an answer', () async {
      var accepted = 0;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '404 page not found',
            404,
            headers: {'content-type': 'text/plain'},
          ),
        ),
        session: _session,
        onGateAccepted: () => accepted++,
      );

      await expectLater(
        client.get(Uri.parse('https://firefly.example/api/v1/about')),
        throwsA(isA<NoRouteToFireflyException>()),
      );
      expect(accepted, isZero);
    });
  });

  group('CosmosSessionClient lifecycle', () {
    test('closing it closes the client it wraps', () {
      var closed = 0;
      final client = CosmosSessionClient(
        inner: MockClient((_) async => http.Response('{}', 200)),
        session: () => null,
      );
      // MockClient's close is a no-op, so the wrapper is checked against one
      // that records instead.
      final recording = _RecordingClient(() => closed++);
      CosmosSessionClient(inner: recording, session: () => null).close();
      client.close();

      expect(closed, 1);
    });
  });

  group('UnsupportedCosmosLogin', () {
    testWidgets('reports itself unavailable and signs nobody in', (
      tester,
    ) async {
      const login = UnsupportedCosmosLogin();
      final route = Uri.parse('https://cash.example');
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.shrink();
          },
        ),
      );

      expect(login.isSupported, isFalse);
      // Both answer null rather than throwing, so a caller that asks anyway
      // gets the same "nobody signed in" a closed window would give.
      expect(await login.renew(route), isNull);
      expect(await login.signIn(context, route), isNull);
    });

    test('a window that would not open says why', () {
      // Not const, so the constructor is actually run.
      // ignore: prefer_const_constructors
      final unavailable = CosmosLoginUnavailable('no window server');

      expect(unavailable.reason, 'no window server');
      expect('$unavailable', contains('no window server'));
    });
  });

  group('NoRouteToFireflyException', () {
    test('names the host that answered without routing', () {
      final error = NoRouteToFireflyException('cash.example');

      expect(error.host, 'cash.example');
      // Says what happened rather than blaming Firefly for a request it never
      // saw, and unreachable so nothing downstream reports a refusal.
      expect('$error', contains('cash.example'));
      expect('$error', contains('did not route'));
      expect(error.unreachable, isTrue);
    });
  });

  group('isCosmosLoginRedirect', () {
    test('only a redirect to a Cosmos login path counts', () {
      expect(
        isCosmosLoginRedirect(302, {
          'location':
              'https://c.example/cosmos-ui/openid?client_id=__route_App',
        }),
        isTrue,
      );
      expect(
        isCosmosLoginRedirect(307, {
          'location': 'https://c.example/cosmos-ui/login?notlogged=1',
        }),
        isTrue,
      );
      // Firefly never sends an API call to a Cosmos login, so a redirect
      // anywhere else is the ledger's business and not a lost session.
      expect(
        isCosmosLoginRedirect(302, {'location': 'https://f.example/elsewhere'}),
        isFalse,
      );
      // Matched on the path, not anywhere in the string. This decides whether
      // someone is told to sign in or told their address is wrong, so a URL
      // that merely mentions the text must not be taken for a Cosmos gate.
      expect(
        isCosmosLoginRedirect(302, {
          'location': 'https://f.example/go?next=/cosmos-ui/openid',
        }),
        isFalse,
      );
      // The OpenID form has to carry the auto-provisioned route client.
      expect(
        isCosmosLoginRedirect(302, {
          'location': 'https://c.example/cosmos-ui/openid?client_id=other',
        }),
        isFalse,
      );
      expect(
        isCosmosLoginRedirect(302, {
          'location': 'https://c.example/cosmos-ui/openid?client_id=__route_Firefly-III',
        }),
        isTrue,
      );
      expect(isCosmosLoginRedirect(302, const {}), isFalse);
      expect(
        isCosmosLoginRedirect(200, {
          'location':
              'https://c.example/cosmos-ui/openid?client_id=__route_App',
        }),
        isFalse,
      );
    });
  });
}

/// Counts closes, which MockClient cannot.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.onClose);

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 200);

  @override
  void close() => onClose();
}
