/// What a restore would do to one row.
enum RestoreAction {
  /// In the backup, gone from the ledger: put it back, under a new id.
  create,

  /// In both, with different fields: write the backup's values over the live
  /// ones.
  update,

  /// In the ledger, absent from the backup: added since, so undo it.
  delete,
}

/// Entity types a restore walks, references first.
///
/// A recreated category has to exist before the transaction naming it, and a
/// deletion runs the list backwards for the same reason.
const List<String> kRestoreTypes = [
  'accounts',
  'categories',
  'tags',
  'budgets',
  'bills',
  'piggy_banks',
  'recurrences',
  'transactions',
];

/// Fields a restore never compares, because nothing can write them.
///
/// A balance moves when a transaction does. Comparing one would report every
/// account as changed after a single transaction was added, and then a restore
/// would claim to fix something it has no way to set.
const Map<String, List<String>> kDerivedFields = {
  'accounts': ['current_balance'],
  'piggy_banks': ['current_amount', 'accounts'],
};

/// What a backup holds that no API call can put back.
///
/// Named rather than silently skipped: a restore that quietly leaves rules
/// behind is one someone finds out about later.
const List<String> kUnrestorableTypes = ['currencies'];

/// One row a restore would touch.
class RestoreStep {
  const RestoreStep({
    required this.type,
    required this.action,
    required this.id,
    required this.label,
    this.changedFields = const [],
    this.row = const {},
  });

  final String type;
  final RestoreAction action;

  /// The row's id in the backup for a create or an update, in the ledger for a
  /// delete.
  final String id;

  /// Name or description, so a plan reads as rows rather than ids.
  final String label;

  /// Which fields differ, for an update.
  final List<String> changedFields;

  /// The backup's version of the row, empty for a delete.
  final Map<String, Object?> row;

  Map<String, Object?> toJson() => {
    'type': type,
    'action': action.name,
    'id': id,
    'label': label,
    if (changedFields.isNotEmpty) 'changed_fields': changedFields,
  };
}

/// Everything a restore would do, before any of it is done.
class RestorePlan {
  const RestorePlan({required this.steps, required this.unrestorable});

  final List<RestoreStep> steps;

  /// Types the backup carries that a restore cannot write back.
  final List<String> unrestorable;

  bool get isEmpty => steps.isEmpty;

  Map<String, int> get countsByAction => {
    for (final action in RestoreAction.values)
      action.name: steps.where((s) => s.action == action).length,
  };

  Map<String, int> get countsByType {
    final counts = <String, int>{};
    for (final step in steps) {
      counts[step.type] = (counts[step.type] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, Object?> toJson() => {
    'steps': [for (final step in steps) step.toJson()],
    'counts_by_action': countsByAction,
    'counts_by_type': countsByType,
    'unrestorable': unrestorable,
  };
}

/// Works out what it would take to make [current] look like [backup].
///
/// Both are snapshots in the shape [FireflyDataExport] writes, so this compares
/// two readings of the same ledger rather than a reading against live objects:
/// the diff is arithmetic on maps, and nothing here can touch Firefly.
///
/// [types] narrows the walk. [includeDeletes] decides whether rows created since
/// the backup are removed; it is off by default because deleting someone's newer
/// work is the one step of a restore that cannot be undone by running it again.
RestorePlan planRestore({
  required Map<String, Object?> backup,
  required Map<String, Object?> current,
  Set<String>? types,
  bool includeDeletes = false,
}) {
  final wanted = types == null
      ? kRestoreTypes
      : [
          for (final type in kRestoreTypes)
            if (types.contains(type)) type,
        ];
  final steps = <RestoreStep>[];

  for (final type in wanted) {
    final backupRows = _rowsById(backup[type]);
    final currentRows = _rowsById(current[type]);
    final ignored = kDerivedFields[type] ?? const <String>[];

    for (final entry in backupRows.entries) {
      final live = currentRows[entry.key];
      if (live == null) {
        steps.add(
          RestoreStep(
            type: type,
            action: RestoreAction.create,
            id: entry.key,
            label: _labelOf(entry.value),
            row: entry.value,
          ),
        );
        continue;
      }
      final changed = _changedFields(entry.value, live, ignored);
      if (changed.isEmpty) continue;
      steps.add(
        RestoreStep(
          type: type,
          action: RestoreAction.update,
          id: entry.key,
          label: _labelOf(entry.value),
          changedFields: changed,
          row: entry.value,
        ),
      );
    }
  }

  if (includeDeletes) {
    // Backwards, so a transaction goes before the account it names.
    for (final type in wanted.reversed) {
      final backupRows = _rowsById(backup[type]);
      final currentRows = _rowsById(current[type]);
      for (final entry in currentRows.entries) {
        if (backupRows.containsKey(entry.key)) continue;
        steps.add(
          RestoreStep(
            type: type,
            action: RestoreAction.delete,
            id: entry.key,
            label: _labelOf(entry.value),
          ),
        );
      }
    }
  }

  return RestorePlan(
    steps: steps,
    unrestorable: [
      for (final type in kUnrestorableTypes)
        if (backup[type] is List && (backup[type]! as List).isNotEmpty) type,
    ],
  );
}

Map<String, Map<String, Object?>> _rowsById(Object? rows) {
  if (rows is! List) return const {};
  return {
    for (final row in rows)
      if (row is Map && row['id'] != null)
        '${row['id']}': row.cast<String, Object?>(),
  };
}

String _labelOf(Map<String, Object?> row) {
  for (final key in ['name', 'title', 'group_title', 'tag']) {
    final value = row[key];
    if (value is String && value.isNotEmpty) return value;
  }
  // A transaction group carries its description on the legs rather than above
  // them, and an untitled group is the common case.
  final splits = row['splits'];
  if (splits is List && splits.isNotEmpty) {
    final first = splits.first;
    if (first is Map && first['description'] is String) {
      return first['description'] as String;
    }
  }
  return '${row['id']}';
}

List<String> _changedFields(
  Map<String, Object?> backup,
  Map<String, Object?> live,
  List<String> ignored,
) {
  final fields = <String>[];
  for (final key in {...backup.keys, ...live.keys}) {
    if (key == 'id' || ignored.contains(key)) continue;
    if (!_sameValue(backup[key], live[key])) fields.add(key);
  }
  fields.sort();
  return fields;
}

/// Compares two snapshot values structurally.
///
/// Lists compare in order, since a split group's legs and a recurrence's
/// repetitions are ordered, and maps compare key by key.
bool _sameValue(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_sameValue(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}
