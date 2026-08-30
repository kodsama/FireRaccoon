import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon/router/categories_tags_route.dart';
import 'package:fireraccoon/screens/categories_tags_screen.dart';
import '../helpers/dialog_test_helpers.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/ui_test_data.dart';

void main() {
  setUp(allowDialogLayoutOverflow);

  GoRoute categoriesTagsRoute() => GoRoute(
    path: CategoriesTagsRoute.path,
    builder: (context, state) => const CategoriesTagsScreen(),
  );

  testWidgets('CategoriesTagsScreen lists categories and opens create dialog', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const CategoriesTagsScreen(),
        initialLocation: CategoriesTagsRoute.location(),
        extraRoutes: [categoriesTagsRoute()],
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsWidgets);
    expect(find.text('Housing'), findsWidgets);

    await tester.tap(find.text('New Category'));
    await tester.pumpAndSettle();

    expect(find.text('New Category'), findsWidgets);
  });

  testWidgets('CategoriesTagsScreen switches to tags tab', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const CategoriesTagsScreen(),
        initialLocation: CategoriesTagsRoute.location(
          tab: CategoriesTagsTab.tags,
        ),
        extraRoutes: [categoriesTagsRoute()],
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#groceries'), findsWidgets);
    expect(find.text('New Tag'), findsOneWidget);

    await tester.tap(find.text('New Tag'));
    await tester.pumpAndSettle();

    expect(find.text('New Tag'), findsWidgets);
  });

  testWidgets('CategoriesTagsScreen opens entity linking from category card', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = buildDialogFireflyService();

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const CategoriesTagsScreen(),
        initialLocation: CategoriesTagsRoute.location(),
        extraRoutes: [categoriesTagsRoute()],
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Link / Auto-Assign...').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Link Category: "Food"'), findsOneWidget);
  });
}
