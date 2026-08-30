import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fireraccoon_engine/models/account.dart';

/// Roles for local People accounts. Firefly III stays single-tenant; these
/// only gate FireRaccoon UI actions.
enum PersonRole {
  admin,
  user,
  viewer;

  static PersonRole fromName(String? name) {
    for (final role in PersonRole.values) {
      if (role.name == name) return role;
    }
    return PersonRole.viewer;
  }
}

/// True when [people] contains at least one admin.
bool peopleHasAdmin(Iterable<Person> people) =>
    people.any((p) => p.role == PersonRole.admin);

/// True when [personId] is an admin and the only one in [people].
bool isSoleAdmin(List<Person> people, String personId) {
  final admins = people.where((p) => p.role == PersonRole.admin).toList();
  return admins.length == 1 && admins.single.id == personId;
}

/// Promotes the first person to admin when the list is non-empty and admin-less.
List<Person> ensureAtLeastOneAdmin(List<Person> people) {
  if (people.isEmpty || peopleHasAdmin(people)) return people;
  final first = people.first;
  return [first.copyWith(role: PersonRole.admin), ...people.skip(1)];
}

/// How a person's circular avatar is resolved.
enum AvatarKind {
  none,
  preset,
  custom;

  static AvatarKind fromName(String? name) {
    for (final kind in AvatarKind.values) {
      if (kind.name == name) return kind;
    }
    return AvatarKind.none;
  }
}

/// Per-person preference bag applied on select/login and re-saved whenever
/// the signed-in person changes theme, locale, or the active person filter.
class PersonPreferences {
  final String? themeModeName;
  final String? funModeName;
  final String? localeCode;
  final String? personFilterId;

  const PersonPreferences({
    this.themeModeName,
    this.funModeName,
    this.localeCode,
    this.personFilterId,
  });

  PersonPreferences copyWith({
    String? themeModeName,
    String? funModeName,
    String? localeCode,
    String? personFilterId,
    bool clearPersonFilterId = false,
  }) {
    return PersonPreferences(
      themeModeName: themeModeName ?? this.themeModeName,
      funModeName: funModeName ?? this.funModeName,
      localeCode: localeCode ?? this.localeCode,
      personFilterId: clearPersonFilterId
          ? null
          : (personFilterId ?? this.personFilterId),
    );
  }

  Map<String, dynamic> toJson() => {
    if (themeModeName != null) 'themeModeName': themeModeName,
    if (funModeName != null) 'funModeName': funModeName,
    if (localeCode != null) 'localeCode': localeCode,
    if (personFilterId != null) 'personFilterId': personFilterId,
  };

  factory PersonPreferences.fromJson(Map<String, dynamic> json) {
    return PersonPreferences(
      themeModeName: json['themeModeName'] as String?,
      funModeName: json['funModeName'] as String?,
      localeCode: json['localeCode'] as String?,
      personFilterId: json['personFilterId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonPreferences &&
          runtimeType == other.runtimeType &&
          themeModeName == other.themeModeName &&
          funModeName == other.funModeName &&
          localeCode == other.localeCode &&
          personFilterId == other.personFilterId;

  @override
  int get hashCode =>
      Object.hash(themeModeName, funModeName, localeCode, personFilterId);
}

/// A household member who may also sign into FireRaccoon. Everyone shares the
/// same Firefly III connection; role and optional password only gate the app.
class Person {
  final String id;
  final String name;
  final int colorValue;
  final AvatarKind avatarKind;

  /// Preset id (e.g. `raccoon_1`) or custom file name under the avatars dir.
  final String? avatarValue;

  final PersonRole role;

  /// PBKDF2-HMAC-SHA256 digest, base64-encoded. Null when no password is set.
  final String? passwordHash;

  /// Base64-encoded salt for [passwordHash]. Null when no password is set.
  final String? salt;

  final String createdAtIso;
  final PersonPreferences preferences;
  final bool biometricsEnabled;

  const Person({
    required this.id,
    required this.name,
    required this.colorValue,
    this.avatarKind = AvatarKind.none,
    this.avatarValue,
    this.role = PersonRole.user,
    this.passwordHash,
    this.salt,
    required this.createdAtIso,
    this.preferences = const PersonPreferences(),
    this.biometricsEnabled = false,
  });

  Color get color => Color(colorValue);

  bool get hasPassword =>
      passwordHash != null &&
      passwordHash!.isNotEmpty &&
      salt != null &&
      salt!.isNotEmpty;

  Person copyWith({
    String? name,
    int? colorValue,
    AvatarKind? avatarKind,
    String? avatarValue,
    bool clearAvatarValue = false,
    PersonRole? role,
    String? passwordHash,
    String? salt,
    bool clearPassword = false,
    PersonPreferences? preferences,
    bool? biometricsEnabled,
  }) {
    return Person(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      avatarKind: avatarKind ?? this.avatarKind,
      avatarValue: clearAvatarValue ? null : (avatarValue ?? this.avatarValue),
      role: role ?? this.role,
      passwordHash: clearPassword ? null : (passwordHash ?? this.passwordHash),
      salt: clearPassword ? null : (salt ?? this.salt),
      createdAtIso: createdAtIso,
      preferences: preferences ?? this.preferences,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    );
  }

  /// Profile fields synced via SharedPreferences / Firefly preferences.
  Map<String, dynamic> toProfileJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'avatarKind': avatarKind.name,
    if (avatarValue != null) 'avatarValue': avatarValue,
  };

  /// Local-only auth fields stored in secure storage.
  Map<String, dynamic> toAuthJson() => {
    'id': id,
    'role': role.name,
    if (passwordHash != null) 'passwordHash': passwordHash,
    if (salt != null) 'salt': salt,
    'createdAtIso': createdAtIso,
    'preferences': preferences.toJson(),
    'biometricsEnabled': biometricsEnabled,
  };

  factory Person.fromProfileAndAuth({
    required Map<String, dynamic> profile,
    Map<String, dynamic>? auth,
  }) {
    final legacyIcon = profile['avatarIcon'] as String?;
    var avatarKind = AvatarKind.fromName(profile['avatarKind'] as String?);
    var avatarValue = profile['avatarValue'] as String?;
    if (avatarKind == AvatarKind.none &&
        legacyIcon != null &&
        legacyIcon.isNotEmpty) {
      avatarKind = AvatarKind.preset;
      avatarValue = legacyIcon;
    }

    return Person(
      id: profile['id'] as String? ?? '',
      name: profile['name'] as String? ?? 'Unnamed',
      colorValue: profile['colorValue'] as int? ?? 0xFF3B82F6,
      avatarKind: avatarKind,
      avatarValue: avatarValue,
      role: PersonRole.fromName(auth?['role'] as String?),
      passwordHash: auth?['passwordHash'] as String?,
      salt: auth?['salt'] as String?,
      createdAtIso:
          auth?['createdAtIso'] as String? ?? DateTime.now().toIso8601String(),
      preferences: auth?['preferences'] is Map<String, dynamic>
          ? PersonPreferences.fromJson(
              auth!['preferences'] as Map<String, dynamic>,
            )
          : const PersonPreferences(),
      biometricsEnabled: auth?['biometricsEnabled'] as bool? ?? false,
    );
  }

  /// Full JSON (tests and one-shot migration helpers).
  Map<String, dynamic> toJson() => {...toProfileJson(), ...toAuthJson()};

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person.fromProfileAndAuth(profile: json, auth: json);
  }

  /// Builds a [Person] from the server `/api/state` public person payload.
  ///
  /// Password material stays on the server; [hasPassword] is mirrored with
  /// placeholders so UI gates that check [Person.hasPassword] keep working.
  factory Person.fromServerPublic(Map<String, dynamic> json) {
    final hasPassword = json['hasPassword'] == true;
    final created =
        json['createdAtIso'] as String? ??
        json['createdAt'] as String? ??
        DateTime.now().toUtc().toIso8601String();
    final prefsRaw = json['preferences'];
    return Person(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed',
      colorValue: json['colorValue'] as int? ?? 0xFF3B82F6,
      avatarKind: AvatarKind.fromName(json['avatarKind'] as String?),
      avatarValue: json['avatarValue'] as String?,
      role: PersonRole.fromName(json['role'] as String?),
      passwordHash: hasPassword ? 'server' : null,
      salt: hasPassword ? 'server' : null,
      createdAtIso: created,
      preferences: prefsRaw is Map<String, dynamic>
          ? PersonPreferences.fromJson(prefsRaw)
          : prefsRaw is Map
          ? PersonPreferences.fromJson(
              prefsRaw.map((k, v) => MapEntry(k.toString(), v)),
            )
          : const PersonPreferences(),
      biometricsEnabled: json['biometricsEnabled'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          colorValue == other.colorValue &&
          avatarKind == other.avatarKind &&
          avatarValue == other.avatarValue &&
          role == other.role &&
          passwordHash == other.passwordHash &&
          salt == other.salt &&
          createdAtIso == other.createdAtIso &&
          preferences == other.preferences &&
          biometricsEnabled == other.biometricsEnabled;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorValue,
    avatarKind,
    avatarValue,
    role,
    passwordHash,
    salt,
    createdAtIso,
    preferences,
    biometricsEnabled,
  );
}

/// Local credentials / role / prefs keyed by person id, plus the shared
/// password-login policy flag.
class PeopleAuthStorage {
  final Map<String, Map<String, dynamic>> byPersonId;
  final bool requirePasswordLogin;

  const PeopleAuthStorage({
    this.byPersonId = const {},
    this.requirePasswordLogin = false,
  });

  Map<String, dynamic> toJson() => {
    'byPersonId': byPersonId,
    'requirePasswordLogin': requirePasswordLogin,
  };

  factory PeopleAuthStorage.fromJson(Map<String, dynamic> json) {
    final raw = json['byPersonId'] as Map<String, dynamic>? ?? const {};
    final byPersonId = <String, Map<String, dynamic>>{};
    for (final entry in raw.entries) {
      if (entry.value is Map<String, dynamic>) {
        byPersonId[entry.key] = Map<String, dynamic>.from(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    return PeopleAuthStorage(
      byPersonId: byPersonId,
      requirePasswordLogin:
          json['requirePasswordLogin'] as bool? ??
          json['requireLogin'] as bool? ??
          false,
    );
  }

  String encode() => jsonEncode(toJson());

  factory PeopleAuthStorage.decode(String source) {
    try {
      return PeopleAuthStorage.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
    } catch (_) {
      return const PeopleAuthStorage();
    }
  }

  PeopleAuthStorage copyWith({
    Map<String, Map<String, dynamic>>? byPersonId,
    bool? requirePasswordLogin,
  }) {
    return PeopleAuthStorage(
      byPersonId: byPersonId ?? this.byPersonId,
      requirePasswordLogin: requirePasswordLogin ?? this.requirePasswordLogin,
    );
  }
}

class AccountOwnership {
  final String accountId;

  /// Map of personId -> share percentage (e.g. {"p1": 0.8, "p2": 0.2}).
  final Map<String, double> personShares;

  const AccountOwnership({required this.accountId, required this.personShares});

  List<String> get ownerIds => personShares.keys.toList();

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'personShares': personShares,
  };

  factory AccountOwnership.fromJson(Map<String, dynamic> json) {
    final rawShares = json['personShares'] as Map<String, dynamic>? ?? {};
    final parsedShares = <String, double>{};
    for (final entry in rawShares.entries) {
      parsedShares[entry.key] =
          double.tryParse(entry.value?.toString() ?? '0') ?? 0.0;
    }
    return AccountOwnership(
      accountId: json['accountId'] as String? ?? '',
      personShares: parsedShares,
    );
  }
}

class AccountOwnershipConfig {
  final int version;
  final List<Person> people;
  final Map<String, AccountOwnership> accountOwnerships;

  const AccountOwnershipConfig({
    this.version = 1,
    this.people = const [],
    this.accountOwnerships = const {},
  });

  /// Calculates the ownership ratio of [accountId] for a given [personId].
  ///
  /// - If [personId] is null (All People view): returns 1.0 (100%).
  /// - If the account is unassigned (no owners set): returns 1.0 (100% for everyone).
  /// - If [personId] is assigned: returns its explicit percentage share.
  /// - If [personId] is not assigned to this account: returns 0.0.
  double getOwnershipRatio(String accountId, String? personId) {
    if (personId == null) return 1.0;
    final ownership = accountOwnerships[accountId];
    if (ownership == null || ownership.personShares.isEmpty) {
      return 1.0;
    }
    if (!ownership.personShares.containsKey(personId)) {
      return 0.0;
    }
    return ownership.personShares[personId]!;
  }

  double getEffectiveBalance(Account account, String? personId) {
    final ratio = getOwnershipRatio(account.id, personId);
    return account.currentBalance * ratio;
  }

  List<Person> getOwnersForAccount(String accountId) {
    final ownership = accountOwnerships[accountId];
    if (ownership == null || ownership.personShares.isEmpty) {
      return const [];
    }
    return people
        .where((person) => ownership.personShares.containsKey(person.id))
        .toList();
  }

  AccountOwnershipConfig copyWith({
    int? version,
    List<Person>? people,
    Map<String, AccountOwnership>? accountOwnerships,
  }) {
    return AccountOwnershipConfig(
      version: version ?? this.version,
      people: people ?? this.people,
      accountOwnerships: accountOwnerships ?? this.accountOwnerships,
    );
  }

  /// Sync payload: profile fields only (no credentials).
  Map<String, dynamic> toJson() => {
    'version': version,
    'people': people.map((p) => p.toProfileJson()).toList(),
    'accountOwnerships': accountOwnerships.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
  };

  factory AccountOwnershipConfig.fromJson(
    Map<String, dynamic> json, {
    PeopleAuthStorage? auth,
  }) {
    final version = json['version'] as int? ?? 1;
    final rawPeople = json['people'] as List<dynamic>? ?? [];
    final authStorage = auth ?? const PeopleAuthStorage();
    final people = rawPeople.whereType<Map<String, dynamic>>().map((p) {
      final id = p['id'] as String? ?? '';
      return Person.fromProfileAndAuth(
        profile: p,
        auth: authStorage.byPersonId[id],
      );
    }).toList();

    final rawOwnerships =
        json['accountOwnerships'] as Map<String, dynamic>? ?? {};
    final accountOwnerships = <String, AccountOwnership>{};
    for (final entry in rawOwnerships.entries) {
      if (entry.value is Map<String, dynamic>) {
        accountOwnerships[entry.key] = AccountOwnership.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    return AccountOwnershipConfig(
      version: version,
      people: people,
      accountOwnerships: accountOwnerships,
    );
  }

  String encode() => jsonEncode(toJson());

  factory AccountOwnershipConfig.decode(
    String source, {
    PeopleAuthStorage? auth,
  }) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      return AccountOwnershipConfig.fromJson(json, auth: auth);
    } catch (_) {
      return const AccountOwnershipConfig();
    }
  }
}
