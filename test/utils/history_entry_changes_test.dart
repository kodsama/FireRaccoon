import 'package:fireraccoon/providers/undo_history_provider.dart';
import 'package:fireraccoon/utils/history_entry_changes.dart';
import 'package:flutter_test/flutter_test.dart';

UndoEntry _entry({
  required Map<String, Object?> before,
  required Map<String, Object?> after,
}) => UndoEntry(
  id: '1',
  timestampUtc: DateTime.utc(2026, 9, 11, 18),
  title: 'Transaction updated',
  details: 'Updated transaction "Rent"',
  type: UndoActionType.transactionUpdate,
  undoPayload: before,
  redoPayload: after,
);

void main() {
  group('what a history entry changed', () {
    test('reports the fields that moved and leaves the rest out', () {
      final changes = historyEntryChanges(
        _entry(
          before: {
            'transactionId': '97071',
            'description': 'Rent',
            'amount': 1200,
          },
          after: {
            'transactionId': '97071',
            'description': 'Rent, February',
            'amount': 1250,
          },
        ),
      );

      expect(changes.map((c) => c.field), ['amount', 'description']);
      expect(changes.first.before, '1200');
      expect(changes.first.after, '1250');
    });

    test('a field only one side has is a change too', () {
      final changes = historyEntryChanges(
        _entry(
          before: {'categoryName': 'Food'},
          after: {'budgetName': 'Housing'},
        ),
      );

      expect(changes.map((c) => c.field), ['budgetName', 'categoryName']);
      expect(
        changes.firstWhere((c) => c.field == 'categoryName').after,
        isNull,
      );
      expect(changes.firstWhere((c) => c.field == 'budgetName').before, isNull);
    });

    test('an emptied field reads as cleared, not as a change to nothing', () {
      // An action that clears a field and one that never set it leave the
      // same thing behind, so an empty string is no value rather than a value
      // of its own.
      final changes = historyEntryChanges(
        _entry(
          before: {'notes': 'from the bank', 'tags': <String>[]},
          after: {'notes': '', 'tags': <String>[]},
        ),
      );

      expect(changes, hasLength(1));
      expect(changes.single.field, 'notes');
      expect(changes.single.before, 'from the bank');
      expect(changes.single.after, isNull);
    });

    test('a change that moved nothing has nothing to show', () {
      expect(
        historyEntryChanges(
          _entry(
            before: {'transactionId': '1', 'description': 'Rent'},
            after: {'transactionId': '1', 'description': 'Rent'},
          ),
        ),
        isEmpty,
      );
    });

    test('a list or a map is shown rather than hidden', () {
      final changes = historyEntryChanges(
        _entry(
          before: {
            'tags': ['Holidays'],
          },
          after: {
            'tags': ['Holidays', 'Shared'],
          },
        ),
      );

      expect(changes.single.before, '["Holidays"]');
      expect(changes.single.after, '["Holidays","Shared"]');
    });
  });

  group('a payload key read by a person', () {
    test('is spaced and capitalised', () {
      expect(historyFieldLabel('sourceName'), 'Source name');
      expect(historyFieldLabel('transactionId'), 'Transaction id');
      expect(historyFieldLabel('foreign_amount'), 'Foreign amount');
      expect(historyFieldLabel('amount'), 'Amount');
    });

    test('leaves a key it cannot improve alone', () {
      expect(historyFieldLabel(''), '');
    });
  });
}
