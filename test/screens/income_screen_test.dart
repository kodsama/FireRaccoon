import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fireraccoon/screens/income_screen.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

class _HangingTransactionsService extends FakeFireflyService {
  _HangingTransactionsService()
    : super(
        accounts: sampleAccounts,
        transactions: sampleTransactions,
        primaryCurrency: sampleCurrency,
        currentUser: sampleUser,
      );

  final Completer<List<Transaction>> _transactions = Completer();

  @override
  Future<List<Transaction>> getTransactions({
    DateTime? start,
    DateTime? end,
    String? type,
    void Function(List<Transaction> firstPage)? onFirstPage,
  }) {
    return _transactions.future;
  }
}

void main() {
  testWidgets('IncomeScreen keeps period filter visible while analytics load', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const IncomeScreen(),
        initialLocation: '/income',
        fireflyService: _HangingTransactionsService(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('This Month'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('IncomeScreen keeps period filter visible when analytics fail', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final service = FakeFireflyService(
      accounts: sampleAccounts,
      transactions: sampleTransactions,
      primaryCurrency: sampleCurrency,
      currentUser: sampleUser,
    )..throwOn = Exception('firefly down');

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const IncomeScreen(),
        initialLocation: '/income',
        fireflyService: service,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This Month'), findsOneWidget);
  });

  testWidgets('IncomeScreen period selection updates the route', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const IncomeScreen(),
        initialLocation: '/income',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This Year'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(IncomeScreen));
    expect(GoRouterState.of(context).uri.toString(), '/income?period=year');
    expect(find.text('This Year'), findsWidgets);
  });
}
