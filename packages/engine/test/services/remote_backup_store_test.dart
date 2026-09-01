import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'firefly_api_service_fetch_test.dart' show jsonHttpResponse;

RemoteBackupStore _storeWith(MockClient client) => RemoteBackupStore(
  baseUrl: 'https://fireraccoon.test/',
  headers: const {'authorization': 'Bearer frcn_key'},
  client: client,
);

void main() {
  test('stores a file under the backup it belongs to', () async {
    late final String path;
    late final Map<String, String> sent;
    final store = _storeWith(
      MockClient((request) async {
        path = request.url.path;
        sent = request.headers;
        expect(request.method, 'PUT');
        expect(request.bodyBytes, [1, 2, 3]);
        return jsonHttpResponse({'ok': true}, status: 201);
      }),
    );

    await store.put('20260901T222736+0200', 'csv/rules.csv', [1, 2, 3]);

    expect(path, '/api/backups/20260901T222736%2B0200/files/csv/rules.csv');
    expect(sent['authorization'], 'Bearer frcn_key');
  });

  test('reads a file back', () async {
    final store = _storeWith(
      MockClient((request) async => jsonHttpResponse('id,name\n1,rules\n')),
    );

    final bytes = await store.get('b1', 'csv/rules.csv');

    expect(utf8.decode(bytes!), 'id,name\n1,rules\n');
  });

  test('a missing file is nothing rather than a failure', () async {
    final store = _storeWith(
      MockClient((request) async => jsonHttpResponse({}, status: 404)),
    );

    expect(await store.get('b1', 'snapshot.json'), isNull);
  });

  test('lists the ids the server holds', () async {
    final store = _storeWith(
      MockClient(
        (request) async => jsonHttpResponse({
          'backups': ['b2', 'b1'],
        }),
      ),
    );

    expect(await store.listBackupIds(), ['b2', 'b1']);
  });

  test('answers an unexpected listing shape with nothing', () async {
    final store = _storeWith(
      MockClient((request) async => jsonHttpResponse('[]')),
    );

    expect(await store.listBackupIds(), isEmpty);
  });

  test('deletes a backup whole', () async {
    late final String method;
    final store = _storeWith(
      MockClient((request) async {
        method = request.method;
        return jsonHttpResponse({}, status: 204);
      }),
    );

    await store.deleteBackup('b1');

    expect(method, 'DELETE');
  });

  test('reports what the server refused', () async {
    final store = _storeWith(
      MockClient((request) async => jsonHttpResponse({}, status: 403)),
    );

    await expectLater(
      store.put('b1', 'snapshot.json', const [1]),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('403')),
      ),
    );
    await expectLater(
      store.get('b1', 'snapshot.json'),
      throwsA(isA<StateError>()),
    );
    await expectLater(store.listBackupIds(), throwsA(isA<StateError>()));
    await expectLater(store.deleteBackup('b1'), throwsA(isA<StateError>()));
  });
}
