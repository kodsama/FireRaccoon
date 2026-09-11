import 'package:fireraccoon/widgets/tight_rows_table_shell.dart';
import 'package:fireraccoon/widgets/transaction_edit_panel.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screen_test_app.dart';

const _viewport = 900.0;
const _tableWidth = 1400.0;

Transaction _withdrawal() => Transaction(
  id: 'fit-1',
  type: 'withdrawal',
  date: DateTime(2026, 7, 1),
  amount: 1881,
  description: 'Hotel Bangkok (Thailand)',
  sourceName: 'Checking',
  destinationName: 'Trip.com',
  categoryName: 'Holiday > Housing',
  currencySymbol: 'kr',
  currencyCode: 'SEK',
);

Future<void> _pumpInShell(WidgetTester tester, {required bool fit}) async {
  final panel = TransactionEditPanel(
    transaction: _withdrawal(),
    onCancel: () {},
    onSave: (_) async {},
  );

  await tester.pumpWidget(
    await buildScreenTestApp(
      child: Material(
        child: SizedBox(
          width: _viewport,
          child: SingleChildScrollView(
            child: TightRowsTableShell(
              minContentWidth: _tableWidth,
              header: const SizedBox.shrink(),
              rows: [fit ? FitToTightRowsViewport(child: panel) : panel],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _rightEdge(WidgetTester tester, String label) => tester
    .getBottomRight(
      find
          .ancestor(of: find.text(label), matching: find.byType(InputDecorator))
          .first,
    )
    .dx;

void main() {
  testWidgets('a table wider than the window would push fields off it', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    // What the panel does when it takes the table's width: the right-hand
    // column of every row lands beyond the edge of the window, which reads as
    // a form that will not resize.
    await _pumpInShell(tester, fit: false);

    expect(_rightEdge(tester, 'Category'), greaterThan(_viewport));
  });

  testWidgets('held to the viewport, every field stays inside it', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpInShell(tester, fit: true);

    for (final label in [
      'Amount',
      'Date',
      'Category',
      'Payee',
      'Asset account',
      'Description',
      'Budget',
      'Tags',
    ]) {
      expect(
        _rightEdge(tester, label),
        lessThanOrEqualTo(_viewport),
        reason: '$label runs past the window',
      );
    }
    // Filling the window rather than shrinking to its own idea of a width.
    expect(_rightEdge(tester, 'Description'), greaterThan(_viewport * 0.9));
  });

  testWidgets('with no table around it the child is left alone', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const Material(
          child: SizedBox(
            width: 400,
            child: FitToTightRowsViewport(child: Text('bare')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('bare'), findsOneWidget);
  });
}
