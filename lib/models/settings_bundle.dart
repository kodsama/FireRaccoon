import 'dart:convert';

import '../utils/settings_secrets_crypto.dart';
import 'people_models.dart';

/// Schema version for FireRaccoon settings backup files.
///
/// v2 seals Firefly tokens and password hashes under a backup passphrase.
const int kSettingsBundleSchemaVersion = 2;

/// Server-mode password placeholders must never enter a portable backup.
bool isPortablePasswordMaterial({
  required String? passwordHash,
  required String? salt,
}) {
  if (passwordHash == null ||
      passwordHash.isEmpty ||
      salt == null ||
      salt.isEmpty) {
    return false;
  }
  // Person.fromServerPublic mirrors hasPassword with these sentinels.
  if (passwordHash == 'server' || salt == 'server') return false;
  return true;
}

/// Firefly III connection fields carried in a settings backup.
class SettingsFireflyBundle {
  final String serverUrl;
  final String apiToken;
  final String authMode;
  final bool allowInsecure;

  const SettingsFireflyBundle({
    required this.serverUrl,
    this.apiToken = '',
    this.authMode = 'token',
    this.allowInsecure = false,
  });

  bool get hasServerUrl => serverUrl.isNotEmpty;

  /// Ready to apply as a Firefly connection (URL + token).
  bool get isValid => serverUrl.isNotEmpty && apiToken.isNotEmpty;

  /// Public fields only — never includes [apiToken].
  Map<String, dynamic> toPublicJson() => {
    'serverUrl': serverUrl,
    'authMode': authMode,
    'allowInsecure': allowInsecure,
  };

  factory SettingsFireflyBundle.fromPublicJson(Map<String, dynamic> json) {
    return SettingsFireflyBundle(
      serverUrl: (json['serverUrl'] as String? ?? '').trim(),
      // Intentionally ignore any plaintext apiToken in the public section.
      apiToken: '',
      authMode: json['authMode'] as String? ?? 'token',
      allowInsecure: json['allowInsecure'] as bool? ?? false,
    );
  }

  SettingsFireflyBundle copyWith({String? apiToken}) {
    return SettingsFireflyBundle(
      serverUrl: serverUrl,
      apiToken: apiToken ?? this.apiToken,
      authMode: authMode,
      allowInsecure: allowInsecure,
    );
  }
}

/// Portable settings snapshot.
///
/// In memory this may hold Firefly tokens and salted password hashes. On disk
/// those values live only inside a passphrase-sealed `secrets` blob — never
/// as plaintext JSON fields.
class SettingsBundle {
  final int schemaVersion;
  final String exportedAtIso;
  final Map<String, dynamic> device;
  final SettingsPeopleBundle people;
  final SettingsFireflyBundle? firefly;
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
    this.firefly,
    this.accountClassifications = const {},
    this.sideMenu,
    this.accountColumns,
    this.transactionColumns,
    this.viewMode,
    this.tightRowsColumns,
    this.prognosis,
  });

  /// True when export needs a passphrase to seal reversible / auth material.
  bool get needsSecretsPassphrase {
    final token = firefly?.apiToken ?? '';
    if (token.isNotEmpty) return true;
    return people.people.any(
      (p) => isPortablePasswordMaterial(
        passwordHash: p.passwordHash,
        salt: p.salt,
      ),
    );
  }

  /// Public JSON only (no apiToken, no password hashes).
  Map<String, dynamic> toPublicJson() => {
    'app': 'fireraccoon',
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAtIso,
    'device': device,
    'people': people.toPublicJson(),
    if (firefly != null && firefly!.hasServerUrl)
      'firefly': firefly!.toPublicJson(),
    'accountClassifications': accountClassifications,
    if (sideMenu != null) 'sideMenu': sideMenu,
    if (accountColumns != null) 'accountColumns': accountColumns,
    if (transactionColumns != null) 'transactionColumns': transactionColumns,
    if (viewMode != null) 'viewMode': viewMode,
    if (tightRowsColumns != null) 'tightRowsColumns': tightRowsColumns,
    if (prognosis != null) 'prognosis': prognosis,
  };

  Map<String, dynamic> buildSecretsPayload() {
    final peopleAuth = <String, Map<String, String>>{};
    for (final person in people.people) {
      if (isPortablePasswordMaterial(
        passwordHash: person.passwordHash,
        salt: person.salt,
      )) {
        peopleAuth[person.id] = {
          'passwordHash': person.passwordHash!,
          'salt': person.salt!,
        };
      }
    }
    return {
      if (firefly != null && firefly!.apiToken.isNotEmpty)
        'apiToken': firefly!.apiToken,
      'requirePasswordLogin': people.requirePasswordLogin,
      'peopleAuth': peopleAuth,
    };
  }

  /// Pretty-printed backup file. Seals secrets when [needsSecretsPassphrase].
  Future<String> encodeSealed(String? passphrase) async {
    final json = toPublicJson();
    if (needsSecretsPassphrase) {
      if (passphrase == null || passphrase.isEmpty) {
        throw ArgumentError(
          'A backup passphrase is required to export credentials.',
        );
      }
      json['secrets'] = await SettingsSecretsCrypto.seal(
        plaintext: buildSecretsPayload(),
        passphrase: passphrase,
      );
    }
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// Whether [source] contains a sealed secrets envelope.
  static bool sourceHasSecrets(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) return false;
    return decoded['secrets'] is Map;
  }

  factory SettingsBundle.fromPublicJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] as int? ?? 0;
    if (version < 1 || version > kSettingsBundleSchemaVersion) {
      throw FormatException('Unsupported settings bundle version: $version');
    }
    if (json['app'] != null && json['app'] != 'fireraccoon') {
      throw FormatException('Not a FireRaccoon settings file.');
    }

    final peopleRaw = json['people'];
    if (peopleRaw is! Map) {
      throw FormatException('Settings file is missing a people section.');
    }

    final classificationsRaw =
        json['accountClassifications'] as Map? ?? const {};
    final classifications = <String, String>{
      for (final e in classificationsRaw.entries)
        e.key.toString(): e.value?.toString() ?? '',
    };

    final tightRaw = json['tightRowsColumns'];
    List<String>? tight;
    if (tightRaw is List) {
      tight = tightRaw.map((e) => e.toString()).toList();
    }

    SettingsFireflyBundle? firefly;
    final fireflyRaw = json['firefly'];
    if (fireflyRaw is Map) {
      final parsed = SettingsFireflyBundle.fromPublicJson(
        Map<String, dynamic>.from(fireflyRaw),
      );
      if (parsed.hasServerUrl) firefly = parsed;
    }

    return SettingsBundle(
      schemaVersion: version,
      exportedAtIso:
          json['exportedAt'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      device: Map<String, dynamic>.from(json['device'] as Map? ?? const {}),
      people: SettingsPeopleBundle.fromPublicJson(
        Map<String, dynamic>.from(peopleRaw),
      ),
      firefly: firefly,
      accountClassifications: classifications,
      sideMenu: json['sideMenu'] is Map
          ? Map<String, dynamic>.from(json['sideMenu'] as Map)
          : null,
      accountColumns: json['accountColumns'] is Map
          ? Map<String, dynamic>.from(json['accountColumns'] as Map)
          : null,
      transactionColumns: json['transactionColumns'] is Map
          ? Map<String, dynamic>.from(json['transactionColumns'] as Map)
          : null,
      viewMode: json['viewMode'] as String?,
      tightRowsColumns: tight,
      prognosis: json['prognosis'] is Map
          ? Map<String, dynamic>.from(json['prognosis'] as Map)
          : null,
    );
  }

  /// Decodes a backup. When a `secrets` blob is present, [passphrase] unlocks
  /// the Firefly token and salted password hashes.
  static Future<SettingsBundle> decode(
    String source, {
    String? passphrase,
  }) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Settings file must be a JSON object.');
    }

    final public = SettingsBundle.fromPublicJson(decoded);
    final secretsRaw = decoded['secrets'];
    if (secretsRaw is! Map) {
      return public;
    }

    final secrets = await SettingsSecretsCrypto.unseal(
      envelope: Map<String, dynamic>.from(secretsRaw),
      passphrase: passphrase ?? '',
    );

    final token = (secrets['apiToken'] as String? ?? '').trim();
    final firefly = public.firefly != null && token.isNotEmpty
        ? public.firefly!.copyWith(apiToken: token)
        : public.firefly;

    final peopleAuthRaw = secrets['peopleAuth'];
    final authById = <String, Map<String, String>>{};
    if (peopleAuthRaw is Map) {
      for (final entry in peopleAuthRaw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final hash = value['passwordHash'] as String?;
        final salt = value['salt'] as String?;
        if (!isPortablePasswordMaterial(passwordHash: hash, salt: salt)) {
          continue;
        }
        authById[entry.key.toString()] = {'passwordHash': hash!, 'salt': salt!};
      }
    }

    final mergedPeople = public.people.people.map((person) {
      final auth = authById[person.id];
      if (auth == null) return person;
      return person.copyWith(
        passwordHash: auth['passwordHash'],
        salt: auth['salt'],
        biometricsEnabled: false,
      );
    }).toList();

    final wantRequire = secrets['requirePasswordLogin'] == true;
    final canRequire =
        wantRequire &&
        mergedPeople.isNotEmpty &&
        mergedPeople.every((p) => p.hasPassword);

    return SettingsBundle(
      schemaVersion: public.schemaVersion,
      exportedAtIso: public.exportedAtIso,
      device: public.device,
      people: SettingsPeopleBundle(
        people: mergedPeople,
        accountOwnerships: public.people.accountOwnerships,
        requirePasswordLogin: canRequire,
      ),
      firefly: firefly,
      accountClassifications: public.accountClassifications,
      sideMenu: public.sideMenu,
      accountColumns: public.accountColumns,
      transactionColumns: public.transactionColumns,
      viewMode: public.viewMode,
      tightRowsColumns: public.tightRowsColumns,
      prognosis: public.prognosis,
    );
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

  /// Public section: profiles and ownership only (no password material).
  Map<String, dynamic> toPublicJson() => {
    // Password-login is restored from the sealed secrets blob after unlock.
    'requirePasswordLogin': false,
    'people': people.map(_publicPersonJson).toList(),
    'accountOwnerships': {
      for (final e in accountOwnerships.entries) e.key: e.value.toJson(),
    },
  };

  factory SettingsPeopleBundle.fromPublicJson(Map<String, dynamic> json) {
    final people = <Person>[];
    final rawPeople = json['people'];
    if (rawPeople is List) {
      for (final item in rawPeople) {
        if (item is! Map) continue;
        final raw = Map<String, dynamic>.from(item)
          ..remove('passwordHash')
          ..remove('salt')
          ..remove('biometricsEnabled');
        final kind = AvatarKind.fromName(raw['avatarKind'] as String?);
        if (kind == AvatarKind.custom) {
          raw['avatarKind'] = AvatarKind.none.name;
          raw.remove('avatarValue');
        }
        people.add(
          Person.fromJson(
            raw,
          ).copyWith(clearPassword: true, biometricsEnabled: false),
        );
      }
    }

    final ownerships = <String, AccountOwnership>{};
    final rawOwnerships = json['accountOwnerships'];
    if (rawOwnerships is Map) {
      for (final entry in rawOwnerships.entries) {
        final value = entry.value;
        if (value is Map) {
          ownerships[entry.key.toString()] = AccountOwnership.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }

    return SettingsPeopleBundle(
      people: people,
      accountOwnerships: ownerships,
      requirePasswordLogin: false,
    );
  }
}

Map<String, dynamic> _publicPersonJson(Person person) {
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

/// Builds an in-memory people section (may include salted hashes).
SettingsPeopleBundle exportPeopleBundle({
  required List<Person> people,
  required Map<String, AccountOwnership> accountOwnerships,
  required bool requirePasswordLogin,
}) {
  final exported = people.map((p) {
    final includePassword = isPortablePasswordMaterial(
      passwordHash: p.passwordHash,
      salt: p.salt,
    );
    final kind = p.avatarKind == AvatarKind.custom
        ? AvatarKind.none
        : p.avatarKind;
    return Person(
      id: p.id,
      name: p.name,
      colorValue: p.colorValue,
      avatarKind: kind,
      avatarValue: kind == AvatarKind.preset ? p.avatarValue : null,
      role: p.role,
      passwordHash: includePassword ? p.passwordHash : null,
      salt: includePassword ? p.salt : null,
      createdAtIso: p.createdAtIso,
      preferences: p.preferences,
      biometricsEnabled: false,
    );
  }).toList();

  final canRequire =
      requirePasswordLogin &&
      exported.isNotEmpty &&
      exported.every((p) => p.hasPassword);

  return SettingsPeopleBundle(
    people: exported,
    accountOwnerships: accountOwnerships,
    requirePasswordLogin: canRequire,
  );
}
