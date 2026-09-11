import 'package:fireraccoon/widgets/tag_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Future<TextEditingController> _pumpField(
  WidgetTester tester, {
  String initial = '',
  List<String> suggestions = const ['Holidays', 'Shared'],
}) async {
  final controller = TextEditingController(text: initial);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TagInputField(
              controller: controller,
              suggestions: suggestions,
              label: 'Tags',
              addHint: 'Add a tag',
            ),
            const TextField(key: Key('elsewhere')),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('every tag in the value gets a chip', (tester) async {
    await _pumpField(tester, initial: 'Holidays, Shared');

    expect(find.widgetWithText(InputChip, 'Holidays'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Shared'), findsOneWidget);
  });

  testWidgets('a typed tag joins the value on submit', (tester) async {
    final controller = await _pumpField(tester, initial: 'Holidays');

    await tester.enterText(find.byType(TextField).first, 'Ferry');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The comma-joined form the save path reads, which is what the chips are
    // a view of.
    expect(controller.text, 'Holidays, Ferry');
    expect(find.widgetWithText(InputChip, 'Ferry'), findsOneWidget);
  });

  testWidgets('a tag left in the box is kept when focus moves on', (
    tester,
  ) async {
    // Waiting for Enter alone threw away a tag that was typed and then left,
    // which is the one thing a chip field must not do.
    final controller = await _pumpField(tester);

    await tester.enterText(find.byType(TextField).first, 'Ferry');
    await tester.tap(find.byKey(const Key('elsewhere')));
    await tester.pumpAndSettle();

    expect(controller.text, 'Ferry');
  });

  testWidgets('the cross takes one off and leaves the rest', (tester) async {
    final controller = await _pumpField(tester, initial: 'Holidays, Shared');

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Holidays'),
        matching: find.byIcon(LucideIcons.x),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.text, 'Shared');
    expect(find.widgetWithText(InputChip, 'Holidays'), findsNothing);
  });

  testWidgets('tapping a chip takes it back into the box to retype', (
    tester,
  ) async {
    final controller = await _pumpField(tester, initial: 'Holidays, Shrd');

    await tester.tap(find.widgetWithText(InputChip, 'Shrd'));
    await tester.pumpAndSettle();

    expect(controller.text, 'Holidays');
    expect(find.text('Shrd'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Shared');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.text, 'Holidays, Shared');
  });

  testWidgets('a tag already carried is not added twice', (tester) async {
    final controller = await _pumpField(tester, initial: 'Holidays');

    await tester.enterText(find.byType(TextField).first, 'holidays');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.text, 'Holidays');
    expect(find.widgetWithText(InputChip, 'Holidays'), findsOneWidget);
  });
}
