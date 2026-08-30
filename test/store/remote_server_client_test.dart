import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fireraccoon/store/remote_server_client.dart';

/// One captured outbound request, so a test can assert on method, path and
/// headers without repeating the MockClient plumbing.
class _Sent {
  _Sent(this.method, this.url, this.headers, this.body);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;
}

void main() {
  late List<_Sent> sent;

  RemoteServerClient clientFor(
    http.Response Function(_Sent request) respond, {
    String baseUrl = 'http://example.test',
    String? sessionToken,
  }) {
    return RemoteServerClient(
      baseUrl: baseUrl,
      sessionToken: sessionToken,
      httpClient: MockClient((request) async {
        final record = _Sent(
          request.method,
          request.url,
          request.headers,
          request.body,
        );
        sent.add(record);
        return respond(record);
      }),
    );
  }

  http.Response okJson(Object body, {int status = 200}) =>
      http.Response(jsonEncode(body), status);

  Map<String, dynamic> publicKey({String id = 'key-1', bool active = true}) => {
    'id': id,
    'personId': 'p-1',
    'label': 'Claude',
    'displayPrefix': 'fra_abcd',
    'createdAt': '2026-01-02T03:04:05.000Z',
    'lastUsedAt': null,
    'revokedAt': active ? null : '2026-01-03T00:00:00.000Z',
    'active': active,
  };

  setUp(() => sent = []);

  group('fetchAgentKeys', () {
    test(
      'gets /api/agent-keys with the session header and json accept',
      () async {
        final client = clientFor(
          (_) => okJson({
            'ok': true,
            'keys': [publicKey(), publicKey(id: 'key-2', active: false)],
          }),
          sessionToken: 'sess-1',
        );

        final keys = await client.fetchAgentKeys();

        expect(sent.single.method, 'GET');
        expect(sent.single.url.path, '/api/agent-keys');
        expect(sent.single.headers['x-fireraccoon-session'], 'sess-1');
        expect(sent.single.headers['accept'], 'application/json');
        // A GET carries no body, so declaring a JSON content-type would be a lie
        // some reverse proxies reject.
        expect(sent.single.headers['content-type'], isNull);
        expect(keys.map((key) => key['id']), ['key-1', 'key-2']);
        expect(keys.first, isA<Map<String, dynamic>>());
      },
    );

    test('omits the session header when no token is set', () async {
      final client = clientFor((_) => okJson({'ok': true, 'keys': const []}));

      await client.fetchAgentKeys();

      expect(sent.single.headers.containsKey('x-fireraccoon-session'), isFalse);
    });

    test('omits the session header when the token is empty', () async {
      final client = clientFor(
        (_) => okJson({'ok': true, 'keys': const []}),
        sessionToken: '',
      );

      await client.fetchAgentKeys();

      expect(sent.single.headers.containsKey('x-fireraccoon-session'), isFalse);
    });

    test('returns empty when the response omits keys', () async {
      final client = clientFor((_) => okJson({'ok': true}));

      expect(await client.fetchAgentKeys(), isEmpty);
    });

    test('returns empty when keys is null', () async {
      final client = clientFor((_) => okJson({'ok': true, 'keys': null}));

      expect(await client.fetchAgentKeys(), isEmpty);
    });

    test('skips entries that are not objects', () async {
      final client = clientFor(
        (_) => okJson({
          'ok': true,
          'keys': ['bogus', 7, null, publicKey()],
        }),
      );

      final keys = await client.fetchAgentKeys();

      expect(keys, hasLength(1));
      expect(keys.single['id'], 'key-1');
    });

    test('raises the server error on 401 rather than an empty list', () async {
      final client = clientFor(
        (_) => okJson({'ok': false, 'error': 'Unauthorized'}, status: 401),
      );

      await expectLater(
        client.fetchAgentKeys(),
        throwsA(
          isA<RemoteServerException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Unauthorized')
              .having((e) => e.storeLocked, 'storeLocked', isFalse),
        ),
      );
    });
  });

  group('issueAgentKey', () {
    test('posts the label as json and returns the one-shot secret', () async {
      final client = clientFor(
        (_) => okJson({
          'ok': true,
          'key': publicKey(),
          'secret': 'fra_abcd1234',
        }, status: 201),
        sessionToken: 'sess-1',
      );

      final body = await client.issueAgentKey(label: 'Claude');

      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/api/agent-keys');
      expect(sent.single.headers['content-type'], contains('application/json'));
      expect(sent.single.headers['x-fireraccoon-session'], 'sess-1');
      expect(jsonDecode(sent.single.body), {'label': 'Claude'});
      expect(body['secret'], 'fra_abcd1234');
    });

    test('surfaces the 403 an agent key gets when minting keys', () async {
      final client = clientFor(
        (_) => okJson({
          'ok': false,
          'error': 'Agent keys cannot issue agent keys',
        }, status: 403),
      );

      await expectLater(
        client.issueAgentKey(label: 'Claude'),
        throwsA(
          isA<RemoteServerException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.message,
                'message',
                'Agent keys cannot issue agent keys',
              ),
        ),
      );
    });
  });

  group('fetchAgentKeySecret', () {
    test('gets the per-key secret path and unwraps secret', () async {
      final client = clientFor(
        (_) => okJson({'ok': true, 'secret': 'fra_abcd1234'}),
        sessionToken: 'sess-1',
      );

      expect(await client.fetchAgentKeySecret('key-1'), 'fra_abcd1234');
      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/api/agent-keys/key-1/secret');
      expect(sent.single.headers['x-fireraccoon-session'], 'sess-1');
    });

    test('returns empty string when the server sends no secret', () async {
      final client = clientFor((_) => okJson({'ok': true}));

      expect(await client.fetchAgentKeySecret('key-1'), isEmpty);
    });

    test('throws with 404 for a key that is not the callers', () async {
      final client = clientFor(
        (_) => okJson({'ok': false, 'error': 'Not found'}, status: 404),
      );

      await expectLater(
        client.fetchAgentKeySecret('key-9'),
        throwsA(
          isA<RemoteServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Not found')
              .having((e) => e.body['ok'], 'body.ok', isFalse),
        ),
      );
    });
  });

  group('revokeAgentKey and forgetAgentKey', () {
    test('revoke deletes the key itself, not its record', () async {
      final client = clientFor(
        (_) => okJson({'ok': true, 'keys': const []}),
        sessionToken: 'sess-1',
      );

      await client.revokeAgentKey('key-1');

      expect(sent.single.method, 'DELETE');
      expect(sent.single.url.path, '/api/agent-keys/key-1');
      expect(sent.single.headers['x-fireraccoon-session'], 'sess-1');
      expect(sent.single.headers['content-type'], isNull);
    });

    test('forget deletes the record path', () async {
      final client = clientFor((_) => okJson({'ok': true, 'keys': const []}));

      await client.forgetAgentKey('key-1');

      expect(sent.single.method, 'DELETE');
      expect(sent.single.url.path, '/api/agent-keys/key-1/record');
    });

    test('revoke throws on 404 instead of reporting success', () async {
      final client = clientFor(
        (_) => okJson({'ok': false, 'error': 'Not found'}, status: 404),
      );

      await expectLater(
        client.revokeAgentKey('gone'),
        throwsA(
          isA<RemoteServerException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('forget throws on 404 instead of reporting success', () async {
      final client = clientFor(
        (_) => okJson({'ok': false, 'error': 'Not found'}, status: 404),
      );

      await expectLater(
        client.forgetAgentKey('gone'),
        throwsA(
          isA<RemoteServerException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('a locked store is distinguishable from a plain failure', () async {
      final client = clientFor(
        (_) => okJson({
          'ok': false,
          'error': 'Encrypted store is locked',
          'code': 'store_locked',
          'storeExists': true,
        }, status: 503),
      );

      await expectLater(
        client.revokeAgentKey('key-1'),
        throwsA(
          isA<RemoteServerException>()
              .having((e) => e.storeLocked, 'storeLocked', isTrue)
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.body['storeExists'], 'body.storeExists', isTrue),
        ),
      );
    });
  });

  group('base url handling', () {
    test('a trailing slash does not become a double slash', () async {
      final client = clientFor(
        (_) => okJson({'ok': true, 'keys': const []}),
        baseUrl: 'http://example.test/',
      );

      await client.fetchAgentKeys();

      expect(sent.single.url.toString(), 'http://example.test/api/agent-keys');
    });

    test('a sub-path base keeps its prefix', () async {
      final client = clientFor(
        (_) => okJson({'ok': true, 'secret': 's'}),
        baseUrl: 'http://example.test/fireraccoon/',
      );

      await client.fetchAgentKeySecret('key-1');

      expect(
        sent.single.url.toString(),
        'http://example.test/fireraccoon/api/agent-keys/key-1/secret',
      );
      expect(
        client.fireflyProxyBase,
        'http://example.test/fireraccoon/api/firefly',
      );
    });

    test('the default http client needs no injection to build urls', () {
      // Constructing without an httpClient must not require a request to be
      // made, so callers can read fireflyProxyBase before any traffic.
      final client = RemoteServerClient(baseUrl: 'http://example.test/');

      expect(client.fireflyProxyBase, 'http://example.test/api/firefly');
      expect(sent, isEmpty);
    });
  });
}
