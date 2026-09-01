import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> _snapshot({
  List<Map<String, Object?>> accounts = const [],
  List<Map<String, Object?>> categories = const [],
  List<Map<String, Object?>> transactions = const [],
  List<Map<String, Object?>> piggyBanks = const [],
  List<Map<String, Object?>> currencies = const [],
}) => {
  'accounts': accounts,
  'categories': categories,
  'tags': const <Map<String, Object?>>[],
  'budgets': const <Map<String, Object?>>[],
  'bills': const <Map<String, Object?>>[],
  'piggy_banks': piggyBanks,
  'recurrences': const <Map<String, Object?>>[],
  'transactions': transactions,
  'currencies': currencies,
};

Map<String, Object?> _transaction({
  required String id,
  String description = 'Groceries',
  double amount = 45,
  String? groupTitle,
}) => {
  'id': id,
  'group_title': groupTitle,
  'total_amount': amount,
  'splits': [
    {
      'journal_id': 'j$id',
      'type': 'withdrawal',
      'date': '2026-01-15T00:00:00.000',
      'amount': amount,
      'description': description,
      'source_id': '5',
      'destination_name': 'Store',
      'tags': const <String>[],
    },
  ],
};

void main() {
  test('an untouched ledger needs nothing done to it', () {
    final snapshot = _snapshot(
      accounts: [
        {'id': '5', 'name': 'Checking', 'current_balance': 100.0},
      ],
      transactions: [_transaction(id: '1')],
    );

    final plan = planRestore(backup: snapshot, current: snapshot);

    expect(plan.isEmpty, isTrue);
    expect(plan.countsByAction['update'], 0);
  });

  test('a row that changed is an update naming the fields', () {
    final plan = planRestore(
      backup: _snapshot(transactions: [_transaction(id: '1', amount: 45)]),
      current: _snapshot(
        transactions: [_transaction(id: '1', amount: 60, groupTitle: 'Shop')],
      ),
    );

    final step = plan.steps.single;
    expect(step.action, RestoreAction.update);
    expect(step.type, 'transactions');
    expect(step.id, '1');
    expect(step.label, 'Groceries');
    expect(step.changedFields, ['group_title', 'splits', 'total_amount']);
  });

  test('a row deleted since the backup comes back', () {
    final plan = planRestore(
      backup: _snapshot(transactions: [_transaction(id: '1')]),
      current: _snapshot(),
    );

    expect(plan.steps.single.action, RestoreAction.create);
    expect(plan.steps.single.row['id'], '1');
  });

  test('a row added since the backup is left alone unless asked', () {
    final backup = _snapshot();
    final current = _snapshot(transactions: [_transaction(id: '9')]);

    expect(planRestore(backup: backup, current: current).isEmpty, isTrue);

    final withDeletes = planRestore(
      backup: backup,
      current: current,
      includeDeletes: true,
    );
    expect(withDeletes.steps.single.action, RestoreAction.delete);
    expect(withDeletes.steps.single.id, '9');
  });

  test('references are put back before the rows that name them', () {
    final plan = planRestore(
      backup: _snapshot(
        accounts: [
          {'id': '5', 'name': 'Checking'},
        ],
        categories: [
          {'id': '7', 'name': 'Food'},
        ],
        transactions: [_transaction(id: '1')],
      ),
      current: _snapshot(),
    );

    expect(plan.steps.map((s) => s.type), [
      'accounts',
      'categories',
      'transactions',
    ]);
  });

  test('deletions run the other way, transactions first', () {
    final plan = planRestore(
      backup: _snapshot(),
      current: _snapshot(
        accounts: [
          {'id': '5', 'name': 'Checking'},
        ],
        transactions: [_transaction(id: '1')],
      ),
      includeDeletes: true,
    );

    expect(plan.steps.map((s) => s.type), ['transactions', 'accounts']);
  });

  test('a balance that moved is not a change a restore can make', () {
    final plan = planRestore(
      backup: _snapshot(
        accounts: [
          {'id': '5', 'name': 'Checking', 'current_balance': 100.0},
        ],
      ),
      current: _snapshot(
        accounts: [
          {'id': '5', 'name': 'Checking', 'current_balance': 55.0},
        ],
      ),
    );

    expect(plan.isEmpty, isTrue);
  });

  test('a piggy bank that only filled up is left alone', () {
    final plan = planRestore(
      backup: _snapshot(
        piggyBanks: [
          {
            'id': '3',
            'name': 'Holiday',
            'current_amount': 10.0,
            'accounts': [
              {'account_id': '5', 'current_amount': 10.0},
            ],
          },
        ],
      ),
      current: _snapshot(
        piggyBanks: [
          {
            'id': '3',
            'name': 'Holiday',
            'current_amount': 90.0,
            'accounts': [
              {'account_id': '5', 'current_amount': 90.0},
            ],
          },
        ],
      ),
    );

    expect(plan.isEmpty, isTrue);
  });

  test('a named type is the only one walked', () {
    final plan = planRestore(
      backup: _snapshot(
        accounts: [
          {'id': '5', 'name': 'Checking'},
        ],
        transactions: [_transaction(id: '1')],
      ),
      current: _snapshot(),
      types: {'transactions'},
    );

    expect(plan.steps.single.type, 'transactions');
  });

  test('what no restore can write back is named rather than skipped', () {
    final plan = planRestore(
      backup: _snapshot(
        currencies: [
          {'id': '1', 'code': 'EUR'},
        ],
      ),
      current: _snapshot(),
    );

    expect(plan.unrestorable, ['currencies']);
    expect(plan.isEmpty, isTrue);
  });

  test('a plan counts itself by action and by type', () {
    final plan = planRestore(
      backup: _snapshot(
        categories: [
          {'id': '7', 'name': 'Food'},
        ],
        transactions: [_transaction(id: '1', amount: 45)],
      ),
      current: _snapshot(
        transactions: [
          _transaction(id: '1', amount: 60),
          _transaction(id: '2'),
        ],
      ),
      includeDeletes: true,
    );

    expect(plan.countsByAction, {'create': 1, 'update': 1, 'delete': 1});
    expect(plan.countsByType, {'categories': 1, 'transactions': 2});
    expect(plan.toJson()['counts_by_action'], plan.countsByAction);
  });

  test('a snapshot with nothing where rows should be reads as empty', () {
    final plan = planRestore(
      backup: {'transactions': 'not a list'},
      current: const {},
    );

    expect(plan.isEmpty, isTrue);
  });

  test('a row falls back to its id when it has no name to show', () {
    final plan = planRestore(
      backup: _snapshot(
        transactions: [
          {'id': '4', 'splits': const <Object?>[]},
        ],
      ),
      current: _snapshot(),
    );

    expect(plan.steps.single.label, '4');
  });
}
