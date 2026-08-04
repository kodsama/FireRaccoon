import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:test/test.dart';

Account _account({
  required String id,
  required String name,
  String type = 'asset',
  String role = 'defaultAsset',
  String currencyCode = 'SEK',
  String currencySymbol = 'kr',
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    role: role,
    currentBalance: 0,
    currencySymbol: currencySymbol,
    currencyCode: currencyCode,
  );
}

Transaction _tx({
  String id = '1',
  required String type,
  required double amount,
  required String source,
  required String destination,
  String description = 'Purchase',
  String categoryName = 'Food',
  String? categoryId,
  List<String> tags = const [],
  String currencyCode = 'SEK',
  String currencySymbol = 'kr',
  List<Transaction>? splits,
}) {
  return Transaction(
    id: id,
    type: type,
    date: DateTime(2026, 7, 1),
    amount: amount,
    description: description,
    sourceName: source,
    destinationName: destination,
    categoryName: categoryName,
    categoryId: categoryId,
    currencySymbol: currencySymbol,
    currencyCode: currencyCode,
    tags: tags,
    splits: splits ?? const [],
  );
}

void main() {
  group('isCreditCardAccount', () {
    test('true only for ccAsset role', () {
      expect(
        isCreditCardAccount(_account(id: '1', name: 'Card', role: 'ccAsset')),
        isTrue,
      );
      expect(
        isCreditCardAccount(
          _account(id: '2', name: 'Checking', role: 'defaultAsset'),
        ),
        isFalse,
      );
      expect(
        isCreditCardAccount(
          _account(
            id: '3',
            name: 'Loan',
            type: 'liability',
            role: 'defaultAsset',
          ),
        ),
        isFalse,
      );
    });
  });

  group('isCreditCardPurchase', () {
    test('true for withdrawals from the card', () {
      final purchase = _tx(
        type: 'withdrawal',
        amount: 100,
        source: 'Platinum',
        destination: 'Store',
      );
      expect(isCreditCardPurchase(purchase, 'Platinum'), isTrue);
    });

    test('false for transfers into the card (paybacks)', () {
      final payback = _tx(
        type: 'transfer',
        amount: 500,
        source: 'Allkonto',
        destination: 'Platinum',
      );
      expect(isCreditCardPurchase(payback, 'Platinum'), isFalse);
    });

    test('false for deposits into the card', () {
      final deposit = _tx(
        type: 'deposit',
        amount: 50,
        source: 'Refund',
        destination: 'Platinum',
      );
      expect(isCreditCardPurchase(deposit, 'Platinum'), isFalse);
    });

    test('true for transfers out of the card (cash advances)', () {
      final out = _tx(
        type: 'transfer',
        amount: 200,
        source: 'Platinum',
        destination: 'Revolut',
      );
      expect(isCreditCardPurchase(out, 'Platinum'), isTrue);
    });
  });

  group('creditCardPaybackAmount', () {
    test('returns absolute signed effect on the card', () {
      final purchase = _tx(
        type: 'withdrawal',
        amount: 43.8,
        source: 'Platinum',
        destination: 'Spotify',
      );
      expect(creditCardPaybackAmount(purchase, 'Platinum'), 43.8);
    });

    test('sums splits on the card', () {
      final group = _tx(
        id: '99',
        type: 'withdrawal',
        amount: 30,
        source: 'Platinum',
        destination: 'Market',
        splits: [
          _tx(
            id: '99',
            type: 'withdrawal',
            amount: 30,
            source: 'Platinum',
            destination: 'Market',
          ),
          _tx(
            id: '99',
            type: 'withdrawal',
            amount: 20,
            source: 'Platinum',
            destination: 'Pharmacy',
          ),
        ],
      );
      expect(creditCardPaybackAmount(group, 'Platinum'), 50);
    });
  });

  group('buildCreditCardPaybackTransfer', () {
    test('builds multi-split transfer mirroring purchases', () {
      final payment = _account(id: '10', name: 'Allkonto');
      final card = _account(id: '20', name: 'Platinum', role: 'ccAsset');
      final purchases = [
        _tx(
          id: 'j1',
          type: 'withdrawal',
          amount: 43.8,
          source: 'Platinum',
          destination: 'Spotify',
          description: 'Spotify premium',
          categoryName: 'Hobby',
          categoryId: '730',
          tags: const ['music'],
        ),
        _tx(
          id: 'j2',
          type: 'withdrawal',
          amount: 120,
          source: 'Platinum',
          destination: 'Fello',
          description: 'Fello Mobile phone',
          categoryName: 'Phone',
          categoryId: '731',
        ),
      ];

      final transfer = buildCreditCardPaybackTransfer(
        paymentAccount: payment,
        creditCard: card,
        paybackDate: DateTime(2026, 7, 31),
        purchases: purchases,
      );

      expect(transfer.type, 'transfer');
      expect(transfer.date, DateTime(2026, 7, 31));
      expect(transfer.groupTitle, 'Credit card payback — Platinum');
      expect(transfer.isSplitGroup, isTrue);
      expect(transfer.splits, hasLength(2));
      expect(transfer.totalAmount, closeTo(163.8, 0.001));

      final first = transfer.splits[0];
      expect(first.type, 'transfer');
      expect(first.sourceId, '10');
      expect(first.sourceName, 'Allkonto');
      expect(first.destinationId, '20');
      expect(first.destinationName, 'Platinum');
      expect(first.amount, 43.8);
      expect(first.description, 'Spotify premium');
      expect(first.categoryId, '730');
      expect(first.categoryName, 'Hobby');
      expect(first.tags, ['music']);
      expect(first.notes, 'fireracoon:linked_journal:j1');
      expect(first.reconciled, isTrue);
      expect(first.currencyCode, 'SEK');

      expect(transfer.splits[1].notes, 'fireracoon:linked_journal:j2');
      expect(transfer.splits[1].amount, 120);
      expect(transfer.reconciled, isTrue);
    });

    test('skips non-purchase journals', () {
      final payment = _account(id: '10', name: 'Allkonto');
      final card = _account(id: '20', name: 'Platinum', role: 'ccAsset');
      final transfer = buildCreditCardPaybackTransfer(
        paymentAccount: payment,
        creditCard: card,
        paybackDate: DateTime(2026, 7, 31),
        purchases: [
          _tx(
            id: 'pay',
            type: 'transfer',
            amount: 500,
            source: 'Allkonto',
            destination: 'Platinum',
          ),
          _tx(
            id: 'buy',
            type: 'withdrawal',
            amount: 10,
            source: 'Platinum',
            destination: 'Store',
          ),
        ],
      );

      expect(transfer.splits, hasLength(1));
      expect(transfer.splits.single.notes, 'fireracoon:linked_journal:buy');
    });

    test('throws when no eligible purchases', () {
      final payment = _account(id: '10', name: 'Allkonto');
      final card = _account(id: '20', name: 'Platinum', role: 'ccAsset');
      expect(
        () => buildCreditCardPaybackTransfer(
          paymentAccount: payment,
          creditCard: card,
          paybackDate: DateTime(2026, 7, 31),
          purchases: [
            _tx(
              type: 'transfer',
              amount: 100,
              source: 'Allkonto',
              destination: 'Platinum',
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('paymentAccountsForCreditCard', () {
    test('filters active same-currency assets excluding the card', () {
      final card = _account(id: '20', name: 'Platinum', role: 'ccAsset');
      final accounts = [
        card,
        _account(id: '10', name: 'Allkonto'),
        _account(
          id: '11',
          name: 'Euro',
          currencyCode: 'EUR',
          currencySymbol: '€',
        ),
        Account(
          id: '12',
          name: 'Inactive',
          type: 'asset',
          role: 'defaultAsset',
          currentBalance: 0,
          currencySymbol: 'kr',
          currencyCode: 'SEK',
          active: false,
        ),
        _account(id: '13', name: 'Loan', type: 'liability'),
      ];

      final options = paymentAccountsForCreditCard(card, accounts);
      expect(options.map((a) => a.id), ['10']);
    });
  });
}
