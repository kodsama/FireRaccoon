import 'package:fireraccoon/utils/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a scaffold with a button that raises feedback, optionally from inside a
/// dialog so the layering can be asserted.
Future<void> _pumpHost(
  WidgetTester tester, {
  required void Function(BuildContext context) onPressed,
  bool insideDialog = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              if (!insideDialog) {
                onPressed(context);
                return;
              }
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('a modal'),
                  actions: [
                    TextButton(
                      onPressed: () => onPressed(ctx),
                      child: const Text('raise'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(dismissToast);

  testWidgets('an error stays put and closes only when dismissed', (
    tester,
  ) async {
    await _pumpHost(tester, onPressed: (c) => showErrorToast(c, 'it broke'));

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('it broke'), findsOneWidget);

    // Well past any SnackBar's default lifetime.
    await tester.pump(const Duration(seconds: 30));
    expect(
      find.text('it broke'),
      findsOneWidget,
      reason: 'an error the reader has not seen must not disappear',
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('it broke'), findsNothing);
  });

  testWidgets('a confirmation clears itself and has no close icon', (
    tester,
  ) async {
    await _pumpHost(tester, onPressed: (c) => showInfoToast(c, 'copied'));

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('copied'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('copied'), findsNothing);
  });

  testWidgets('feedback raised from a dialog renders above it', (tester) async {
    await _pumpHost(
      tester,
      insideDialog: true,
      onPressed: (c) => showErrorToast(c, 'above the scrim'),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('raise'));
    await tester.pump();

    // The dialog is still up, and the message is visible over it. A SnackBar
    // would have rendered inside the Scaffold, beneath the modal barrier.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('above the scrim'), findsOneWidget);

    final toast = tester.getTopLeft(find.text('above the scrim'));
    final dialog = tester.getTopLeft(find.byType(AlertDialog));
    expect(
      toast.dy,
      greaterThan(dialog.dy),
      reason: 'the toast sits at the bottom, over the dialog',
    );
  });

  testWidgets('a second message replaces the first', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => showErrorToast(context, 'first'),
                  child: const Text('one'),
                ),
                ElevatedButton(
                  onPressed: () => showErrorToast(context, 'second'),
                  child: const Text('two'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('one'));
    await tester.pump();
    await tester.tap(find.text('two'));
    await tester.pump();

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('an info message cannot outlive the error that replaced it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => showInfoToast(context, 'transient'),
                  child: const Text('info'),
                ),
                ElevatedButton(
                  onPressed: () => showErrorToast(context, 'persistent'),
                  child: const Text('error'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('info'));
    await tester.pump();
    await tester.tap(find.text('error'));
    await tester.pump();

    // The info timer must not tear down the error that took its place.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('persistent'), findsOneWidget);
  });

  testWidgets('dismissing twice is harmless', (tester) async {
    await _pumpHost(tester, onPressed: (c) => showErrorToast(c, 'boom'));
    await tester.tap(find.text('go'));
    await tester.pump();

    dismissToast();
    dismissToast();
    await tester.pump();

    expect(find.text('boom'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a message is selectable so it can be copied out', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      onPressed: (c) => showErrorToast(c, 'PlatformException(-34018)'),
    );
    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.byType(SelectableText), findsOneWidget);
  });
}
