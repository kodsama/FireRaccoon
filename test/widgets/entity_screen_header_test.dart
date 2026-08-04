import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/widgets/entity_screen_header.dart';

import '../helpers/screen_test_app.dart';

void main() {
  testWidgets(
    'EntityScreenHeader keeps title readable with many trailing actions',
    (tester) async {
      await tester.pumpWidget(
        await buildScreenTestApp(
          child: SizedBox(
            width: 900,
            child: EntityScreenHeader(
              title: 'Transactions',
              subtitle: 'Showing 960 of 1957 transactions',
              createLabel: 'New transaction',
              onCreate: () {},
              trailing: List.generate(
                6,
                (index) => OutlinedButton(
                  onPressed: () {},
                  child: Text('Action $index'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final titleBox = tester.getSize(find.text('Transactions'));
      expect(titleBox.width, greaterThan(80));
      expect(find.text('Showing 960 of 1957 transactions'), findsOneWidget);
    },
  );

  testWidgets('EntityScreenHeader stays full width inside CustomScrollView', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(30),
              sliver: SliverToBoxAdapter(
                child: EntityScreenHeader(
                  title: 'Transactions',
                  subtitle: 'Showing 103 of 1957 transactions',
                  createLabel: 'New transaction',
                  onCreate: () {},
                  trailing: [
                    _toolbarChip('Balance: N/A'),
                    _toolbarChip('Filter Account'),
                    _toolbarChip('Group By'),
                    _toolbarChip('All transactions'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final titleBox = tester.getSize(find.text('Transactions'));
    expect(titleBox.width, greaterThan(120));
    expect(find.text('Showing 103 of 1957 transactions'), findsOneWidget);
  });
}

Widget _toolbarChip(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label),
  );
}
