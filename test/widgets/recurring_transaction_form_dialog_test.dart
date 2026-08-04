import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/utils/create_flows.dart';
import 'package:fireracoon/widgets/recurring_transaction_form_dialog.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/ui_test_data.dart';

Future<void> _openCreateDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open Dialog'));
  await settleIgnoringOverflow(tester);
}

Future<void> _fillMandatoryFields(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Monthly rent');
  await tester.enterText(fields.at(2), 'Rent payment');
  await tester.enterText(fields.at(3), '1200.00');
  await tester.pump();
}

void main() {
  setUp(allowDialogLayoutOverflow);

  testWidgets('showRecurringTransactionFormDialog creates a recurrence', (
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
              onPressed: () =>
                  openCreateRecurringTransactionDialog(context, ref),
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

    await _openCreateDialog(tester);
    expect(find.text('Create Recurring Transaction'), findsOneWidget);

    await _fillMandatoryFields(tester);
    await tapDialogPrimaryAction(tester, label: 'Create');

    expect(find.text('Create Recurring Transaction'), findsNothing);
    expect(find.text('Recurring transaction created.'), findsOneWidget);
  });

  testWidgets('showRecurringTransactionFormDialog edits a recurrence', (
    tester,
  ) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService(recurrences: [sampleRecurrence]);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showRecurringTransactionFormDialog(
                context: context,
                ref: ref,
                recurrence: sampleRecurrence,
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

    await _openCreateDialog(tester);
    expect(find.text('Edit Recurring Transaction'), findsOneWidget);
    expect(find.text('Weekly groceries'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'Biweekly groceries');
    await tapDialogPrimaryAction(tester, label: 'Save');

    expect(find.text('Edit Recurring Transaction'), findsNothing);
  });
}
