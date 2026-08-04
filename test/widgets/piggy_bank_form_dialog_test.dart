import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/utils/create_flows.dart';
import 'package:fireracoon/widgets/piggy_bank_form_dialog.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/ui_test_data.dart';

void main() {
  setUp(allowDialogLayoutOverflow);

  testWidgets('showPiggyBankFormDialog creates a piggy bank', (tester) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => openCreatePiggyBankDialog(context, ref),
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

    expect(find.text('Create piggy bank'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Emergency Fund');
    await tester.enterText(fields.at(1), '3000.00');
    await tester.tap(find.text('Checking'));
    await tester.pump();

    await tapDialogPrimaryAction(tester, label: 'Create');

    expect(find.text('Create piggy bank'), findsNothing);
    expect(find.text('Piggy bank created.'), findsOneWidget);
  });

  testWidgets('showPiggyBankFormDialog edits a piggy bank', (tester) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService(piggyBanks: [samplePiggyBank]);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => showPiggyBankFormDialog(
                context: context,
                ref: ref,
                piggyBank: samplePiggyBank,
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

    expect(find.text('Edit piggy bank'), findsOneWidget);
    expect(find.text('Vacation Fund'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'Holiday Fund');
    await tapDialogPrimaryAction(tester, label: 'Save');

    expect(find.text('Edit piggy bank'), findsNothing);
  });
}
