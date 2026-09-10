import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon/widgets/firefly_refresh_button.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

void main() {
  testWidgets('a tap re-reads Firefly', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = _CountingAccountsFake(
      accounts: List<Account>.from(sampleAccounts),
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const FireflyRefreshButton(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    // An edit made in Firefly itself is the only thing this button is for: the
    // providers hold their data for the session and nothing else invalidates
    // them, so a view could otherwise only be brought up to date by relaunching.
    final readsAfterWarm = fake.accountReads;

    await tester.tap(find.byType(FireflyRefreshButton));
    await tester.pumpAndSettle();

    expect(fake.accountReads, greaterThan(readsAfterWarm));
  });

  testWidgets('it spins while the read is in flight and takes one tap', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = _CountingAccountsFake(
      accounts: List<Account>.from(sampleAccounts),
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const FireflyRefreshButton(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    // Held open from here so the in-flight state can be looked at. A timer
    // would do too, but this test owns exactly when the read lands.
    final hold = Completer<void>();
    fake.hold = hold;

    await tester.tap(find.byType(FireflyRefreshButton));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(FireflyRefreshButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    // A second tap during the read would start a second one, and the caller
    // gets no signal that the first is still running.
    final duringFlight = fake.accountReads;
    await tester.tap(find.byType(FireflyRefreshButton));
    await tester.pump();
    expect(fake.accountReads, duringFlight);

    fake.hold = null;
    hold.complete();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(FireflyRefreshButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('it is shaped like the header controls it sits between', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const FireflyRefreshButton(),
        fireflyService: _CountingAccountsFake(
          accounts: List<Account>.from(sampleAccounts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Undo and redo are bare IconButtons. A bordered pill with a label read as
    // a page control, which is what this used to be.
    expect(
      find.descendant(
        of: find.byType(FireflyRefreshButton),
        matching: find.byType(IconButton),
      ),
      findsOneWidget,
    );
    expect(find.text('Refresh'), findsNothing);
    expect(find.byTooltip('Re-fetch data from Firefly III'), findsOneWidget);
  });
}

class _CountingAccountsFake extends FakeFireflyService {
  _CountingAccountsFake({required super.accounts})
    : super(
        transactions: sampleTransactions,
        budgets: sampleBudgets,
        primaryCurrency: sampleCurrency,
        currentUser: sampleUser,
      );

  int accountReads = 0;

  /// Blocks the next reads, so a test can look at the button mid-flight.
  Completer<void>? hold;

  @override
  Future<List<Account>> getAccounts({
    List<String> types = const ['asset', 'liability'],
  }) async {
    accountReads++;
    await hold?.future;
    return super.getAccounts(types: types);
  }
}
