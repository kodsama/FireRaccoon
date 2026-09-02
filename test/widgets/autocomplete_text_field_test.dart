import 'package:fireraccoon/widgets/autocomplete_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required TextEditingController controller,
    List<String> suggestions = const ['Avanza Retirement', 'Rent', 'Spotify'],
    ValueChanged<String>? onSelected,
    ValueChanged<String>? onCreateNew,
    String? createLabel,
    bool tagMode = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AutocompleteTextField(
              controller: controller,
              suggestions: suggestions,
              onSelected: onSelected,
              onCreateNew: onCreateNew,
              createLabel: createLabel,
              tagMode: tagMode,
              decoration: const InputDecoration(hintText: 'Search...'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a matching suggestion fills the field when picked', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? selected;
    await pumpField(
      tester,
      controller: controller,
      onSelected: (value) => selected = value,
    );

    await tester.enterText(find.byType(TextField), 'Avan');
    await tester.pumpAndSettle();
    expect(find.text('Avanza Retirement'), findsOneWidget);

    await tester.tap(find.text('Avanza Retirement'));
    await tester.pumpAndSettle();

    expect(controller.text, 'Avanza Retirement');
    expect(selected, 'Avanza Retirement');
  });

  testWidgets('typing something new offers to create it', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? created;
    await pumpField(
      tester,
      controller: controller,
      onCreateNew: (value) => created = value,
      createLabel: 'Create payee',
    );

    await tester.enterText(find.byType(TextField), 'Klarna');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create payee "Klarna"'));
    await tester.pumpAndSettle();

    expect(created, 'Klarna');
    // Creating is the caller's job: the field is left as typed.
    expect(controller.text, 'Klarna');
  });

  testWidgets('an exact match is not offered for creation', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpField(
      tester,
      controller: controller,
      onCreateNew: (_) {},
      createLabel: 'Create payee',
    );

    await tester.enterText(find.byType(TextField), 'Rent');
    await tester.pumpAndSettle();

    // The typed text and the suggestion tile, and no offer to create it again.
    expect(find.text('Rent'), findsNWidgets(2));
    expect(find.textContaining('Create payee'), findsNothing);
  });

  testWidgets('tag mode appends to what is already typed', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpField(
      tester,
      controller: controller,
      suggestions: const ['groceries', 'rent'],
      tagMode: true,
    );

    await tester.enterText(find.byType(TextField), 'groceries, re');
    await tester.pumpAndSettle();

    await tester.tap(find.text('rent'));
    await tester.pumpAndSettle();

    // Trailing separator: the next tag can be typed straight away.
    expect(controller.text, 'groceries, rent, ');
  });
}
