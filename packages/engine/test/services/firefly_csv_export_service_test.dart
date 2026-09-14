import 'dart:convert';

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

/// Answers every export with a one-row CSV naming the data set it came from,
/// and the piggy-bank endpoint with [piggyBanks] when given.
MockClient _exports({
  List<Uri>? record,
  Map<String, String> bodies = const {},
  Set<String> failing = const {},
  Map<String, Object?>? piggyBanks,
}) {
  return MockClient((request) async {
    record?.add(request.url);
    if (piggyBanks != null && request.url.path == '/api/v1/piggy-banks') {
      return http.Response(jsonEncode(piggyBanks), 200);
    }
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

    test('writes the piggy banks from the API when Firefly cannot', () async {
      // Firefly 6.6.6 answers its piggy-bank export with a 500 of its own,
      // unchanged on develop, so the file was missing from every backup and
      // would have stayed missing. The endpoint carries everything the CSV
      // would.
      final service = FireflyCsvExportService(
        _serviceWith(
          _exports(
            failing: {'piggy-banks'},
            piggyBanks: {
              'data': [
                {
                  'id': '4',
                  'attributes': {
                    'name': 'New Laptop',
                    'target_amount': '2500.00',
                    'current_amount': '100.00',
                    'currency_code': 'EUR',
                    'start_date': '2026-01-01T00:00:00+00:00',
                    'target_date': '2026-12-24T00:00:00+00:00',
                    'order': 3,
                    'active': true,
                    'notes': 'Says "soon", maybe',
                    'object_group_title': 'Gear',
                    'accounts': [
                      {
                        'account_id': '5',
                        'name': 'Checking',
                        'current_amount': '100.00',
                      },
                    ],
                  },
                },
              ],
            },
          ),
        ),
      );

      final files = await service.exportAll(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      final piggies = files.firstWhere(
        (f) => f.dataset == FireflyCsvDataset.piggyBanks,
      );
      expect(piggies.ok, isTrue);
      expect(piggies.writtenByFireRaccoon, isTrue);
      expect(piggies.exportError, contains('500'));
      expect(piggies.rowCount, 1);
      expect(
        piggies.contents,
        'piggy_bank_id,name,account_id,account_name,account_current_amount,'
        'currency_code,target_amount,current_amount,start_date,target_date,'
        'order,active,notes,object_group_title\n'
        '4,New Laptop,5,Checking,100.00,EUR,2500.00,100.00,2026-01-01,'
        '2026-12-24,3,true,"Says ""soon"", maybe",Gear\n',
      );
      // Every other file is still Firefly's own.
      expect(files.where((f) => f.writtenByFireRaccoon).length, 1);
    });

    test('a piggy bank on two accounts is a row per account', () async {
      PiggyBank piggy(String id, List<PiggyBankAccountLink> accounts) =>
          PiggyBank(
            id: id,
            name: 'Trip',
            targetAmount: 900,
            currentAmount: 300,
            currencyCode: 'SEK',
            currencySymbol: 'kr',
            startDate: DateTime(2026, 3, 1),
            accounts: accounts,
          );

      final csv = piggyBanksCsv([
        piggy('1', const [
          PiggyBankAccountLink(
            accountId: '5',
            name: 'Checking',
            currentAmount: 200,
          ),
          PiggyBankAccountLink(
            accountId: '7',
            name: 'Savings',
            currentAmount: 100,
          ),
        ]),
        // One with no account keeps its row, columns empty, and no target
        // date is an empty field rather than a made-up one.
        piggy('2', const []),
      ]);

      expect(csv.split('\n').skip(1).where((l) => l.isNotEmpty), [
        '1,Trip,5,Checking,200.00,SEK,900.00,300.00,2026-03-01,,0,true,,',
        '1,Trip,7,Savings,100.00,SEK,900.00,300.00,2026-03-01,,0,true,,',
        '2,Trip,,,,SEK,900.00,300.00,2026-03-01,,0,true,,',
      ]);
    });

    test('reports the piggy banks missing when the API fails too', () async {
      // Without piggy banks to answer with, the endpoint falls through to the
      // same 500 the export gave.
      final service = FireflyCsvExportService(
        _serviceWith(_exports(failing: {'piggy-banks'})),
      );

      final files = await service.exportAll(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      final piggies = files.firstWhere(
        (f) => f.dataset == FireflyCsvDataset.piggyBanks,
      );
      expect(piggies.ok, isFalse);
      expect(piggies.writtenByFireRaccoon, isFalse);
      expect(piggies.error, contains('500'));
      expect(piggies.error, contains('in its place'));
    });
  });
}
