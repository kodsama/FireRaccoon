import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon/providers/undo_history_provider.dart';
import 'package:fireraccoon/router/history_route.dart';
import 'package:fireraccoon/screens/history_screen.dart';
import '../helpers/screen_test_app.dart';

void main() {
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
