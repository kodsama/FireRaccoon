import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/widgets/payee_form_dialog.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';

final samplePayee = Account(
  id: 'payee_1',
  name: 'Supermarket',
  type: 'expense',
  role: 'defaultAsset',
  currentBalance: 0,
  currencySymbol: '€',
  currencyCode: 'EUR',
);

class _ErrorFireflyService extends FakeFireflyService {
  _ErrorFireflyService()
    : super(
        currencies: [
          const FireflyCurrency(
            id: '1',
            code: 'EUR',
            name: 'Euro',
            symbol: '€',
          ),
        ],
      );

  @override
  Future<Account> createAccount({
    required String name,
    required String type,
    required String currencyCode,
    String? role,
    String? liabilityType,
    String? liabilityDirection,
    double? openingBalance,
    DateTime? openingBalanceDate,
  }) async {
    throw Exception(
      '422 Unprocessable Entity: The name has already been taken.',
    );
  }
}

void main() {
  testWidgets('showPayeeFormDialog detects duplicate payee name locally', (
    tester,
  ) async {
    final fake = FakeFireflyService(
      accounts: [samplePayee],
      currencies: [
        const FireflyCurrency(id: '1', code: 'EUR', name: 'Euro', symbol: '€'),
      ],
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showPayeeFormDialog(context: context, ref: ref),
              child: const Text('Open Dialog'),
            );
          },
        ),
        fireflyService: fake,
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('New Payee'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'supermarket');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(
      find.text('A payee named "supermarket" already exists.'),
      findsWidgets,
    );
  });

  testWidgets('showPayeeFormDialog catches 422 duplicate error from server', (
    tester,
  ) async {
    final fake = _ErrorFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showPayeeFormDialog(context: context, ref: ref),
              child: const Text('Open Dialog'),
            );
          },
        ),
        fireflyService: fake,
        authSettings: AuthSettings(
          serverUrl: 'https://firefly.test',
          apiToken: 'token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'BrandNewStore');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(
      find.text('A payee named "BrandNewStore" already exists.'),
      findsWidgets,
    );
  });
}
