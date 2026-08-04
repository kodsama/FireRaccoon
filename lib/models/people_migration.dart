import 'app_user_models.dart';
import 'people_models.dart';

/// Result of merging legacy AppUser accounts into the People list.
class PeopleMigrationResult {
  final List<Person> people;
  final PeopleAuthStorage auth;
  final bool didMigrate;

  const PeopleMigrationResult({
    required this.people,
    required this.auth,
    required this.didMigrate,
  });
}

/// One-shot merge of [AppUsersStorage] into existing people profiles.
///
/// - App users linked via [AppUser.personId] attach credentials to that person.
/// - Unlinked app users become new people (name = username).
/// - People with no matching app user keep profile data and get role `user`.
/// - Guarantees at least one admin when the resulting list is non-empty.
PeopleMigrationResult migrateAppUsersIntoPeople({
  required List<Person> existingPeople,
  required AppUsersStorage? legacyUsers,
  PeopleAuthStorage? existingAuth,
}) {
  if (legacyUsers == null || legacyUsers.users.isEmpty) {
    final people = ensureAtLeastOneAdmin(existingPeople);
    final auth = _authFromPeople(
      people,
      requirePasswordLogin: existingAuth?.requirePasswordLogin ?? false,
    );
    return PeopleMigrationResult(people: people, auth: auth, didMigrate: false);
  }

  final byId = <String, Person>{
    for (final person in existingPeople) person.id: person,
  };
  final consumedPersonIds = <String>{};

  for (final user in legacyUsers.users) {
    final linkedId = user.personId;
    if (linkedId != null && byId.containsKey(linkedId)) {
      final base = byId[linkedId]!;
      byId[linkedId] = _mergeUserOntoPerson(base, user);
      consumedPersonIds.add(linkedId);
      continue;
    }

    final id = user.id;
    byId[id] = Person(
      id: id,
      name: user.username,
      colorValue: 0xFF3B82F6,
      role: _toPersonRole(user.role),
      passwordHash: user.passwordHash.isEmpty ? null : user.passwordHash,
      salt: user.salt.isEmpty ? null : user.salt,
      createdAtIso: user.createdAtIso,
      preferences: PersonPreferences(
        themeModeName: user.preferences.themeModeName,
        funModeName: user.preferences.funModeName,
        localeCode: user.preferences.localeCode,
        personFilterId: user.preferences.personFilterId ?? user.personId,
      ),
      biometricsEnabled: user.biometricsEnabled,
    );
  }

  for (final person in existingPeople) {
    if (consumedPersonIds.contains(person.id)) continue;
    if (!byId.containsKey(person.id)) {
      byId[person.id] = person;
    } else if (!consumedPersonIds.contains(person.id) &&
        legacyUsers.users.every((u) => u.id != person.id)) {
      // Keep ownership-only person; default role already on profile merge.
      final current = byId[person.id]!;
      if (current.role == PersonRole.viewer &&
          current.createdAtIso == person.createdAtIso) {
        byId[person.id] = current.copyWith(role: PersonRole.user);
      }
    }
  }

  final people = ensureAtLeastOneAdmin(byId.values.toList());
  final auth = _authFromPeople(
    people,
    requirePasswordLogin: legacyUsers.requireLogin,
  );
  return PeopleMigrationResult(people: people, auth: auth, didMigrate: true);
}

Person _mergeUserOntoPerson(Person person, AppUser user) {
  return person.copyWith(
    role: _toPersonRole(user.role),
    passwordHash: user.passwordHash.isEmpty ? null : user.passwordHash,
    salt: user.salt.isEmpty ? null : user.salt,
    preferences: PersonPreferences(
      themeModeName: user.preferences.themeModeName,
      funModeName: user.preferences.funModeName,
      localeCode: user.preferences.localeCode,
      personFilterId: user.preferences.personFilterId ?? person.id,
    ),
    biometricsEnabled: user.biometricsEnabled,
  );
}

PersonRole _toPersonRole(AppUserRole role) {
  switch (role) {
    case AppUserRole.admin:
      return PersonRole.admin;
    case AppUserRole.user:
      return PersonRole.user;
    case AppUserRole.viewer:
      return PersonRole.viewer;
  }
}

PeopleAuthStorage _authFromPeople(
  List<Person> people, {
  required bool requirePasswordLogin,
}) {
  return PeopleAuthStorage(
    byPersonId: {for (final person in people) person.id: person.toAuthJson()},
    requirePasswordLogin: requirePasswordLogin,
  );
}
