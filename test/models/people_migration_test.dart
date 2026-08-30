import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/models/app_user_models.dart';
import 'package:fireraccoon/models/people_migration.dart';
import 'package:fireraccoon/models/people_models.dart';

void main() {
  test('merges linked app user onto matching person', () {
    const people = [
      Person(
        id: 'p1',
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        createdAtIso: '2026-01-01T00:00:00.000Z',
      ),
    ];
    const legacy = AppUsersStorage(
      users: [
        AppUser(
          id: 'u1',
          username: 'alex',
          passwordHash: 'hash',
          salt: 'salt',
          role: AppUserRole.admin,
          personId: 'p1',
          createdAtIso: '2026-01-01T00:00:00.000Z',
        ),
      ],
      requireLogin: true,
    );

    final result = migrateAppUsersIntoPeople(
      existingPeople: people,
      legacyUsers: legacy,
    );

    expect(result.didMigrate, isTrue);
    expect(result.people, hasLength(1));
    expect(result.people.single.id, 'p1');
    expect(result.people.single.role, PersonRole.admin);
    expect(result.people.single.hasPassword, isTrue);
    expect(result.auth.requirePasswordLogin, isTrue);
  });

  test('creates person from unlinked app user', () {
    const legacy = AppUsersStorage(
      users: [
        AppUser(
          id: 'u1',
          username: 'sam',
          passwordHash: 'hash',
          salt: 'salt',
          role: AppUserRole.user,
          createdAtIso: '2026-01-01T00:00:00.000Z',
        ),
      ],
    );

    final result = migrateAppUsersIntoPeople(
      existingPeople: const [],
      legacyUsers: legacy,
    );

    expect(result.people.single.name, 'sam');
    expect(result.people.single.id, 'u1');
  });

  test('promotes first person to admin when none exist', () {
    const people = [
      Person(
        id: 'p1',
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        role: PersonRole.user,
        createdAtIso: '2026-01-01T00:00:00.000Z',
      ),
      Person(
        id: 'p2',
        name: 'Sam',
        colorValue: 0xFF10B981,
        role: PersonRole.user,
        createdAtIso: '2026-01-01T00:00:00.000Z',
      ),
    ];

    final result = migrateAppUsersIntoPeople(
      existingPeople: people,
      legacyUsers: null,
    );

    expect(result.people.first.role, PersonRole.admin);
    expect(result.people.last.role, PersonRole.user);
  });

  test('keeps ownership-only person when merging partial legacy users', () {
    const people = [
      Person(
        id: 'p1',
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        role: PersonRole.viewer,
        createdAtIso: '2026-01-01T00:00:00.000Z',
      ),
      Person(
        id: 'p2',
        name: 'Sam',
        colorValue: 0xFF10B981,
        role: PersonRole.viewer,
        createdAtIso: '2026-01-01T00:00:00.000Z',
      ),
    ];
    const legacy = AppUsersStorage(
      users: [
        AppUser(
          id: 'u1',
          username: 'alex',
          passwordHash: 'hash',
          salt: 'salt',
          role: AppUserRole.viewer,
          personId: 'p1',
          createdAtIso: '2026-01-01T00:00:00.000Z',
        ),
      ],
    );

    final result = migrateAppUsersIntoPeople(
      existingPeople: people,
      legacyUsers: legacy,
    );

    expect(result.people.map((p) => p.id), containsAll(['p1', 'p2']));
    // Ownership-only p2 was viewer with matching createdAt → promoted to user.
    expect(result.people.firstWhere((p) => p.id == 'p2').role, PersonRole.user);
  });
}
