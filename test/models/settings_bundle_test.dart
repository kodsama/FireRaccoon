import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/models/settings_bundle.dart';
import 'package:fireracoon/utils/password_policy.dart';
import 'package:fireracoon/utils/settings_secrets_crypto.dart';

void main() {
  const passphrase = 'Correct-Horse9!';

  SettingsBundle sampleBundle({
    required PasswordHash hashed,
    bool requirePasswordLogin = true,
    String? apiToken = 'ff-token-secret',
  }) {
    return SettingsBundle(
      schemaVersion: kSettingsBundleSchemaVersion,
      exportedAtIso: '2026-08-04T00:00:00.000Z',
      device: const {'locale': 'en', 'themeMode': 'dark'},
      people: exportPeopleBundle(
        people: [
          Person(
            id: 'p1',
            name: 'Alex',
            colorValue: 0xFF3B82F6,
            role: PersonRole.admin,
            passwordHash: hashed.hash,
            salt: hashed.salt,
            biometricsEnabled: true,
            avatarKind: AvatarKind.custom,
            avatarValue: 'p1.png',
            createdAtIso: '2026-01-01T00:00:00.000Z',
            preferences: const PersonPreferences(localeCode: 'fr'),
          ),
          const Person(
            id: 'p2',
            name: 'Sam',
            colorValue: 0xFF10B981,
            role: PersonRole.user,
            passwordHash: 'also-hashed',
            salt: 'also-salt',
            avatarKind: AvatarKind.preset,
            avatarValue: 'raccoon_1',
            createdAtIso: '2026-01-01T00:00:00.000Z',
          ),
        ],
        accountOwnerships: {
          'acc1': const AccountOwnership(
            accountId: 'acc1',
            personShares: {'p1': 1.0},
          ),
        },
        requirePasswordLogin: requirePasswordLogin,
      ),
      firefly: SettingsFireflyBundle(
        serverUrl: 'https://firefly.example',
        apiToken: apiToken ?? '',
        authMode: 'token',
        allowInsecure: true,
      ),
    );
  }

  test(
    'public JSON never contains plaintext token or password hashes',
    () async {
      final hashed = await hashPassword(passphrase);
      final bundle = sampleBundle(hashed: hashed);
      final sealed = await bundle.encodeSealed(passphrase);
      final json = jsonDecode(sealed) as Map<String, dynamic>;

      expect(sealed.contains('ff-token-secret'), isFalse);
      expect(sealed.contains(hashed.hash), isFalse);
      expect(sealed.contains(hashed.salt), isFalse);
      expect(sealed.contains(passphrase), isFalse);
      expect(json['secrets'], isA<Map>());
      expect(json['firefly']['serverUrl'], 'https://firefly.example');
      expect(json['firefly'].containsKey('apiToken'), isFalse);
      expect(json['people']['requirePasswordLogin'], isFalse);

      final alex = (json['people']['people'] as List).first as Map;
      expect(alex.containsKey('passwordHash'), isFalse);
      expect(alex['avatarKind'], 'none');
    },
  );

  test(
    'round-trip unlock restores token, hashes, and password-login',
    () async {
      final hashed = await hashPassword(passphrase);
      final sealed = await sampleBundle(
        hashed: hashed,
      ).encodeSealed(passphrase);
      final restored = await SettingsBundle.decode(
        sealed,
        passphrase: passphrase,
      );

      expect(restored.firefly?.apiToken, 'ff-token-secret');
      expect(restored.firefly?.serverUrl, 'https://firefly.example');
      expect(restored.firefly?.allowInsecure, isTrue);
      expect(restored.people.people.first.hasPassword, isTrue);
      expect(restored.people.people.first.passwordHash, hashed.hash);
      expect(restored.people.people.first.salt, hashed.salt);
      expect(restored.people.people[1].hasPassword, isTrue);
      expect(restored.people.requirePasswordLogin, isTrue);
      expect(
        await verifyPassword(
          passphrase,
          hash: restored.people.people.first.passwordHash!,
          salt: restored.people.people.first.salt!,
        ),
        isTrue,
      );
    },
  );

  test('wrong passphrase fails unlock', () async {
    final hashed = await hashPassword(passphrase);
    final sealed = await sampleBundle(hashed: hashed).encodeSealed(passphrase);
    await expectLater(
      () => SettingsBundle.decode(sealed, passphrase: 'Wrong-Horse9!'),
      throwsA(isA<SettingsSecretsUnlockException>()),
    );
  });

  test(
    'legacy file without secrets imports without passwords or token',
    () async {
      final source = '''
{
  "app": "fireracoon",
  "schemaVersion": 1,
  "exportedAt": "2026-08-04T00:00:00.000Z",
  "device": { "locale": "sv" },
  "firefly": {
    "serverUrl": "https://firefly.example",
    "apiToken": "should-be-ignored",
    "authMode": "token",
    "allowInsecure": true
  },
  "people": {
    "requirePasswordLogin": true,
    "people": [
      {
        "id": "p1",
        "name": "Alex",
        "colorValue": 4281559270,
        "avatarKind": "none",
        "role": "admin",
        "createdAtIso": "2026-01-01T00:00:00.000Z",
        "passwordHash": "should-be-ignored",
        "salt": "ignored"
      }
    ],
    "accountOwnerships": {}
  }
}
''';
      final bundle = await SettingsBundle.decode(source);
      expect(bundle.people.requirePasswordLogin, isFalse);
      expect(bundle.people.people.single.hasPassword, isFalse);
      expect(bundle.firefly?.serverUrl, 'https://firefly.example');
      expect(bundle.firefly?.apiToken, isEmpty);
    },
  );

  test('export without secrets skips passphrase and secrets blob', () async {
    final bundle = SettingsBundle(
      schemaVersion: kSettingsBundleSchemaVersion,
      exportedAtIso: '2026-08-04T00:00:00.000Z',
      device: const {},
      people: const SettingsPeopleBundle(
        people: [
          Person(
            id: 'p1',
            name: 'Alex',
            colorValue: 0xFF3B82F6,
            role: PersonRole.admin,
            createdAtIso: '2026-01-01T00:00:00.000Z',
          ),
        ],
      ),
      firefly: const SettingsFireflyBundle(
        serverUrl: 'https://firefly.example',
      ),
    );
    expect(bundle.needsSecretsPassphrase, isFalse);
    final sealed = await bundle.encodeSealed(null);
    final json = jsonDecode(sealed) as Map<String, dynamic>;
    expect(json.containsKey('secrets'), isFalse);
  });

  test('rejects unsupported schema versions', () async {
    expect(
      () => SettingsBundle.decode(
        '{"app":"fireracoon","schemaVersion":99,"people":{}}',
      ),
      throwsFormatException,
    );
  });

  test('rejects foreign app marker and missing people section', () async {
    expect(
      () => SettingsBundle.decode(
        '{"app":"other","schemaVersion":2,"people":{}}',
      ),
      throwsFormatException,
    );
    expect(
      () => SettingsBundle.decode('{"app":"fireracoon","schemaVersion":2}'),
      throwsFormatException,
    );
    expect(() => SettingsBundle.decode('[]'), throwsFormatException);
  });

  test('rejects server password placeholders from secrets payload', () async {
    final people = exportPeopleBundle(
      people: [
        const Person(
          id: 'p1',
          name: 'Alex',
          colorValue: 0xFF3B82F6,
          role: PersonRole.admin,
          passwordHash: 'server',
          salt: 'server',
          createdAtIso: '2026-01-01T00:00:00.000Z',
        ),
      ],
      accountOwnerships: const {},
      requirePasswordLogin: true,
    );
    expect(people.people.single.hasPassword, isFalse);
    expect(people.requirePasswordLogin, isFalse);
  });

  test('encodeSealed requires passphrase when secrets are present', () async {
    final hashed = await hashPassword(passphrase);
    final bundle = sampleBundle(hashed: hashed);
    await expectLater(() => bundle.encodeSealed(null), throwsArgumentError);
    await expectLater(() => bundle.encodeSealed(''), throwsArgumentError);
  });

  test('sourceHasSecrets detects sealed envelopes', () {
    expect(SettingsBundle.sourceHasSecrets('{"secrets":{}}'), isTrue);
    expect(SettingsBundle.sourceHasSecrets('{"people":{}}'), isFalse);
    expect(SettingsBundle.sourceHasSecrets('[]'), isFalse);
  });

  test(
    'public decode clears custom avatars and null classification values',
    () async {
      final bundle = await SettingsBundle.decode('''
{
  "app": "fireracoon",
  "schemaVersion": 2,
  "people": {
    "people": [
      {
        "id": "p1",
        "name": "Alex",
        "colorValue": 4281559270,
        "avatarKind": "custom",
        "avatarValue": "p1.png",
        "role": "admin",
        "createdAtIso": "2026-01-01T00:00:00.000Z"
      },
      "skip-me"
    ],
    "accountOwnerships": {}
  },
  "accountClassifications": { "acc1": null }
}
''');
      expect(bundle.people.people.single.avatarKind, AvatarKind.none);
      expect(bundle.accountClassifications['acc1'], '');
    },
  );

  test('copyWith updates only the api token', () {
    const firefly = SettingsFireflyBundle(
      serverUrl: 'https://firefly.example',
      apiToken: 'old',
      allowInsecure: true,
    );
    final next = firefly.copyWith(apiToken: 'new');
    expect(next.apiToken, 'new');
    expect(next.serverUrl, firefly.serverUrl);
    expect(next.allowInsecure, isTrue);
  });

  test('secrets without firefly URL keep token offline', () async {
    final hashed = await hashPassword(passphrase);
    final sealed = await sampleBundle(hashed: hashed).encodeSealed(passphrase);
    final json = jsonDecode(sealed) as Map<String, dynamic>;
    json.remove('firefly');
    final restored = await SettingsBundle.decode(
      jsonEncode(json),
      passphrase: passphrase,
    );
    expect(restored.firefly, isNull);
    expect(restored.people.people.first.hasPassword, isTrue);
  });
}
