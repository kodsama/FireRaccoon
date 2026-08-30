import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/providers/view_mode_provider.dart';
import 'package:fireraccoon/widgets/transaction_entity_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fireraccoon/utils/display_labels.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

void main() {
  testWidgets('TightRowsHeaderRow displays column labels and settings button', (
    tester,
  ) async {
    final widget = await buildScreenTestApp(
      child: const Scaffold(body: TightRowsHeaderRow()),
      viewMode: ViewMode.tight,
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.slidersHorizontal), findsOneWidget);
  });

  testWidgets('TightRowsColumnSelectionDialog opens from header button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final widget = await buildScreenTestApp(
      child: const Scaffold(body: TightRowsHeaderRow()),
      viewMode: ViewMode.tight,
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Tap column chooser button
    await tester.tap(find.byIcon(LucideIcons.slidersHorizontal));
    await tester.pumpAndSettle();

    expect(find.byType(TightRowsColumnSelectionDialog), findsOneWidget);
  });

  testWidgets('TransactionEntityTightRow renders transaction title', (
    tester,
  ) async {
    final tx = sampleTransactions.first;

    final widget = await buildScreenTestApp(
      child: Scaffold(body: TransactionEntityTightRow(transaction: tx)),
      viewMode: ViewMode.tight,
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text(tx.displayTitle()), findsOneWidget);
  });

  testWidgets(
    'TransactionEntityTightRow renders running balance when provided',
    (tester) async {
      final tx = sampleTransactions.first;

      final widget = await buildScreenTestApp(
        child: Scaffold(
          body: TransactionEntityTightRow(
            transaction: tx,
            runningBalance: 12345.67,
          ),
        ),
        viewMode: ViewMode.tight,
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.textContaining('12,345.67'), findsOneWidget);
    },
  );

  group('computeRunningBalances', () {
    test('returns null when filterAccount is null', () {
      final balances = computeRunningBalances(
        filterAccount: null,
        transactions: sampleTransactions,
        accounts: sampleAccounts,
        prognosis: null,
      );
      expect(balances, isNull);
    });

    test('computes running balance for single account', () {
      final account = sampleAccounts.first;
      final balances = computeRunningBalances(
        filterAccount: account.name,
        transactions: sampleTransactions,
        accounts: sampleAccounts,
        prognosis: null,
      );
      expect(balances, isNotNull);
      expect(balances!.containsKey(sampleTransactions.first.id), isTrue);
    });
  });
}
