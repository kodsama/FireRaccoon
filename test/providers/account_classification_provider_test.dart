import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireraccoon_engine/models/account.dart';
import 'package:fireraccoon_engine/services/firefly_service.dart';
import 'package:fireraccoon/providers/account_classification_provider.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/store/legacy_rename_migration.dart';

import '../helpers/mock_firefly_service.dart';

/// Stands in for a credential read that answers after the first build, which
/// is the ordering every first launch has.
class _LateService extends Notifier<FireflyService?> {
  @override
  FireflyService? build() => null;

  void connect(FireflyService service) => state = service;
}

final _lateServiceProvider = NotifierProvider<_LateService, FireflyService?>(
  _LateService.new,
);

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

    test('reads classifications once the connection appears', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = FakeFireflyService();
      service.preferences[kAccountClassificationPreferenceKey] = {
        'account-1': 'investment',
      };
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiServiceProvider.overrideWith(
            (ref) => ref.watch(_lateServiceProvider),
          ),
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

      expect(container.read(accountClassificationProvider), isEmpty);

      container.read(_lateServiceProvider.notifier).connect(service);
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (container.read(accountClassificationProvider).isNotEmpty) break;
      }

      expect(
        container.read(accountClassificationProvider)['account-1'],
        AccountCategory.investment,
      );
    });

    test('recovers classifications stored before the rename', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = FakeFireflyService();
      service.preferences[legacyPreferenceName(
        kAccountClassificationPreferenceKey,
      )] = {
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
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(accountClassificationProvider)['account-1'],
        AccountCategory.creditCard,
      );
      // Written back under the name in use, so the next launch reads it there.
      expect(service.preferences[kAccountClassificationPreferenceKey], {
        'account-1': 'creditCard',
      });
    });

    test('a refused read leaves the local cache alone', () async {
      SharedPreferences.setMockInitialValues({
        kAccountClassificationPreferenceKey: jsonEncode({
          'account-1': 'savings',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = FakeFireflyService()
        ..throwOn = Exception('token expired');
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
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(accountClassificationProvider)['account-1'],
        AccountCategory.savings,
      );
    });
  });
}
