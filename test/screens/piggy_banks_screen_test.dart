import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon/screens/piggy_banks_screen.dart';
import '../helpers/dialog_test_helpers.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/ui_test_data.dart';

void main() {
  setUp(allowDialogLayoutOverflow);

  testWidgets('PiggyBanksScreen lists piggy banks and opens create dialog', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService(piggyBanks: [samplePiggyBank]);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const PiggyBanksScreen(),
        initialLocation: '/piggy-banks',
        extraRoutes: [
          GoRoute(
            path: '/piggy-banks',
            builder: (context, state) => const PiggyBanksScreen(),
          ),
        ],
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vacation Fund'), findsWidgets);

    await tester.tap(find.text('New piggy bank'));
    await settleIgnoringOverflow(tester);

    expect(find.text('Create piggy bank'), findsOneWidget);
  });

  testWidgets('PiggyBanksScreen opens edit dialog from card actions', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService(piggyBanks: [samplePiggyBank]);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const PiggyBanksScreen(),
        initialLocation: '/piggy-banks',
        extraRoutes: [
          GoRoute(
            path: '/piggy-banks',
            builder: (context, state) => const PiggyBanksScreen(),
          ),
        ],
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit'));
    await settleIgnoringOverflow(tester);

    expect(find.text('Edit piggy bank'), findsOneWidget);
  });
}
