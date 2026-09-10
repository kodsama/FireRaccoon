import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

class _RecordingApi implements FireflyService {
  final updates = <Transaction>[];
  final creates = <Transaction>[];
  int failAfterUpdates = -1;

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    if (failAfterUpdates >= 0 && updates.length >= failAfterUpdates) {
      throw StateError('update failed');
    }
    updates.add(transaction);
    return transaction;
  }

  @override
  Future<Transaction> createTransaction(Transaction transaction) async {
    creates.add(transaction);
    return transaction.copyWith(id: 'created-1');
  }

  /// What the ledger already has of type `reconciliation`.
  List<Account> reconciliationAccounts = const [];
  final accountCreates = <String>[];

  @override
  Future<List<Account>> getAccounts({
    List<String> types = const ['asset', 'liability'],
  }) async => types.contains('reconciliation')
      ? reconciliationAccounts
      : const <Account>[];

  @override
  Future<Account> createAccount({
    required String name,
    required String type,
    required String currencyCode,
    String? role,
  }) async {
    accountCreates.add('$type:$name:$currencyCode');
    return _account(
      id: 'new-1',
      name: name,
      type: type,
      currencyCode: currencyCode,
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Transaction _tx({
  required String id,
  bool reconciled = false,
  double amount = 10,
  String type = 'withdrawal',
  String source = 'Checking',
  String destination = 'Store',
}) {
  return Transaction(
    id: id,
    type: type,
    date: DateTime(2026, 1, 1),
    amount: amount,
    description: id,
    sourceName: source,
    destinationName: destination,
    categoryName: '',
    currencySymbol: '€',
    currencyCode: 'EUR',
    reconciled: reconciled,
  );
}

Account _account({
  required String id,
  required String name,
  String type = 'asset',
  String role = 'defaultAsset',
  String currencyCode = 'EUR',
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    role: role,
    currentBalance: 0,
    currencySymbol: '€',
    currencyCode: currencyCode,
  );
}

void main() {
  test('store skips already-reconciled journals', () async {
    final api = _RecordingApi();
    final service = ReconciliationService(api);
    final already = _tx(id: '1', reconciled: true);
    final pending = _tx(id: '2');

    final result = await service.store(
      journalsToReconcile: [already, pending],
      accountId: 'a1',
      accountName: 'Checking',
      currencyCode: 'EUR',
      currencySymbol: '€',
      endDate: DateTime(2026, 1, 31),
      gap: 0,
      createCorrection: false,
    );

    expect(api.updates, hasLength(1));
    expect(api.updates.single.id, '2');
    expect(result.reconciled, hasLength(2));
    expect(result.correction, isNull);
  });

  test('store creates correction when gap exceeds tolerance', () async {
    final api = _RecordingApi();
    final service = ReconciliationService(api);

    final result = await service.store(
      journalsToReconcile: [_tx(id: '1')],
      accountId: 'a1',
      accountName: 'Checking',
      currencyCode: 'EUR',
      currencySymbol: '€',
      endDate: DateTime(2026, 1, 31),
      gap: 12.5,
    );

    expect(api.creates, hasLength(1));
    expect(result.correction?.id, 'created-1');
  });

  test(
    'a correction makes the reconciliation account Firefly has not',
    () async {
      // Firefly creates these only from its own interface, and a correction
      // names one: on a ledger that has never reconciled this account there was
      // nothing for it to name, and no way through the API to make one, so the
      // correction could not be written at all.
      final api = _RecordingApi();
      final service = ReconciliationService(api);

      await service.store(
        journalsToReconcile: [_tx(id: '1')],
        accountId: 'a1',
        accountName: 'Checking',
        currencyCode: 'EUR',
        currencySymbol: '\u20ac',
        endDate: DateTime(2026, 1, 31),
        gap: 12.5,
      );

      expect(api.accountCreates, [
        'reconciliation:Checking reconciliation:EUR',
      ]);
      // Named exactly as the correction refers to it, or Firefly cannot resolve
      // the name and refuses the write.
      final correction = api.creates.single;
      expect([
        correction.sourceName,
        correction.destinationName,
      ], contains('Checking reconciliation'));
    },
  );

  test('one that already exists is not made again', () async {
    final api = _RecordingApi()
      ..reconciliationAccounts = [
        _account(
          id: 'r1',
          name: 'Checking reconciliation',
          type: 'reconciliation',
        ),
      ];
    final service = ReconciliationService(api);

    await service.store(
      journalsToReconcile: [_tx(id: '1')],
      accountId: 'a1',
      accountName: 'Checking',
      currencyCode: 'EUR',
      currencySymbol: '\u20ac',
      endDate: DateTime(2026, 1, 31),
      gap: 12.5,
    );

    expect(api.accountCreates, isEmpty);
    expect(api.creates, hasLength(1));
  });

  test('nothing is made when there is no correction to write', () async {
    final api = _RecordingApi();
    final service = ReconciliationService(api);

    await service.store(
      journalsToReconcile: [_tx(id: '1')],
      accountId: 'a1',
      accountName: 'Checking',
      currencyCode: 'EUR',
      currencySymbol: '\u20ac',
      endDate: DateTime(2026, 1, 31),
      gap: 0,
    );

    expect(api.accountCreates, isEmpty);
    expect(api.creates, isEmpty);
  });

  test('store reports partial progress on mid-loop failure', () async {
    final api = _RecordingApi()..failAfterUpdates = 1;
    final service = ReconciliationService(api);

    expect(
      () => service.store(
        journalsToReconcile: [
          _tx(id: '1'),
          _tx(id: '2'),
        ],
        accountId: 'a1',
        accountName: 'Checking',
        currencyCode: 'EUR',
        currencySymbol: '€',
        endDate: DateTime(2026, 1, 31),
        gap: 0,
        createCorrection: false,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('after marking 1 of 2'),
        ),
      ),
    );
    expect(api.updates, hasLength(1));
  });

  group('storeCreditCardPayback', () {
    final card = _account(id: 'cc', name: 'Platinum', role: 'ccAsset');
    final payment = _account(id: 'pay', name: 'Allkonto');

    test('marks purchases reconciled and creates payback transfer', () async {
      final api = _RecordingApi();
      final service = ReconciliationService(api);
      final purchases = [
        _tx(id: 'j1', amount: 40, source: 'Platinum', destination: 'Store'),
        _tx(id: 'j2', amount: 10, source: 'Platinum', destination: 'Cafe'),
      ];

      final result = await service.storeCreditCardPayback(
        journalsToReconcile: purchases,
        creditCard: card,
        paymentAccount: payment,
        paybackDate: DateTime(2026, 7, 31),
      );

      expect(api.updates, hasLength(2));
      expect(api.creates, hasLength(1));
      expect(result.payback?.id, 'created-1');
      expect(result.correction, isNull);
      final created = api.creates.single;
      expect(created.type, 'transfer');
      expect(created.splits, hasLength(2));
      expect(created.totalAmount, 50);
      expect(created.groupTitle, 'Platinum Payback');
    });

    test('rejects non-credit-card destination', () async {
      final api = _RecordingApi();
      final service = ReconciliationService(api);
      expect(
        () => service.storeCreditCardPayback(
          journalsToReconcile: [
            _tx(id: '1', source: 'Checking', destination: 'Store'),
          ],
          creditCard: payment,
          paymentAccount: payment,
          paybackDate: DateTime(2026, 7, 31),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(api.updates, isEmpty);
      expect(api.creates, isEmpty);
    });

    test('rejects payment account with mismatched currency', () async {
      final api = _RecordingApi();
      final service = ReconciliationService(api);
      final usdPayment = _account(
        id: 'usd',
        name: 'USD Checking',
        currencyCode: 'USD',
      );

      expect(
        () => service.storeCreditCardPayback(
          journalsToReconcile: [
            _tx(id: '1', amount: 10, source: 'Platinum', destination: 'A'),
          ],
          creditCard: card,
          paymentAccount: usdPayment,
          paybackDate: DateTime(2026, 7, 31),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('does not create payback when marking fails mid-loop', () async {
      final api = _RecordingApi()..failAfterUpdates = 1;
      final service = ReconciliationService(api);

      expect(
        () => service.storeCreditCardPayback(
          journalsToReconcile: [
            _tx(id: '1', amount: 10, source: 'Platinum', destination: 'A'),
            _tx(id: '2', amount: 10, source: 'Platinum', destination: 'B'),
          ],
          creditCard: card,
          paymentAccount: payment,
          paybackDate: DateTime(2026, 7, 31),
        ),
        throwsA(isA<StateError>()),
      );
      expect(api.creates, isEmpty);
    });
  });
}
