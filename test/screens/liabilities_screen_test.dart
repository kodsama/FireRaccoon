import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/models/account.dart';
import 'package:fireracoon/screens/liabilities_screen.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/screen_test_app.dart';

void main() {
  testWidgets('LiabilitiesScreen hides inactive liabilities by default', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final inactive = Account(
      id: '2',
      name: 'Closed Loan',
      type: 'liability',
      role: 'defaultAsset',
      currentBalance: 0,
      currencySymbol: 'kr',
      currencyCode: 'SEK',
      active: false,
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const LiabilitiesScreen(),
        fireflyService: FakeFireflyService(accounts: [inactive]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Closed Loan'), findsNothing);
  });

  testWidgets('LiabilitiesScreen shows inactive liabilities when toggled', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final inactive = Account(
      id: '2',
      name: 'Closed Loan',
      type: 'liability',
      role: 'defaultAsset',
      currentBalance: 0,
      currencySymbol: 'kr',
      currencyCode: 'SEK',
      active: false,
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const LiabilitiesScreen(),
        initialLocation: '/liabilities?showInactive=true',
        fireflyService: FakeFireflyService(accounts: [inactive]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Closed Loan'), findsWidgets);
    expect(find.text('Inactive'), findsWidgets);
  });

  testWidgets('LiabilitiesScreen renders credit card accounts as liabilities', (
    tester,
  ) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final creditCard = Account(
      id: '3',
      name: 'Amex Credit Card',
      type: 'asset',
      role: 'ccAsset',
      currentBalance: -5000,
      currencySymbol: 'kr',
      currencyCode: 'SEK',
      active: true,
    );

    await tester.pumpWidget(
      await buildScreenTestApp(
        child: const LiabilitiesScreen(),
        fireflyService: FakeFireflyService(accounts: [creditCard]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amex Credit Card'), findsWidgets);
  });
}
