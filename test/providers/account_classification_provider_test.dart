import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon_engine/models/account.dart';
import 'package:fireracoon/providers/account_classification_provider.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/theme_provider.dart';

import '../helpers/mock_firefly_service.dart';

Account _createAccount({
  required String id,
  required String name,
  required String type,
  required String role,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    role: role,
    currentBalance: 100.0,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getCategoryForAccount', () {
    test('unknown stored category names fall back to asset', () {
      expect(AccountCategory.fromName('unknown'), AccountCategory.asset);
    });

    test('defaults to asset for standard asset account', () {
      final acc = _createAccount(
        id: '1',
        name: 'Checking',
        type: 'asset',
        role: 'defaultAsset',
      );
      expect(getCategoryForAccount(acc, {}), AccountCategory.asset);
    });

    test('defaults to creditCard for ccAsset role', () {
      final acc = _createAccount(
        id: '2',
        name: 'Visa',
        type: 'asset',
        role: 'ccAsset',
      );
      expect(getCategoryForAccount(acc, {}), AccountCategory.creditCard);
    });

    test('defaults to liability for liability account', () {
      final acc = _createAccount(
        id: '3',
        name: 'Mortgage',
        type: 'liability',
        role: 'defaultAsset',
      );
      expect(getCategoryForAccount(acc, {}), AccountCategory.liability);
    });

    test('defaults to savings for savingAsset role or savings name', () {
      final accRole = _createAccount(
        id: '10',
        name: 'Emergency Fund',
        type: 'asset',
        role: 'savingAsset',
      );
      expect(getCategoryForAccount(accRole, {}), AccountCategory.savings);

      final accName = _createAccount(
        id: '11',
        name: 'High Yield Savings',
        type: 'asset',
        role: 'defaultAsset',
      );
      expect(getCategoryForAccount(accName, {}), AccountCategory.savings);
    });

    test('uses custom classification override when present', () {
      final acc = _createAccount(
        id: '4',
        name: 'My Custom Brokerage',
        type: 'asset',
        role: 'defaultAsset',
      );
      final customMap = {'4': AccountCategory.investment};
      expect(getCategoryForAccount(acc, customMap), AccountCategory.investment);
    });
  });

  group('AccountClassificationNotifier', () {
    test('loads local classifications and persists changes', () async {
      SharedPreferences.setMockInitialValues({
        kAccountClassificationPreferenceKey: jsonEncode({
          'account-1': 'investment',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(accountClassificationProvider)['account-1'],
        AccountCategory.investment,
      );
      await container
          .read(accountClassificationProvider.notifier)
          .setClassification('account-2', AccountCategory.savings);
      await container
          .read(accountClassificationProvider.notifier)
          .setClassification('account-1', null);

      expect(container.read(accountClassificationProvider), {
        'account-2': AccountCategory.savings,
      });
      expect(
        jsonDecode(prefs.getString(kAccountClassificationPreferenceKey)!),
        {'account-2': 'savings'},
      );
    });

    test(
      'syncs remote classifications and clearAll back to the service',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = FakeFireflyService();
        service.preferences[kAccountClassificationPreferenceKey] = {
          'account-1': 'creditCard',
        };
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            apiServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          accountClassificationProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(accountClassificationProvider)['account-1'],
          AccountCategory.creditCard,
        );

        await container.read(accountClassificationProvider.notifier).clearAll();
        expect(container.read(accountClassificationProvider), isEmpty);
        expect(
          service.preferences[kAccountClassificationPreferenceKey],
          isEmpty,
        );
      },
    );

    test('falls back to empty state for malformed local JSON', () async {
      SharedPreferences.setMockInitialValues({
        kAccountClassificationPreferenceKey: '{bad',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(accountClassificationProvider), isEmpty);
    });

    test('decodes remote classifications returned as JSON text', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = FakeFireflyService();
      service.preferences[kAccountClassificationPreferenceKey] = jsonEncode({
        'account-1': 'savings',
      });
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        accountClassificationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(accountClassificationProvider)['account-1'],
        AccountCategory.savings,
      );
    });
  });
}
