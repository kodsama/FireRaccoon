import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/view_mode_provider.dart';
import 'package:fireracoon/screens/accounts_screen.dart';
import 'package:fireracoon/utils/locale_formatting.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';
import '../helpers/test_data.dart';

void main() {
  testWidgets('AccountsScreen renders asset accounts', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(child: const AccountsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Checking'), findsWidgets);
    expect(find.text('Asset Accounts'), findsOneWidget);
  });

  testWidgets('AccountsScreen reconcile action jumps to the account view', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(child: const AccountsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reconcile account').first);
    await tester.pumpAndSettle();

    // Navigates to the account's transactions, pre-armed for reconciliation.
    final uri = GoRouterState.of(
      tester.element(find.byType(AccountsScreen)),
    ).uri;
    expect(uri.path, '/transactions');
    expect(uri.queryParameters['account'], 'Checking');
    expect(uri.queryParameters['reconcile'], '1');
  });

  testWidgets('account reconcile tile jumps to the reconcile view', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        // Start with Checking card expanded so the reconcile tile is visible.
        initialLocation: '/accounts?account=Checking',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Click to reconcile'), findsWidgets);
    await tester.tap(find.text('Click to reconcile').first);
    await tester.pumpAndSettle();

    final uri = GoRouterState.of(
      tester.element(find.byType(AccountsScreen)),
    ).uri;
    expect(uri.path, '/transactions');
    expect(uri.queryParameters['account'], 'Checking');
    expect(uri.queryParameters['reconcile'], '1');
  });

  testWidgets('AccountsScreen renders liability accounts', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final liability = Account(
      id: '2',
      name: 'Mortgage',
      type: 'liability',
      role: 'defaultAsset',
      currentBalance: -300,
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        fireflyService: FakeFireflyService(
          accounts: [...sampleAccounts, liability],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Liability Accounts'), findsOneWidget);
    expect(find.text('Mortgage'), findsWidgets);
  });

  testWidgets('AccountsScreen filters to liabilities only', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final liability = Account(
      id: '2',
      name: 'Mortgage',
      type: 'liability',
      role: 'defaultAsset',
      currentBalance: -300,
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        initialLocation: '/accounts?type=liability',
        fireflyService: FakeFireflyService(
          accounts: [...sampleAccounts, liability],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Asset Accounts'), findsNothing);
    expect(find.text('Mortgage'), findsWidgets);
  });

  testWidgets('AccountsScreen edits account name', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final fake = UpdatingAccountsFake(accounts: sampleAccounts);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        fireflyService: fake,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit').first);
    await tester.pumpAndSettle();

    final nameField = find
        .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
        .first;
    await tester.enterText(nameField, 'Savings');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(fake.updatedNames, contains('Savings'));
  });

  testWidgets('AccountsScreen renders compact view', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        viewMode: ViewMode.compact,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Checking'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('the tooltip carries the recorded balance and the caveat', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        viewMode: ViewMode.compact,
        fireflyService: FakeFireflyService(
          accounts: sampleAccounts,
          balancesByDate: const {
            '1': {'2027-03-15': 4321},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ref = ProviderScope.containerOf(
      tester.element(find.byType(AccountsScreen)),
    );
    ref.read(accountBalanceDateProvider.notifier).select(DateTime(2027, 3, 15));
    await tester.pumpAndSettle();

    // The tight rows have one narrow column and no room for a second number,
    // so both figures have to be reachable from the tooltip.
    final tooltip = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((t) => t.message)
        .whereType<String>()
        .firstWhere((message) => message.contains('Recorded'));
    expect(tooltip, contains('4,321'));
    // A date past the horizon gets the last projected figure, and says so.
    expect(tooltip, contains('does not reach this far ahead'));
  });

  testWidgets('an expanded account keeps its history out of its future', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    // Firefly returns newest first, and a ledger that materialises its
    // recurrences has its newest rows months ahead: one page of twenty came
    // back with eighteen future rows and no history on it at all.
    final now = DateTime.now();
    final past = DateTime(now.year, now.month, now.day - 2);
    final ahead = DateTime(now.year, now.month, now.day + 40);
    Transaction row(String id, DateTime date) => Transaction(
      id: id,
      type: 'withdrawal',
      date: date,
      amount: 100,
      description: 'Row $id',
      sourceName: 'Checking',
      destinationName: 'Shop',
      categoryName: 'Food',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

    final rows = [row('future', ahead), row('posted', past)];
    final service = FakeFireflyService(
      accounts: sampleAccounts,
      accountTransactionPages: {
        '1': {
          1: TransactionPageResult(
            transactions: rows,
            currentPage: 1,
            totalPages: 1,
            total: rows.length,
          ),
        },
      },
    );
    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        initialLocation: '/accounts?account=Checking',
        // Compact rows are full width. The card grid gives the expanded panel
        // about 270px, where a transaction row overflows by 28px on its own,
        // which predates this and is not what the test is about.
        viewMode: ViewMode.compact,
        fireflyService: service,
      ),
    );
    await tester.pumpAndSettle();

    // The posted row is listed; the future one sits behind its own heading.
    expect(find.text('Row posted'), findsWidgets);
    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Row future'), findsNothing);

    // Firefly answers a one-sided range with nothing at all, so both windows
    // have to name both ends. A fake that reads a missing bound as unbounded
    // cannot tell, which is how this shipped once already.
    expect(service.accountPageWindows, hasLength(2));
    for (final window in service.accountPageWindows) {
      expect(window.start, isNotNull);
      expect(window.end, isNotNull);
    }
  });

  testWidgets('AccountsScreen hides inactive accounts by default', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final inactive = Account(
      id: '3',
      name: 'Closed Savings',
      type: 'asset',
      role: 'savingAsset',
      currentBalance: 0,
      currencySymbol: '€',
      currencyCode: 'EUR',
      active: false,
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        fireflyService: FakeFireflyService(
          accounts: [...sampleAccounts, inactive],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Closed Savings'), findsNothing);
  });

  testWidgets('AccountsScreen shows inactive accounts when toggled', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final inactive = Account(
      id: '3',
      name: 'Closed Savings',
      type: 'asset',
      role: 'savingAsset',
      currentBalance: 0,
      currencySymbol: '€',
      currencyCode: 'EUR',
      active: false,
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        initialLocation: '/accounts?showInactive=true',
        fireflyService: FakeFireflyService(
          accounts: [...sampleAccounts, inactive],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Closed Savings'), findsWidgets);
    expect(find.text('Inactive'), findsWidgets);
  });

  testWidgets('the balance column opens on the end of the current month', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(child: const AccountsScreen()),
    );
    await tester.pumpAndSettle();

    // The only figure the column could show before the date became selectable,
    // so an existing view opens exactly as it did.
    final endOfMonth = endOfMonthFor(DateTime.now());
    final label = LocaleFormatting(
      const Locale('en'),
    ).formatMediumDate(endOfMonth);
    expect(find.text(label), findsWidgets);
  });

  testWidgets('picking a date moves the column to that date', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const AccountsScreen(),
        fireflyService: FakeFireflyService(
          accounts: sampleAccounts,
          balancesByDate: const {
            '1': {'2027-03-15': 4321},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ref = ProviderScope.containerOf(
      tester.element(find.byType(AccountsScreen)),
    );
    ref.read(accountBalanceDateProvider.notifier).select(DateTime(2027, 3, 15));
    await tester.pumpAndSettle();

    final label = LocaleFormatting(
      const Locale('en'),
    ).formatMediumDate(DateTime(2027, 3, 15));
    expect(find.text(label), findsWidgets);
    // And the recorded balance the ledger holds through that day comes with it.
    expect(find.textContaining('4,321'), findsWidgets);
  });

  testWidgets('the chip opens a picker and takes the date from it', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(child: const AccountsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show balances at another date'));
    await tester.pumpAndSettle();

    // Confirming without moving takes the date the chip was already showing.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final ref = ProviderScope.containerOf(
      tester.element(find.byType(AccountsScreen)),
    );
    expect(ref.read(accountBalanceDateProvider), endOfMonthFor(DateTime.now()));
  });

  testWidgets('cancelling the picker leaves the date alone', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(child: const AccountsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show balances at another date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final ref = ProviderScope.containerOf(
      tester.element(find.byType(AccountsScreen)),
    );
    expect(ref.read(accountBalanceDateProvider), isNull);
    // And no reset control, since there is nothing to reset.
    expect(find.byTooltip('Back to the end of this month'), findsNothing);
  });

  testWidgets('the reset control goes back to the end of the month', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      await buildScreenTestApp(child: const AccountsScreen()),
    );
    await tester.pumpAndSettle();

    final ref = ProviderScope.containerOf(
      tester.element(find.byType(AccountsScreen)),
    );
    ref.read(accountBalanceDateProvider.notifier).select(DateTime(2027, 3, 15));
    await tester.pumpAndSettle();

    // Only there once a date has been picked, so it never invites a reset of
    // the default.
    await tester.tap(find.byTooltip('Back to the end of this month'));
    await tester.pumpAndSettle();

    expect(ref.read(accountBalanceDateProvider), isNull);
    final label = LocaleFormatting(
      const Locale('en'),
    ).formatMediumDate(endOfMonthFor(DateTime.now()));
    expect(find.text(label), findsWidgets);
  });
}

class UpdatingAccountsFake extends FakeFireflyService {
  UpdatingAccountsFake({required super.accounts});

  final updatedNames = <String>[];

  @override
  Future<void> updateAccount(
    String accountId, {
    String? name,
    String? type,
    String? iban,
    String? bic,
    String? accountNumber,
    String? notes,
    bool? active,
    String? role,
    String? currencyCode,
    String? liabilityType,
    String? liabilityDirection,
    bool? includeNetWorth,
    double? openingBalance,
    DateTime? openingBalanceDate,
    double? virtualBalance,
    double? interest,
    String? interestPeriod,
  }) async {
    if (name != null) updatedNames.add(name);
  }
}
