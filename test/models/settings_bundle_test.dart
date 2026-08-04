import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/models/people_models.dart';
import 'package:fireracoon/models/settings_bundle.dart';
import 'package:fireracoon/utils/password_policy.dart';

void main() {
  test('export strips passwords, biometrics, and custom avatars', () {
    final hashed = hashPassword('Correct-Horse9!');
    final people = [
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
        avatarKind: AvatarKind.preset,
        avatarValue: 'raccoon_1',
        createdAtIso: '2026-01-01T00:00:00.000Z',
      ),
    ];

    final bundle = SettingsBundle(
      schemaVersion: kSettingsBundleSchemaVersion,
      exportedAtIso: '2026-08-04T00:00:00.000Z',
      device: {'locale': 'en', 'themeMode': 'dark'},
      people: exportPeopleBundle(
        people: people,
        accountOwnerships: {
          'acc1': const AccountOwnership(
            accountId: 'acc1',
            personShares: {'p1': 1.0},
          ),
        },
        requirePasswordLogin: true,
      ),
    );

    final json = bundle.toJson();
    final encoded = bundle.encodePretty();

    expect(encoded.contains('passwordHash'), isFalse);
    expect(encoded.contains('salt'), isFalse);
    expect(encoded.contains('Correct-Horse'), isFalse);
    expect(json['people']['requirePasswordLogin'], isTrue);

    final exportedPeople = json['people']['people'] as List<dynamic>;
    final alex = exportedPeople.first as Map<String, dynamic>;
    expect(alex['avatarKind'], 'none');
    expect(alex.containsKey('avatarValue'), isFalse);
    expect(alex['role'], 'admin');
    expect(alex['preferences']['localeCode'], 'fr');

    final sam = exportedPeople[1] as Map<String, dynamic>;
    expect(sam['avatarKind'], 'preset');
    expect(sam['avatarValue'], 'raccoon_1');
  });

  test('import decode clears password login and custom avatars', () {
    final source = '''
{
  "app": "fireracoon",
  "schemaVersion": 1,
  "exportedAt": "2026-08-04T00:00:00.000Z",
  "device": { "locale": "sv" },
  "people": {
    "requirePasswordLogin": true,
    "people": [
      {
        "id": "p1",
        "name": "Alex",
        "colorValue": 4281559270,
        "avatarKind": "custom",
        "avatarValue": "p1.png",
        "role": "admin",
        "createdAtIso": "2026-01-01T00:00:00.000Z",
        "passwordHash": "should-be-ignored",
        "salt": "ignored"
      }
    ],
    "accountOwnerships": {}
  },
  "accountClassifications": { "acc1": "savings" }
}
''';

    final bundle = SettingsBundle.decode(source);
    expect(bundle.people.requirePasswordLogin, isFalse);
    expect(bundle.people.people.single.hasPassword, isFalse);
    expect(bundle.people.people.single.avatarKind, AvatarKind.none);
    expect(bundle.accountClassifications['acc1'], 'savings');
    expect(bundle.device['locale'], 'sv');
  });

  test('rejects unsupported schema versions', () {
    expect(
      () => SettingsBundle.decode(
        '{"app":"fireracoon","schemaVersion":99,"people":{}}',
      ),
      throwsFormatException,
    );
  });

  test('rejects foreign app marker and missing people section', () {
    expect(
      () => SettingsBundle.decode(
        '{"app":"other","schemaVersion":1,"people":{}}',
      ),
      throwsFormatException,
    );
    expect(
      () => SettingsBundle.decode('{"app":"fireracoon","schemaVersion":1}'),
      throwsFormatException,
    );
    expect(() => SettingsBundle.decode('[]'), throwsFormatException);
  });

  test('decode accepts optional sections and list coercions', () {
    final bundle = SettingsBundle.decode('''
{
  "app": "fireracoon",
  "schemaVersion": 1,
  "people": { "people": [], "accountOwnerships": {} },
  "sideMenu": { "nodes": [] },
  "accountColumns": { "order": ["account"], "widths": {"account": 100} },
  "transactionColumns": { "order": ["date"], "widths": {"date": 80} },
  "prognosis": { "mode": "expected" },
  "tightRowsColumns": ["date", 2],
  "viewMode": "compact"
}
''');
    expect(bundle.sideMenu, isNotNull);
    expect(bundle.accountColumns, isNotNull);
    expect(bundle.transactionColumns, isNotNull);
    expect(bundle.prognosis, isNotNull);
    expect(bundle.tightRowsColumns, ['date', '2']);
    expect(bundle.viewMode, 'compact');
  });

  test('people section imports ownership maps and skips bad entries', () {
    final people = SettingsPeopleBundle.fromJson({
      'people': [
        {
          'id': 'p1',
          'name': 'Alex',
          'colorValue': 0xFF3B82F6,
          'createdAtIso': '2026-01-01T00:00:00.000Z',
          'avatarKind': 'custom',
          'avatarValue': 'p1.png',
        },
      ],
      'accountOwnerships': {
        'acc1': {
          'accountId': 'acc1',
          'personShares': {'p1': 1.0},
        },
        'acc-bad': 'not-a-map',
      },
      'requirePasswordLogin': true,
    });
    expect(people.requirePasswordLogin, isFalse);
    expect(people.people.single.avatarKind, AvatarKind.none);
    expect(people.accountOwnerships.keys, ['acc1']);
    expect(people.accountOwnerships['acc1']!.personShares['p1'], 1.0);
  });
}
