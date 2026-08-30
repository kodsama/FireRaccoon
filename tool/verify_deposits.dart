// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// Verifies revenue/deposit transaction CRUD against live Firefly III.
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
  final description = 'FireRaccoon verify deposit $stamp';

  print('Connected as ${(await service.getCurrentUser()).email}');

  final accounts = await service.getAccounts();
  final currency = await service.getPrimaryCurrency();
  final revenue = accounts.firstWhere((a) => a.type == 'revenue');
  final asset = accounts.firstWhere(
    (a) => a.type == 'asset' && a.currencyCode == currency.code,
  );

  print('Creating deposit from ${revenue.name} to ${asset.name}…');
  final created = await service.createTransaction(
    Transaction(
      id: '',
      type: 'deposit',
      date: DateTime.now(),
      amount: 99.99,
      description: description,
      sourceName: revenue.name,
      sourceId: revenue.id,
      destinationName: asset.name,
      destinationId: asset.id,
      categoryName: 'Income',
      currencySymbol: currency.symbol,
      currencyCode: currency.code,
      notes: 'revenue verify',
      tags: ['verify'],
    ),
  );
  print('Created deposit journal id=${created.id}');

  print('Creating split deposit…');
  final split = await service.createTransaction(
    Transaction(
      id: '',
      type: 'deposit',
      date: DateTime.now(),
      amount: 50,
      description: '$description split',
      sourceName: revenue.name,
      sourceId: revenue.id,
      destinationName: asset.name,
      destinationId: asset.id,
      categoryName: 'Income',
      currencySymbol: currency.symbol,
      currencyCode: currency.code,
      groupTitle: '$description split',
      splits: [
        Transaction(
          id: '',
          type: 'deposit',
          date: DateTime.now(),
          amount: 50,
          description: '$description split',
          sourceName: revenue.name,
          sourceId: revenue.id,
          destinationName: asset.name,
          destinationId: asset.id,
          categoryName: 'Income',
          currencySymbol: currency.symbol,
          currencyCode: currency.code,
        ),
        Transaction(
          id: '',
          type: 'deposit',
          date: DateTime.now(),
          amount: 25,
          description: '$description split',
          sourceName: revenue.name,
          sourceId: revenue.id,
          destinationName: asset.name,
          destinationId: asset.id,
          categoryName: 'Income',
          currencySymbol: currency.symbol,
          currencyCode: currency.code,
        ),
      ],
    ),
  );
  print('Created split deposit id=${split.id}');

  await service.deleteTransaction(created.id);
  await service.deleteTransaction(split.id);

  print('OK — revenue/deposit CRUD verified against $url');
}
