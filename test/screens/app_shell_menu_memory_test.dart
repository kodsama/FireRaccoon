import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/screens/app_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opens containers over one set of stored preferences, so a second one reads
/// the menu the way the first one left it: a relaunch, without the app.
Future<ProviderContainer Function()> _launcher([
  Map<String, Object> stored = const {},
]) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  return () {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the menu is remembered', () {
    test('a collapsed group is still collapsed next time', () async {
      final launch = await _launcher();

      final first = launch();
      expect(first.read(expandedSidebarGroupsProvider), contains('budgets'));
      await first
          .read(expandedSidebarGroupsProvider.notifier)
          .toggleGroup('budgets');

      final next = launch();
      expect(
        next.read(expandedSidebarGroupsProvider),
        isNot(contains('budgets')),
      );
      // Only the one that was closed: the rest are where they were.
      expect(next.read(expandedSidebarGroupsProvider), contains('accounts'));
    });

    test('a group opened again is open next time', () async {
      final launch = await _launcher();

      final first = launch();
      final notifier = first.read(expandedSidebarGroupsProvider.notifier);
      await notifier.toggleGroup('stats');
      await notifier.toggleGroup('stats');

      expect(launch().read(expandedSidebarGroupsProvider), contains('stats'));
    });

    test('every group collapsed stays that way', () async {
      // A stored empty list is somebody who closed all of them, not somebody
      // who has never touched the menu, and the two would otherwise look
      // alike on the way back in.
      final launch = await _launcher({'expandedSidebarGroups': <String>[]});

      expect(launch().read(expandedSidebarGroupsProvider), isEmpty);
    });

    test('a menu nobody has touched opens its groups', () async {
      final launch = await _launcher();

      expect(
        launch().read(expandedSidebarGroupsProvider),
        containsAll(['accounts', 'budgets', 'stats', 'details']),
      );
    });

    test('the rail comes back the way it was left', () async {
      final launch = await _launcher();

      final first = launch();
      expect(first.read(sidebarExpandedProvider), isTrue);
      await first.read(sidebarExpandedProvider.notifier).toggle();

      expect(launch().read(sidebarExpandedProvider), isFalse);
    });
  });
}
