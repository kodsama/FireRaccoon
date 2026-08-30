import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/l10n/app_localizations_en.dart';
import 'package:fireraccoon/l10n/fun_l10n.dart';

void main() {
  test('FunL10n uses raccoon labels when enabled', () {
    final l10n = AppLocalizationsEn();
    final fun = FunL10n(l10n, isRaccoon: true);

    expect(fun.navAccounts, 'Stashes');
    expect(fun.navTransactions, 'Heist Log');
    expect(fun.income, 'Snatched');
    expect(fun.spending, 'Burnt');
    expect(fun.transactionType('deposit'), 'Snatch');
    expect(fun.kpiIncome('Jul'), 'Snatched Funds');
  });

  test('FunL10n keeps normal labels when disabled', () {
    final l10n = AppLocalizationsEn();
    final fun = FunL10n(l10n, isRaccoon: false);

    expect(fun.navAccounts, 'Accounts');
    expect(fun.income, 'Income');
    expect(fun.transactionType('withdrawal'), 'Withdrawal');
  });
}
