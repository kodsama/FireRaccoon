import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/widgets/name_filter_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/localized_test_app.dart';

void main() {
  testWidgets('narrows by label and answers the sentinel for all', (
    tester,
  ) async {
    String? picked;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: buildLocalizedTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showNameFilterDialog(
                  context: context,
                  title: 'Filter tag',
                  allLabel: 'All tags',
                  emptyLabel: 'No tags found.',
                  names: const ['', 'Holiday', 'Work trip'],
                  currentFilter: 'Holiday',
                  icon: LucideIcons.tag,
                  labelOf: (name) => name.isEmpty ? '(none)' : name,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'trip');
    await tester.pumpAndSettle();
    expect(find.text('Holiday'), findsNothing);
    expect(find.text('All tags'), findsNothing);
    await tester.tap(find.text('Work trip'));
    await tester.pumpAndSettle();
    expect(picked, 'Work trip');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('(none)'));
    await tester.pumpAndSettle();
    expect(picked, '');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nothing like it');
    await tester.pumpAndSettle();
    expect(find.text('No tags found.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('All tags'));
    await tester.pumpAndSettle();
    expect(picked, allNamesSentinel);
  });

  testWidgets('picking several ticks names and answers them on Apply', (
    tester,
  ) async {
    Set<String>? picked;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: buildLocalizedTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showNamesFilterDialog(
                  context: context,
                  title: 'Tag',
                  emptyLabel: 'No tags found.',
                  names: const ['Holiday', 'Work'],
                  selected: const {'Retired tag'},
                  icon: LucideIcons.tag,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // A name in use is offered even when the list no longer holds it.
    expect(find.text('Retired tag'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Retired tag'));
    await tester.tap(find.text('Holiday'));
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(picked, {'Holiday', 'Work'});

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
  });
}
