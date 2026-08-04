import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('LiabilityInput.toCreateJson', () {
    test('includes mandatory liability fields', () {
      final json = LiabilityInput(
        name: 'Car Loan',
        currencyCode: 'EUR',
        liabilityType: LiabilityType.loan,
        liabilityDirection: LiabilityDirection.credit,
        amountOwed: 5000,
        startDate: DateTime(2024, 1, 15),
        interest: 3.5,
        interestPeriod: InterestPeriod.monthly,
      ).toCreateJson();

      expect(json['name'], 'Car Loan');
      expect(json['type'], 'liability');
      expect(json['currency_code'], 'EUR');
      expect(json['liability_type'], 'loan');
      expect(json['liability_direction'], 'credit');
      expect(json['opening_balance'], '5000.00');
      expect(json['opening_balance_date'], '2024-01-15');
      expect(json['interest'], '3.5');
      expect(json['interest_period'], 'monthly');
      expect(json['include_net_worth'], isTrue);
    });

    test('omits empty optional fields', () {
      final json = const LiabilityInput(
        name: 'Debt',
        currencyCode: 'USD',
        liabilityType: LiabilityType.debt,
        liabilityDirection: LiabilityDirection.debit,
        includeNetWorth: false,
      ).toCreateJson();

      expect(json, isNot(contains('opening_balance')));
      expect(json, isNot(contains('notes')));
      expect(json['include_net_worth'], isFalse);
    });

    test('includes optional banking fields when set', () {
      final json = const LiabilityInput(
        name: 'Mortgage',
        currencyCode: 'EUR',
        liabilityType: LiabilityType.mortgage,
        liabilityDirection: LiabilityDirection.credit,
        iban: 'GB82WEST12345698765432',
        bic: 'WESTGB22',
        accountNumber: '12345',
        notes: 'Primary residence',
      ).toCreateJson();

      expect(json['iban'], 'GB82WEST12345698765432');
      expect(json['bic'], 'WESTGB22');
      expect(json['account_number'], '12345');
      expect(json['notes'], 'Primary residence');
    });
  });
}
