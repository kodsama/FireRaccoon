import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/screens/expenses_screen.dart';
import '../helpers/screen_test_app.dart';

void main() {
  testWidgets('ExpensesScreen renders spending analysis', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const ExpensesScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('Food'), findsWidgets);
  });

  testWidgets('ExpensesScreen filters by category from route', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const ExpensesScreen(),
        initialLocation: '/expenses?category=Food',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clear filters'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);
  });

  testWidgets('ExpensesScreen clears filters', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const ExpensesScreen(),
        initialLocation: '/expenses?category=Food',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Clear filters'), findsNothing);
    expect(find.text('Food'), findsWidgets);
  });

  testWidgets('ExpensesScreen opens period filter menu', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const ExpensesScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();

    expect(find.text('This Year'), findsOneWidget);
    await tester.tap(find.text('This Year'));
    await tester.pumpAndSettle();

    expect(find.text('This Year'), findsWidgets);
  });

  testWidgets('ExpensesScreen category checkbox toggles plot visibility', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const ExpensesScreen()),
    );
    await tester.pumpAndSettle();

    final foodRow = find.ancestor(
      of: find.text('Food'),
      matching: find.byType(Row),
    );
    final foodCheckbox = find.descendant(
      of: foodRow,
      matching: find.byType(Checkbox),
    );
    expect(foodCheckbox, findsOneWidget);

    await tester.tap(foodCheckbox);
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(foodCheckbox);
    expect(checkbox.value, isFalse);
  });
}
