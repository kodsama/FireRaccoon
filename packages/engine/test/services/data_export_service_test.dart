import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../helpers/firefly_fixtures.dart';
import 'firefly_api_service_fetch_test.dart' show jsonHttpResponse;

FireflyApiService _serviceWith(MockClient client) => FireflyApiService(
  serverUrl: 'https://firefly.test',
  apiToken: 'test-token',
  client: client,
  readRetryBaseDelayMs: 0,
);

/// Answers every list endpoint the export reads, so the walk is exercised end
/// to end rather than one call at a time.
MockClient _everything({List<Uri>? record}) {
  return MockClient((request) async {
    record?.add(request.url);
    final path = request.url.path;
    if (path.endsWith('/accounts')) return jsonHttpResponse(accountsBody());
    if (path.endsWith('/transactions')) {
      return jsonHttpResponse(
        transactionsPageBody(items: [transactionItem(id: '1')]),
      );
    }
    if (path.endsWith('/budgets')) return jsonHttpResponse(budgetsBody());
    if (path.endsWith('/categories')) {
      return jsonHttpResponse({
        'data': [
          {
            'id': '7',
            'attributes': {'name': 'Food'},
          },
        ],
      });
    }
    if (path.endsWith('/tags')) {
      return jsonHttpResponse({
        'data': [
          {
            'id': '2',
            'attributes': {'tag': 'shared'},
          },
        ],
      });
    }
    if (path.endsWith('/bills')) return jsonHttpResponse({'data': []});
    if (path.endsWith('/piggy-banks')) return jsonHttpResponse({'data': []});
    if (path.endsWith('/recurrences')) return jsonHttpResponse({'data': []});
    if (path.endsWith('/currencies')) return jsonHttpResponse({'data': []});
    return jsonHttpResponse({
      'message': 'unexpected ${request.url}',
    }, status: 404);
  });
}

void main() {
  group('DataExportService', () {
    test('reads every entity and reports what it holds', () async {
      final calls = <Uri>[];
      final snapshot = await DataExportService(
        _serviceWith(_everything(record: calls)),
      ).export(takenAt: DateTime.utc(2026, 8, 21, 9));

      expect(snapshot.counts['accounts'], greaterThan(0));
      expect(snapshot.counts['transactions'], 1);
      expect(snapshot.counts['categories'], 1);
      expect(snapshot.counts['tags'], 1);

      // Every list endpoint was actually visited.
      for (final segment in [
        '/accounts',
        '/transactions',
        '/budgets',
        '/categories',
        '/tags',
        '/bills',
        '/piggy-banks',
        '/recurrences',
        '/currencies',
      ]) {
        expect(
          calls.any((uri) => uri.path.endsWith(segment)),
          isTrue,
          reason: 'never read $segment',
        );
      }
    });

    test('says what it does not cover', () async {
      // A snapshot that reads like a backup is worse than no snapshot: the
      // database, the attachments and the instance key are out of an API
      // client's reach and restoring needs the volume archive.
      final snapshot = await DataExportService(
        _serviceWith(_everything()),
      ).export(takenAt: DateTime.utc(2026, 8, 21, 9));

      final json = snapshot.toJson();
      expect(json['schema_version'], kDataExportSchemaVersion);
      expect(json['taken_at'], '2026-08-21T09:00:00.000Z');
      expect(json['excludes'], contains('database'));
      expect(json['excludes'], contains('attachments'));
      expect(json['excludes'], contains('app_key'));
    });

    test('records the window the transactions were read over', () async {
      final snapshot = await DataExportService(_serviceWith(_everything()))
          .export(
            from: DateTime(2026, 1, 1),
            to: DateTime(2026, 2, 1),
            takenAt: DateTime.utc(2026, 8, 21),
          );

      final json = snapshot.toJson();
      expect(json['transactions_from'], '2026-01-01');
      expect(json['transactions_to'], '2026-02-01');
    });

    test('writes every leg of a split journal', () async {
      // A snapshot that flattened a group would restore a loan payment as one
      // line and lose the breakdown.
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/transactions')) {
          return jsonHttpResponse(
            transactionsPageBody(
              items: [
                {
                  'id': '77',
                  'type': 'transactions',
                  'attributes': {
                    'group_title': 'Rent and fees',
                    'transactions': [
                      {
                        'transaction_journal_id': '811',
                        'type': 'withdrawal',
                        'date': '2026-02-01',
                        'amount': '1200.00',
                        'description': 'Rent',
                        'currency_code': 'EUR',
                        'currency_symbol': '€',
                      },
                      {
                        'transaction_journal_id': '812',
                        'type': 'withdrawal',
                        'date': '2026-02-01',
                        'amount': '25.00',
                        'description': 'Service fee',
                        'currency_code': 'EUR',
                        'currency_symbol': '€',
                      },
                    ],
                  },
                },
              ],
            ),
          );
        }
        if (path.endsWith('/accounts')) return jsonHttpResponse(accountsBody());
        return jsonHttpResponse({'data': []});
      });

      final snapshot = await DataExportService(_serviceWith(client)).export();
      final json = jsonDecode(jsonEncode(snapshot.toJson()));
      final group = (json['transactions'] as List).single;

      expect(group['group_title'], 'Rent and fees');
      expect(group['total_amount'], 1225.0);
      final splits = group['splits'] as List;
      expect(splits.map((s) => s['description']), ['Rent', 'Service fee']);
      expect(splits.map((s) => s['journal_id']), ['811', '812']);
    });

    test('maps the entities the API answers with', () async {
      // Every entity gets its own shape in the snapshot, so each mapper is
      // exercised against a real payload rather than an empty list.
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/accounts')) return jsonHttpResponse(accountsBody());
        if (path.endsWith('/transactions')) {
          return jsonHttpResponse(transactionsPageBody(items: []));
        }
        if (path.endsWith('/bills')) {
          return jsonHttpResponse({
            'data': [
              {
                'id': '9',
                'attributes': {
                  'name': 'Rent',
                  'amount_min': '1200.00',
                  'amount_max': '1250.00',
                  'currency_code': 'EUR',
                  'currency_symbol': '\u20ac',
                  'date': '2026-03-01',
                  'end_date': '2027-03-01',
                  'repeat_freq': 'monthly',
                  'skip': 0,
                  'active': true,
                  'notes': 'flat',
                  'object_group_title': 'Housing',
                },
              },
            ],
          });
        }
        if (path.endsWith('/piggy-banks')) {
          return jsonHttpResponse({
            'data': [
              {
                'id': '4',
                'attributes': {
                  'name': 'New Laptop',
                  'target_amount': '2500.00',
                  'current_amount': '100.00',
                  'currency_code': 'EUR',
                  'currency_symbol': '\u20ac',
                  'start_date': '2026-01-01',
                  'target_date': '2026-12-01',
                  'active': true,
                  'notes': 'saving',
                  'object_group_title': 'Goals',
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
          });
        }
        if (path.endsWith('/recurrences')) {
          return jsonHttpResponse({
            'data': [
              {
                'id': '12',
                'attributes': {
                  'type': 'withdrawal',
                  'title': 'Rent',
                  'description': 'Monthly rent',
                  'first_date': '2026-09-01',
                  'repeat_until': '2027-09-01',
                  'nr_of_repetitions': 12,
                  'active': true,
                  'apply_rules': true,
                  'notes': 'standing',
                  'repetitions': [
                    {'type': 'monthly', 'moment': '1', 'skip': 0, 'weekend': 1},
                  ],
                  'transactions': [
                    {
                      'description': 'Rent payment',
                      'amount': '1200.00',
                      'currency_code': 'EUR',
                      'source_id': '5',
                      'source_name': 'Checking',
                      'destination_id': '9',
                      'destination_name': 'Landlord',
                      'category_name': 'Housing',
                      'budget_name': 'Fixed',
                      'tags': ['standing'],
                    },
                  ],
                },
              },
            ],
          });
        }
        if (path.endsWith('/currencies')) {
          return jsonHttpResponse({
            'data': [
              {
                'id': '1',
                'attributes': {
                  'code': 'EUR',
                  'name': 'Euro',
                  'symbol': '\u20ac',
                  'enabled': true,
                },
              },
            ],
          });
        }
        return jsonHttpResponse({'data': []});
      });

      final snapshot = await DataExportService(_serviceWith(client)).export();
      final json = jsonDecode(jsonEncode(snapshot.toJson()));

      final bill = (json['bills'] as List).single;
      expect(bill['name'], 'Rent');
      expect(bill['repeat_freq'], 'monthly');
      expect(bill['end_date'], '2027-03-01');
      expect(bill['object_group_title'], 'Housing');

      final piggy = (json['piggy_banks'] as List).single;
      expect(piggy['name'], 'New Laptop');
      expect(piggy['target_amount'], 2500.0);
      expect(piggy['target_date'], '2026-12-01');
      expect((piggy['accounts'] as List).single['account_id'], '5');

      final rule = (json['recurrences'] as List).single;
      expect(rule['title'], 'Rent');
      expect(rule['type'], 'withdrawal');
      expect(rule['first_date'], '2026-09-01');
      expect(rule['nr_of_repetitions'], 12);
      expect((rule['repetitions'] as List).single['moment'], '1');
      final line = (rule['transactions'] as List).single;
      expect(line['amount'], 1200.0);
      expect(line['destination_name'], 'Landlord');
      expect(line['tags'], ['standing']);

      final currency = (json['currencies'] as List).single;
      expect(currency['code'], 'EUR');
      expect(currency['enabled'], isTrue);

      final account = (json['accounts'] as List).first;
      expect(account['name'], isNotNull);
      expect(account.containsKey('account_number'), isTrue);
    });

    test('encodes to JSON without losing anything to a type', () async {
      // The whole point is a file someone can read later, so nothing in the
      // tree may be a Dart object jsonEncode refuses.
      final snapshot = await DataExportService(
        _serviceWith(_everything()),
      ).export();

      expect(() => jsonEncode(snapshot.toJson()), returnsNormally);
    });
  });
}
