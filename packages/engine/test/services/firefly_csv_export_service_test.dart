import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

FireflyApiService _serviceWith(MockClient client) => FireflyApiService(
  serverUrl: 'https://firefly.test',
  apiToken: 'test-token',
  client: client,
  readRetryBaseDelayMs: 0,
);

/// Answers every export with a one-row CSV naming the data set it came from.
MockClient _exports({
  List<Uri>? record,
  Map<String, String> bodies = const {},
  Set<String> failing = const {},
}) {
  return MockClient((request) async {
    record?.add(request.url);
    final dataset = request.url.pathSegments.last;
    if (failing.contains(dataset)) {
      return http.Response('{"message":"boom"}', 500);
    }
    final body = bodies[dataset] ?? 'id,name\n1,$dataset\n';
    return http.Response(body, 200);
  });
}

void main() {
  group('exportCsv', () {
    test('reads a data set whole when no window is given', () async {
      final urls = <Uri>[];
      final service = _serviceWith(_exports(record: urls));

      final csv = await service.exportCsv(FireflyCsvDataset.rules);

      expect(csv, 'id,name\n1,rules\n');
      expect(urls.single.path, '/api/v1/data/export/rules');
      expect(urls.single.query, isEmpty);
    });

    test('names both ends of the window when it is given', () async {
      final urls = <Uri>[];
      final service = _serviceWith(_exports(record: urls));

      await service.exportCsv(
        FireflyCsvDataset.transactions,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 3, 4),
      );

      expect(urls.single.queryParameters, {
        'start': '2026-01-01',
        'end': '2026-03-04',
      });
    });

    test('reports the status when Firefly refuses', () async {
      final service = _serviceWith(_exports(failing: {'transactions'}));

      await expectLater(
        service.exportCsv(FireflyCsvDataset.transactions),
        throwsA(
          isA<FireflyApiException>().having(
            (e) => e.message,
            'message',
            contains('500'),
          ),
        ),
      );
    });
  });

  group('exportAll', () {
    test('reads every data set Firefly exports', () async {
      final urls = <Uri>[];
      final service = FireflyCsvExportService(
        _serviceWith(_exports(record: urls)),
      );

      final files = await service.exportAll(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 6, 30),
      );

      expect(files.length, FireflyCsvDataset.values.length);
      expect(files.every((f) => f.ok), isTrue);
      expect(
        files.map((f) => f.dataset.fileName),
        containsAll(<String>['rules.csv', 'piggy-banks.csv', 'budgets.csv']),
      );
      // Only the transaction export carries a window.
      final windowed = urls.where((u) => u.query.isNotEmpty).toList();
      expect(windowed.single.path, '/api/v1/data/export/transactions');
    });

    test('splits the transaction window a year at a time', () async {
      final urls = <Uri>[];
      final service = FireflyCsvExportService(
        _serviceWith(_exports(record: urls)),
      );

      final files = await service.exportAll(
        from: DateTime(2024, 3, 15),
        to: DateTime(2026, 5, 20),
      );

      final windows = urls
          .where((u) => u.path.endsWith('/transactions'))
          .map(
            (u) => '${u.queryParameters['start']}..${u.queryParameters['end']}',
          )
          .toList();
      expect(windows, [
        '2024-03-15..2024-12-31',
        '2025-01-01..2025-12-31',
        '2026-01-01..2026-05-20',
      ]);
      final transactions = files.firstWhere(
        (f) => f.dataset == FireflyCsvDataset.transactions,
      );
      expect(transactions.chunks, 3);
    });

    test('keeps one header when the window was split', () async {
      final service = FireflyCsvExportService(
        _serviceWith(
          _exports(bodies: {'transactions': 'id,description\n1,rent\n'}),
        ),
      );

      final files = await service.exportAll(
        from: DateTime(2025, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      final transactions = files.firstWhere(
        (f) => f.dataset == FireflyCsvDataset.transactions,
      );

      expect('id,description'.allMatches(transactions.contents).length, 1);
      expect(transactions.contents, 'id,description\n1,rent\n1,rent\n');
      expect(transactions.rowCount, 2);
    });

    test('keeps a row whose description carries a newline', () async {
      final service = FireflyCsvExportService(
        _serviceWith(
          _exports(
            bodies: {'transactions': 'id,description\n1,"rent\nand fees"\n'},
          ),
        ),
      );

      final files = await service.exportAll(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      final transactions = files.firstWhere(
        (f) => f.dataset == FireflyCsvDataset.transactions,
      );

      expect(transactions.contents, contains('"rent\nand fees"'));
      expect(transactions.rowCount, 1);
    });

    test('reports a data set that failed and keeps the rest', () async {
      final service = FireflyCsvExportService(
        _serviceWith(_exports(failing: {'rules'})),
      );

      final files = await service.exportAll(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      final rules = files.firstWhere(
        (f) => f.dataset == FireflyCsvDataset.rules,
      );
      expect(rules.ok, isFalse);
      expect(rules.error, contains('500'));
      expect(rules.rowCount, 0);
      expect(
        files.where((f) => f.ok).length,
        FireflyCsvDataset.values.length - 1,
      );
    });

    test('joins chunks that do not end their last row', () async {
      final service = FireflyCsvExportService(
        _serviceWith(
          _exports(bodies: {'transactions': 'id,description\n1,rent'}),
        ),
      );

      final files = await service.exportAll(
        from: DateTime(2025, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      final transactions = files.firstWhere(
        (f) => f.dataset == FireflyCsvDataset.transactions,
      );

      expect(transactions.contents, 'id,description\n1,rent\n1,rent');
      expect(transactions.rowCount, 2);
    });

    test('counts a row whose field carries a doubled quote once', () async {
      final service = FireflyCsvExportService(
        _serviceWith(
          _exports(
            bodies: {'transactions': 'id,description\n1,"say ""hi"" now"\n'},
          ),
        ),
      );

      final files = await service.exportAll(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      expect(
        files
            .firstWhere((f) => f.dataset == FireflyCsvDataset.transactions)
            .rowCount,
        1,
      );
    });

    test('counts no rows for an export that only has a header', () async {
      final service = FireflyCsvExportService(
        _serviceWith(_exports(bodies: {'bills': 'id,name\n'})),
      );

      final files = await service.exportAll(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      expect(
        files.firstWhere((f) => f.dataset == FireflyCsvDataset.bills).rowCount,
        0,
      );
    });
  });
}
