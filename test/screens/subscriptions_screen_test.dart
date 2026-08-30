import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon/screens/subscriptions_screen.dart';
import '../helpers/dialog_test_helpers.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';
import '../helpers/ui_test_data.dart';

void main() {
  setUp(allowDialogLayoutOverflow);

  final billTransaction = Transaction(
    id: '77',
    type: 'withdrawal',
    date: DateTime(2026, 7, 1),
    amount: 1200,
    description: 'July rent payment',
    sourceName: 'Checking',
    destinationName: 'Landlord',
    categoryName: 'Housing',
    currencySymbol: '€',
    currencyCode: 'EUR',
    billId: '1',
    billName: 'Monthly Rent',
  );

  testWidgets(
    'SubscriptionsScreen expands a subscription to show its transactions',
    (tester) async {
      configureLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      final fake = FakeFireflyService(
        bills: sampleBills,
        transactions: [billTransaction],
      );

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: const SubscriptionsScreen(),
          fireflyService: fake,
        ),
      );
      await tester.pumpAndSettle();

      // Linked transactions are hidden until the card is expanded.
      expect(find.text('July rent payment'), findsNothing);

      await tester.tap(find.text('Monthly Rent').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('July rent payment'), findsWidgets);
    },
  );

  testWidgets('expanded subscription transaction row offers duplicate action', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = FakeFireflyService(
      bills: sampleBills,
      transactions: [billTransaction],
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SubscriptionsScreen(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Monthly Rent').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The standard row exposes the same actions as the transactions
    // screen, including duplicate.
    expect(find.byTooltip('Duplicate'), findsWidgets);
  });

  testWidgets('SubscriptionsScreen opens create subscription dialog', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SubscriptionsScreen(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Subscription'));
    await settleIgnoringOverflow(tester);

    expect(find.text('Create Subscription'), findsOneWidget);
  });

  testWidgets('SubscriptionsScreen opens recurring transaction dialog', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService(recurrences: [sampleRecurrence]);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SubscriptionsScreen(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly groceries'), findsWidgets);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Recurring'));
    await settleIgnoringOverflow(tester);

    expect(find.text('Create Recurring Transaction'), findsOneWidget);
  });

  testWidgets('SubscriptionsScreen opens edit subscription dialog', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const SubscriptionsScreen(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Subscription'), findsOneWidget);
  });
}
