import 'package:fireraccoon/providers/people_providers.dart';
import 'package:fireraccoon/widgets/person_selector_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/localized_test_app.dart';
import '../helpers/static_people_notifier.dart';

void main() {
  Future<ProviderContainer> pumpSelector(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peopleProvider.overrideWith(
            () => StaticPeopleNotifier([
              testPerson('p1', 'Ada'),
              testPerson('p2', 'Grace'),
            ]),
          ),
        ],
        child: buildLocalizedTestApp(child: const PersonSelectorWidget()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(PersonSelectorWidget)),
    );
  }

  testWidgets('picking a person filters to them', (tester) async {
    final container = await pumpSelector(tester);

    await tester.tap(find.byType(PersonSelectorWidget));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grace').last);
    await tester.pumpAndSettle();

    expect(container.read(activePersonFilterProvider), 'p2');
  });

  testWidgets('picking All People clears the filter', (tester) async {
    // PopupMenuButton reports a null result as a dismissal: it calls
    // onCanceled and never onSelected. The entry that clears the filter
    // carried a null value, so choosing it did nothing at all and the filter
    // stayed on whoever was selected.
    final container = await pumpSelector(tester);
    container.read(activePersonFilterProvider.notifier).setPersonFilter('p1');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PersonSelectorWidget));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All People').last);
    await tester.pumpAndSettle();

    expect(container.read(activePersonFilterProvider), isNull);
  });
}
