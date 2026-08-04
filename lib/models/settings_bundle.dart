import 'dart:convert';

import 'people_models.dart';

/// Schema version for FireRacoon settings backup files.
const int kSettingsBundleSchemaVersion = 1;

/// Portable settings snapshot. Never includes passwords, Firefly tokens,
/// session ids, or custom avatar binary data.
class SettingsBundle {
  final int schemaVersion;
  final String exportedAtIso;
  final Map<String, dynamic> device;
  final SettingsPeopleBundle people;
  final Map<String, String> accountClassifications;
  final Map<String, dynamic>? sideMenu;
  final Map<String, dynamic>? accountColumns;
  final Map<String, dynamic>? transactionColumns;
  final String? viewMode;
  final List<String>? tightRowsColumns;
  final Map<String, dynamic>? prognosis;

  const SettingsBundle({
    required this.schemaVersion,
    required this.exportedAtIso,
    required this.device,
    required this.people,
    this.accountClassifications = const {},
    this.sideMenu,
    this.accountColumns,
    this.transactionColumns,
    this.viewMode,
    this.tightRowsColumns,
    this.prognosis,
  });

  Map<String, dynamic> toJson() => {
    'app': 'fireracoon',
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAtIso,
    'device': device,
    'people': people.toJson(),
    'accountClassifications': accountClassifications,
    if (sideMenu != null) 'sideMenu': sideMenu,
    if (accountColumns != null) 'accountColumns': accountColumns,
    if (transactionColumns != null) 'transactionColumns': transactionColumns,
    if (viewMode != null) 'viewMode': viewMode,
    if (tightRowsColumns != null) 'tightRowsColumns': tightRowsColumns,
    if (prognosis != null) 'prognosis': prognosis,
  };

  String encodePretty() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory SettingsBundle.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 0;
    if (version < 1 || version > kSettingsBundleSchemaVersion) {
      throw FormatException('Unsupported settings bundle version: $version');
    }
    if (json['app'] != null && json['app'] != 'fireracoon') {
      throw FormatException('Not a FireRacoon settings file.');
    }

    final peopleRaw = json['people'];
    if (peopleRaw is! Map<String, dynamic>) {
      throw FormatException('Settings file is missing a people section.');
    }

    final classificationsRaw =
        json['accountClassifications'] as Map<String, dynamic>? ?? const {};
    final classifications = <String, String>{
      for (final e in classificationsRaw.entries)
        e.key: e.value?.toString() ?? '',
    };

    final tightRaw = json['tightRowsColumns'];
    List<String>? tight;
    if (tightRaw is List) {
      tight = tightRaw.map((e) => e.toString()).toList();
    }

    return SettingsBundle(
      schemaVersion: version,
      exportedAtIso:
          json['exportedAt'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      device: Map<String, dynamic>.from(
        json['device'] as Map<String, dynamic>? ?? const {},
      ),
      people: SettingsPeopleBundle.fromJson(peopleRaw),
      accountClassifications: classifications,
      sideMenu: json['sideMenu'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['sideMenu'] as Map)
          : null,
      accountColumns: json['accountColumns'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['accountColumns'] as Map)
          : null,
      transactionColumns: json['transactionColumns'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['transactionColumns'] as Map)
          : null,
      viewMode: json['viewMode'] as String?,
      tightRowsColumns: tight,
      prognosis: json['prognosis'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['prognosis'] as Map)
          : null,
    );
  }

  factory SettingsBundle.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Settings file must be a JSON object.');
    }
    return SettingsBundle.fromJson(decoded);
  }
}

class SettingsPeopleBundle {
  final List<Person> people;
  final Map<String, AccountOwnership> accountOwnerships;
  final bool requirePasswordLogin;

  const SettingsPeopleBundle({
    this.people = const [],
    this.accountOwnerships = const {},
    this.requirePasswordLogin = false,
  });

  Map<String, dynamic> toJson() => {
    'requirePasswordLogin': requirePasswordLogin,
    'people': people.map(_exportablePersonJson).toList(),
    'accountOwnerships': {
      for (final e in accountOwnerships.entries) e.key: e.value.toJson(),
    },
  };

  factory SettingsPeopleBundle.fromJson(Map<String, dynamic> json) {
    final rawPeople = json['people'] as List<dynamic>? ?? const [];
    final people = rawPeople.whereType<Map<String, dynamic>>().map((raw) {
      // Import never carries passwords; custom avatars become none.
      final kind = AvatarKind.fromName(raw['avatarKind'] as String?);
      final sanitized = Map<String, dynamic>.from(raw)
        ..remove('passwordHash')
        ..remove('salt')
        ..remove('biometricsEnabled');
      if (kind == AvatarKind.custom) {
        sanitized['avatarKind'] = AvatarKind.none.name;
        sanitized.remove('avatarValue');
      }
      return Person.fromJson(
        sanitized,
      ).copyWith(clearPassword: true, biometricsEnabled: false);
    }).toList();

    final rawOwnerships =
        json['accountOwnerships'] as Map<String, dynamic>? ?? {};
    final ownerships = <String, AccountOwnership>{};
    for (final entry in rawOwnerships.entries) {
      if (entry.value is Map<String, dynamic>) {
        ownerships[entry.key] = AccountOwnership.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    // Passwords are never in the file, so password-login cannot stay enabled.
    return SettingsPeopleBundle(
      people: people,
      accountOwnerships: ownerships,
      requirePasswordLogin: false,
    );
  }
}

Map<String, dynamic> _exportablePersonJson(Person person) {
  final kind = person.avatarKind == AvatarKind.custom
      ? AvatarKind.none
      : person.avatarKind;
  final value = kind == AvatarKind.preset ? person.avatarValue : null;
  return {
    'id': person.id,
    'name': person.name,
    'colorValue': person.colorValue,
    'avatarKind': kind.name,
    'avatarValue': ?value,
    'role': person.role.name,
    'createdAtIso': person.createdAtIso,
    'preferences': person.preferences.toJson(),
  };
}

/// Builds an exportable people section from live state (strips secrets/assets).
SettingsPeopleBundle exportPeopleBundle({
  required List<Person> people,
  required Map<String, AccountOwnership> accountOwnerships,
  required bool requirePasswordLogin,
}) {
  return SettingsPeopleBundle(
    people: people
        .map((p) => Person.fromJson(_exportablePersonJson(p)))
        .toList(),
    accountOwnerships: accountOwnerships,
    // Record the flag; import will clear it if nobody has a password.
    requirePasswordLogin: requirePasswordLogin,
  );
}
