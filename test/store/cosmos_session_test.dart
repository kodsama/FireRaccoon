import 'dart:convert';

import 'package:fireraccoon/store/cosmos_login.dart';
import 'package:fireraccoon/store/cosmos_session.dart';
import 'package:fireraccoon/store/cosmos_session_client.dart';
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

    test('a redirect to the Cosmos login reports the session gone', () async {
      var expired = 0;
      final client = CosmosSessionClient(
        inner: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {
              'location': 'https://cosmos.example/cosmos-ui/openid?x=1',
            },
          ),
        ),
        session: _session,
        onSessionExpired: () => expired++,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(expired, 1);
    });

    test('an ordinary answer is not mistaken for an expiry', () async {
      var expired = 0;
      final client = CosmosSessionClient(
        inner: MockClient((_) async => http.Response('{}', 200)),
        session: _session,
        onSessionExpired: () => expired++,
      );

      await client.get(Uri.parse('https://firefly.example/api/v1/about'));

      expect(expired, isZero);
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
    test('reports itself unavailable and signs nobody in', () async {
      const login = UnsupportedCosmosLogin();

      expect(login.isSupported, isFalse);
      expect(await login.signIn(Uri.parse('https://firefly.example')), isNull);
    });
  });

  group('isCosmosLoginRedirect', () {
    test('only a redirect to a Cosmos login path counts', () {
      expect(
        isCosmosLoginRedirect(302, {
          'location': 'https://c.example/cosmos-ui/openid',
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
      expect(isCosmosLoginRedirect(302, const {}), isFalse);
      expect(
        isCosmosLoginRedirect(200, {
          'location': 'https://c.example/cosmos-ui/openid',
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
