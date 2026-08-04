import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fireracoon/models/account.dart';
import 'package:fireracoon/providers/view_mode_provider.dart';
import 'package:fireracoon/screens/accounts_screen.dart';
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
