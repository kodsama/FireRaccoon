import 'package:fireraccoon/providers/view_mode_provider.dart';
import 'package:fireraccoon/screens/prognosis_screen.dart';
import 'package:fireraccoon/widgets/autocomplete_text_field.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';

Account _account({
  required String id,
  required String name,
  bool active = true,
}) => Account(
  id: id,
  name: name,
  type: 'asset',
  role: 'defaultAsset',
  currentBalance: 1000,
  currencySymbol: '€',
  currencyCode: 'EUR',
  active: active,
);

Transaction _tx(String accountName) => Transaction(
  id: 't-$accountName',
  type: 'withdrawal',
  date: DateTime.now().subtract(const Duration(days: 5)),
  amount: 25,
  description: 'Groceries',
  sourceName: accountName,
  destinationName: 'Store',
  categoryName: 'Food',
  currencySymbol: '€',
  currencyCode: 'EUR',
);

void main() {
  testWidgets(
    'PrognosisScreen offers open accounts and leaves out closed ones',
    (tester) async {
      configureLargeScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);

      // A closed account has nothing ahead of it, so a forecast of it is a
      // forecast of nothing.
      final accounts = [
        _account(id: '1', name: 'Everyday'),
        _account(id: '2', name: 'Old Savings', active: false),
      ];
      final transactions = [_tx('Everyday'), _tx('Old Savings')];

      await tester.pumpWidget(
        await buildScreenTestApp(
          child: const PrognosisScreen(),
          fireflyService: FakeFireflyService(
            accounts: accounts,
            transactions: transactions,
            transactionPages: {
              1: TransactionPageResult(
                transactions: transactions,
                currentPage: 1,
                totalPages: 1,
                total: transactions.length,
              ),
            },
          ),
          viewMode: ViewMode.compact,
        ),
      );
      await pumpScreen(tester);

      final field = find.byType(AutocompleteTextField);
      expect(field, findsOneWidget);

      final suggestions = tester
          .widget<AutocompleteTextField>(field)
          .suggestions;
      expect(suggestions, contains('Everyday'));
      expect(suggestions, isNot(contains('Old Savings')));
    },
  );

  testWidgets('PrognosisScreen picks the account by name, not by position', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    // A dropdown is unusable once a ledger has dozens of accounts, which is why
    // every other picker in the app filters as you type.
    final accounts = [
      _account(id: '1', name: 'Everyday'),
      _account(id: '2', name: 'Holiday fund'),
    ];
    final transactions = [_tx('Everyday'), _tx('Holiday fund')];

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const PrognosisScreen(),
        fireflyService: FakeFireflyService(
          accounts: accounts,
          transactions: transactions,
          transactionPages: {
            1: TransactionPageResult(
              transactions: transactions,
              currentPage: 1,
              totalPages: 1,
              total: transactions.length,
            ),
          },
        ),
        viewMode: ViewMode.compact,
      ),
    );
    await pumpScreen(tester);

    final picker = tester.widget<AutocompleteTextField>(
      find.byType(AutocompleteTextField),
    );
    expect(picker.suggestions, containsAll(['Everyday', 'Holiday fund']));

    // Choosing by name selects that account rather than whatever sat there.
    picker.onSelected!('Holiday fund');
    await pumpScreen(tester);

    expect(
      tester
          .widget<AutocompleteTextField>(find.byType(AutocompleteTextField))
          .controller
          .text,
      'Holiday fund',
    );
  });
}
