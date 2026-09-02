import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'firefly_api_service_fetch_test.dart' show jsonHttpResponse;

/// One row as Firefly answers a write, with whatever id it decided on.
Map<String, Object?> _created(String id, String type, [String name = 'x']) => {
  'data': {
    'id': id,
    'type': type,
    'attributes': {
      'name': name,
      'type': 'asset',
      'account_role': 'defaultAsset',
      'current_balance': '0',
      'currency_code': 'EUR',
      'transactions': [
        {
          'type': 'withdrawal',
          'date': '2026-01-15',
          'amount': '45.00',
          'description': 'Groceries',
          'currency_code': 'EUR',
        },
      ],
    },
  },
};

({
  FireflyApiService api,
  List<({String method, String path, String body})> calls,
})
_recordingService({Map<String, String> ids = const {}}) {
  final calls = <({String method, String path, String body})>[];
  final client = MockClient((request) async {
    calls.add((
      method: request.method,
      path: request.url.path,
      body: request.body,
    ));
    if (request.method == 'DELETE') return jsonHttpResponse({}, status: 204);
    final segment = request.url.pathSegments.last;
    return jsonHttpResponse(
      _created(ids[segment] ?? 'new-$segment', segment),
      status: request.method == 'POST' ? 201 : 200,
    );
  });
  return (
    api: FireflyApiService(
      serverUrl: 'https://firefly.test',
      apiToken: 'test-token',
      client: client,
      readRetryBaseDelayMs: 0,
    ),
    calls: calls,
  );
}

RestoreStep _step({
  required String type,
  required RestoreAction action,
  String id = '1',
  Map<String, Object?> row = const {},
}) =>
    RestoreStep(type: type, action: action, id: id, label: 'row $id', row: row);

Map<String, Object?> _transactionRow({
  String id = '1',
  String? sourceId = '5',
  List<Map<String, Object?>>? splits,
}) => {
  'id': id,
  'group_title': null,
  'splits':
      splits ??
      [
        {
          'type': 'withdrawal',
          'date': '2026-01-15T00:00:00.000',
          'amount': 45.0,
          'description': 'Groceries',
          'source_id': sourceId,
          'source_name': 'Checking',
          'destination_name': 'Store',
          'currency_code': 'EUR',
          'tags': const <String>[],
        },
      ],
};

void main() {
  test('a deleted category comes back and reports its new id', () async {
    final service = _recordingService(ids: {'categories': '77'});
    final runner = RestoreRunner(service.api);

    final outcomes = await runner.apply(
      RestorePlan(
        steps: [
          _step(
            type: 'categories',
            action: RestoreAction.create,
            id: '7',
            row: const {'id': '7', 'name': 'Food'},
          ),
        ],
        unrestorable: const [],
      ),
    );

    expect(outcomes.single.applied, isTrue);
    expect(outcomes.single.newId, '77');
    expect(runner.remappedIds, {'7': '77'});
    expect(service.calls.single.method, 'POST');
    expect(jsonDecode(service.calls.single.body)['name'], 'Food');
  });

  test(
    'a transaction naming a recreated account points at the new one',
    () async {
      final service = _recordingService(ids: {'accounts': '55'});
      final runner = RestoreRunner(service.api);

      await runner.apply(
        RestorePlan(
          steps: [
            _step(
              type: 'accounts',
              action: RestoreAction.create,
              id: '5',
              row: const {
                'id': '5',
                'name': 'Checking',
                'type': 'asset',
                'currency_code': 'EUR',
              },
            ),
            _step(
              type: 'transactions',
              action: RestoreAction.create,
              row: _transactionRow(sourceId: '5'),
            ),
          ],
          unrestorable: const [],
        ),
      );

      final write = service.calls.last;
      expect(write.path, '/api/v1/transactions');
      final leg =
          (jsonDecode(write.body)['transactions'] as List).single
              as Map<String, Object?>;
      expect(leg['source_id'], '55');
    },
  );

  test('a split group goes back with every leg', () async {
    final service = _recordingService();
    final runner = RestoreRunner(service.api);

    await runner.apply(
      RestorePlan(
        steps: [
          _step(
            type: 'transactions',
            action: RestoreAction.create,
            row: _transactionRow(
              splits: [
                {
                  'type': 'withdrawal',
                  'date': '2026-01-15T00:00:00.000',
                  'amount': 20.0,
                  'description': 'Food',
                  'source_id': '5',
                  'destination_name': 'Store',
                  'currency_code': 'EUR',
                  'tags': const <String>[],
                },
                {
                  'type': 'withdrawal',
                  'date': '2026-01-15T00:00:00.000',
                  'amount': 25.0,
                  'description': 'Wine',
                  'source_id': '5',
                  'destination_name': 'Store',
                  'currency_code': 'EUR',
                  'tags': const <String>[],
                },
              ],
            ),
          ),
        ],
        unrestorable: const [],
      ),
    );

    final legs = jsonDecode(service.calls.single.body)['transactions'] as List;
    expect(legs, hasLength(2));
    expect((legs.last as Map)['description'], 'Wine');
  });

  test('an update writes the backup values over the live row', () async {
    final service = _recordingService();
    final runner = RestoreRunner(service.api);

    await runner.apply(
      RestorePlan(
        steps: [
          _step(
            type: 'budgets',
            action: RestoreAction.update,
            id: '3',
            row: const {
              'id': '3',
              'name': 'Food',
              'active': true,
              'currency_code': 'EUR',
              'auto_budget_type': 'reset',
              'auto_budget_amount': 400.0,
              'auto_budget_period': 'monthly',
            },
          ),
        ],
        unrestorable: const [],
      ),
    );

    expect(service.calls.single.method, 'PUT');
    expect(service.calls.single.path, '/api/v1/budgets/3');
    expect(jsonDecode(service.calls.single.body)['name'], 'Food');
  });

  test('a row added since the backup is deleted', () async {
    final service = _recordingService();
    final runner = RestoreRunner(service.api);

    final outcomes = await runner.apply(
      RestorePlan(
        steps: [
          _step(type: 'transactions', action: RestoreAction.delete, id: '9'),
        ],
        unrestorable: const [],
      ),
    );

    expect(outcomes.single.applied, isTrue);
    expect(service.calls.single.method, 'DELETE');
    expect(service.calls.single.path, '/api/v1/transactions/9');
  });

  test('one step failing does not stop the rest', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add(request.url.path);
      if (request.url.path.contains('tags')) {
        return jsonHttpResponse({'message': 'no'}, status: 500);
      }
      return jsonHttpResponse(_created('9', 'categories'), status: 201);
    });
    final runner = RestoreRunner(
      FireflyApiService(
        serverUrl: 'https://firefly.test',
        apiToken: 'test-token',
        client: client,
        readRetryBaseDelayMs: 0,
      ),
    );

    final outcomes = await runner.apply(
      RestorePlan(
        steps: [
          _step(
            type: 'tags',
            action: RestoreAction.create,
            id: 't1',
            row: const {'id': 't1', 'name': 'shared'},
          ),
          _step(
            type: 'categories',
            action: RestoreAction.create,
            id: 'c1',
            row: const {'id': 'c1', 'name': 'Food'},
          ),
        ],
        unrestorable: const [],
      ),
    );

    expect(outcomes.first.applied, isFalse);
    expect(outcomes.first.error, contains('500'));
    expect(outcomes.last.applied, isTrue);
    expect(outcomes.first.toJson()['error'], isNotNull);
  });

  test(
    'a type nothing can write back is refused rather than guessed at',
    () async {
      final service = _recordingService();
      final runner = RestoreRunner(service.api);

      final outcomes = await runner.apply(
        RestorePlan(
          steps: [
            _step(type: 'currencies', action: RestoreAction.create, id: '1'),
            _step(type: 'currencies', action: RestoreAction.update, id: '1'),
            _step(type: 'currencies', action: RestoreAction.delete, id: '1'),
          ],
          unrestorable: const ['currencies'],
        ),
      );

      expect(outcomes.every((o) => !o.applied), isTrue);
      expect(outcomes.first.error, contains('cannot create'));
      expect(service.calls, isEmpty);
    },
  );

  test(
    'a transaction with no legs is refused rather than written empty',
    () async {
      final service = _recordingService();
      final runner = RestoreRunner(service.api);

      final outcomes = await runner.apply(
        RestorePlan(
          steps: [
            _step(
              type: 'transactions',
              action: RestoreAction.create,
              row: const {'id': '1', 'splits': <Object?>[]},
            ),
          ],
          unrestorable: const [],
        ),
      );

      expect(outcomes.single.applied, isFalse);
      expect(outcomes.single.error, contains('no legs'));
      expect(service.calls, isEmpty);
    },
  );

  group('every type a plan can name', () {
    /// A row shaped enough for each type's input builder to read.
    const rows = <String, Map<String, Object?>>{
      'accounts': {
        'id': '5',
        'name': 'Checking',
        'type': 'asset',
        'currency_code': 'EUR',
        'role': 'defaultAsset',
        'active': true,
      },
      'categories': {'id': '7', 'name': 'Food'},
      'tags': {'id': 't1', 'name': 'shared'},
      'budgets': {
        'id': '3',
        'name': 'Food',
        'currency_code': 'EUR',
        'auto_budget_type': 'reset',
        'auto_budget_amount': 400.0,
        'auto_budget_period': 'monthly',
      },
      'bills': {
        'id': '4',
        'name': 'Rent',
        'amount_min': 900.0,
        'amount_max': 950.0,
        'currency_code': 'EUR',
        'date': '2026-01-01',
        'repeat_freq': 'monthly',
        'skip': 0,
        'active': true,
      },
      'piggy_banks': {
        'id': '6',
        'name': 'Holiday',
        'target_amount': 1000.0,
        'currency_code': 'EUR',
        'start_date': '2026-01-01',
        'accounts': [
          {'account_id': '5'},
        ],
      },
      'recurrences': {
        'id': '8',
        'title': 'Salary',
        'type': 'deposit',
        'first_date': '2026-01-01',
        'active': true,
        'apply_rules': true,
        'repetitions': [
          {'type': 'monthly', 'moment': '1', 'skip': 0, 'weekend': 1},
        ],
        'transactions': [
          {
            'description': 'Salary',
            'amount': 2000.0,
            'currency_code': 'EUR',
            'source_id': '9',
            'destination_id': '5',
            'category_id': '7',
            'budget_id': '3',
            'bill_id': '4',
            'tags': <String>['income'],
          },
        ],
      },
    };

    const paths = <String, String>{
      'accounts': '/api/v1/accounts',
      'categories': '/api/v1/categories',
      'tags': '/api/v1/tags',
      'budgets': '/api/v1/budgets',
      'bills': '/api/v1/bills',
      'piggy_banks': '/api/v1/piggy-banks',
      'recurrences': '/api/v1/recurrences',
    };

    for (final entry in rows.entries) {
      test('${entry.key} can be created, updated and deleted', () async {
        for (final action in RestoreAction.values) {
          final service = _recordingService();
          final outcomes = await RestoreRunner(service.api).apply(
            RestorePlan(
              steps: [
                _step(
                  type: entry.key,
                  action: action,
                  id: '${entry.value['id']}',
                  row: entry.value,
                ),
              ],
              unrestorable: const [],
            ),
          );

          expect(
            outcomes.single.applied,
            isTrue,
            reason: '${entry.key} ${action.name}: ${outcomes.single.error}',
          );
          expect(
            service.calls.first.path,
            startsWith(paths[entry.key]!),
            reason: '${entry.key} ${action.name}',
          );
          expect(service.calls.first.method, switch (action) {
            RestoreAction.create => 'POST',
            RestoreAction.update => 'PUT',
            RestoreAction.delete => 'DELETE',
          }, reason: '${entry.key} ${action.name}');
        }
      });
    }

    test('a liability goes back as one, not as a bare account', () async {
      final service = _recordingService();

      await RestoreRunner(service.api).apply(
        RestorePlan(
          steps: [
            _step(
              type: 'accounts',
              action: RestoreAction.create,
              id: '11',
              row: const {
                'id': '11',
                'name': 'Mortgage',
                'type': 'liabilities',
                'currency_code': 'EUR',
                'liability_type': 'mortgage',
                'liability_direction': 'debit',
                'opening_balance': -150000.0,
                'opening_balance_date': '2020-06-01',
                'interest': 1.5,
                'interest_period': 'yearly',
              },
            ),
          ],
          unrestorable: const [],
        ),
      );

      // One call, not the create-then-fill a plain account needs.
      expect(service.calls, hasLength(1));
      final body =
          jsonDecode(service.calls.single.body) as Map<String, Object?>;
      expect(body['liability_type'], 'mortgage');
      expect(body['liability_direction'], 'debit');
    });

    test('a row missing everything optional still goes back', () async {
      final service = _recordingService();

      final outcomes = await RestoreRunner(service.api).apply(
        RestorePlan(
          steps: [
            for (final type in [
              'budgets',
              'bills',
              'piggy_banks',
              'recurrences',
            ])
              _step(
                type: type,
                action: RestoreAction.create,
                id: 'x',
                row: const {'id': 'x'},
              ),
          ],
          unrestorable: const [],
        ),
      );

      expect(outcomes.every((o) => o.applied), isTrue);
    });
  });

  test(
    'a transaction that changed is written back over the live one',
    () async {
      final service = _recordingService();

      final outcomes = await RestoreRunner(service.api).apply(
        RestorePlan(
          steps: [
            _step(
              type: 'transactions',
              action: RestoreAction.update,
              id: '1',
              row: _transactionRow(),
            ),
          ],
          unrestorable: const [],
        ),
      );

      expect(outcomes.single.applied, isTrue);
      expect(service.calls.single.method, 'PUT');
      expect(service.calls.single.path, '/api/v1/transactions/1');
    },
  );

  test(
    'a liability naming nothing Firefly knows falls back to a debt',
    () async {
      final service = _recordingService();

      await RestoreRunner(service.api).apply(
        RestorePlan(
          steps: [
            _step(
              type: 'accounts',
              action: RestoreAction.create,
              id: '11',
              row: const {
                'id': '11',
                'name': 'Something owed',
                'type': 'liabilities',
                'currency_code': 'EUR',
                'liability_type': 'not-a-type',
                'liability_direction': 'sideways',
              },
            ),
          ],
          unrestorable: const [],
        ),
      );

      final body =
          jsonDecode(service.calls.single.body) as Map<String, Object?>;
      expect(body['liability_type'], 'debt');
      expect(body['liability_direction'], 'credit');
    },
  );

  test('counts its steps as it goes', () async {
    final service = _recordingService();
    final steps = <String>[];

    await RestoreRunner(service.api).apply(
      RestorePlan(
        steps: [
          _step(
            type: 'categories',
            action: RestoreAction.create,
            id: '7',
            row: const {'id': '7', 'name': 'Food'},
          ),
          _step(type: 'tags', action: RestoreAction.delete, id: 't1'),
        ],
        unrestorable: const [],
      ),
      onStep: (done, total) => steps.add('$done/$total'),
    );

    expect(steps, ['1/2', '2/2']);
  });
}
