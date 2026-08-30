// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';

/// Verifies piggy bank CRUD against a live Firefly III instance.
///
/// Usage:
///   FIREFLY_URL=http://localhost:8081 FIREFLY_TOKEN=... \
///     dart run tool/verify_piggy_banks.dart
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
  final name = 'FireRaccoon verify piggy $stamp';

  print('Checking connection…');
  final user = await service.getCurrentUser();
  print('Connected as ${user.email}');

  final currency = await service.getPrimaryCurrency();
  final accounts = await service.getAccounts();
  final account = accounts.firstWhere(
    (a) => a.currencyCode == currency.code && a.type == 'asset',
    orElse: () => accounts.firstWhere((a) => a.type == 'asset'),
  );

  print('Listing piggy banks…');
  final before = await service.getPiggyBanks();
  print('Found ${before.length} piggy bank(s).');

  print('Creating "$name" on account ${account.name}…');
  final created = await service.createPiggyBank(
    PiggyBankInput(
      name: name,
      targetAmount: 250,
      currencyCode: currency.code,
      accountIds: [account.id],
      startDate: DateTime(2026, 1, 1),
      targetDate: DateTime(2026, 12, 31),
      notes: 'Created by tool/verify_piggy_banks.dart',
      objectGroupTitle: 'Verification',
    ),
  );
  print('Created id=${created.id} target=${created.targetAmount}');

  print('Updating target amount…');
  final updated = await service.updatePiggyBank(
    created.id,
    PiggyBankInput(
      name: created.name,
      targetAmount: 300,
      currencyCode: created.currencyCode,
      accountIds: created.accounts.map((a) => a.accountId).toList(),
      startDate: created.startDate,
      targetDate: created.targetDate,
      notes: 'Updated by verify script',
      objectGroupTitle: created.objectGroupTitle,
    ),
  );
  print('Updated target=${updated.targetAmount}');

  print('Deleting…');
  await service.deletePiggyBank(created.id);

  final after = await service.getPiggyBanks();
  if (after.any((p) => p.id == created.id)) {
    print('ERROR: piggy bank still present after delete.');
    exitCode = 1;
    return;
  }

  print('OK — piggy bank CRUD verified against $url');
}
