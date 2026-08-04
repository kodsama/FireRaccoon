import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon/fun_modes/fun_mode.dart';
import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/providers/locale_provider.dart';
import 'package:fireracoon/providers/people_providers.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/services/biometric_auth.dart';

import '../helpers/fake_biometric_auth.dart';

const String _kStrongPassword = 'Correct-Horse9!';
const int _kColor = 0xFF3B82F6;

class _ThrowingStoragePlatform extends TestFlutterSecureStoragePlatform {
  _ThrowingStoragePlatform() : super({});

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => throw Exception('storage unavailable');

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => throw Exception('storage unavailable');

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => throw Exception('storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStorage;
  late FakeBiometricAuth biometricAuth;

  setUp(() async {
    secureStorage = {};
    biometricAuth = FakeBiometricAuth();
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureStorage,
    );
    SharedPreferences.setMockInitialValues({});
  });

  Future<Person> addAdmin(
    ProviderContainer container, {
    String name = 'alex',
    String? password = _kStrongPassword,
  }) {
    return container
        .read(peopleProvider.notifier)
        .addPerson(name: name, colorValue: _kColor, password: password);
  }

  Future<void> waitHydrated(ProviderContainer container) async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (container.read(peopleProvider).isHydrated) return;
    }
    fail('people provider never hydrated');
  }

  Future<ProviderContainer> buildContainer({BiometricAuth? biometrics}) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        peopleProvider.overrideWith(
          () => PeopleNotifier(
            storage: const FlutterSecureStorage(),
            biometricAuth: biometrics ?? biometricAuth,
          ),
        ),
      ],
    );
  }

  group('bootstrap and first admin', () {
    test('starts empty with no people', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      final state = container.read(peopleProvider);
      expect(state.isEnabled, isFalse);
      expect(state.requiresLoginGate, isFalse);
      expect(container.read(canWriteFinancialDataProvider), isTrue);
    });

    test('addPerson makes the first person admin and signs them in', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      final admin = await addAdmin(container);

      final state = container.read(peopleProvider);
      expect(state.isEnabled, isTrue);
      expect(state.people.single.role, PersonRole.admin);
      expect(state.currentPerson?.id, admin.id);
      expect(state.requiresLoginGate, isFalse);
      expect(container.read(currentPersonProvider)?.name, 'alex');
    });

    test('addPerson rejects a weak password', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      expect(
        () => container
            .read(peopleProvider.notifier)
            .addPerson(name: 'alex', colorValue: _kColor, password: 'weak'),
        throwsArgumentError,
      );
      expect(container.read(peopleProvider).isEnabled, isFalse);
    });

    test('second person is a regular user, not admin', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      await addAdmin(container);
      final other = await container
          .read(peopleProvider.notifier)
          .addPerson(
            name: 'sam',
            colorValue: 0xFF10B981,
            password: _kStrongPassword,
          );

      expect(other.role, PersonRole.user);
      expect(container.read(peopleProvider).people, hasLength(2));
    });

    test('keeps in-memory people when secure storage is unavailable', () async {
      FlutterSecureStoragePlatform.instance = _ThrowingStoragePlatform();
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      await addAdmin(container);
      await container.read(peopleProvider.notifier).logout();

      expect(container.read(peopleProvider).people.single.name, 'alex');
      expect(container.read(peopleProvider).currentPerson, isNull);
    });
  });

  group('login', () {
    Future<ProviderContainer> containerWithAdmin() async {
      final container = await buildContainer();
      await waitHydrated(container);
      await addAdmin(container);
      await container.read(peopleProvider.notifier).logout();
      return container;
    }

    test('requires login once signed out and people exist', () async {
      final container = await containerWithAdmin();
      addTearDown(container.dispose);

      expect(container.read(peopleProvider).requiresLoginGate, isTrue);
    });

    test('succeeds with the correct name and password', () async {
      final container = await containerWithAdmin();
      addTearDown(container.dispose);

      final person = await container
          .read(peopleProvider.notifier)
          .login('alex', _kStrongPassword);

      expect(person, isNotNull);
      expect(container.read(peopleProvider).currentPerson?.name, 'alex');
      expect(container.read(peopleProvider).requiresLoginGate, isFalse);
    });

    test('is case-insensitive on name', () async {
      final container = await containerWithAdmin();
      addTearDown(container.dispose);

      final person = await container
          .read(peopleProvider.notifier)
          .login('ALEX', _kStrongPassword);

      expect(person, isNotNull);
    });

    test('rejects an incorrect password', () async {
      final container = await containerWithAdmin();
      addTearDown(container.dispose);

      final person = await container
          .read(peopleProvider.notifier)
          .login('alex', 'wrong-password');

      expect(person, isNull);
      expect(container.read(peopleProvider).currentPerson, isNull);
    });

    test('rejects an unknown name', () async {
      final container = await containerWithAdmin();
      addTearDown(container.dispose);

      final person = await container
          .read(peopleProvider.notifier)
          .login('nobody', _kStrongPassword);

      expect(person, isNull);
    });

    test('logout clears the current session', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);
      await addAdmin(container);

      await container.read(peopleProvider.notifier).logout();

      expect(container.read(peopleProvider).currentPerson, isNull);
      expect(container.read(peopleProvider).requiresLoginGate, isTrue);
    });
  });

  group('person management and roles', () {
    Future<ProviderContainer> containerWithAdminSignedIn() async {
      final container = await buildContainer();
      await waitHydrated(container);
      await addAdmin(container);
      return container;
    }

    test('admin can add another person with a distinct role', () async {
      final container = await containerWithAdminSignedIn();
      addTearDown(container.dispose);

      final viewer = await container
          .read(peopleProvider.notifier)
          .addPerson(
            name: 'sam',
            colorValue: 0xFF10B981,
            password: _kStrongPassword,
            role: PersonRole.viewer,
          );

      expect(container.read(peopleProvider).people, hasLength(2));
      expect(viewer.role, PersonRole.viewer);
    });

    test('addPerson rejects a duplicate name', () async {
      final container = await containerWithAdminSignedIn();
      addTearDown(container.dispose);

      expect(
        () => container
            .read(peopleProvider.notifier)
            .addPerson(
              name: 'Alex',
              colorValue: 0xFF10B981,
              password: _kStrongPassword,
            ),
        throwsArgumentError,
      );
    });

    test('viewer cannot manage people; admin can', () async {
      final container = await containerWithAdminSignedIn();
      addTearDown(container.dispose);
      await container
          .read(peopleProvider.notifier)
          .addPerson(
            name: 'sam',
            colorValue: 0xFF10B981,
            password: _kStrongPassword,
            role: PersonRole.viewer,
          );

      expect(container.read(canManagePeopleProvider), isTrue);
      expect(container.read(canWriteFinancialDataProvider), isTrue);
      expect(container.read(canManageFireflyConnectionProvider), isTrue);

      await container.read(peopleProvider.notifier).logout();
      await container
          .read(peopleProvider.notifier)
          .login('sam', _kStrongPassword);

      expect(container.read(canManagePeopleProvider), isFalse);
      expect(container.read(canWriteFinancialDataProvider), isFalse);
      expect(container.read(canManageFireflyConnectionProvider), isFalse);
    });

    test(
      'removePerson signs the deleted person out if they were active',
      () async {
        final container = await containerWithAdminSignedIn();
        addTearDown(container.dispose);
        final viewer = await container
            .read(peopleProvider.notifier)
            .addPerson(
              name: 'sam',
              colorValue: 0xFF10B981,
              password: _kStrongPassword,
              role: PersonRole.viewer,
            );
        await container.read(peopleProvider.notifier).logout();
        await container
            .read(peopleProvider.notifier)
            .login('sam', _kStrongPassword);

        await container.read(peopleProvider.notifier).removePerson(viewer.id);

        expect(container.read(peopleProvider).people, hasLength(1));
        expect(container.read(peopleProvider).currentPerson, isNull);
      },
    );

    test(
      'removePerson keeps the session when deleting another person',
      () async {
        final container = await containerWithAdminSignedIn();
        addTearDown(container.dispose);
        final viewer = await container
            .read(peopleProvider.notifier)
            .addPerson(
              name: 'sam',
              colorValue: 0xFF10B981,
              password: _kStrongPassword,
              role: PersonRole.viewer,
            );

        await container.read(peopleProvider.notifier).removePerson(viewer.id);

        expect(container.read(peopleProvider).currentPerson?.name, 'alex');
        expect(container.read(peopleProvider).lastSessionPerson?.name, 'alex');
      },
    );

    test('changePassword rejects the wrong old password', () async {
      final container = await containerWithAdminSignedIn();
      addTearDown(container.dispose);
      final admin = container.read(peopleProvider).people.single;

      final changed = await container
          .read(peopleProvider.notifier)
          .changePassword(
            admin.id,
            oldPassword: 'not-the-password',
            newPassword: 'New-Password9!',
          );

      expect(changed, isFalse);
      final stillWorks = await container
          .read(peopleProvider.notifier)
          .login('alex', _kStrongPassword);
      expect(stillWorks, isNotNull);
    });

    test('changePassword updates the password used to log in', () async {
      final container = await containerWithAdminSignedIn();
      addTearDown(container.dispose);
      final admin = container.read(peopleProvider).people.single;

      final changed = await container
          .read(peopleProvider.notifier)
          .changePassword(
            admin.id,
            oldPassword: _kStrongPassword,
            newPassword: 'New-Password9!',
          );
      expect(changed, isTrue);

      await container.read(peopleProvider.notifier).logout();
      final oldFails = await container
          .read(peopleProvider.notifier)
          .login('alex', _kStrongPassword);
      final newWorks = await container
          .read(peopleProvider.notifier)
          .login('alex', 'New-Password9!');

      expect(oldFails, isNull);
      expect(newWorks, isNotNull);
    });

    test(
      'changePassword rejects unknown people and weak new passwords',
      () async {
        final container = await containerWithAdminSignedIn();
        addTearDown(container.dispose);
        final admin = container.read(peopleProvider).people.single;

        expect(
          () => container
              .read(peopleProvider.notifier)
              .changePassword(
                'missing',
                oldPassword: _kStrongPassword,
                newPassword: 'New-Password9!',
              ),
          throwsArgumentError,
        );
        expect(
          () => container
              .read(peopleProvider.notifier)
              .changePassword(
                admin.id,
                oldPassword: _kStrongPassword,
                newPassword: 'weak',
              ),
          throwsArgumentError,
        );
      },
    );

    test('setPassword and clearPassword round-trip', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      final admin = await container
          .read(peopleProvider.notifier)
          .addPerson(name: 'alex', colorValue: _kColor);
      expect(admin.hasPassword, isFalse);

      await container
          .read(peopleProvider.notifier)
          .setPassword(admin.id, _kStrongPassword);
      expect(container.read(peopleProvider).people.single.hasPassword, isTrue);

      await container.read(peopleProvider.notifier).clearPassword(admin.id);
      expect(container.read(peopleProvider).people.single.hasPassword, isFalse);
      expect(
        container.read(peopleProvider).people.single.biometricsEnabled,
        isFalse,
      );
    });
  });

  group('requirePasswordLogin and session persistence', () {
    test('a persistent session survives reload by default', () async {
      final firstContainer = await buildContainer();
      await waitHydrated(firstContainer);
      await addAdmin(firstContainer);
      firstContainer.dispose();

      final secondContainer = await buildContainer();
      addTearDown(secondContainer.dispose);
      await waitHydrated(secondContainer);

      expect(secondContainer.read(peopleProvider).currentPerson?.name, 'alex');
      expect(secondContainer.read(peopleProvider).requiresLoginGate, isFalse);
    });

    test(
      'requirePasswordLogin forces a fresh login even with a remembered session',
      () async {
        final firstContainer = await buildContainer();
        await waitHydrated(firstContainer);
        await addAdmin(firstContainer);
        final missing = await firstContainer
            .read(peopleProvider.notifier)
            .setRequirePasswordLogin(true);
        expect(missing, isEmpty);
        firstContainer.dispose();

        final secondContainer = await buildContainer();
        addTearDown(secondContainer.dispose);
        await waitHydrated(secondContainer);

        expect(secondContainer.read(peopleProvider).currentPerson, isNull);
        expect(secondContainer.read(peopleProvider).requiresLoginGate, isTrue);

        final person = await secondContainer
            .read(peopleProvider.notifier)
            .login('alex', _kStrongPassword);
        expect(person, isNotNull);
      },
    );

    test(
      'setRequirePasswordLogin is blocked when people are missing passwords',
      () async {
        final container = await buildContainer();
        addTearDown(container.dispose);
        await waitHydrated(container);

        await container
            .read(peopleProvider.notifier)
            .addPerson(name: 'alex', colorValue: _kColor);
        await container
            .read(peopleProvider.notifier)
            .addPerson(name: 'sam', colorValue: 0xFF10B981);

        final missing = await container
            .read(peopleProvider.notifier)
            .setRequirePasswordLogin(true);

        expect(missing.map((p) => p.name), ['alex', 'sam']);
        expect(container.read(peopleProvider).requirePasswordLogin, isFalse);
      },
    );

    test(
      'login restores appearance prefs and defaults filter to person id',
      () async {
        final container = await buildContainer();
        addTearDown(container.dispose);
        await waitHydrated(container);
        final admin = await addAdmin(container);
        await container
            .read(peopleProvider.notifier)
            .updatePerson(
              admin.copyWith(
                preferences: const PersonPreferences(
                  themeModeName: 'dark',
                  funModeName: 'none',
                  localeCode: 'fr',
                ),
              ),
            );
        await container.read(peopleProvider.notifier).logout();

        await container
            .read(peopleProvider.notifier)
            .login('alex', _kStrongPassword);

        expect(container.read(themeProvider).themeMode, ThemeMode.dark);
        expect(container.read(localeProvider).languageCode, 'fr');
        expect(container.read(activePersonFilterProvider), admin.id);

        container
            .read(localeProvider.notifier)
            .setLocale(AppLocale.fromCode('en'));
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(peopleProvider).currentPerson?.preferences.localeCode,
          'en',
        );
      },
    );

    test('login applies a stored personFilterId preference', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);
      final admin = await addAdmin(container);
      await container
          .read(peopleProvider.notifier)
          .updatePerson(
            admin.copyWith(
              preferences: const PersonPreferences(
                personFilterId: 'custom-filter',
              ),
            ),
          );
      await container.read(peopleProvider.notifier).logout();

      await container
          .read(peopleProvider.notifier)
          .login('alex', _kStrongPassword);

      expect(container.read(activePersonFilterProvider), 'custom-filter');
    });

    test(
      'selectPerson switches without password when password login is off',
      () async {
        final container = await buildContainer();
        addTearDown(container.dispose);
        await waitHydrated(container);
        final admin = await addAdmin(container);
        final other = await container
            .read(peopleProvider.notifier)
            .addPerson(
              name: 'bob',
              colorValue: 0xFF10B981,
              password: _kStrongPassword,
            );

        final selected = await container
            .read(peopleProvider.notifier)
            .selectPerson(other.id);
        expect(selected?.name, 'bob');
        expect(container.read(peopleProvider).currentPerson?.id, other.id);
        expect(container.read(activePersonFilterProvider), other.id);

        final missing = await container
            .read(peopleProvider.notifier)
            .setRequirePasswordLogin(true);
        expect(missing, isEmpty);
        expect(
          await container.read(peopleProvider.notifier).selectPerson(admin.id),
          isNull,
        );
        expect(container.read(peopleProvider).currentPerson?.id, other.id);
      },
    );

    test('login falls back for unknown stored appearance names', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);
      final admin = await addAdmin(container);
      await container
          .read(peopleProvider.notifier)
          .updatePerson(
            admin.copyWith(
              preferences: const PersonPreferences(
                themeModeName: 'unknown',
                funModeName: 'unknown',
              ),
            ),
          );
      await container.read(peopleProvider.notifier).logout();

      await container
          .read(peopleProvider.notifier)
          .login('alex', _kStrongPassword);

      expect(container.read(themeProvider).themeMode, ThemeMode.system);
      expect(container.read(themeProvider).funMode, FunMode.none);
    });
  });

  group('biometrics', () {
    test('setBiometricsEnabled requires a successful auth prompt', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);
      final admin = await addAdmin(container);

      biometricAuth.authenticateResult = false;
      final failed = await container
          .read(peopleProvider.notifier)
          .setBiometricsEnabled(
            admin.id,
            enabled: true,
            localizedReason: 'Enable',
          );
      expect(failed, isFalse);
      expect(
        container.read(peopleProvider).currentPerson?.biometricsEnabled,
        isFalse,
      );

      biometricAuth.authenticateResult = true;
      final ok = await container
          .read(peopleProvider.notifier)
          .setBiometricsEnabled(
            admin.id,
            enabled: true,
            localizedReason: 'Enable',
          );
      expect(ok, isTrue);
      expect(
        container.read(peopleProvider).currentPerson?.biometricsEnabled,
        isTrue,
      );
      expect(biometricAuth.authenticateCalls, greaterThanOrEqualTo(2));
    });

    test(
      'setBiometricsEnabled rejects missing people and unavailable auth',
      () async {
        final container = await buildContainer();
        addTearDown(container.dispose);
        await waitHydrated(container);
        final admin = await addAdmin(container);

        expect(
          () => container
              .read(peopleProvider.notifier)
              .setBiometricsEnabled(
                'missing',
                enabled: true,
                localizedReason: 'Enable',
              ),
          throwsArgumentError,
        );
        biometricAuth.available = false;
        expect(
          await container
              .read(peopleProvider.notifier)
              .setBiometricsEnabled(
                admin.id,
                enabled: true,
                localizedReason: 'Enable',
              ),
          isFalse,
        );
      },
    );

    test('setBiometricsEnabled requires a password', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);
      final admin = await container
          .read(peopleProvider.notifier)
          .addPerson(name: 'alex', colorValue: _kColor);

      expect(
        await container
            .read(peopleProvider.notifier)
            .setBiometricsEnabled(
              admin.id,
              enabled: true,
              localizedReason: 'Enable',
            ),
        isFalse,
      );
    });

    test('loginWithBiometrics unlocks the last session person', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);
      final admin = await addAdmin(container);
      await container
          .read(peopleProvider.notifier)
          .setBiometricsEnabled(
            admin.id,
            enabled: true,
            localizedReason: 'Enable',
          );
      await container.read(peopleProvider.notifier).logout();

      expect(container.read(peopleProvider).requiresLoginGate, isTrue);
      expect(container.read(peopleProvider).canUnlockWithBiometrics, isTrue);

      final unlocked = await container
          .read(peopleProvider.notifier)
          .loginWithBiometrics(localizedReason: 'Unlock');
      expect(unlocked?.name, 'alex');
      expect(container.read(peopleProvider).requiresLoginGate, isFalse);
    });

    test('loginWithBiometrics fails when auth is cancelled', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);
      final admin = await addAdmin(container);
      await container
          .read(peopleProvider.notifier)
          .setBiometricsEnabled(
            admin.id,
            enabled: true,
            localizedReason: 'Enable',
          );
      await container.read(peopleProvider.notifier).logout();

      biometricAuth.authenticateResult = false;
      final unlocked = await container
          .read(peopleProvider.notifier)
          .loginWithBiometrics(localizedReason: 'Unlock');
      expect(unlocked, isNull);
      expect(container.read(peopleProvider).requiresLoginGate, isTrue);
    });
  });
}
