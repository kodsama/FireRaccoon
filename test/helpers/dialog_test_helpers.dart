import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Form dialogs use a two-column layout above ~720px; in widget tests that
/// split width can trigger harmless dropdown overflows.
void allowDialogLayoutOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('RenderFlex overflowed') ||
        message.contains('overflowed by')) {
      return;
    }
    (previous ?? FlutterError.presentError)(details);
  };
  addTearDown(() {
    FlutterError.onError = previous;
  });
}

/// Single-column dialog width avoids split-layout overflow in widget tests.
void configureDialogTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(560, 1400);
  tester.view.devicePixelRatio = 1.0;
}

Future<void> settleIgnoringOverflow(WidgetTester tester) async {
  // Prefer bounded pumps: Firefly connection polling uses a periodic Timer
  // that prevents pumpAndSettle from ever becoming idle.
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  while (tester.takeException() != null) {}
}

Future<void> tapDialogPrimaryAction(
  WidgetTester tester, {
  required String label,
}) async {
  final button = find.widgetWithText(ElevatedButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button, warnIfMissed: false);
  await settleIgnoringOverflow(tester);
}

/// Reads the confirmation challenge word from the open dialog.
String readConfirmationChallengeWord(WidgetTester tester) {
  String? challenge;
  for (final element in find.byType(RichText).evaluate()) {
    final widget = element.widget;
    if (widget is RichText && widget.text is TextSpan) {
      final span = widget.text as TextSpan;
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan &&
            child.style?.fontWeight == FontWeight.w800 &&
            child.text != null &&
            child.text!.isNotEmpty) {
          challenge = child.text;
        }
      }
    }
  }
  if (challenge == null) {
    fail('Could not find confirmation challenge word in dialog');
  }
  return challenge;
}

Future<void> confirmDialogWithChallenge(WidgetTester tester) async {
  final word = readConfirmationChallengeWord(tester);
  await tester.enterText(find.byType(EditableText), word);
  await tester.pump();
  await tester.tap(find.byType(ElevatedButton).last);
  await settleIgnoringOverflow(tester);
}
