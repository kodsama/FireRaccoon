import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/widgets/confirmation_dialog.dart';
import '../helpers/dialog_test_helpers.dart';
import '../helpers/localized_test_app.dart';

void main() {
  testWidgets('showConfirmationDialog cancels without challenge', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showConfirmationDialog(
                context: context,
                title: 'Delete Budget',
                message: 'Are you sure?',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Budget'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Budget'), findsNothing);
  });

  testWidgets('showConfirmationDialog confirms after typing challenge word', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showConfirmationDialog(
                context: context,
                title: 'Delete Budget',
                message: 'Are you sure?',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await confirmDialogWithChallenge(tester);

    expect(result, isTrue);
  });

  testWidgets('confirm button stays disabled until challenge matches', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showConfirmationDialog(
                context: context,
                title: 'Delete Item',
                message: 'Sure?',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton).last).onPressed,
      isNull,
    );

    final word = readConfirmationChallengeWord(tester);
    await tester.enterText(find.byType(EditableText), word);
    await tester.pump();

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton).last).onPressed,
      isNotNull,
    );
  });
}
