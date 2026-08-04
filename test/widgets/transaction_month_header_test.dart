import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/widgets/selection_check_control.dart';
import 'package:fireracoon/widgets/transaction_month_header.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../helpers/screen_test_app.dart';

void main() {
  testWidgets('TransactionMonthHeader shows label and trailing sum', (
    tester,
  ) async {
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionMonthHeader(
          label: 'September 2026',
          trailingLabel: '€120.00',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('€120.00'), findsOneWidget);
  });

  testWidgets('TransactionMonthHeader toggles selection when enabled', (
    tester,
  ) async {
    var toggled = false;

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: TransactionMonthHeader(
          label: 'September 2026',
          dense: true,
          selectionState: SelectionState.partial,
          selectionEnabled: true,
          onSelectionToggle: () => toggled = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SelectionCheckControl), findsOneWidget);
    await tester.tap(find.byType(SelectionCheckControl));
    expect(toggled, isTrue);
  });

  testWidgets('TransactionMonthHeader dense mode uses InkWell', (tester) async {
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const TransactionMonthHeader(
          label: 'July 2026',
          dense: true,
          selectionState: SelectionState.all,
          selectionEnabled: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SelectionCheckControl), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets);
  });
}
