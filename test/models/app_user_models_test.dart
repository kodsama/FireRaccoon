import 'package:fireraccoon/models/app_user_models.dart';
import 'package:fireraccoon/models/people_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUserRole', () {
    test('fromName resolves known roles and defaults to viewer', () {
      expect(AppUserRole.fromName('admin'), AppUserRole.admin);
      expect(AppUserRole.fromName('user'), AppUserRole.user);
      expect(AppUserRole.fromName('viewer'), AppUserRole.viewer);
      expect(AppUserRole.fromName('nope'), AppUserRole.viewer);
      expect(AppUserRole.fromName(null), AppUserRole.viewer);
    });
  });

  group('AppUserPreferences', () {
    test('copy, json, equality, and hashCode', () {
      const preferences = AppUserPreferences(
        themeModeName: 'dark',
        funModeName: 'raccoon',
        localeCode: 'en',
        personFilterId: 'person-1',
      );

      final copy = preferences.copyWith(localeCode: 'fr');
      expect(copy.themeModeName, 'dark');
      expect(copy.funModeName, 'raccoon');
      expect(copy.localeCode, 'fr');
      expect(copy.personFilterId, 'person-1');
      expect(preferences.copyWith(), preferences);
      expect(AppUserPreferences.fromJson(preferences.toJson()), preferences);
      expect(
        AppUserPreferences.fromJson(preferences.toJson()).hashCode,
        preferences.hashCode,
      );
      expect(preferences, isNot(const AppUserPreferences()));
      expect(preferences == Object(), isFalse);
    });
  });

  group('AppUser', () {
    test('copyWith replaces fields and can clear personId', () {
      const user = AppUser(
        id: 'u1',
        username: 'alex',
        passwordHash: 'hash',
        salt: 'salt',
        role: AppUserRole.admin,
        personId: 'person-1',
        createdAtIso: '2026-07-30T10:00:00.000Z',
        biometricsEnabled: false,
      );

      final copy = user.copyWith(
        username: 'sam',
        role: AppUserRole.viewer,
        clearPersonId: true,
        preferences: const AppUserPreferences(localeCode: 'fr'),
        biometricsEnabled: true,
        passwordHash: 'h2',
        salt: 's2',
      );

      expect(copy.id, user.id);
      expect(copy.username, 'sam');
      expect(copy.role, AppUserRole.viewer);
      expect(copy.personId, isNull);
      expect(copy.preferences.localeCode, 'fr');
      expect(copy.biometricsEnabled, isTrue);
      expect(copy.passwordHash, 'h2');
      expect(copy.salt, 's2');
      expect(copy.createdAtIso, user.createdAtIso);

      // No-arg copyWith exercises the `?? this.field` fallbacks.
      final unchanged = user.copyWith();
      expect(unchanged.username, user.username);
      expect(unchanged.passwordHash, user.passwordHash);
      expect(unchanged.salt, user.salt);
      expect(unchanged.role, user.role);
      expect(unchanged.personId, user.personId);
      expect(unchanged.preferences, user.preferences);
      expect(unchanged.biometricsEnabled, user.biometricsEnabled);
      expect(user.copyWith(personId: 'p2').personId, 'p2');
    });

    test('json round-trip preserves fields', () {
      const user = AppUser(
        id: 'u1',
        username: 'alex',
        passwordHash: 'hash',
        salt: 'salt',
        role: AppUserRole.user,
        personId: 'p1',
        createdAtIso: '2026-01-01T00:00:00.000Z',
        preferences: AppUserPreferences(themeModeName: 'light'),
        biometricsEnabled: true,
      );
      final restored = AppUser.fromJson(user.toJson());
      expect(restored.id, user.id);
      expect(restored.username, user.username);
      expect(restored.passwordHash, user.passwordHash);
      expect(restored.salt, user.salt);
      expect(restored.role, user.role);
      expect(restored.personId, user.personId);
      expect(restored.createdAtIso, user.createdAtIso);
      expect(restored.preferences.themeModeName, 'light');
      expect(restored.biometricsEnabled, isTrue);
    });

    test('fromJson tolerates sparse maps', () {
      final user = AppUser.fromJson({'id': 'x'});
      expect(user.id, 'x');
      expect(user.username, '');
      expect(user.role, AppUserRole.viewer);
      expect(user.biometricsEnabled, isFalse);
      expect(user.preferences, const AppUserPreferences());
    });
  });

  group('AppUsersStorage', () {
    test('encode/decode round-trip', () {
      const storage = AppUsersStorage(
        users: [
          AppUser(
            id: 'u1',
            username: 'alex',
            passwordHash: 'h',
            salt: 's',
            role: AppUserRole.admin,
            createdAtIso: '2026-01-01T00:00:00.000Z',
          ),
        ],
        requireLogin: true,
      );
      final restored = AppUsersStorage.decode(storage.encode());
      expect(restored.requireLogin, isTrue);
      expect(restored.users, hasLength(1));
      expect(restored.users.single.username, 'alex');
    });

    test('decode returns empty storage on garbage', () {
      final restored = AppUsersStorage.decode('{not-json');
      expect(restored.users, isEmpty);
      expect(restored.requireLogin, isFalse);
    });

    test('fromJson skips non-map users', () {
      final storage = AppUsersStorage.fromJson({
        'users': [
          {'id': 'u1', 'username': 'a', 'passwordHash': '', 'salt': ''},
          'skip-me',
        ],
        'requireLogin': false,
      });
      expect(storage.users, hasLength(1));
    });
  });

  test('preferences copy and compare by value', () {
    const preferences = PersonPreferences(
      themeModeName: 'dark',
      funModeName: 'raccoon',
      localeCode: 'en',
      personFilterId: 'person-1',
    );

    final copy = preferences.copyWith(localeCode: 'fr');

    expect(copy.themeModeName, 'dark');
    expect(copy.funModeName, 'raccoon');
    expect(copy.localeCode, 'fr');
    expect(copy.personFilterId, 'person-1');
    expect(preferences.copyWith(), preferences);
    expect(PersonPreferences.fromJson(preferences.toJson()), preferences);
    expect(
      PersonPreferences.fromJson(preferences.toJson()).hashCode,
      preferences.hashCode,
    );
    expect(preferences, isNot(const PersonPreferences()));
  });

  test('person copyWith replaces fields and can clear password', () {
    const person = Person(
      id: 'person-1',
      name: 'alex',
      colorValue: 0xFF3B82F6,
      role: PersonRole.admin,
      passwordHash: 'hash',
      salt: 'salt',
      createdAtIso: '2026-07-30T10:00:00.000Z',
    );

    final copy = person.copyWith(
      name: 'sam',
      role: PersonRole.viewer,
      clearPassword: true,
      preferences: const PersonPreferences(localeCode: 'fr'),
      biometricsEnabled: true,
    );

    expect(copy.id, person.id);
    expect(copy.name, 'sam');
    expect(copy.hasPassword, isFalse);
    expect(copy.role, PersonRole.viewer);
    expect(copy.preferences.localeCode, 'fr');
    expect(copy.biometricsEnabled, isTrue);
    expect(copy.createdAtIso, person.createdAtIso);
  });
}
