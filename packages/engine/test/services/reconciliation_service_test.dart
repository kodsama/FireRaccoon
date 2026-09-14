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

  /// Refuses every create of this type, the way Firefly refuses a correction
  /// against an account it will not reconcile.
  String? refuseCreateOfType;

  @override
  Future<Transaction> createTransaction(Transaction transaction) async {
    if (transaction.type == refuseCreateOfType) {
      throw StateError('422 Mortgage is not an asset account');
    }
    creates.add(transaction);
    return transaction.copyWith(id: 'created-1');
  }

  final accountCreates = <String>[];

  /// Every account read, by the types it asked for.
  final accountReads = <List<String>>[];

  /// What the ledger holds of type `reconciliation`.
  List<Account> reconciliationAccounts = const [];

  @override
  Future<List<Account>> getAccounts({
    List<String> types = const ['asset', 'liability'],
  }) async {
    accountReads.add(types);
    return types.contains('reconciliation')
        ? reconciliationAccounts
        : const <Account>[];
  }

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
    final api = _RecordingApi()
      ..reconciliationAccounts = [
        _account(
          id: 'r1',
          name: 'Checking reconciliation (EUR)',
          type: 'reconciliation',
        ),
      ];
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

  test('a correction names the account Firefly keeps for this one', () async {
    // Read, never guessed and never made: Firefly names it itself, its API
    // refuses to create the type, and a correction naming an account it
    // cannot find is refused.
    final api = _RecordingApi()
      ..reconciliationAccounts = [
        _account(
          id: 'r1',
          name: 'Checking reconciliation (EUR)',
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

    expect(api.accountReads, [
      ['reconciliation'],
    ]);
    final correction = api.creates.single;
    expect(correction.type, 'reconciliation');
    expect(correction.amount, 12.5);
    // Short by the gap, so the money arrives and this account is the
    // destination.
    expect(correction.destinationId, 'a1');
    expect(correction.destinationName, 'Checking');
    expect(correction.sourceId, 'r1');
    expect(correction.sourceName, 'Checking reconciliation (EUR)');
    // Nothing is made: Firefly's API takes none of the types this needs.
    expect(api.accountCreates, isEmpty);
  });

  test('a surplus leaves this account as the source', () async {
    final api = _RecordingApi()
      ..reconciliationAccounts = [
        _account(
          id: 'r1',
          name: 'Checking reconciliation (EUR)',
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
      gap: -12.5,
    );

    final correction = api.creates.single;
    expect(correction.sourceId, 'a1');
    expect(correction.sourceName, 'Checking');
    expect(correction.destinationId, 'r1');
    expect(correction.destinationName, 'Checking reconciliation (EUR)');
  });

  test('an account Firefly has never reconciled is reported', () async {
    // It makes these only from its own interface, so there is nothing to name
    // and nothing the API can do about it. The rows are already marked.
    final api = _RecordingApi();
    final service = ReconciliationService(api);

    final result = await service.store(
      journalsToReconcile: [_tx(id: '1')],
      accountId: 'a1',
      accountName: 'Checking',
      currencyCode: 'EUR',
      currencySymbol: '\u20ac',
      endDate: DateTime(2026, 1, 31),
      gap: 12.5,
    );

    expect(api.creates, isEmpty);
    expect(api.accountCreates, isEmpty);
    expect(result.reconciled, hasLength(1));
    expect(result.correction, isNull);
    expect(result.correctionError, contains('Reconcile that account once'));
  });

  test('nothing is written when there is no correction to make', () async {
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

    expect(api.creates, isEmpty);
    expect(api.accountCreates, isEmpty);
  });

  test('a refused correction leaves the journals reconciled', () async {
    // Firefly will not put a reconciliation account against anything but an
    // asset account. The marking already happened, and failing the whole call
    // would hide it and invite the lot to be run again.
    final api = _RecordingApi()
      ..refuseCreateOfType = 'reconciliation'
      ..reconciliationAccounts = [
        _account(
          id: 'r1',
          name: 'Mortgage reconciliation (EUR)',
          type: 'reconciliation',
        ),
      ];
    final service = ReconciliationService(api);

    final result = await service.store(
      journalsToReconcile: [_tx(id: '1')],
      accountId: 'a1',
      accountName: 'Mortgage',
      currencyCode: 'EUR',
      currencySymbol: '\u20ac',
      endDate: DateTime(2026, 1, 31),
      gap: 12.5,
    );

    expect(result.reconciled, hasLength(1));
    expect(result.correction, isNull);
    expect(result.correctionError, contains('not an asset account'));
    expect(api.updates, hasLength(1));
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

    test(
      'writes the correction the statement leaves, after the payback',
      () async {
        // The payback is dated past the close and never part of the gap, so a
        // card whose ledger sat a fixed amount off the bank's balance for years
        // had no way through this path to be put right.
        final api = _RecordingApi()
          ..reconciliationAccounts = [
            _account(
              id: 'r1',
              name: 'Platinum reconciliation (EUR)',
              type: 'reconciliation',
            ),
          ];
        final service = ReconciliationService(api);

        final result = await service.storeCreditCardPayback(
          journalsToReconcile: [
            _tx(id: 'j1', amount: 40, source: 'Platinum', destination: 'Store'),
          ],
          creditCard: card,
          paymentAccount: payment,
          paybackDate: DateTime(2026, 7, 31),
          correction: (gap: -60, endDate: DateTime(2026, 7, 15)),
        );

        expect(api.creates.map((t) => t.type), ['transfer', 'reconciliation']);
        final correction = api.creates.last;
        expect(correction.date, DateTime(2026, 7, 15));
        expect(correction.amount, 60);
        // The ledger held less debt than the bank said, so the money leaves
        // the card and lands on the account Firefly keeps for it.
        expect(correction.sourceId, 'cc');
        expect(correction.sourceName, 'Platinum');
        expect(correction.destinationId, 'r1');
        expect(correction.destinationName, 'Platinum reconciliation (EUR)');
        expect(api.accountCreates, isEmpty);
        expect(result.payback?.type, 'transfer');
        expect(result.correction?.type, 'reconciliation');
        expect(result.correctionError, isNull);
      },
    );

    test('a refused correction keeps the payback and says why', () async {
      final api = _RecordingApi()
        ..refuseCreateOfType = 'reconciliation'
        ..reconciliationAccounts = [
          _account(
            id: 'r1',
            name: 'Platinum reconciliation (EUR)',
            type: 'reconciliation',
          ),
        ];
      final service = ReconciliationService(api);

      final result = await service.storeCreditCardPayback(
        journalsToReconcile: [
          _tx(id: 'j1', amount: 40, source: 'Platinum', destination: 'Store'),
        ],
        creditCard: card,
        paymentAccount: payment,
        paybackDate: DateTime(2026, 7, 31),
        correction: (gap: -60, endDate: DateTime(2026, 7, 15)),
      );

      expect(result.payback?.type, 'transfer');
      expect(result.correction, isNull);
      expect(result.correctionError, contains('not an asset account'));
      expect(result.reconciled, hasLength(1));
    });

    test('a gap within tolerance gets the payback and no correction', () async {
      final api = _RecordingApi();
      final service = ReconciliationService(api);

      final result = await service.storeCreditCardPayback(
        journalsToReconcile: [
          _tx(id: 'j1', amount: 40, source: 'Platinum', destination: 'Store'),
        ],
        creditCard: card,
        paymentAccount: payment,
        paybackDate: DateTime(2026, 7, 31),
        correction: (gap: 0.004, endDate: DateTime(2026, 7, 15)),
      );

      expect(api.creates.map((t) => t.type), ['transfer']);
      expect(api.accountCreates, isEmpty);
      expect(result.correction, isNull);
    });
  });
}
