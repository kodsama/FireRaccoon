import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:fireraccoon/providers/view_mode_provider.dart';
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

  test('ViewModeNotifier defaults to standard', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(viewModeProvider), ViewMode.standard);
  });

  test('ViewModeNotifier loads compact from storage', () async {
    secureStorage['globalViewMode'] = 'compact';
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(viewModeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(viewModeProvider), ViewMode.compact);
  });

  test('ViewModeNotifier loads tight from storage', () async {
    secureStorage['globalViewMode'] = 'tight';
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(viewModeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(viewModeProvider), ViewMode.tight);
  });

  test(
    'toggle switches mode sequentially (standard -> compact -> tight -> standard) and persists',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(viewModeProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      container.read(viewModeProvider.notifier).toggle();
      expect(container.read(viewModeProvider), ViewMode.compact);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await appSecureStorage.read(key: 'globalViewMode'), 'compact');

      container.read(viewModeProvider.notifier).toggle();
      expect(container.read(viewModeProvider), ViewMode.tight);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await appSecureStorage.read(key: 'globalViewMode'), 'tight');

      container.read(viewModeProvider.notifier).toggle();
      expect(container.read(viewModeProvider), ViewMode.standard);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await appSecureStorage.read(key: 'globalViewMode'), 'standard');
    },
  );

  test('setMode updates state and persists explicitly', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(viewModeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await container.read(viewModeProvider.notifier).setMode(ViewMode.tight);
    expect(container.read(viewModeProvider), ViewMode.tight);
    expect(await appSecureStorage.read(key: 'globalViewMode'), 'tight');
  });
}
