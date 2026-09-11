import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon/providers/undo_history_provider.dart';
import 'package:fireraccoon/router/history_route.dart';
import 'package:fireraccoon/screens/history_screen.dart';

import 'package:fireraccoon/providers/view_mode_provider.dart';

import '../helpers/screen_test_app.dart';

void main() {
  testWidgets('tight rows reach the history too', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const HistoryScreen(),
        initialLocation: HistoryRoute.location(),
        viewMode: ViewMode.tight,
        extraRoutes: [
          GoRoute(
            path: HistoryRoute.path,
            builder: (context, state) => const HistoryScreen(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HistoryScreen)),
    );
    container
        .read(undoHistoryProvider.notifier)
        .record(
          title: 'Subscription created',
          details: 'Created subscription "Rent"',
          type: UndoActionType.billCreate,
          undoPayload: const {'billId': '1'},
          redoPayload: const {'name': 'Rent'},
        );
    await tester.pumpAndSettle();

    // The mode is chosen once in the header, so a list that ignored it was
    // the odd one out rather than a list with nothing to say.
    final row = find.ancestor(
      of: find.text('Created subscription "Rent"'),
      matching: find.byType(Row),
    );
    expect(row, findsWidgets);
    expect(
      tester.getTopLeft(find.text('Created subscription "Rent"')).dy,
      closeTo(tester.getTopLeft(find.text('Subscription created')).dy, 1),
    );
  });

  testWidgets('an entry opens on what it changed, and can be taken back', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const HistoryScreen(),
        initialLocation: HistoryRoute.location(),
        extraRoutes: [
          GoRoute(
            path: HistoryRoute.path,
            builder: (context, state) => const HistoryScreen(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HistoryScreen)),
    );
    final notifier = container.read(undoHistoryProvider.notifier);
    notifier.record(
      title: 'Theme changed',
      details: 'Switched to light',
      type: UndoActionType.themeMode,
      undoPayload: const {'mode': 'dark'},
      redoPayload: const {'mode': 'light'},
    );
    notifier.record(
      title: 'Theme changed',
      details: 'Switched the accent',
      type: UndoActionType.themeAccent,
      undoPayload: const {'accent': 'blue'},
      redoPayload: const {'accent': 'lime'},
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Switched to light'));
    await tester.pumpAndSettle();

    // Both sides of the change are stored, so the difference between them is
    // exact rather than reconstructed.
    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('Mode'), findsOneWidget);
    expect(find.text('dark  →  light'), findsOneWidget);

    await tester.tap(find.text('Revert this change'));
    await tester.pumpAndSettle();

    // The one after it is left alone: reaching an old change through undo
    // would have taken that one with it.
    final history = container.read(undoHistoryProvider);
    expect(
      history.entries.map((entry) => entry.details),
      containsAllInOrder([
        'Switched to light',
        'Switched the accent',
        'Reverted: Switched to light',
      ]),
    );
    // Undoing the revert does it again, so the taking-back is itself a change.
    expect(history.entries.last.undoPayload, const {'mode': 'light'});
    expect(history.entries.last.redoPayload, const {'mode': 'dark'});
  });

  testWidgets('HistoryScreen shows undo entries and supports undo', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const HistoryScreen(),
        initialLocation: HistoryRoute.location(),
        extraRoutes: [
          GoRoute(
            path: HistoryRoute.path,
            builder: (context, state) => const HistoryScreen(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HistoryScreen)),
    );
    container
        .read(undoHistoryProvider.notifier)
        .record(
          title: 'Subscription created',
          details: 'Created subscription "Rent"',
          type: UndoActionType.billCreate,
          undoPayload: const {'billId': '1'},
          redoPayload: const {'name': 'Rent'},
        );
    await tester.pumpAndSettle();

    expect(find.text('Subscription created'), findsWidgets);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
  });

  testWidgets('HistoryScreen filters entries by search query', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const HistoryScreen(),
        initialLocation: HistoryRoute.location(),
        extraRoutes: [
          GoRoute(
            path: HistoryRoute.path,
            builder: (context, state) => const HistoryScreen(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HistoryScreen)),
    );
    container
        .read(undoHistoryProvider.notifier)
        .record(
          title: 'Piggy bank created',
          details: 'Created piggy bank "Holiday"',
          type: UndoActionType.piggyBankCreate,
          undoPayload: const {'piggyBankId': '1'},
          redoPayload: const {'name': 'Holiday'},
        );
    container
        .read(undoHistoryProvider.notifier)
        .record(
          title: 'Subscription created',
          details: 'Created subscription "Rent"',
          type: UndoActionType.billCreate,
          undoPayload: const {'billId': '2'},
          redoPayload: const {'name': 'Rent'},
        );
    await tester.pumpAndSettle();

    expect(find.text('Piggy bank created'), findsWidgets);
    expect(find.text('Subscription created'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'piggy');
    await tester.pumpAndSettle();

    expect(find.text('Piggy bank created'), findsWidgets);
    expect(find.text('Subscription created'), findsNothing);
  });
}
