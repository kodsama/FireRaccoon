import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/widgets/piggy_bank_form_dialog.dart';
import 'package:fireraccoon/widgets/recurring_transaction_form_dialog.dart';
import 'package:fireraccoon/widgets/subscription_form_dialog.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';

final _eur = const FireflyCurrency(
  id: '1',
  code: 'EUR',
  name: 'Euro',
  symbol: '€',
);

final _checking = Account(
  id: '1',
  name: 'Checking',
  type: 'asset',
  role: 'defaultAsset',
  currentBalance: 1000,
  currencySymbol: '€',
  currencyCode: 'EUR',
);

FakeFireflyService _fake() => FakeFireflyService(
  accounts: [_checking],
  currencies: [_eur],
  budgets: const [],
  categories: const [],
  tags: const [],
  bills: const [],
  recurrences: const [],
  piggyBanks: const [],
);

Future<void> _openDialog(
  WidgetTester tester, {
  required Future<void> Function(BuildContext, WidgetRef) open,
  FakeFireflyService? fireflyService,
}) async {
  await tester.pumpWidget(
    await buildScreenTestApp(
      child: Consumer(
        builder: (context, ref, _) {
          return ElevatedButton(
            onPressed: () => open(context, ref),
            child: const Text('Open'),
          );
        },
      ),
      fireflyService: fireflyService ?? _fake(),
      authSettings: AuthSettings(
        serverUrl: 'https://firefly.test',
        apiToken: 'token',
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recurring transaction form dialog renders create UI', (
    tester,
  ) async {
    await _openDialog(
      tester,
      open: (context, ref) async {
        await showRecurringTransactionFormDialog(context: context, ref: ref);
      },
    );

    expect(find.byType(Dialog), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('piggy bank form dialog renders create UI', (tester) async {
    await _openDialog(
      tester,
      open: (context, ref) async {
        await showPiggyBankFormDialog(context: context, ref: ref);
      },
    );

    expect(find.byType(TextField), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('subscription form dialog renders create UI', (tester) async {
    await _openDialog(
      tester,
      open: (context, ref) async {
        await showSubscriptionFormDialog(context: context, ref: ref);
      },
    );

    expect(find.byType(TextField), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
