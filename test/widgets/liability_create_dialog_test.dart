import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/utils/create_flows.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/ui_test_data.dart';

void main() {
  setUp(allowDialogLayoutOverflow);

  testWidgets('showLiabilityCreateDialog creates a liability', (tester) async {
    configureDialogTestSurface(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Consumer(
          builder: (context, ref, _) {
            return ElevatedButton(
              onPressed: () => openCreateAccountDialog(
                context,
                ref,
                accountType: 'liability',
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

    expect(find.text('New Liability'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Car Loan');
    await tester.enterText(find.byType(TextField).at(1), '15000');
    await tester.pump();

    await tapDialogPrimaryAction(tester, label: 'Create');

    expect(find.text('New Liability'), findsNothing);
    expect(find.text('Liability created.'), findsOneWidget);
  });
}
