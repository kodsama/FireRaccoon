import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fireracoon/screens/payees_screen.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/ui_test_data.dart';

void main() {
  testWidgets('PayeesScreen lists payees and opens create dialog', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService(accounts: dialogAccounts);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const PayeesScreen(),
        initialLocation: '/payees',
        extraRoutes: [
          GoRoute(
            path: '/payees',
            builder: (context, state) => const PayeesScreen(),
          ),
        ],
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Store'), findsWidgets);

    await tester.tap(find.text('New Payee'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('PayeesScreen opens entity linking from payee card', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService(accounts: dialogAccounts);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const PayeesScreen(),
        initialLocation: '/payees',
        extraRoutes: [
          GoRoute(
            path: '/payees',
            builder: (context, state) => const PayeesScreen(),
          ),
        ],
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Link / Auto-Assign...').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Link Payee: "Store"'), findsOneWidget);
  });
}
