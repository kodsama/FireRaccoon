import 'package:fireracoon/widgets/tight_rows_table_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TightRowsTableShell scrolls header and rows together', (
    tester,
  ) async {
    final headerKey = GlobalKey();
    final rowKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 400,
            child: TightRowsTableShell(
              minContentWidth: 500,
              header: SizedBox(
                key: headerKey,
                height: 40,
                child: const Text('Header'),
              ),
              rows: [
                SizedBox(key: rowKey, height: 40, child: const Text('Row')),
              ],
            ),
          ),
        ),
      ),
    );

    final scrollable = find.byType(Scrollable);
    expect(scrollable, findsOneWidget);

    await tester.drag(scrollable, const Offset(-120, 0));
    await tester.pumpAndSettle();

    final headerLeft = tester.getTopLeft(find.byKey(headerKey)).dx;
    final rowLeft = tester.getTopLeft(find.byKey(rowKey)).dx;
    expect(headerLeft, closeTo(rowLeft, 0.5));
    expect(headerLeft, lessThan(0));
  });

  testWidgets('TightRowsTableShell does not scroll when content fits', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            height: 400,
            child: TightRowsTableShell(
              minContentWidth: 300,
              header: SizedBox(height: 40, child: Text('Header')),
              rows: [SizedBox(height: 40, child: Text('Row'))],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Scrollable), findsNothing);
  });
}
