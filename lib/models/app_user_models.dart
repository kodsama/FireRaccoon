import 'dart:convert';

/// Roles for the FireRacoon app-user layer. Firefly III itself stays
/// single-tenant; these roles only gate FireRacoon's own UI actions.
enum AppUserRole {
  admin,
  user,
  viewer;

  static AppUserRole fromName(String? name) {
    for (final role in AppUserRole.values) {
      if (role.name == name) return role;
    }
    return AppUserRole.viewer;
  }
}

/// Per-user preference bag applied on login and re-saved whenever the
/// signed-in user changes theme, locale, or the active person filter.
class AppUserPreferences {
  final String? themeModeName;
  final String? funModeName;
  final String? localeCode;
  final String? personFilterId;

  const AppUserPreferences({
    this.themeModeName,
    this.funModeName,
    this.localeCode,
    this.personFilterId,
  });

  AppUserPreferences copyWith({
    String? themeModeName,
    String? funModeName,
    String? localeCode,
    String? personFilterId,
  }) {
    return AppUserPreferences(
      themeModeName: themeModeName ?? this.themeModeName,
      funModeName: funModeName ?? this.funModeName,
      localeCode: localeCode ?? this.localeCode,
      personFilterId: personFilterId ?? this.personFilterId,
    );
  }

  Map<String, dynamic> toJson() => {
    if (themeModeName != null) 'themeModeName': themeModeName,
    if (funModeName != null) 'funModeName': funModeName,
    if (localeCode != null) 'localeCode': localeCode,
    if (personFilterId != null) 'personFilterId': personFilterId,
  };

  factory AppUserPreferences.fromJson(Map<String, dynamic> json) {
    return AppUserPreferences(
      themeModeName: json['themeModeName'] as String?,
      funModeName: json['funModeName'] as String?,
      localeCode: json['localeCode'] as String?,
      personFilterId: json['personFilterId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserPreferences &&
          runtimeType == other.runtimeType &&
          themeModeName == other.themeModeName &&
          funModeName == other.funModeName &&
          localeCode == other.localeCode &&
          personFilterId == other.personFilterId;

  @override
  int get hashCode =>
      Object.hash(themeModeName, funModeName, localeCode, personFilterId);
}

/// A local FireRacoon app-user account. Everyone shares the same Firefly
/// III connection; this only controls who can open the app and what they
/// may do inside it.
class AppUser {
  final String id;
  final String username;

  /// PBKDF2-HMAC-SHA256 digest, base64-encoded. Never the plaintext password.
  final String passwordHash;

  /// Base64-encoded random salt used to derive [passwordHash].
  final String salt;
  final AppUserRole role;

  /// Optional link to a [Person] from `peopleSettingsProvider`, used to
  /// default the account-ownership filter for this user.
  final String? personId;
  final String createdAtIso;
  final AppUserPreferences preferences;

  /// When true, the login screen may unlock this user via device biometrics
  /// (or device PIN) instead of typing the password.
  final bool biometricsEnabled;

  const AppUser({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.role,
    this.personId,
    required this.createdAtIso,
    this.preferences = const AppUserPreferences(),
    this.biometricsEnabled = false,
  });

  AppUser copyWith({
    String? username,
    String? passwordHash,
    String? salt,
    AppUserRole? role,
    String? personId,
    bool clearPersonId = false,
    AppUserPreferences? preferences,
    bool? biometricsEnabled,
  }) {
    return AppUser(
      id: id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      role: role ?? this.role,
      personId: clearPersonId ? null : (personId ?? this.personId),
      createdAtIso: createdAtIso,
      preferences: preferences ?? this.preferences,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'passwordHash': passwordHash,
    'salt': salt,
    'role': role.name,
    if (personId != null) 'personId': personId,
    'createdAtIso': createdAtIso,
    'preferences': preferences.toJson(),
    'biometricsEnabled': biometricsEnabled,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
      salt: json['salt'] as String? ?? '',
      role: AppUserRole.fromName(json['role'] as String?),
      personId: json['personId'] as String?,
      createdAtIso:
          json['createdAtIso'] as String? ?? DateTime.now().toIso8601String(),
      preferences: json['preferences'] is Map<String, dynamic>
          ? AppUserPreferences.fromJson(
              json['preferences'] as Map<String, dynamic>,
            )
          : const AppUserPreferences(),
      biometricsEnabled: json['biometricsEnabled'] as bool? ?? false,
    );
  }
}

/// Encodes/decodes the full app-users blob stored under a single secure
/// storage key: the user list plus the shared `requireLogin` setting.
class AppUsersStorage {
  final List<AppUser> users;
  final bool requireLogin;

  const AppUsersStorage({this.users = const [], this.requireLogin = false});

  Map<String, dynamic> toJson() => {
    'users': users.map((u) => u.toJson()).toList(),
    'requireLogin': requireLogin,
  };

  factory AppUsersStorage.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['users'] as List<dynamic>? ?? const [];
    return AppUsersStorage(
      users: rawUsers
          .whereType<Map<String, dynamic>>()
          .map(AppUser.fromJson)
          .toList(),
      requireLogin: json['requireLogin'] as bool? ?? false,
    );
  }

  String encode() => jsonEncode(toJson());

  factory AppUsersStorage.decode(String source) {
    try {
      return AppUsersStorage.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppUsersStorage();
    }
  }
}
