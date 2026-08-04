import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/l10n/app_localizations_en.dart';
import 'package:fireracoon/l10n/l10n_extensions.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('localizedAccountRole maps Firefly roles to human labels', () {
    expect(localizedAccountRole(l10n, 'defaultAsset'), 'Checking account');
    expect(localizedAccountRole(l10n, 'sharedAsset'), 'Shared account');
    expect(localizedAccountRole(l10n, 'savingAsset'), 'Savings account');
    expect(localizedAccountRole(l10n, 'ccAsset'), 'Credit card');
  });

  test('localizedAccountRole falls back to the raw value when unknown', () {
    expect(localizedAccountRole(l10n, ''), '');
    expect(localizedAccountRole(l10n, 'somethingElse'), 'somethingElse');
  });
}
