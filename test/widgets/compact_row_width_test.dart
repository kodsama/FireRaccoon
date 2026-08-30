import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/models/transaction.dart';
import 'package:fireraccoon/widgets/transaction_entity_card.dart';

import '../helpers/screen_test_app.dart';

void main() {
  testWidgets('a compact row fits the width an expanded card gives it', (
    tester,
  ) async {
    // The card grid leaves the expanded panel about 270 logical pixels, and the
    // row's fixed children alone came to more than that.
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: Center(
            child: SizedBox(
              width: 270,
              child: TransactionEntityCompactRow(
                transaction: Transaction(
                  id: '1',
                  type: 'withdrawal',
                  date: DateTime(2026, 8, 20),
                  amount: 1234.56,
                  description: 'A payee with a fairly ordinary name',
                  sourceName: 'Checking',
                  destinationName: 'Shop',
                  categoryName: 'Food',
                  currencySymbol: 'kr',
                  currencyCode: 'SEK',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('at full width it keeps the amount and the actions inline', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: Material(
          child: Center(
            child: SizedBox(
              width: 800,
              child: TransactionEntityCompactRow(
                transaction: Transaction(
                  id: '1',
                  type: 'withdrawal',
                  date: DateTime(2026, 8, 20),
                  amount: 1234.56,
                  description: 'A payee',
                  sourceName: 'Checking',
                  destinationName: 'Shop',
                  categoryName: 'Food',
                  currencySymbol: 'kr',
                  currencyCode: 'SEK',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // One amount, not two, and the edit cluster is present.
    expect(find.textContaining('1,234.56'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
  });
}
