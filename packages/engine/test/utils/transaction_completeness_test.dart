import 'package:fireracoon_engine/models/transaction.dart';
import 'package:fireracoon_engine/utils/transaction_completeness.dart';
import 'package:test/test.dart';

Transaction _tx({
  String id = '1',
  String type = 'withdrawal',
  String description = 'Groceries',
  String categoryName = 'Food',
  String? categoryId = '7',
  String? budgetName = 'Household',
  String? budgetId = '3',
  List<String> tags = const ['weekly'],
  String? notes = 'note',
  String? piggyBankId = '4',
  String sourceName = 'Checking',
  String destinationName = 'Store',
  DateTime? date,
  List<Transaction> splits = const [],
}) => Transaction(
  id: id,
  type: type,
  date: date ?? DateTime(2026, 6, 1),
  amount: 10,
  description: description,
  sourceName: sourceName,
  destinationName: destinationName,
  categoryName: categoryName,
  categoryId: categoryId,
  budgetName: budgetName,
  budgetId: budgetId,
  tags: tags,
  notes: notes,
  piggyBankId: piggyBankId,
  currencySymbol: '€',
  currencyCode: 'EUR',
  splits: splits,
);

const _all = {
  TransactionField.description,
  TransactionField.category,
  TransactionField.budget,
  TransactionField.tags,
  TransactionField.payee,
  TransactionField.notes,
  TransactionField.piggyBank,
};

void main() {
  group('missingTransactionFields', () {
    test('reports nothing for a fully filled transaction', () {
      expect(missingTransactionFields(_tx(), fields: _all), isEmpty);
    });

    test('reports each field it lacks', () {
      final bare = _tx(
        description: '  ',
        categoryName: '',
        categoryId: null,
        budgetName: null,
        budgetId: null,
        tags: const [],
        notes: null,
        piggyBankId: null,
        destinationName: '',
      );

      expect(missingTransactionFields(bare, fields: _all), _all);
    });

    test('a category counts as present when only the id is set', () {
      // Firefly can answer with one and not the other, and either means the
      // category is on the transaction.
      final byId = _tx(categoryName: '', categoryId: '7');
      final byName = _tx(categoryName: 'Food', categoryId: null);

      for (final transaction in [byId, byName]) {
        expect(
          missingTransactionFields(
            transaction,
            fields: {TransactionField.category},
          ),
          isEmpty,
        );
      }
    });

    test('does not ask a deposit for a budget', () {
      // Budgets are for spending. Flagging every income row for a budget it
      // cannot have is how a maintenance list fills with work nobody can do.
      final income = _tx(
        type: 'deposit',
        budgetName: null,
        budgetId: null,
        sourceName: 'Employer',
      );

      expect(
        missingTransactionFields(income, fields: {TransactionField.budget}),
        isEmpty,
      );
    });

    test('does not ask a transfer for a payee', () {
      // Both sides are your own accounts, so there is no payee to fill in.
      final transfer = _tx(
        type: 'transfer',
        destinationName: 'Savings',
        budgetName: null,
        budgetId: null,
      );

      expect(
        missingTransactionFields(
          transfer,
          fields: {TransactionField.payee, TransactionField.budget},
        ),
        isEmpty,
      );
    });

    test('reads the payee from the side that faces outward', () {
      final spending = _tx(destinationName: '');
      final income = _tx(type: 'deposit', sourceName: '');

      for (final transaction in [spending, income]) {
        expect(
          missingTransactionFields(
            transaction,
            fields: {TransactionField.payee},
          ),
          {TransactionField.payee},
        );
      }
    });

    test('finds a gap on any leg of a split group', () {
      // Half a card bill categorised and half not is the case worth finding,
      // and reading only the first leg would hide it.
      final group = _tx(
        splits: [
          _tx(id: 'a'),
          _tx(id: 'b', categoryName: '', categoryId: null),
        ],
      );

      expect(
        missingTransactionFields(group, fields: {TransactionField.category}),
        {TransactionField.category},
      );
    });
  });

  group('hasMissingFields', () {
    test('matches nothing when no field was asked for', () {
      // Asking for no gaps is asking for no rows, not for every row.
      final bare = _tx(description: '', categoryName: '', categoryId: null);

      expect(hasMissingFields(bare, fields: const {}), isFalse);
    });
  });

  group('transactionsMissingFields', () {
    test('returns the incomplete ones, newest first', () {
      final complete = _tx(id: 'ok', date: DateTime(2026, 6, 3));
      final older = _tx(
        id: 'older',
        date: DateTime(2026, 6, 1),
        categoryName: '',
        categoryId: null,
      );
      final newer = _tx(
        id: 'newer',
        date: DateTime(2026, 6, 2),
        categoryName: '',
        categoryId: null,
      );

      final result = transactionsMissingFields(
        [older, complete, newer],
        fields: {TransactionField.category},
      );

      expect(result.map((t) => t.id), ['newer', 'older']);
    });
  });

  group('countMissingByField', () {
    test('counts one transaction towards every field it lacks', () {
      final bare = _tx(
        id: 'bare',
        description: '',
        categoryName: '',
        categoryId: null,
      );
      final noCategory = _tx(id: 'partial', categoryName: '', categoryId: null);

      final counts = countMissingByField(
        [bare, noCategory, _tx(id: 'ok')],
        fields: {TransactionField.description, TransactionField.category},
      );

      expect(counts[TransactionField.description], 1);
      expect(counts[TransactionField.category], 2);
    });

    test('reports a zero for a field nothing is missing', () {
      final counts = countMissingByField(
        [_tx()],
        fields: {TransactionField.tags},
      );

      expect(counts, {TransactionField.tags: 0});
    });
  });
}
