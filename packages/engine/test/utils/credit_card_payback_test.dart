import 'package:fireraccoon_engine/fireraccoon_engine.dart';
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
  _linkTests();

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
        destination: 'Checking',
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
      expect(transfer.groupTitle, 'Platinum Payback');
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
      expect(first.notes, 'fireraccoon:linked_journal:j1');
      expect(first.reconciled, isTrue);
      expect(first.currencyCode, 'SEK');

      expect(transfer.splits[1].notes, 'fireraccoon:linked_journal:j2');
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
      expect(transfer.splits.single.notes, 'fireraccoon:linked_journal:buy');
    });

    test('a refund is netted off, and the legs go with it', () {
      final payment = _account(id: '10', name: 'Allkonto');
      final card = _account(id: '20', name: 'Platinum', role: 'ccAsset');

      final transfer = buildCreditCardPaybackTransfer(
        paymentAccount: payment,
        creditCard: card,
        paybackDate: DateTime(2026, 7, 31),
        purchases: [
          _tx(
            id: 'buy-1',
            type: 'withdrawal',
            amount: 1000,
            source: 'Platinum',
            destination: 'Store',
          ),
          _tx(
            id: 'buy-2',
            type: 'withdrawal',
            amount: 200,
            source: 'Platinum',
            destination: 'Hotel',
          ),
          _tx(
            id: 'back',
            type: 'deposit',
            amount: 200,
            source: 'Hotel',
            destination: 'Platinum',
          ),
        ],
      );

      // The bank bills the difference and that is what leaves the account, so
      // no leg is true on its own any more.
      expect(transfer.amount, 1000);
      expect(transfer.splits, isEmpty);
      expect(transfer.sourceId, '10');
      expect(transfer.destinationId, '20');
      expect(transfer.reconciled, isTrue);
      // Every row it settles is still named, the refund included.
      expect(
        transfer.notes,
        'fireraccoon:linked_journal:buy-1\n'
        'fireraccoon:linked_journal:buy-2\n'
        'fireraccoon:linked_journal:back',
      );
    });

    test('a refund worth the whole bill leaves nothing to pay', () {
      final payment = _account(id: '10', name: 'Allkonto');
      final card = _account(id: '20', name: 'Platinum', role: 'ccAsset');

      expect(
        () => buildCreditCardPaybackTransfer(
          paymentAccount: payment,
          creditCard: card,
          paybackDate: DateTime(2026, 7, 31),
          purchases: [
            _tx(
              id: 'buy',
              type: 'withdrawal',
              amount: 200,
              source: 'Platinum',
              destination: 'Hotel',
            ),
            _tx(
              id: 'back',
              type: 'deposit',
              amount: 200,
              source: 'Hotel',
              destination: 'Platinum',
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a payment already made is skipped, not netted', () {
      final payment = _account(id: '10', name: 'Allkonto');
      final card = _account(id: '20', name: 'Platinum', role: 'ccAsset');

      final transfer = buildCreditCardPaybackTransfer(
        paymentAccount: payment,
        creditCard: card,
        paybackDate: DateTime(2026, 7, 31),
        purchases: [
          _tx(
            id: 'buy',
            type: 'withdrawal',
            amount: 300,
            source: 'Platinum',
            destination: 'Store',
          ),
          _tx(
            id: 'paid',
            type: 'transfer',
            amount: 100,
            source: 'Allkonto',
            destination: 'Platinum',
          ),
        ],
      );

      // Money from another account of your own is a payment, not a refund, and
      // the split shape survives it.
      expect(transfer.amount, 300);
      expect(transfer.splits, hasLength(1));
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

Transaction _cardRow({
  required String id,
  required DateTime date,
  required double amount,
  String type = 'withdrawal',
  String source = 'Card',
  String destination = 'Store',
  String description = 'Purchase',
  String? notes,
  List<Transaction> splits = const [],
}) => Transaction(
  id: id,
  type: type,
  date: date,
  amount: amount,
  description: description,
  sourceName: source,
  destinationName: destination,
  categoryName: '',
  currencySymbol: 'kr',
  currencyCode: 'SEK',
  notes: notes,
  splits: splits,
);

// Reading the link notes back.
void _linkTests() {
  final card = _account(id: 'card', name: 'Card', role: 'ccAsset');

  group('linkedJournalIdsIn', () {
    test('reads the current spelling and the one before the rename', () {
      expect(linkedJournalIdsIn('fireraccoon:linked_journal:41'), {'41'});
      expect(linkedJournalIdsIn('fireracoon:linked_journal:41'), {'41'});
    });

    test('reads several links from one note, and nothing from none', () {
      expect(
        linkedJournalIdsIn(
          'fireraccoon:linked_journal:1\nfireracoon:linked_journal:2\n'
          'bank text: ICA',
        ),
        {'1', '2'},
      );
      expect(linkedJournalIdsIn(null), isEmpty);
      expect(linkedJournalIdsIn('bank text: ICA'), isEmpty);
    });
  });

  group('paybackSettledIds', () {
    test('collects every leg once, in note order', () {
      final payback = _cardRow(
        id: 'a',
        type: 'transfer',
        source: 'Checking',
        destination: 'Card',
        date: DateTime(2026, 6, 15),
        amount: 100,
        splits: [
          _cardRow(
            id: 'a',
            type: 'transfer',
            source: 'Checking',
            destination: 'Card',
            date: DateTime(2026, 6, 15),
            amount: 40,
            notes: 'fireraccoon:linked_journal:p1',
          ),
          _cardRow(
            id: 'a',
            type: 'transfer',
            source: 'Checking',
            destination: 'Card',
            date: DateTime(2026, 6, 15),
            amount: 60,
            notes:
                'fireracoon:linked_journal:p2\nfireraccoon:linked_journal:p1',
          ),
        ],
      );

      expect(paybackSettledIds(payback), ['p1', 'p2']);
    });
  });

  group('isCreditCardPayback', () {
    test('a transfer onto the card is one, anything else is not', () {
      final onto = _cardRow(
        id: 'a',
        type: 'transfer',
        source: 'Checking',
        destination: 'Card',
        date: DateTime(2026, 6, 15),
        amount: 100,
      );
      final off = _cardRow(
        id: 'b',
        type: 'transfer',
        source: 'Card',
        destination: 'Checking',
        date: DateTime(2026, 6, 15),
        amount: 100,
      );
      final refund = _cardRow(
        id: 'c',
        type: 'deposit',
        source: 'Store',
        destination: 'Card',
        date: DateTime(2026, 6, 15),
        amount: 10,
      );

      expect(isCreditCardPayback(onto, card), isTrue);
      expect(isCreditCardPayback(off, card), isFalse);
      expect(isCreditCardPayback(refund, card), isFalse);
    });
  });

  group('analyseCardSettlements', () {
    final p1 = _cardRow(id: 'p1', date: DateTime(2026, 6, 1), amount: 40);
    final p2 = _cardRow(id: 'p2', date: DateTime(2026, 6, 10), amount: 60);
    final r1 = _cardRow(
      id: 'r1',
      type: 'deposit',
      source: 'Store',
      destination: 'Card',
      date: DateTime(2026, 6, 12),
      amount: 10,
    );
    final p3 = _cardRow(id: 'p3', date: DateTime(2026, 6, 20), amount: 25);
    final p4 = _cardRow(id: 'p4', date: DateTime(2026, 7, 5), amount: 15);
    final linkedPayback = _cardRow(
      id: 'a',
      type: 'transfer',
      source: 'Checking',
      destination: 'Card',
      date: DateTime(2026, 6, 15),
      amount: 100,
      notes:
          'fireraccoon:linked_journal:p1\nfireracoon:linked_journal:p2\n'
          'fireraccoon:linked_journal:p0',
    );
    final handWritten = _cardRow(
      id: 'b',
      type: 'transfer',
      source: 'Checking',
      destination: 'Card',
      date: DateTime(2026, 6, 30),
      amount: 35,
      description: 'Card payment',
    );

    test('reads what each payback settles and what none does', () {
      final result = analyseCardSettlements(
        card: card,
        // Out of order on purpose: paybacks come back oldest first.
        transactions: [p4, handWritten, p3, r1, linkedPayback, p2, p1],
      );

      expect(result.paybacks.map((s) => s.payback.id), ['a', 'b']);
      final linked = result.paybacks.first;
      expect(linked.linked, isTrue);
      expect(linked.settles.map((t) => t.id), ['p1', 'p2']);
      // Settled from before the rows given, so named rather than resolved.
      expect(linked.notFetched, ['p0']);
      final unlinked = result.paybacks.last;
      expect(unlinked.linked, isFalse);
      expect(unlinked.settles, isEmpty);
      expect(result.unlinkedPaybacks.map((s) => s.payback.id), ['b']);
      expect(result.lastPayback?.id, 'b');
      // The refund and the later purchase no payback links, oldest first; the
      // July purchase is after the last payback and is not yet due.
      expect(result.unsettled.map((t) => t.id), ['r1', 'p3']);
    });

    test('with no payback there is nothing to call unsettled', () {
      final result = analyseCardSettlements(card: card, transactions: [p1, p2]);

      expect(result.paybacks, isEmpty);
      expect(result.unsettled, isEmpty);
      expect(result.lastPayback, isNull);
    });

    test('a purchase dated on the payback day is not yet due', () {
      final sameDay = _cardRow(
        id: 'p5',
        date: DateTime(2026, 6, 30, 9),
        amount: 5,
      );
      final result = analyseCardSettlements(
        card: card,
        transactions: [handWritten, sameDay, p3],
      );

      expect(result.unsettled.map((t) => t.id), ['p3']);
    });
  });
}
