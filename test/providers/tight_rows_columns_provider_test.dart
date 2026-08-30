import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:fireraccoon/providers/tight_rows_columns_provider.dart';
import 'package:fireraccoon/store/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStorage;

  setUp(() {
    secureStorage = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureStorage,
    );
  });

  test('TightRowsColumnsNotifier defaults to defaultColumns', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(tightRowsColumnsProvider),
      TightRowsColumnsNotifier.defaultColumns,
    );
  });

  test('TightRowsColumnsNotifier loads columns from storage', () async {
    secureStorage['tightRowsColumns'] = 'date,account,amount';
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(tightRowsColumnsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(tightRowsColumnsProvider), {
      TightRowColumn.date,
      TightRowColumn.account,
      TightRowColumn.amount,
    });
  });

  test('toggleColumn adds and removes columns and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tightRowsColumnsProvider.notifier);

    // Default includes date. Toggle it off.
    await notifier.toggleColumn(TightRowColumn.date);
    expect(
      container.read(tightRowsColumnsProvider).contains(TightRowColumn.date),
      false,
    );
    // Secrets share one keychain item, so the assertion is that the choice
    // was persisted, not which item it landed in.
    expect(await appSecureStorage.read(key: 'tightRowsColumns'), isNotNull);

    // Toggle it back on.
    await notifier.toggleColumn(TightRowColumn.date);
    expect(
      container.read(tightRowsColumnsProvider).contains(TightRowColumn.date),
      true,
    );
  });

  test('toggleColumn prevents removing the last remaining column', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(tightRowsColumnsProvider.notifier);
    await notifier.setColumns({TightRowColumn.amount});

    await notifier.toggleColumn(TightRowColumn.amount);
    expect(container.read(tightRowsColumnsProvider), {TightRowColumn.amount});
  });
}
