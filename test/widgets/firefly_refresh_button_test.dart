import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:fireraccoon/screens/accounts_screen.dart';
import 'package:fireraccoon/screens/dashboard_screen.dart';
import 'package:fireraccoon/widgets/firefly_refresh_button.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

void main() {
  testWidgets('the accounts view re-reads Firefly from its own button', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final live = List<Account>.from(sampleAccounts);
    final fake = _CountingAccountsFake(accounts: live);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        initialLocation: '/accounts',
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checking'), findsWidgets);
    final readsAfterWarm = fake.accountReads;

    // An edit made in Firefly itself is the only thing this button is for:
    // the providers hold their data for the session and nothing else invalidates
    // them, so until now the accounts view could only be brought up to date by
    // relaunching or by walking over to the transactions screen.
    live
      ..clear()
      ..add(sampleAccounts.first.copyWith(name: 'Renamed in Firefly'));

    await tester.tap(find.byType(FireflyRefreshButton));
    await tester.pumpAndSettle();

    expect(fake.accountReads, greaterThan(readsAfterWarm));
    expect(find.text('Renamed in Firefly'), findsWidgets);
  });

  testWidgets('the dashboard re-reads Firefly from its own button', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final live = List<Account>.from(sampleAccounts);
    final fake = _CountingAccountsFake(accounts: live);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const DashboardScreen(),
        // The account tiles are the one thing on the dashboard that shows an
        // edit made in Firefly by name.
        initialLocation: '/?tab=accounts',
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checking'), findsWidgets);
    final readsAfterWarm = fake.accountReads;

    live
      ..clear()
      ..add(sampleAccounts.first.copyWith(name: 'Renamed in Firefly'));

    await tester.tap(find.byType(FireflyRefreshButton));
    await tester.pumpAndSettle();

    expect(fake.accountReads, greaterThan(readsAfterWarm));
    expect(find.text('Renamed in Firefly'), findsWidgets);
  });

  testWidgets('the button spins while the read is in flight', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = _CountingAccountsFake(
      accounts: List<Account>.from(sampleAccounts),
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        initialLocation: '/accounts',
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

    // A second tap during the read would start a second one, and the caller
    // gets no signal that the first is still running.
    expect(
      find.descendant(
        of: find.byType(FireflyRefreshButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
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
