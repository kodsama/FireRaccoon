import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fireracoon/utils/locale_formatting.dart';
import 'package:fireracoon/widgets/selectable_transaction_row.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

void main() {
  testWidgets('SelectableTransactionRow toggles selection on tap', (
    tester,
  ) async {
    var selected = false;

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            return SelectableTransactionRow(
              title: 'Groceries',
              subtitle: 'Jul 9 · Unreconciled',
              amountLabel: '-€42.00',
              amountColor: Colors.red,
              selectionState: selected
                  ? SelectionState.all
                  : SelectionState.none,
              selectionEnabled: true,
              onSelectionToggle: () => setState(() => selected = !selected),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Groceries'), findsOneWidget);
    await tester.tap(find.text('Groceries'));
    await tester.pump();
    expect(selected, isTrue);
  });

  testWidgets('ReconciliationTransactionRow disables future transactions', (
    tester,
  ) async {
    final format = LocaleFormatting(const Locale('en'));
    final futureTx = sampleTransactions.first.copyWith(
      date: DateTime.now().add(const Duration(days: 30)),
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: ReconciliationTransactionRow(
          transaction: futureTx,
          inRange: true,
          isFuture: true,
          signedAmount: -10,
          format: format,
          reconciledLabel: 'Reconciled',
          unreconciledLabel: 'Unreconciled',
          futureLabel: 'Future',
          onToggleReconciled: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Future'), findsOneWidget);
    await tester.tap(find.text(futureTx.description));
    await tester.pump();
    // No selection change expected — row is disabled.
  });

  testWidgets('ReconciliationTransactionRow shows reconciled state', (
    tester,
  ) async {
    final format = LocaleFormatting(const Locale('en'));
    final reconciledTx = sampleTransactions.first.copyWith(reconciled: true);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: ReconciliationTransactionRow(
          transaction: reconciledTx,
          inRange: true,
          isFuture: false,
          signedAmount: -10,
          format: format,
          reconciledLabel: 'Reconciled',
          unreconciledLabel: 'Unreconciled',
          futureLabel: 'Future',
          onToggleReconciled: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Reconciled'), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
  });
}
