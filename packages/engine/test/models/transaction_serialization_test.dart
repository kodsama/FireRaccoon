import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Transaction.formatApiDateTime', () {
    test('keeps UTC instants unambiguous', () {
      final formatted = Transaction.formatApiDateTime(
        DateTime.utc(2026, 7, 11, 10, 30),
      );
      expect(formatted, '2026-07-11T10:30:00.000Z');
    });

    test('appends an explicit offset for local times', () {
      final local = DateTime(2026, 7, 11, 10, 30);
      final formatted = Transaction.formatApiDateTime(local);
      // Local ISO strings carry no offset by default; the suffix must encode
      // the actual zone so the server cannot reinterpret the timestamp.
      final offset = local.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final abs = offset.abs();
      final expectedSuffix =
          '$sign${abs.inHours.toString().padLeft(2, '0')}:'
          '${(abs.inMinutes % 60).toString().padLeft(2, '0')}';
      expect(formatted, startsWith('2026-07-11T10:30:00.000'));
      expect(formatted, endsWith(expectedSuffix));
    });

    test('toSplitJson serializes date with offset and round-trips', () {
      final transaction = Transaction(
        id: '1',
        type: 'withdrawal',
        date: DateTime(2026, 7, 11, 0, 0),
        amount: 5,
        description: 'Coffee',
        sourceName: 'Checking',
        destinationName: 'Cafe',
        categoryName: '',
        currencySymbol: '\u20ac',
        currencyCode: 'EUR',
      );

      final json = transaction.toSplitJson();
      final parsed = DateTime.parse(json['date'] as String).toLocal();
      expect(parsed, transaction.date);
    });

    test('toSplitJson serializes budget_name and category_name', () {
      final transaction = Transaction(
        id: '1',
        type: 'withdrawal',
        date: DateTime(2026, 7, 11, 0, 0),
        amount: 5,
        description: 'Coffee',
        sourceName: 'Checking',
        destinationName: 'Cafe',
        categoryName: 'New Category',
        budgetName: 'New Budget',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );

      final json = transaction.toSplitJson();
      expect(json['category_name'], 'New Category');
      expect(json['budget_name'], 'New Budget');
    });

    test('a cleared field is sent as an empty value, not left out', () {
      // An empty value is left out, so omitting a field and emptying one were
      // the same request and Firefly kept what it had. Naming the intent is
      // the only way to take a note or a category away.
      final transaction = Transaction(
        id: '1',
        type: 'withdrawal',
        date: DateTime(2026, 7, 11),
        amount: 5,
        description: 'Coffee',
        sourceName: 'Checking',
        destinationName: 'Cafe',
        categoryName: '',
        currencySymbol: '€',
        currencyCode: 'EUR',
        clearedFields: const {'notes', 'category_name', 'tags'},
      );

      final json = transaction.toSplitJson();
      expect(json['notes'], '');
      expect(json['category_name'], '');
      expect(json['tags'], isEmpty);
    });

    test('a field left unmentioned stays out of the payload', () {
      final transaction = Transaction(
        id: '1',
        type: 'withdrawal',
        date: DateTime(2026, 7, 11),
        amount: 5,
        description: 'Coffee',
        sourceName: 'Checking',
        destinationName: 'Cafe',
        categoryName: '',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );

      final json = transaction.toSplitJson();
      expect(json.containsKey('notes'), isFalse);
      expect(json.containsKey('category_name'), isFalse);
    });

    test(
      'toSplitJson includes foreign currency, piggy bank, and interest date',
      () {
        final transaction = Transaction(
          id: '1',
          type: 'withdrawal',
          date: DateTime(2026, 7, 11, 0, 0),
          amount: 5,
          description: 'Coffee',
          sourceName: 'Checking',
          destinationName: 'Cafe',
          categoryName: 'Food',
          currencySymbol: '€',
          currencyCode: 'EUR',
          foreignAmount: 6,
          foreignCurrencyCode: 'USD',
          categoryId: 'c1',
          budgetId: 'b1',
          notes: 'note',
          tags: ['food'],
          billId: 'bill1',
          piggyBankId: 'p1',
          interestDate: DateTime(2026, 7, 12),
        );

        final json = transaction.toSplitJson();
        expect(json['foreign_amount'], '6.00');
        expect(json['foreign_currency_code'], 'USD');
        expect(json['category_id'], 'c1');
        expect(json['budget_id'], 'b1');
        expect(json['notes'], 'note');
        expect(json['tags'], ['food']);
        expect(json['bill_id'], 'bill1');
        expect(json['piggy_bank_id'], 'p1');
        expect(json['interest_date'], '2026-07-12');
      },
    );
  });

  group('transactionAccountNames', () {
    test('collects top-level and split account names, dropping empties', () {
      final split = Transaction(
        id: '1-a',
        type: 'transfer',
        date: DateTime(2026, 7, 1),
        amount: 10,
        description: 'move',
        sourceName: 'Checking',
        destinationName: 'Savings',
        categoryName: '',
        currencySymbol: '\u20ac',
        currencyCode: 'EUR',
      );
      final transaction = Transaction(
        id: '1',
        type: 'transfer',
        date: DateTime(2026, 7, 1),
        amount: 10,
        description: 'move',
        sourceName: 'Checking',
        destinationName: '',
        categoryName: '',
        currencySymbol: '\u20ac',
        currencyCode: 'EUR',
        splits: [split],
      );

      expect(transactionAccountNames(transaction), {'Checking', 'Savings'});
    });
  });

  group('Transaction update serialization', () {
    test(
      'omits financial fields for reconciled transactions when isUpdate is true',
      () {
        final transaction = Transaction(
          id: '97083',
          type: 'transfer',
          date: DateTime(2026, 7, 22),
          amount: 10000.0,
          description: 'Transfer',
          sourceId: '10299',
          sourceName: 'Wallet SEK',
          destinationId: '10278',
          destinationName: 'Personal Current',
          categoryName: '',
          currencySymbol: 'kr',
          currencyCode: 'SEK',
          reconciled: true,
        );

        final payload = transaction.toApiPayload(isUpdate: true);
        final split =
            (payload['transactions'] as List).first as Map<String, dynamic>;

        expect(split['reconciled'], isTrue);
        expect(split['description'], 'Transfer');
        expect(split.containsKey('amount'), isFalse);
        expect(split.containsKey('currency_code'), isFalse);
        expect(split.containsKey('source_id'), isFalse);
        expect(split.containsKey('source_name'), isFalse);
        expect(split.containsKey('destination_id'), isFalse);
        expect(split.containsKey('destination_name'), isFalse);
      },
    );

    test('includes financial fields for unreconciled transaction updates', () {
      final transaction = Transaction(
        id: '97083',
        type: 'transfer',
        date: DateTime(2026, 7, 22),
        amount: 10000.0,
        description: 'Transfer',
        sourceId: '10299',
        sourceName: 'Wallet SEK',
        destinationId: '10278',
        destinationName: 'Personal Current',
        categoryName: '',
        currencySymbol: 'kr',
        currencyCode: 'SEK',
        reconciled: false,
      );

      final payload = transaction.toApiPayload(isUpdate: true);
      final split =
          (payload['transactions'] as List).first as Map<String, dynamic>;

      expect(split['reconciled'], isFalse);
      expect(split['amount'], '10000.00');
      expect(split['currency_code'], 'SEK');
      expect(split['source_id'], '10299');
      expect(split['destination_id'], '10278');
    });

    test(
      'includes financial fields for reconciled transactions on creation (isUpdate: false)',
      () {
        final transaction = Transaction(
          id: '97083',
          type: 'transfer',
          date: DateTime(2026, 7, 22),
          amount: 10000.0,
          description: 'Transfer',
          sourceId: '10299',
          sourceName: 'Wallet SEK',
          destinationId: '10278',
          destinationName: 'Personal Current',
          categoryName: '',
          currencySymbol: 'kr',
          currencyCode: 'SEK',
          reconciled: true,
        );

        final payload = transaction.toApiPayload(isUpdate: false);
        final split =
            (payload['transactions'] as List).first as Map<String, dynamic>;

        expect(split['reconciled'], isTrue);
        expect(split['amount'], '10000.00');
        expect(split['currency_code'], 'SEK');
        expect(split['source_id'], '10299');
        expect(split['destination_id'], '10278');
      },
    );
  });
}
