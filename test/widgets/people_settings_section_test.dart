import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/providers/people_providers.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/widgets/people_settings_section.dart';

import '../helpers/dialog_test_helpers.dart';
import '../helpers/fake_biometric_auth.dart';
import '../helpers/localized_test_app.dart';
import '../helpers/screen_test_app.dart';

List<Override> _peopleOverrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  peopleProvider.overrideWith(
    () => PeopleNotifier(
      storage: const FlutterSecureStorage(),
      biometricAuth: FakeBiometricAuth(),
    ),
  ),
];

Future<void> _waitHydrated(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    final element = find.byType(PeopleSettingsSection);
    if (element.evaluate().isEmpty) continue;
    try {
      final container = ProviderScope.containerOf(tester.element(element));
      if (container.read(peopleProvider).isHydrated) return;
    } catch (_) {}
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpDialog(WidgetTester tester, {Person? personToEdit}) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _peopleOverrides(prefs),
        child: buildLocalizedTestApp(
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () => showAddEditPersonDialog(
                  context,
                  ref,
                  personToEdit: personToEdit,
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ElevatedButton)),
      );
      if (container.read(peopleProvider).isHydrated) break;
    }

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Add Person dialog shows name field and color options', (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text('Add Person'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Color Badge'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit Person dialog shows delete action', (tester) async {
    await pumpDialog(
      tester,
      personToEdit: Person(
        id: 'person_1',
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        createdAtIso: '2026-01-01T00:00:00.000',
      ),
    );

    expect(find.text('Edit Person'), findsOneWidget);
    expect(find.text('Delete Person'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PeopleSettingsSection renders when hydrated', (tester) async {
    configureLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _peopleOverrides(prefs),
        child: buildLocalizedTestApp(child: const PeopleSettingsSection()),
      ),
    );
    await _waitHydrated(tester);
    await settleIgnoringOverflow(tester);

    expect(find.byType(PeopleSettingsSection), findsOneWidget);
    expect(find.text('People'), findsOneWidget);

    await tester.tap(find.text('People'));
    await settleIgnoringOverflow(tester);

    expect(find.text('Add Person'), findsOneWidget);
  });
}
