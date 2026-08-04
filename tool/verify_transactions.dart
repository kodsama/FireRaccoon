// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fireracoon_engine/fireracoon_engine.dart';

/// Verifies transaction create/update/delete against live Firefly III.
Future<void> main() async {
  final url = Platform.environment['FIREFLY_URL'] ?? 'http://localhost:8081';
  final token = Platform.environment['FIREFLY_TOKEN'];
  if (token == null || token.isEmpty) {
    print('Set FIREFLY_URL and FIREFLY_TOKEN (e.g. from .env).');
    exitCode = 1;
    return;
  }

  final service = FireflyApiService(serverUrl: url, apiToken: token);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final description = 'FireRacoon verify txn $stamp';

  print('Connected as ${(await service.getCurrentUser()).email}');

  final accounts = await service.getAccounts();
  final source = accounts.firstWhere((a) => a.type == 'asset');
  final destination = accounts.firstWhere((a) => a.type == 'expense');
  final currency = await service.getPrimaryCurrency();

  print('Creating withdrawal with optional fields…');
  final created = await service.createTransaction(
    Transaction(
      id: '',
      type: 'withdrawal',
      date: DateTime.now(),
      amount: 12.34,
      description: description,
      sourceName: source.name,
      sourceId: source.id,
      destinationName: destination.name,
      destinationId: destination.id,
      categoryName: 'Food',
      currencySymbol: currency.symbol,
      currencyCode: currency.code,
      foreignAmount: 15,
      foreignCurrencyCode: 'USD',
      notes: 'verify notes',
      tags: ['verify'],
    ),
  );
  print('Created journal id=${created.id}');

  print('Creating split transaction…');
  final split = await service.createTransaction(
    Transaction(
      id: '',
      type: 'withdrawal',
      date: DateTime.now(),
      amount: 5,
      description: '$description split',
      sourceName: source.name,
      sourceId: source.id,
      destinationName: destination.name,
      destinationId: destination.id,
      categoryName: '',
      currencySymbol: currency.symbol,
      currencyCode: currency.code,
      groupTitle: '$description split',
      splits: [
        Transaction(
          id: '',
          type: 'withdrawal',
          date: DateTime.now(),
          amount: 5,
          description: '$description split',
          sourceName: source.name,
          sourceId: source.id,
          destinationName: destination.name,
          destinationId: destination.id,
          categoryName: '',
          currencySymbol: currency.symbol,
          currencyCode: currency.code,
        ),
        Transaction(
          id: '',
          type: 'withdrawal',
          date: DateTime.now(),
          amount: 7.5,
          description: '$description split',
          sourceName: source.name,
          sourceId: source.id,
          destinationName: destination.name,
          destinationId: destination.id,
          categoryName: '',
          currencySymbol: currency.symbol,
          currencyCode: currency.code,
        ),
      ],
    ),
  );
  print('Created split journal id=${split.id} splits=${split.splits.length}');

  print('Updating single transaction…');
  await service.updateTransaction(
    created.copyWith(
      amount: 20,
      notes: 'updated by verify script',
    ),
  );

  print('Deleting test transactions…');
  await service.deleteTransaction(created.id);
  await service.deleteTransaction(split.id);

  print('OK — transaction CRUD verified against $url');
}
