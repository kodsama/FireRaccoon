import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/widgets/split_transaction_rows.dart';
import 'package:fireracoon/widgets/transaction_entity_card.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../helpers/screen_test_app.dart';

Transaction _transfer({
  required String source,
  required String destination,
  double amount = 6500,
  List<Transaction> splits = const [],
}) {
  return Transaction(
    id: 'xfer-1',
    type: 'transfer',
    date: DateTime(2026, 7, 20),
    amount: amount,
    description: 'Shared costs',
    sourceName: source,
    destinationName: destination,
    categoryName: 'Transfer',
    currencySymbol: 'kr',
    currencyCode: 'SEK',
    splits: splits,
  );
}

void main() {
  group('TransactionEntityCompactRow transfer signing', () {
    testWidgets('shows transfer as positive on destination account', (
      tester,
    ) async {
      final transfer = _transfer(
        source: 'Partner Current',
        destination: 'Joint Current',
      );

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: TransactionEntityCompactRow(
            transaction: transfer,
            filterAccount: 'Joint Current',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('+kr6,500.00'), findsOneWidget);
      expect(find.textContaining('-kr6,500.00'), findsNothing);
    });

    testWidgets('shows transfer as negative on source account', (tester) async {
      final transfer = _transfer(
        source: 'Partner Current',
        destination: 'Joint Current',
      );

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: TransactionEntityCompactRow(
            transaction: transfer,
            filterAccount: 'Partner Current',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('-kr6,500.00'), findsOneWidget);
    });

    testWidgets('shows transfer as negative when no account filter', (
      tester,
    ) async {
      final transfer = _transfer(source: 'Checking', destination: 'Savings');

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: TransactionEntityCompactRow(transaction: transfer),
        ),
      );
      await tester.pump();

      expect(find.textContaining('-kr6,500.00'), findsOneWidget);
    });

    testWidgets('negative amount reverses signs for source and destination', (
      tester,
    ) async {
      final transfer = _transfer(
        source: 'Personal',
        destination: 'Common',
        amount: -6500,
      );

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: TransactionEntityCompactRow(
            transaction: transfer,
            filterAccount: 'Common',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('-kr6,500.00'), findsOneWidget);

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: TransactionEntityCompactRow(
            transaction: transfer,
            filterAccount: 'Personal',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('+kr6,500.00'), findsOneWidget);
    });
  });

  group('TransactionEntityCard transfer signing', () {
    testWidgets('shows transfer as positive on destination account', (
      tester,
    ) async {
      final transfer = _transfer(source: 'Personal', destination: 'Common');

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: TransactionEntityCard(
            transaction: transfer,
            filterAccount: 'Common',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('+kr6,500.00'), findsOneWidget);
      expect(find.textContaining('-kr6,500.00'), findsNothing);
    });

    testWidgets('shows transfer as negative on source account', (tester) async {
      final transfer = _transfer(source: 'Personal', destination: 'Common');

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: TransactionEntityCard(
            transaction: transfer,
            filterAccount: 'Personal',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('-kr6,500.00'), findsOneWidget);
    });
  });

  group('SplitTransactionChildList transfer signing', () {
    testWidgets('signs each split relative to the filtered account', (
      tester,
    ) async {
      final transfer = _transfer(
        source: 'Personal',
        destination: 'Common',
        amount: 100,
        splits: [
          _transfer(
            source: 'Personal',
            destination: 'Common',
            amount: 40,
          ).copyWith(id: 's1', description: 'Part A'),
          _transfer(
            source: 'Personal',
            destination: 'Common',
            amount: 60,
          ).copyWith(id: 's2', description: 'Part B'),
        ],
      );

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: SplitTransactionChildList(
            transaction: transfer,
            filterAccount: 'Common',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('+kr40.00'), findsOneWidget);
      expect(find.textContaining('+kr60.00'), findsOneWidget);
      expect(find.textContaining('-kr'), findsNothing);

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: SplitTransactionChildList(
            transaction: transfer,
            filterAccount: 'Personal',
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('-kr40.00'), findsOneWidget);
      expect(find.textContaining('-kr60.00'), findsOneWidget);
    });
  });
}
