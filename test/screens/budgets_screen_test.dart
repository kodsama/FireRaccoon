import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon/providers/view_mode_provider.dart';
import 'package:fireracoon/screens/budgets_screen.dart';
import '../helpers/dialog_test_helpers.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

void main() {
  setUp(allowDialogLayoutOverflow);

  testWidgets('BudgetsScreen renders budget list', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(child: const BudgetsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);
    expect(find.text('New Budget'), findsOneWidget);
  });

  testWidgets('BudgetsScreen shows expanded budget transactions', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = FakeFireflyService(
      budgets: sampleBudgets,
      budgetTransactions: {'1': sampleTransactions},
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const BudgetsScreen(),
        initialLocation: '/?budget=Food',
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsWidgets);
  });

  testWidgets('BudgetsScreen creates a budget from the dialog', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final fake = FakeFireflyService(budgets: sampleBudgets);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const BudgetsScreen(),
        fireflyService: fake,
      ),
    );
    await settleIgnoringOverflow(tester);
    await tester.tap(find.text('New Budget'));
    await settleIgnoringOverflow(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'Travel');
    await tester.enterText(fields.last, '300');
    await tester.pump();

    await tapDialogPrimaryAction(tester, label: 'Create');

    expect(find.text('Budget created.'), findsOneWidget);
  });

  testWidgets('BudgetsScreen deletes budget after confirmation', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = DeletingFakeFireflyService(budgets: sampleBudgets);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const BudgetsScreen(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete Budget'), findsOneWidget);
    await confirmDialogWithChallenge(tester);

    expect(fake.deletedBudgetIds, contains('1'));
  });

  testWidgets('BudgetsScreen expands budget on tap', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = FakeFireflyService(
      budgets: sampleBudgets,
      budgetTransactions: {'1': sampleTransactions},
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const BudgetsScreen(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Food').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Salary'), findsWidgets);
  });

  testWidgets('BudgetsScreen edits budget amount', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = UpdatingFakeFireflyService(budgets: sampleBudgets);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const BudgetsScreen(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.updatedBudgets.single.input.autoBudgetAmount, 500);
  });

  testWidgets('BudgetsScreen renders compact view', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const BudgetsScreen(),
        viewMode: ViewMode.compact,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('BudgetsScreen shows over-budget status', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final overBudget = [
      Budget(
        id: '2',
        name: 'Travel',
        active: true,
        spent: 500,
        autoBudgetAmount: 300,
        autoBudgetPeriod: AutoBudgetPeriod.monthly,
        currencySymbol: '€',
        currencyCode: 'EUR',
      ),
    ];
    final overBudgetTransactions = [
      Transaction(
        id: '10',
        type: 'withdrawal',
        date: sampleDayInCurrentMonth(8),
        amount: 500,
        description: 'Trip',
        sourceName: 'Checking',
        destinationName: 'Airline',
        categoryName: 'Travel',
        currencySymbol: '€',
        currencyCode: 'EUR',
        budgetId: '2',
      ),
    ];

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const BudgetsScreen(),
        fireflyService: FakeFireflyService(
          budgets: overBudget,
          budgetTransactions: {'2': overBudgetTransactions},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Over budget'), findsOneWidget);
  });
}

class DeletingFakeFireflyService extends FakeFireflyService {
  DeletingFakeFireflyService({required super.budgets});

  final deletedBudgetIds = <String>[];

  @override
  Future<void> deleteBudget(String budgetId) async {
    deletedBudgetIds.add(budgetId);
  }
}

class UpdatingFakeFireflyService extends FakeFireflyService {
  UpdatingFakeFireflyService({required super.budgets});

  final updatedBudgets = <({String id, BudgetInput input})>[];

  @override
  Future<void> updateBudget(String budgetId, BudgetInput input) async {
    updatedBudgets.add((id: budgetId, input: input));
  }
}
