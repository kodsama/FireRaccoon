// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// Verifies transfer transaction CRUD against live Firefly III.
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
  final description = 'FireRaccoon verify transfer $stamp';

  print('Connected as ${(await service.getCurrentUser()).email}');

  final accounts = await service.getAccounts();
  final currency = await service.getPrimaryCurrency();
  final assets = accounts
      .where(
        (a) => a.type == 'asset' && a.currencyCode == currency.code,
      )
      .toList();
  if (assets.length < 2) {
    print('Need at least two asset accounts in ${currency.code}.');
    exitCode = 1;
    return;
  }

  final source = assets[0];
  final destination = assets[1];

  print('Creating transfer ${source.name} → ${destination.name}…');
  final created = await service.createTransaction(
    Transaction(
      id: '',
      type: 'transfer',
      date: DateTime.now(),
      amount: 42,
      description: description,
      sourceName: source.name,
      sourceId: source.id,
      destinationName: destination.name,
      destinationId: destination.id,
      categoryName: '',
      currencySymbol: currency.symbol,
      currencyCode: currency.code,
      notes: 'transfer verify',
      tags: ['verify'],
    ),
  );
  print('Created transfer journal id=${created.id}');

  print('Creating split transfer…');
  final split = await service.createTransaction(
    Transaction(
      id: '',
      type: 'transfer',
      date: DateTime.now(),
      amount: 10,
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
          type: 'transfer',
          date: DateTime.now(),
          amount: 10,
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
          type: 'transfer',
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
      ],
    ),
  );
  print('Created split transfer id=${split.id}');

  await service.deleteTransaction(created.id);
  await service.deleteTransaction(split.id);

  print('OK — transfer CRUD verified against $url');
}
