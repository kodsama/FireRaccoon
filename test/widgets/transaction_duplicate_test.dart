import 'package:fireraccoon/widgets/transaction_entity_card.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transactionForDuplicate keeps fields but uses today', () {
    final source = Transaction(
      id: '42',
      type: 'withdrawal',
      date: DateTime(2020, 1, 15, 10, 30),
      amount: 99.5,
      description: 'Coffee',
      sourceName: 'Checking',
      destinationName: 'Cafe',
      categoryName: 'Food',
      currencySymbol: '€',
      currencyCode: 'EUR',
      budgetId: '7',
      budgetName: 'Fun',
      notes: 'Morning pick-me-up',
      tags: const ['coffee'],
      reconciled: true,
    );

    final duplicate = transactionForDuplicate(source);
    final now = DateTime.now();

    expect(duplicate.type, source.type);
    expect(duplicate.amount, source.amount);
    expect(duplicate.description, source.description);
    expect(duplicate.budgetId, source.budgetId);
    expect(duplicate.notes, source.notes);
    expect(duplicate.tags, source.tags);
    expect(duplicate.date.year, now.year);
    expect(duplicate.date.month, now.month);
    expect(duplicate.date.day, now.day);
    expect(duplicate.splits, isEmpty);
    expect(duplicate.reconciled, isFalse);
  });

  test(
    'transactionForDuplicate copies split groups with today on each split',
    () {
      final splitA = Transaction(
        id: '10',
        type: 'withdrawal',
        date: DateTime(2021, 5, 1),
        amount: 30,
        description: 'Split purchase',
        sourceName: 'Checking',
        destinationName: 'Store',
        categoryName: 'Food',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );
      final splitB = splitA.copyWith(amount: 20, categoryName: 'Household');
      final source = splitA.copyWith(
        splits: [splitA, splitB],
        groupTitle: 'Split purchase',
      );

      final duplicate = transactionForDuplicate(source);
      final now = DateTime.now();

      expect(duplicate.splits, hasLength(2));
      expect(duplicate.splits[0].amount, 30);
      expect(duplicate.splits[1].amount, 20);
      expect(duplicate.splits[0].date.day, now.day);
      expect(duplicate.splits[1].date.day, now.day);
      expect(duplicate.groupTitle, 'Split purchase');
    },
  );
}
