// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// Verifies subscription (bill) CRUD against a live Firefly III instance.
///
/// Usage:
///   FIREFLY_URL=http://localhost:8081 FIREFLY_TOKEN=... \
///     dart run tool/verify_subscriptions.dart
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
  final name = 'FireRaccoon verify $stamp';

  print('Checking connection…');
  final user = await service.getCurrentUser();
  print('Connected as ${user.email}');

  print('Listing subscriptions…');
  final before = await service.getBills();
  print('Found ${before.length} subscription(s).');

  print('Creating "$name"…');
  final created = await service.createBill(
    BillInput(
      name: name,
      amountMin: 10,
      amountMax: 12,
      currencyCode: (await service.getPrimaryCurrency()).code,
      date: DateTime.now(),
      repeatFrequency: BillRepeatFrequency.monthly,
      skip: 0,
      active: true,
      notes: 'Created by tool/verify_subscriptions.dart',
      objectGroupTitle: 'Verification',
    ),
  );
  print('Created id=${created.id} repeat=${created.repeatFrequency.apiValue}');

  print('Updating skip=1…');
  final updated = await service.updateBill(
    created.id,
    BillInput(
      name: created.name,
      amountMin: created.amountMin,
      amountMax: created.amountMax,
      currencyCode: created.currencyCode,
      date: created.date,
      repeatFrequency: created.repeatFrequency,
      skip: 1,
      active: false,
      notes: created.notes,
      objectGroupTitle: created.objectGroupTitle,
    ),
  );
  print('Updated skip=${updated.skip} active=${updated.active}');

  print('Deleting…');
  await service.deleteBill(created.id);

  final after = await service.getBills();
  final stillThere = after.any((b) => b.id == created.id);
  if (stillThere) {
    print('ERROR: subscription still present after delete.');
    exitCode = 1;
    return;
  }

  print('OK — subscription CRUD verified against $url');
}
