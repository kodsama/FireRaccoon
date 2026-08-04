import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/widgets/entity_linking_dialog.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/ui_test_data.dart';

void main() {
  setUp(allowDialogLayoutOverflow);

  testWidgets('showEntityLinkingDialog links payee transactions to category', (
    tester,
  ) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final matchingTransaction = Transaction(
      id: '99',
      type: 'withdrawal',
      date: DateTime(2026, 7, 10),
      amount: 45,
      description: 'Weekly shop',
      sourceName: 'Checking',
      destinationName: 'Store',
      categoryName: '',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    final fake = buildDialogFireflyService(transactions: [matchingTransaction]);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showEntityLinkingDialog(
                context: context,
                ref: ref,
                sourceType: EntityLinkingSourceType.payee,
                sourceName: 'Store',
              ),
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
    await settleIgnoringOverflow(tester);

    await tester.tap(find.text('Open Dialog'));
    await settleIgnoringOverflow(tester);

    expect(find.textContaining('Link Payee: "Store"'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settleIgnoringOverflow(tester);
    await tester.tap(find.text('Food').last);
    await settleIgnoringOverflow(tester);

    await tester.tap(find.text('Apply Link'));
    await settleIgnoringOverflow(tester);

    await confirmDialogWithChallenge(tester);

    expect(find.textContaining('Successfully linked'), findsOneWidget);
  });

  testWidgets('showEntityLinkingDialog can assign a tag target', (
    tester,
  ) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showEntityLinkingDialog(
                context: context,
                ref: ref,
                sourceType: EntityLinkingSourceType.category,
                sourceName: 'Food',
              ),
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
    await settleIgnoringOverflow(tester);

    await tester.tap(find.text('Open Dialog'));
    await settleIgnoringOverflow(tester);

    await tester.tap(find.text('Tag'));
    await settleIgnoringOverflow(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settleIgnoringOverflow(tester);
    await tester.tap(find.text('#groceries'));
    await settleIgnoringOverflow(tester);

    expect(find.textContaining('Tag: "groceries"'), findsOneWidget);
  });
}
