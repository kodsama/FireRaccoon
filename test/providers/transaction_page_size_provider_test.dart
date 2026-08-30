import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireraccoon/providers/transaction_page_size_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('TransactionPageSizeNotifier loads default from prefs', () async {
    SharedPreferences.setMockInitialValues({'transactionPageSize': 120});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(transactionPageSizeProvider), 120);
  });

  test(
    'TransactionPageSizeNotifier clamps oversized persisted value',
    () async {
      SharedPreferences.setMockInitialValues({'transactionPageSize': 10000});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(transactionPageSizeProvider), 500);
    },
  );

  test('setPageSize persists normalized value', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(transactionPageSizeProvider.notifier).setPageSize(77);
    expect(container.read(transactionPageSizeProvider), 80);
    expect(prefs.getInt('transactionPageSize'), 80);
  });

  test('setPageSize is a no-op when value unchanged', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(transactionPageSizeProvider.notifier).setPageSize(60);
    await container.read(transactionPageSizeProvider.notifier).setPageSize(60);
    expect(prefs.getInt('transactionPageSize'), 60);
  });

  test('setPageSizeFromSliderIndex updates page size', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(transactionPageSizeProvider.notifier)
        .setPageSizeFromSliderIndex(2);
    expect(container.read(transactionPageSizeProvider), 30);
  });
}
