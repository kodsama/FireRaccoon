import 'dart:convert';

import '../providers/undo_history_provider.dart';

/// One field a change moved, as it was and as it became.
class HistoryFieldChange {
  const HistoryFieldChange({
    required this.field,
    required this.before,
    required this.after,
  });

  /// The payload key, as the action that recorded it spelled it.
  final String field;

  /// Null where the field was not there at all, which is how a creation and a
  /// deletion differ from an edit.
  final String? before;
  final String? after;
}

/// What a history entry changed, read off the two sides it stored.
///
/// An entry holds the whole thing before and the whole thing after, because
/// that is what undoing and redoing need. The difference between them is the
/// closest thing to "what changed" the history has, and it is exact: nothing
/// here is reconstructed or guessed.
List<HistoryFieldChange> historyEntryChanges(UndoEntry entry) {
  final before = entry.undoPayload;
  final after = entry.redoPayload;
  final fields = {...before.keys, ...after.keys}.toList()..sort();
  return [
    for (final field in fields)
      if (_text(before[field]) != _text(after[field]))
        HistoryFieldChange(
          field: field,
          before: _text(before[field]),
          after: _text(after[field]),
        ),
  ];
}

/// `sourceName` as "Source name", for a payload key written by code and read
/// by a person.
String historyFieldLabel(String field) {
  final spaced = field
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => ' ${m[1]}')
      .replaceAll('_', ' ')
      .trim();
  if (spaced.isEmpty) return field;
  return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
}

/// A payload value as one line of text, or null where there was no value.
///
/// An empty string counts as no value: an action that clears a field and one
/// that never set it leave the same thing behind, and showing `""` as a
/// change from nothing would be noise.
String? _text(Object? value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  if (value is num || value is bool) return '$value';
  final encoded = jsonEncode(value);
  return encoded == '[]' || encoded == '{}' ? null : encoded;
}
