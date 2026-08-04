import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/utils/search_filter.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

void main() {
  group('matchesSearchQuery', () {
    test('empty query matches everything', () {
      expect(matchesSearchQuery(null, ['foo']), isTrue);
      expect(matchesSearchQuery('', ['foo']), isTrue);
      expect(matchesSearchQuery('   ', ['foo']), isTrue);
    });

    test('matches case-insensitively across fields', () {
      expect(matchesSearchQuery('gro', ['Groceries', 'Rent']), isTrue);
      expect(matchesSearchQuery('RENT', ['Groceries', 'Rent']), isTrue);
      expect(matchesSearchQuery('xyz', ['Groceries', 'Rent']), isFalse);
    });
  });

  group('model search extensions', () {
    final account = Account(
      id: '1',
      name: 'Checking',
      type: 'asset',
      role: 'defaultAsset',
      currentBalance: 100,
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    final transaction = Transaction(
      id: '1',
      type: 'withdrawal',
      date: DateTime(2026, 1, 1),
      amount: 10,
      description: 'Coffee shop',
      sourceName: 'Checking',
      destinationName: 'Groceries',
      categoryName: 'Food',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    test('account matches name and metadata', () {
      expect(account.matchesSearch('check'), isTrue);
      expect(account.matchesSearch('eur'), isTrue);
      expect(account.matchesSearch('savings'), isFalse);
    });

    test('transaction matches description and parties', () {
      expect(transaction.matchesSearch('coffee'), isTrue);
      expect(transaction.matchesSearch('groceries'), isTrue);
      expect(transaction.matchesSearch('flight'), isFalse);
    });
  });
}
