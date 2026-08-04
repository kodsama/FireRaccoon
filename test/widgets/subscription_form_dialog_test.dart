import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/utils/create_flows.dart';
import 'package:fireracoon/widgets/subscription_form_dialog.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';
import '../helpers/ui_test_data.dart';

void main() {
  setUp(allowDialogLayoutOverflow);

  testWidgets('showSubscriptionFormDialog creates a subscription', (
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
              onPressed: () => openCreateSubscriptionDialog(context, ref),
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

    expect(find.text('Create Subscription'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Streaming Service');
    await tester.enterText(fields.at(1), '14.99');
    await tester.enterText(fields.at(2), '14.99');
    await tester.pump();

    await tapDialogPrimaryAction(tester, label: 'Create');

    expect(find.text('Create Subscription'), findsNothing);
    expect(find.text('Subscription created.'), findsOneWidget);
  });

  testWidgets('showSubscriptionFormDialog edits a subscription', (
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
              onPressed: () => showSubscriptionFormDialog(
                context: context,
                ref: ref,
                bill: sampleBills.first,
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

    expect(find.text('Edit Subscription'), findsOneWidget);
    expect(find.text('Monthly Rent'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'Apartment Rent');
    await tapDialogPrimaryAction(tester, label: 'Save');

    expect(find.text('Edit Subscription'), findsNothing);
  });
}
