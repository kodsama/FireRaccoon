import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon_engine/models/account.dart';
import 'package:fireracoon/models/people_models.dart';

void main() {
  group('Person model tests', () {
    test('serializes and deserializes Person correctly', () {
      const person = Person(
        id: 'p1',
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        avatarKind: AvatarKind.preset,
        avatarValue: 'raccoon_1',
        createdAtIso: '2026-01-01T00:00:00.000Z',
      );

      final json = person.toJson();
      expect(json['id'], 'p1');
      expect(json['name'], 'Alex');
      expect(json['colorValue'], 0xFF3B82F6);
      expect(json['avatarKind'], 'preset');
      expect(json['avatarValue'], 'raccoon_1');

      final reconstructed = Person.fromJson(json);
      expect(reconstructed, equals(person));
    });

    test('reads legacy avatarIcon as preset', () {
      final person = Person.fromJson({
        'id': 'p1',
        'name': 'Alex',
        'colorValue': 0xFF3B82F6,
        'avatarIcon': 'raccoon_2',
      });
      expect(person.avatarKind, AvatarKind.preset);
      expect(person.avatarValue, 'raccoon_2');
    });

    test('fromServerPublic maps admin bootstrap payload', () {
      final person = Person.fromServerPublic({
        'id': 'admin_1',
        'name': 'Alex',
        'colorValue': 0xFF1565C0,
        'avatarKind': 'none',
        'role': 'admin',
        'createdAt': '2026-08-05T00:00:00.000Z',
        'hasPassword': true,
        'preferences': {'themeModeName': 'dark'},
      });
      expect(person.id, 'admin_1');
      expect(person.role, PersonRole.admin);
      expect(person.hasPassword, isTrue);
      expect(person.createdAtIso, '2026-08-05T00:00:00.000Z');
      expect(person.preferences.themeModeName, 'dark');
    });

    test('fromServerPublic accepts untyped preference maps', () {
      final person = Person.fromServerPublic({
        'id': 'p2',
        'name': 'Sam',
        'hasPassword': false,
        'preferences': <dynamic, dynamic>{'themeModeName': 'system'},
      });
      expect(person.preferences.themeModeName, 'system');
      expect(person.hasPassword, isFalse);
      expect(person.createdAtIso, isNotEmpty);
    });

    test('copyWith, color, and hashCode preserve value semantics', () {
      const person = Person(
        id: 'p1',
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        avatarKind: AvatarKind.preset,
        avatarValue: 'raccoon_1',
        createdAtIso: '2026-01-01T00:00:00.000Z',
      );

      final copy = person.copyWith(name: 'Sam', colorValue: 0xFF10B981);

      expect(person.color.toARGB32(), 0xFF3B82F6);
      expect(person.copyWith(), person);
      expect(copy.id, 'p1');
      expect(copy.name, 'Sam');
      expect(copy.colorValue, 0xFF10B981);
      expect(copy.avatarValue, 'raccoon_1');
      expect(Person.fromJson(person.toJson()).hashCode, person.hashCode);
    });

    test('hasPassword is false when hash or salt missing', () {
      const person = Person(
        id: 'p1',
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        createdAtIso: '2026-01-01T00:00:00.000Z',
      );
      expect(person.hasPassword, isFalse);
    });

    test('admin helpers keep at least one admin', () {
      const alex = Person(
        id: 'p1',
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        role: PersonRole.user,
        createdAtIso: '2026-01-01T00:00:00.000Z',
      );
      const sam = Person(
        id: 'p2',
        name: 'Sam',
        colorValue: 0xFF10B981,
        role: PersonRole.admin,
        createdAtIso: '2026-01-01T00:00:00.000Z',
      );

      expect(peopleHasAdmin(const [alex]), isFalse);
      expect(peopleHasAdmin(const [alex, sam]), isTrue);
      expect(isSoleAdmin(const [sam], 'p2'), isTrue);
      expect(isSoleAdmin(const [alex, sam], 'p2'), isTrue);
      expect(
        isSoleAdmin(const [
          alex,
          sam,
          Person(
            id: 'p3',
            name: 'Leo',
            colorValue: 0xFFF59E0B,
            role: PersonRole.admin,
            createdAtIso: '2026-01-01T00:00:00.000Z',
          ),
        ], 'p2'),
        isFalse,
      );
      expect(ensureAtLeastOneAdmin(const [alex]).single.role, PersonRole.admin);
      expect(ensureAtLeastOneAdmin(const [alex, sam]).map((p) => p.role), [
        PersonRole.user,
        PersonRole.admin,
      ]);
    });
  });

  group('AccountOwnershipConfig ratio split calculations', () {
    const alex = Person(
      id: 'p_alex',
      name: 'Alex',
      colorValue: 0xFF3B82F6,
      createdAtIso: '2026-01-01T00:00:00.000Z',
    );
    const sam = Person(
      id: 'p_sam',
      name: 'Sam',
      colorValue: 0xFF10B981,
      createdAtIso: '2026-01-01T00:00:00.000Z',
    );
    const leo = Person(
      id: 'p_leo',
      name: 'Leo',
      colorValue: 0xFF8B5CF6,
      createdAtIso: '2026-01-01T00:00:00.000Z',
    );

    final config = AccountOwnershipConfig(
      version: 1,
      people: const [alex, sam, leo],
      accountOwnerships: {
        'acc_single': const AccountOwnership(
          accountId: 'acc_single',
          personShares: {'p_alex': 1.0},
        ),
        'acc_equal_2': const AccountOwnership(
          accountId: 'acc_equal_2',
          personShares: {'p_alex': 0.5, 'p_sam': 0.5},
        ),
        'acc_equal_3': const AccountOwnership(
          accountId: 'acc_equal_3',
          personShares: {
            'p_alex': 1.0 / 3.0,
            'p_sam': 1.0 / 3.0,
            'p_leo': 1.0 / 3.0,
          },
        ),
        'acc_custom_80_20': const AccountOwnership(
          accountId: 'acc_custom_80_20',
          personShares: {'p_alex': 0.8, 'p_sam': 0.2},
        ),
        'acc_unassigned': const AccountOwnership(
          accountId: 'acc_unassigned',
          personShares: {},
        ),
      },
    );

    test(
      'All People view (personId == null) returns 1.0 (100%) for all accounts',
      () {
        expect(config.getOwnershipRatio('acc_single', null), 1.0);
        expect(config.getOwnershipRatio('acc_equal_2', null), 1.0);
        expect(config.getOwnershipRatio('acc_custom_80_20', null), 1.0);
        expect(config.getOwnershipRatio('acc_unassigned', null), 1.0);
      },
    );

    test('Single owner gets 100% and non-owner gets 0%', () {
      expect(config.getOwnershipRatio('acc_single', 'p_alex'), 1.0);
      expect(config.getOwnershipRatio('acc_single', 'p_sam'), 0.0);
      expect(config.getOwnershipRatio('acc_single', 'p_leo'), 0.0);
    });

    test('2 shared equal owners get 50% (0.5) each', () {
      expect(config.getOwnershipRatio('acc_equal_2', 'p_alex'), 0.5);
      expect(config.getOwnershipRatio('acc_equal_2', 'p_sam'), 0.5);
      expect(config.getOwnershipRatio('acc_equal_2', 'p_leo'), 0.0);
    });

    test('3 shared equal owners get 33.3% (1/3) each', () {
      expect(
        config.getOwnershipRatio('acc_equal_3', 'p_alex'),
        closeTo(0.3333333333333333, 0.0001),
      );
      expect(
        config.getOwnershipRatio('acc_equal_3', 'p_sam'),
        closeTo(0.3333333333333333, 0.0001),
      );
      expect(
        config.getOwnershipRatio('acc_equal_3', 'p_leo'),
        closeTo(0.3333333333333333, 0.0001),
      );
    });

    test(
      'Custom percentage split (Alex 80%, Sam 20%) calculates correctly',
      () {
        expect(config.getOwnershipRatio('acc_custom_80_20', 'p_alex'), 0.8);
        expect(config.getOwnershipRatio('acc_custom_80_20', 'p_sam'), 0.2);
        expect(config.getOwnershipRatio('acc_custom_80_20', 'p_leo'), 0.0);
      },
    );

    test('Unassigned accounts return 1.0 (100%) across all person views', () {
      expect(config.getOwnershipRatio('acc_unassigned', 'p_alex'), 1.0);
      expect(config.getOwnershipRatio('acc_unassigned', 'p_sam'), 1.0);
      expect(config.getOwnershipRatio('acc_missing', 'p_alex'), 1.0);
    });

    test('Effective balance calculation scales current balance properly', () {
      final loanAccount = Account(
        id: 'acc_custom_80_20',
        name: 'House Loan',
        type: 'liability',
        role: 'defaultAsset',
        currentBalance: -200000.0,
        currencySymbol: '€',
        currencyCode: 'EUR',
      );

      expect(config.getEffectiveBalance(loanAccount, 'p_alex'), -160000.0);
      expect(config.getEffectiveBalance(loanAccount, 'p_sam'), -40000.0);
    });

    test('Versioned JSON encoding and decoding works seamlessly', () {
      final encoded = config.encode();
      final decoded = AccountOwnershipConfig.decode(encoded);

      expect(decoded.version, 1);
      expect(decoded.people.length, 3);
      expect(decoded.getOwnershipRatio('acc_custom_80_20', 'p_alex'), 0.8);
      expect(decoded.getOwnershipRatio('acc_custom_80_20', 'p_sam'), 0.2);
    });

    test('owner lookup returns assigned people and ignores unknown ids', () {
      expect(config.accountOwnerships['acc_equal_2']!.ownerIds, [
        'p_alex',
        'p_sam',
      ]);
      expect(
        config.getOwnersForAccount('acc_equal_2').map((person) => person.id),
        ['p_alex', 'p_sam'],
      );
      expect(config.getOwnersForAccount('acc_unassigned'), isEmpty);
      expect(config.getOwnersForAccount('missing'), isEmpty);
    });

    test('copyWith replaces selected configuration fields', () {
      final copy = config.copyWith(
        version: 2,
        people: const [alex],
        accountOwnerships: const {},
      );

      expect(copy.version, 2);
      expect(copy.people, [alex]);
      expect(copy.accountOwnerships, isEmpty);
    });

    test('decode returns defaults for malformed JSON', () {
      final decoded = AccountOwnershipConfig.decode('not-json');

      expect(decoded.version, 1);
      expect(decoded.people, isEmpty);
      expect(decoded.accountOwnerships, isEmpty);
    });
  });

  group('PeopleAuthStorage', () {
    test('reads legacy requireLogin and supports copyWith', () {
      final auth = PeopleAuthStorage.fromJson({
        'requireLogin': true,
        'byPersonId': {
          'p1': {'role': 'admin'},
          'bad': 'skip-me',
        },
      });
      expect(auth.requirePasswordLogin, isTrue);
      expect(auth.byPersonId.keys, ['p1']);

      final copy = auth.copyWith(
        byPersonId: const {},
        requirePasswordLogin: false,
      );
      expect(copy.byPersonId, isEmpty);
      expect(copy.requirePasswordLogin, isFalse);
      final unchanged = auth.copyWith();
      expect(unchanged.requirePasswordLogin, auth.requirePasswordLogin);
      expect(unchanged.byPersonId, auth.byPersonId);
    });
  });
}
