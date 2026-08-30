import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/password_cost.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireraccoon_engine/models/account.dart';
import 'package:fireraccoon_engine/models/transaction.dart';
import 'package:fireraccoon/deployment/deployment_providers.dart';
import 'package:fireraccoon/deployment/fireraccoon_mode.dart';
import 'package:fireraccoon/models/app_user_models.dart';
import 'package:fireraccoon/models/people_models.dart';
import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/dashboard_stats_providers.dart';
import 'package:fireraccoon/providers/people_providers.dart';
import 'package:fireraccoon/providers/server_session_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/store/remote_server_client.dart';

import '../helpers/fake_biometric_auth.dart';
import '../helpers/fixed_accounts_notifier.dart';
import '../helpers/fixed_transactions_notifier.dart';
import '../helpers/mock_firefly_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
  });

  Future<SharedPreferences> freshPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  Future<ProviderContainer> buildContainer({
    SharedPreferences? prefs,
    List<Override>? extraOverrides,
  }) async {
    final resolvedPrefs = prefs ?? await freshPrefs();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(resolvedPrefs),
        peopleProvider.overrideWith(
          () => PeopleNotifier(
            storage: const FlutterSecureStorage(),
            biometricAuth: FakeBiometricAuth(),
            pbkdf2Iterations: kTestPbkdf2Iterations,
          ),
        ),
        ...?extraOverrides,
      ],
    );
  }

  Future<void> waitHydrated(ProviderContainer container) async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (container.read(peopleProvider).isHydrated) return;
    }
    fail('people provider never hydrated');
  }

  group('ActivePersonFilterNotifier tests', () {
    test('starts with null (All People) and updates filter state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(activePersonFilterProvider), null);

      container
          .read(activePersonFilterProvider.notifier)
          .setPersonFilter('person_1');
      expect(container.read(activePersonFilterProvider), 'person_1');

      container.read(activePersonFilterProvider.notifier).clearFilter();
      expect(container.read(activePersonFilterProvider), null);
    });
  });

  group('PeopleNotifier ownership tests', () {
    test('adds person and persists locally', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      await container
          .read(peopleProvider.notifier)
          .addPerson(name: 'Alex', colorValue: 0xFF3B82F6);

      final config = container.read(peopleSettingsProvider);
      expect(config.people.length, 1);
      expect(config.people.first.name, 'Alex');
    });

    test('setPresetAvatar persists and survives provider reload', () async {
      final prefs = await freshPrefs();
      final container = await buildContainer(prefs: prefs);
      addTearDown(container.dispose);
      await waitHydrated(container);

      final notifier = container.read(peopleProvider.notifier);
      final person = await notifier.addPerson(
        name: 'Alex',
        colorValue: 0xFF10B981,
      );
      await notifier.setPresetAvatar(person.id, 'raccoon_2');

      final updated = container.read(peopleProvider).people.single;
      expect(updated.avatarKind, AvatarKind.preset);
      expect(updated.avatarValue, 'raccoon_2');

      // Reload from the same SharedPreferences mock.
      final reloaded = await buildContainer(prefs: prefs);
      addTearDown(reloaded.dispose);
      await waitHydrated(reloaded);
      final again = reloaded.read(peopleProvider).people.single;
      expect(again.avatarKind, AvatarKind.preset);
      expect(again.avatarValue, 'raccoon_2');
    });

    test(
      'sets account ownership and calculates effective account balances',
      () async {
        final container = await buildContainer();
        addTearDown(container.dispose);
        await waitHydrated(container);

        final notifier = container.read(peopleProvider.notifier);
        await notifier.addPerson(name: 'Alex', colorValue: 0xFF3B82F6);
        await notifier.addPerson(name: 'Sam', colorValue: 0xFF10B981);

        final people = container.read(peopleProvider).people;
        expect(
          people.length,
          2,
          reason:
              'Expected exactly 2 people, got: ${people.map((p) => p.name).toList()}',
        );
        final alexId = people.firstWhere((p) => p.name == 'Alex').id;
        final samId = people.firstWhere((p) => p.name == 'Sam').id;

        await notifier.setAccountOwners(
          'loan_1',
          customShares: {alexId: 0.8, samId: 0.2},
        );

        final config = container.read(peopleSettingsProvider);
        expect(config.getOwnershipRatio('loan_1', alexId), 0.8);
        expect(config.getOwnershipRatio('loan_1', samId), 0.2);

        final loanAccount = Account(
          id: 'loan_1',
          name: 'Mortgage',
          type: 'liability',
          role: 'defaultAsset',
          currentBalance: -200000.0,
          currencySymbol: '€',
          currencyCode: 'EUR',
        );

        expect(config.getEffectiveBalance(loanAccount, alexId), -160000.0);
        expect(config.getEffectiveBalance(loanAccount, samId), -40000.0);
      },
    );

    test(
      'updates and removes people while normalizing remaining shares',
      () async {
        final prefs = await freshPrefs();
        final container = await buildContainer(prefs: prefs);
        addTearDown(container.dispose);
        await waitHydrated(container);

        final notifier = container.read(peopleProvider.notifier);
        await notifier.addPerson(name: 'Alex', colorValue: 0xFF3B82F6);
        await notifier.addPerson(name: 'Sam', colorValue: 0xFF10B981);
        await notifier.addPerson(name: 'Leo', colorValue: 0xFF8B5CF6);
        final people = container.read(peopleProvider).people;
        final alex = people[0];
        final sam = people[1];
        final leo = people[2];

        await notifier.updatePerson(sam.copyWith(name: 'Samuel'));
        await notifier.setAccountOwners(
          'shared',
          ownerIds: [alex.id, sam.id, leo.id],
        );
        container
            .read(activePersonFilterProvider.notifier)
            .setPersonFilter(sam.id);
        await notifier.removePerson(sam.id);

        final config = container.read(peopleSettingsProvider);
        expect(config.people.map((person) => person.name), ['Alex', 'Leo']);
        expect(config.getOwnershipRatio('shared', alex.id), 0.5);
        expect(config.getOwnershipRatio('shared', leo.id), 0.5);
        expect(container.read(activePersonFilterProvider), isNull);

        await notifier.setAccountOwners('shared');
        expect(
          container.read(peopleSettingsProvider).accountOwnerships,
          isEmpty,
        );
        expect(prefs.getString(kPeopleConfigPreferenceKey), isNotNull);
      },
    );

    test('loads a locally persisted people configuration', () async {
      final encoded = AccountOwnershipConfig(
        people: [
          Person(
            id: 'p1',
            name: 'Alex',
            colorValue: 0xFF3B82F6,
            createdAtIso: '2026-01-01T00:00:00.000',
          ),
        ],
      ).encode();
      SharedPreferences.setMockInitialValues({
        kPeopleConfigPreferenceKey: encoded,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = await buildContainer(prefs: prefs);
      addTearDown(container.dispose);
      await waitHydrated(container);

      expect(container.read(peopleSettingsProvider).people.single.name, 'Alex');
    });

    test('syncs remote people configuration and writes updates back', () async {
      final prefs = await freshPrefs();
      final service = FakeFireflyService();
      service.preferences[kPeopleConfigPreferenceKey] = {
        'version': 1,
        'people': [
          {'id': 'p1', 'name': 'Remote', 'colorValue': 0xFF3B82F6},
        ],
        'accountOwnerships': <String, dynamic>{},
      };
      final container = await buildContainer(
        prefs: prefs,
        extraOverrides: [apiServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        peopleProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await waitHydrated(container);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(peopleSettingsProvider).people.single.name,
        'Remote',
      );

      await container
          .read(peopleProvider.notifier)
          .addPerson(name: 'Local', colorValue: 0xFF10B981);

      expect(
        service.preferences[kPeopleConfigPreferenceKey],
        isA<Map<String, dynamic>>(),
      );
    });

    test('decodes remote people configuration returned as text', () async {
      final prefs = await freshPrefs();
      final service = FakeFireflyService();
      service.preferences[kPeopleConfigPreferenceKey] = AccountOwnershipConfig(
        people: [
          Person(
            id: 'p1',
            name: 'Remote',
            colorValue: 0xFF3B82F6,
            createdAtIso: '2026-01-01T00:00:00.000',
          ),
        ],
      ).encode();
      final container = await buildContainer(
        prefs: prefs,
        extraOverrides: [apiServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        peopleProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await waitHydrated(container);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(peopleSettingsProvider).people.single.name,
        'Remote',
      );
    });

    test(
      'effective providers apply ownership to accounts and transactions',
      () async {
        final prefs = await freshPrefs();
        final account = Account(
          id: 'account-1',
          name: 'Checking',
          type: 'asset',
          role: 'defaultAsset',
          currentBalance: 100,
          currencySymbol: '€',
          currencyCode: 'EUR',
        );
        final transaction = Transaction(
          id: 'tx-1',
          type: 'withdrawal',
          date: DateTime(2026, 7, 30),
          amount: 10,
          description: 'Groceries',
          sourceId: account.id,
          sourceName: account.name,
          destinationName: 'Shop',
          categoryName: 'Food',
          currencySymbol: '€',
          currencyCode: 'EUR',
        );
        final container = await buildContainer(
          prefs: prefs,
          extraOverrides: [
            accountsProvider.overrideWith(
              () => FixedAccountsNotifier([account]),
            ),
            transactionsProvider.overrideWith(
              () => FixedTransactionsNotifier([transaction]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await waitHydrated(container);

        final notifier = container.read(peopleProvider.notifier);
        await notifier.addPerson(name: 'Alex', colorValue: 0xFF3B82F6);
        final personId = container.read(peopleProvider).people.single.id;
        await notifier.setAccountOwners(
          account.id,
          customShares: {personId: 0.25},
        );
        container
            .read(activePersonFilterProvider.notifier)
            .setPersonFilter(personId);

        await container.read(accountsProvider.future);
        await container.read(transactionsProvider.future);
        // A quarter share of a joint account is what counts towards this
        // person's net worth, and the account still holds all of it.
        expect(
          container.read(shareWeightedAccountsProvider).single.currentBalance,
          25,
        );
        expect(
          container.read(ownedAccountsProvider).single.currentBalance,
          100,
        );
        expect(container.read(filteredTransactionsProvider).single.id, 'tx-1');

        // The account card reads its headline figure off the projection, so a
        // projection built from share-weighted balances was what put a quarter
        // of a joint account where its balance belongs.
        final prognosis = container
            .read(accountPrognosisProvider)
            .forAccount(account.id);
        expect(prognosis, isNotNull);
        expect(prognosis!.currentBalance, 100);

        // Net worth is the one place the share is the answer.
        expect(container.read(netWorthBreakdownProvider).netWorth, 25);
      },
    );

    test('filtered transactions include destination-owned accounts', () async {
      final prefs = await freshPrefs();
      final destination = Account(
        id: 'account-2',
        name: 'Savings',
        type: 'asset',
        role: 'defaultAsset',
        currentBalance: 100,
        currencySymbol: '€',
        currencyCode: 'EUR',
      );
      final transaction = Transaction(
        id: 'tx-2',
        type: 'deposit',
        date: DateTime(2026, 7, 30),
        amount: 10,
        description: 'Salary',
        sourceName: 'Employer',
        destinationId: destination.id,
        destinationName: destination.name,
        categoryName: '',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );
      final container = await buildContainer(
        prefs: prefs,
        extraOverrides: [
          accountsProvider.overrideWith(
            () => FixedAccountsNotifier([destination]),
          ),
          transactionsProvider.overrideWith(
            () => FixedTransactionsNotifier([transaction]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await waitHydrated(container);

      final notifier = container.read(peopleProvider.notifier);
      await notifier.addPerson(name: 'Alex', colorValue: 0xFF3B82F6);
      final personId = container.read(peopleProvider).people.single.id;
      await notifier.setAccountOwners(
        destination.id,
        customShares: {personId: 1},
      );
      container
          .read(activePersonFilterProvider.notifier)
          .setPersonFilter(personId);
      await container.read(transactionsProvider.future);

      expect(container.read(filteredTransactionsProvider).single.id, 'tx-2');
    });
  });

  group('PeopleNotifier avatar and password edge cases', () {
    test('rejects invalid avatar and password operations', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);

      final notifier = container.read(peopleProvider.notifier);
      final person = await notifier.addPerson(
        name: 'Alex',
        colorValue: 0xFF3B82F6,
      );

      expect(notifier.biometricAuth, isA<FakeBiometricAuth>());
      expect(
        () => notifier.saveCustomAvatar(person.id, Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => notifier.setPresetAvatar(person.id, 'not-a-preset'),
        throwsArgumentError,
      );
      expect(
        () => notifier.setPresetAvatar('missing', 'raccoon_1'),
        throwsArgumentError,
      );
      expect(() => notifier.clearAvatar('missing'), throwsArgumentError);
      expect(
        () => notifier.setPassword(person.id, 'short'),
        throwsArgumentError,
      );
      expect(
        () => notifier.setPassword('missing', 'Correct-Horse9!'),
        throwsArgumentError,
      );

      await notifier.setPassword(person.id, 'Correct-Horse9!');
      await notifier.setRequirePasswordLogin(true);
      expect(() => notifier.clearPassword(person.id), throwsStateError);
      await notifier.setRequirePasswordLogin(false);
      await notifier.clearPassword(person.id);
      expect(() => notifier.clearPassword('missing'), throwsArgumentError);

      await notifier.setPassword(person.id, 'Correct-Horse9!');
      await notifier.addPerson(
        name: 'Taken',
        colorValue: 0xFF10B981,
        password: 'Correct-Horse9!',
      );
      expect(
        () => notifier.updatePerson(person.copyWith(name: 'Taken')),
        throwsArgumentError,
      );

      await notifier.setRequirePasswordLogin(true);
      final alex = container
          .read(peopleProvider)
          .people
          .firstWhere((p) => p.id == person.id);
      await expectLater(
        notifier.updatePerson(alex.copyWith(clearPassword: true)),
        throwsA(isA<StateError>()),
      );
      await notifier.setRequirePasswordLogin(false);

      expect(
        () =>
            notifier.saveCustomAvatar('missing', Uint8List.fromList([1, 2, 3])),
        throwsArgumentError,
      );

      final customPerson = alex.copyWith(
        avatarKind: AvatarKind.custom,
        clearAvatarValue: true,
      );
      expect(await notifier.resolveCustomAvatarBytes(customPerson), isNull);

      await notifier.login('Alex', 'Correct-Horse9!');
      await notifier.importSettings(
        people: container.read(peopleProvider).people,
        accountOwnerships: const {},
        requirePasswordLogin: false,
      );
      expect(container.read(peopleProvider).loggedInPersonId, person.id);
    });

    test('migrates legacy app users from secure storage', () async {
      final hashed = await hashTestPassword('Correct-Horse9!');
      final legacy = AppUsersStorage(
        users: [
          AppUser(
            id: 'u1',
            username: 'alex',
            passwordHash: hashed.hash,
            salt: hashed.salt,
            role: AppUserRole.admin,
            personId: 'p1',
            createdAtIso: '2026-01-01T00:00:00.000Z',
          ),
        ],
      );
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
        'app_users_v1': legacy.encode(),
        'app_users_session_id': 'p1',
        'app_users_last_user_id': 'p1',
      });
      final encoded = AccountOwnershipConfig(
        people: [
          Person(
            id: 'p1',
            name: 'Alex',
            colorValue: 0xFF3B82F6,
            createdAtIso: '2026-01-01T00:00:00.000Z',
          ),
        ],
      ).encode();
      SharedPreferences.setMockInitialValues({
        kPeopleConfigPreferenceKey: encoded,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = await buildContainer(prefs: prefs);
      addTearDown(container.dispose);
      await waitHydrated(container);

      final person = container.read(peopleProvider).people.single;
      expect(person.role, PersonRole.admin);
      expect(person.hasPassword, isTrue);
    });

    test('merges remote profiles while keeping local auth fields', () async {
      final hashed = await hashTestPassword('Correct-Horse9!');
      final local = AccountOwnershipConfig(
        people: [
          Person(
            id: 'p1',
            name: 'Local',
            colorValue: 0xFF3B82F6,
            role: PersonRole.admin,
            passwordHash: hashed.hash,
            salt: hashed.salt,
            createdAtIso: '2026-01-01T00:00:00.000Z',
            preferences: const PersonPreferences(localeCode: 'fr'),
            biometricsEnabled: true,
          ),
        ],
      );
      // Seed auth so hydrate does not rewrite Firefly prefs before fetch.
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
        kPeopleAuthStorageKey: PeopleAuthStorage(
          byPersonId: {
            'p1': {
              'role': 'admin',
              'passwordHash': hashed.hash,
              'salt': hashed.salt,
              'biometricsEnabled': true,
              'preferences': {'localeCode': 'fr'},
            },
          },
        ).encode(),
      });
      SharedPreferences.setMockInitialValues({
        kPeopleConfigPreferenceKey: local.encode(),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = FakeFireflyService();
      service.preferences[kPeopleConfigPreferenceKey] = {
        'version': 1,
        'people': [
          {
            'id': 'p1',
            'name': 'Remote',
            'colorValue': 0xFF10B981,
            'role': 'viewer',
            'createdAtIso': '2026-01-01T00:00:00.000Z',
          },
        ],
        'accountOwnerships': <String, dynamic>{},
      };
      final container = await buildContainer(
        prefs: prefs,
        extraOverrides: [apiServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        peopleProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await waitHydrated(container);
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (container.read(peopleProvider).people.single.name == 'Remote') {
          break;
        }
      }

      final person = container.read(peopleProvider).people.single;
      expect(person.name, 'Remote');
      expect(person.role, PersonRole.admin);
      expect(person.hasPassword, isTrue);
      expect(person.preferences.localeCode, 'fr');
      expect(person.biometricsEnabled, isTrue);
    });

    test(
      'rewrites remote config when a newer local write wins the race',
      () async {
        final prefs = await freshPrefs();
        final gate = Completer<void>();
        var setCalls = 0;
        final service = _GatedPrefService(gate: gate, onSet: () => setCalls++);
        final container = await buildContainer(
          prefs: prefs,
          extraOverrides: [apiServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);
        await waitHydrated(container);

        final notifier = container.read(peopleProvider.notifier);
        final first = notifier.addPerson(name: 'Alex', colorValue: 0xFF3B82F6);
        // Let the first persist reach the gated setPreference.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final second = notifier.addPerson(name: 'Sam', colorValue: 0xFF10B981);
        gate.complete();
        await Future.wait([first, second]);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(setCalls, greaterThanOrEqualTo(2));
        final remote = service.preferences[kPeopleConfigPreferenceKey];
        expect(remote, isA<Map<String, dynamic>>());
        final people = (remote as Map<String, dynamic>)['people'] as List;
        expect(people, hasLength(2));
      },
    );
  });

  group('PeopleNotifier importSettings', () {
    test(
      'applies people, ownerships and policy, and survives a reload',
      () async {
        final prefs = await freshPrefs();
        final container = await buildContainer(prefs: prefs);
        addTearDown(container.dispose);
        await waitHydrated(container);

        final ana = await hashTestPassword('Import-Horse9!');
        final bo = await hashTestPassword('Second-Horse9!');
        await container
            .read(peopleProvider.notifier)
            .importSettings(
              people: [
                Person(
                  id: 'ana',
                  name: 'Ana',
                  colorValue: 0xFF3B82F6,
                  role: PersonRole.admin,
                  passwordHash: ana.hash,
                  salt: ana.salt,
                  createdAtIso: '2026-02-01T00:00:00.000Z',
                ),
                Person(
                  id: 'bo',
                  name: 'Bo',
                  colorValue: 0xFF10B981,
                  passwordHash: bo.hash,
                  salt: bo.salt,
                  createdAtIso: '2026-02-02T00:00:00.000Z',
                ),
              ],
              accountOwnerships: const {
                'acc-9': AccountOwnership(
                  accountId: 'acc-9',
                  personShares: {'ana': 0.6, 'bo': 0.4},
                ),
              },
              requirePasswordLogin: true,
            );

        final state = container.read(peopleProvider);
        expect(state.people.map((p) => p.id), ['ana', 'bo']);
        expect(state.requirePasswordLogin, isTrue);
        expect(state.config.getOwnershipRatio('acc-9', 'ana'), 0.6);

        // An import that only lands in memory looks fine until the next launch,
        // so reload from the same prefs and keychain.
        final reloaded = await buildContainer(prefs: prefs);
        addTearDown(reloaded.dispose);
        await waitHydrated(reloaded);

        final restored = reloaded.read(peopleProvider);
        expect(restored.people.map((p) => p.id), ['ana', 'bo']);
        expect(restored.requirePasswordLogin, isTrue);
        expect(restored.config.getOwnershipRatio('acc-9', 'bo'), 0.4);
        expect(
          await reloaded
              .read(peopleProvider.notifier)
              .login('Ana', 'Import-Horse9!'),
          isNotNull,
          reason: 'imported password material must reach secure storage',
        );
      },
    );

    test(
      'drops the session when the file omits the logged-in person',
      () async {
        final container = await buildContainer();
        addTearDown(container.dispose);
        await waitHydrated(container);

        final notifier = container.read(peopleProvider.notifier);
        final alex = await notifier.addPerson(
          name: 'Alex',
          colorValue: 0xFF3B82F6,
        );
        expect(container.read(peopleProvider).loggedInPersonId, alex.id);
        expect(container.read(activePersonFilterProvider), alex.id);

        await notifier.importSettings(
          people: [
            Person(
              id: 'ana',
              name: 'Ana',
              colorValue: 0xFF10B981,
              role: PersonRole.admin,
              createdAtIso: '2026-02-01T00:00:00.000Z',
            ),
          ],
          accountOwnerships: const {},
          requirePasswordLogin: false,
        );

        expect(container.read(peopleProvider).loggedInPersonId, isNull);
        expect(container.read(activePersonFilterProvider), isNull);
        expect(
          await const FlutterSecureStorage().read(key: kPeopleSessionKey),
          isNull,
          reason:
              'a stale session id would log in a person who no longer exists',
        );
      },
    );

    test(
      'leaves login-with-password off for a server placeholder hash',
      () async {
        final container = await buildContainer();
        addTearDown(container.dispose);
        await waitHydrated(container);

        final ana = await hashTestPassword('Import-Horse9!');
        await container
            .read(peopleProvider.notifier)
            .importSettings(
              people: [
                Person(
                  id: 'ana',
                  name: 'Ana',
                  colorValue: 0xFF3B82F6,
                  role: PersonRole.admin,
                  passwordHash: ana.hash,
                  salt: ana.salt,
                  createdAtIso: '2026-02-01T00:00:00.000Z',
                ),
                Person(
                  id: 'bo',
                  name: 'Bo',
                  colorValue: 0xFF10B981,
                  passwordHash: 'server',
                  salt: 'server',
                  createdAtIso: '2026-02-02T00:00:00.000Z',
                ),
              ],
              accountOwnerships: const {},
              requirePasswordLogin: true,
            );

        final state = container.read(peopleProvider);
        expect(
          state.requirePasswordLogin,
          isFalse,
          reason: 'Bo has no usable hash, so the gate would lock everyone out',
        );
        expect(
          state.people.firstWhere((p) => p.id == 'ana').hasPassword,
          isTrue,
        );
        expect(
          state.people.firstWhere((p) => p.id == 'bo').hasPassword,
          isFalse,
        );
      },
    );
  });

  group('PeopleNotifier secure storage failures', () {
    test(
      'keeps hydrating and editing people when the keychain fails',
      () async {
        final encoded = AccountOwnershipConfig(
          people: [
            Person(
              id: 'p1',
              name: 'Alex',
              colorValue: 0xFF3B82F6,
              role: PersonRole.admin,
              createdAtIso: '2026-01-01T00:00:00.000Z',
            ),
          ],
        ).encode();
        SharedPreferences.setMockInitialValues({
          kPeopleConfigPreferenceKey: encoded,
        });
        final prefs = await SharedPreferences.getInstance();
        FlutterSecureStoragePlatform.instance = _FailingSecureStoragePlatform(
          {},
        );

        final container = await buildContainer(prefs: prefs);
        addTearDown(container.dispose);
        await waitHydrated(container);

        expect(
          container.read(peopleProvider).people.single.id,
          'p1',
          reason: 'prefs still hold the profiles when auth reads fail',
        );

        final notifier = container.read(peopleProvider.notifier);
        await notifier.addPerson(name: 'Sam', colorValue: 0xFF10B981);
        expect(container.read(peopleProvider).people, hasLength(2));
        expect(prefs.getString(kPeopleConfigPreferenceKey), contains('Sam'));
      },
    );

    test('switches session in memory when keychain writes fail', () async {
      const person = Person(
        id: 'p1',
        name: 'Alex',
        colorValue: 0xFF3B82F6,
        role: PersonRole.admin,
        createdAtIso: '2026-01-01T00:00:00.000Z',
      );
      SharedPreferences.setMockInitialValues({
        kPeopleConfigPreferenceKey: const AccountOwnershipConfig(
          people: [person],
        ).encode(),
      });
      final prefs = await SharedPreferences.getInstance();
      // Readable store, unwritable device: a passwordless setup, so selecting
      // a person is meant to succeed even though the session cannot be saved.
      FlutterSecureStoragePlatform.instance = _FailingSecureStoragePlatform({
        kPeopleAuthStorageKey: PeopleAuthStorage(
          byPersonId: {'p1': person.toAuthJson()},
        ).encode(),
      }, failReads: false);

      final container = await buildContainer(prefs: prefs);
      addTearDown(container.dispose);
      await waitHydrated(container);

      final notifier = container.read(peopleProvider.notifier);
      await notifier.selectPerson('p1');
      expect(container.read(peopleProvider).loggedInPersonId, 'p1');

      await notifier.logout();
      final state = container.read(peopleProvider);
      expect(state.loggedInPersonId, isNull);
      expect(state.lastSessionPersonId, 'p1');
    });
  });

  group('PeopleNotifier server mode', () {
    Map<String, dynamic> serverPeopleState() => {
      'storeLocked': false,
      'storeExists': true,
      'setupRequired': false,
      'me': {'id': 'admin_1', 'name': 'Alex', 'role': 'admin'},
      'people': [
        {
          'id': 'admin_1',
          'name': 'Alex',
          'colorValue': 0xFF1565C0,
          'role': 'admin',
          'createdAt': '2026-08-01T00:00:00.000Z',
          'hasPassword': true,
          'preferences': {'themeModeName': 'dark'},
        },
      ],
      'accountOwnerships': [
        {
          'accountId': 'acc-1',
          'personShares': {'admin_1': 1.0},
        },
      ],
      'requirePasswordLogin': true,
    };

    Future<ProviderContainer> buildServerContainer({
      required http.Client httpClient,
      String? sessionToken = 'sess',
      SharedPreferences? prefs,
    }) async {
      final resolvedPrefs = prefs ?? await freshPrefs();
      if (sessionToken != null) {
        FlutterSecureStoragePlatform.instance =
            TestFlutterSecureStoragePlatform({
              'serverSessionToken': sessionToken,
            });
      }
      final client = RemoteServerClient(
        baseUrl: 'http://example.test',
        sessionToken: sessionToken,
        httpClient: httpClient,
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(resolvedPrefs),
          deploymentConfigProvider.overrideWithValue(
            const DeploymentConfig(
              mode: FireraccoonMode.server,
              apiBase: 'http://example.test',
            ),
          ),
          authProvider.overrideWith(
            () => AuthNotifier(storage: const FlutterSecureStorage()),
          ),
          serverSessionProvider.overrideWith(
            () => ServerSessionNotifier(
              storage: const FlutterSecureStorage(),
              clientFactory: (_) => client,
            ),
          ),
          peopleProvider.overrideWith(
            () => PeopleNotifier(
              storage: const FlutterSecureStorage(),
              biometricAuth: FakeBiometricAuth(),
              pbkdf2Iterations: kTestPbkdf2Iterations,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(serverSessionProvider.future);
      return container;
    }

    test('syncFromServerStore loads people and list ownerships', () async {
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(jsonEncode(serverPeopleState()), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);

      await container
          .read(peopleProvider.notifier)
          .syncFromServerStore(loggedInPersonId: 'admin_1');

      final state = container.read(peopleProvider);
      expect(state.people, hasLength(1));
      expect(state.people.single.id, 'admin_1');
      expect(state.people.single.hasPassword, isTrue);
      expect(
        state.config.accountOwnerships['acc-1']?.personShares['admin_1'],
        1,
      );
      expect(state.loggedInPersonId, 'admin_1');
    });

    test('hydrate does not push local people repairs to the server', () async {
      // Ownership-only prefs + empty auth used to seed defaults and PUT
      // requirePasswordLogin: false from the still-empty PeopleState.
      // No session: isolate hydrate from preference-sync PUT loops.
      final encoded = AccountOwnershipConfig(
        people: [
          Person(
            id: 'stale_local_id',
            name: 'Alex',
            colorValue: 0xFF3B82F6,
            role: PersonRole.user,
            createdAtIso: '2026-01-01T00:00:00.000Z',
          ),
        ],
      ).encode();
      SharedPreferences.setMockInitialValues({
        kPeopleConfigPreferenceKey: encoded,
      });
      final prefs = await SharedPreferences.getInstance();

      var putPeopleCalls = 0;
      final container = await buildServerContainer(
        prefs: prefs,
        sessionToken: null,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state/people')) {
            putPeopleCalls++;
            return http.Response(jsonEncode(serverPeopleState()), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(putPeopleCalls, 0, reason: 'hydrate must not PUT people');
      expect(container.read(peopleProvider).people.single.id, 'stale_local_id');
    });

    test('syncFromServerStore accepts map ownerships and typed maps', () async {
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'me': {'id': 'p1', 'name': 'Sam'},
                'people': [
                  {
                    'id': 'p1',
                    'name': 'Sam',
                    'role': 'member',
                    'hasPassword': false,
                    'preferences': <dynamic, dynamic>{'themeModeName': 'light'},
                  },
                  <String, dynamic>{
                    'id': 'p2',
                    'name': 'Lee',
                    'role': 'user',
                    'hasPassword': false,
                  },
                ],
                'accountOwnerships': {
                  'acc-2': {
                    'personShares': {'p1': 1.0},
                  },
                  'bad': 'nope',
                },
                'requirePasswordLogin': false,
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);
      await container.read(peopleProvider.notifier).syncFromServerStore();

      final state = container.read(peopleProvider);
      expect(state.people.map((p) => p.id).toList(), ['p1', 'p2']);
      expect(state.config.accountOwnerships['acc-2'], isNotNull);
      expect(state.requirePasswordLogin, isFalse);
    });

    test('syncFromServerStore swallows fetch errors', () async {
      var failNextState = false;
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            if (failNextState) {
              throw Exception('network');
            }
            return http.Response(jsonEncode(serverPeopleState()), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);
      await container
          .read(peopleProvider.notifier)
          .syncFromServerStore(loggedInPersonId: 'admin_1');
      expect(container.read(peopleProvider).people, isNotEmpty);

      failNextState = true;
      await container.read(peopleProvider.notifier).syncFromServerStore();
      expect(container.read(peopleProvider).people, isNotEmpty);

      failNextState = false;
      await container.read(peopleProvider.notifier).syncFromServerStore();
      // Bad payload type is a no-op return inside apply.
    });

    test('addPerson persists through putPeople in server mode', () async {
      var putPeopleCalls = 0;
      Map<String, dynamic>? lastPutBody;
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(jsonEncode(serverPeopleState()), 200);
          }
          if (request.url.path.endsWith('/api/state/people')) {
            putPeopleCalls++;
            lastPutBody = jsonDecode(request.body) as Map<String, dynamic>;
            final people = (lastPutBody!['people'] as List)
                .cast<Map<String, dynamic>>();
            return http.Response(
              jsonEncode({
                ...serverPeopleState(),
                'people': people
                    .map(
                      (p) => {
                        ...p,
                        'hasPassword': true,
                        'createdAt':
                            p['createdAt'] ?? '2026-08-01T00:00:00.000Z',
                      },
                    )
                    .toList(),
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);
      await container
          .read(peopleProvider.notifier)
          .syncFromServerStore(loggedInPersonId: 'admin_1');

      await container
          .read(peopleProvider.notifier)
          .addPerson(
            name: 'Sam',
            colorValue: 0xFF10B981,
            password: 'Correct-Horse9!',
          );

      expect(putPeopleCalls, greaterThanOrEqualTo(1));
      expect(lastPutBody?['passwordUpdates'], isA<Map>());
      expect(
        container.read(peopleProvider).people.length,
        greaterThanOrEqualTo(2),
      );
    });

    test('changePassword verifies old password through server login', () async {
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(jsonEncode(serverPeopleState()), 200);
          }
          if (request.url.path.endsWith('/api/login')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['password'] == 'Old-Horse9!') {
              return http.Response(jsonEncode({'ok': true}), 200);
            }
            return http.Response(jsonEncode({'error': 'bad password'}), 401);
          }
          if (request.url.path.endsWith('/api/state/people')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final people = (body['people'] as List)
                .cast<Map<String, dynamic>>();
            return http.Response(
              jsonEncode({
                ...serverPeopleState(),
                'people': people
                    .map(
                      (p) => {
                        ...p,
                        'hasPassword': true,
                        'createdAt':
                            p['createdAt'] ?? '2026-08-01T00:00:00.000Z',
                      },
                    )
                    .toList(),
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);
      await container
          .read(peopleProvider.notifier)
          .syncFromServerStore(loggedInPersonId: 'admin_1');

      final ok = await container
          .read(peopleProvider.notifier)
          .changePassword(
            'admin_1',
            oldPassword: 'Old-Horse9!',
            newPassword: 'New-Horse9!',
          );
      expect(ok, isTrue);

      final bad = await container
          .read(peopleProvider.notifier)
          .changePassword(
            'admin_1',
            oldPassword: 'nope',
            newPassword: 'New-Horse9!',
          );
      expect(bad, isFalse);
    });

    test('setPassword queues server password updates', () async {
      Map<String, dynamic>? lastPutBody;
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(
              jsonEncode({
                ...serverPeopleState(),
                'requirePasswordLogin': false,
                'people': [
                  {
                    'id': 'member_1',
                    'name': 'Sam',
                    'role': 'user',
                    'hasPassword': false,
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state/people')) {
            lastPutBody = jsonDecode(request.body) as Map<String, dynamic>;
            final people = (lastPutBody!['people'] as List)
                .cast<Map<String, dynamic>>();
            return http.Response(
              jsonEncode({
                ...serverPeopleState(),
                'people': people
                    .map(
                      (p) => {
                        ...p,
                        'hasPassword': true,
                        'createdAt':
                            p['createdAt'] ?? '2026-08-01T00:00:00.000Z',
                      },
                    )
                    .toList(),
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);
      await container
          .read(peopleProvider.notifier)
          .syncFromServerStore(loggedInPersonId: 'member_1');

      await container
          .read(peopleProvider.notifier)
          .setPassword('member_1', 'Fresh-Horse9!');

      expect(lastPutBody?['passwordUpdates'], isA<Map>());
    });

    test('hydrate promotes an admin when config has none', () async {
      final encoded = AccountOwnershipConfig(
        people: [
          Person(
            id: 'p1',
            name: 'Alex',
            colorValue: 0xFF3B82F6,
            role: PersonRole.user,
            createdAtIso: '2026-01-01T00:00:00.000Z',
          ),
        ],
      ).encode();
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
        kPeopleAuthStorageKey: PeopleAuthStorage(
          byPersonId: {
            'p1': const Person(
              id: 'p1',
              name: 'Alex',
              colorValue: 0xFF3B82F6,
              role: PersonRole.user,
              createdAtIso: '2026-01-01T00:00:00.000Z',
            ).toAuthJson(),
          },
        ).encode(),
      });
      SharedPreferences.setMockInitialValues({
        kPeopleConfigPreferenceKey: encoded,
      });
      final container = await buildContainer(
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(container.dispose);
      await waitHydrated(container);
      expect(
        container.read(peopleProvider).people.single.role,
        PersonRole.admin,
      );
    });

    test('putPeople failures are swallowed', () async {
      final container = await buildServerContainer(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state')) {
            return http.Response(jsonEncode(serverPeopleState()), 200);
          }
          if (request.url.path.endsWith('/api/state/people')) {
            return http.Response(jsonEncode({'error': 'boom'}), 500);
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);
      await container
          .read(peopleProvider.notifier)
          .syncFromServerStore(loggedInPersonId: 'admin_1');

      await container
          .read(peopleProvider.notifier)
          .addPerson(name: 'Sam', colorValue: 0xFF10B981);
      expect(container.read(peopleProvider).people, isNotEmpty);
    });

    test('syncFromServerStore no-ops outside server mode', () async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      await waitHydrated(container);
      await container.read(peopleProvider.notifier).syncFromServerStore();
      expect(container.read(peopleProvider).isHydrated, isTrue);
    });

    test('importSettings without a session keeps people locally', () async {
      final prefs = await freshPrefs();
      var putPeopleCalls = 0;
      final container = await buildServerContainer(
        prefs: prefs,
        sessionToken: null,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/api/capabilities')) {
            return http.Response(
              jsonEncode({
                'storeLocked': false,
                'storeExists': true,
                'setupRequired': false,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/api/state/people')) {
            putPeopleCalls++;
            return http.Response(jsonEncode(serverPeopleState()), 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await waitHydrated(container);

      await container
          .read(peopleProvider.notifier)
          .importSettings(
            people: [
              Person(
                id: 'imported_1',
                name: 'Ana',
                colorValue: 0xFF3B82F6,
                role: PersonRole.admin,
                createdAtIso: '2026-02-01T00:00:00.000Z',
              ),
            ],
            accountOwnerships: const {
              'acc-9': AccountOwnership(
                accountId: 'acc-9',
                personShares: {'imported_1': 1.0},
              ),
            },
            requirePasswordLogin: false,
          );

      expect(
        putPeopleCalls,
        0,
        reason: 'an unauthenticated client must not attempt a server write',
      );
      final state = container.read(peopleProvider);
      expect(state.people.single.id, 'imported_1');
      expect(state.config.getOwnershipRatio('acc-9', 'imported_1'), 1.0);
      expect(
        prefs.getString(kPeopleConfigPreferenceKey),
        contains('imported_1'),
      );
    });

    test(
      'importSettings sends portable hashes as server auth imports',
      () async {
        Map<String, dynamic>? lastPutBody;
        final container = await buildServerContainer(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/api/capabilities')) {
              return http.Response(
                jsonEncode({
                  'storeLocked': false,
                  'storeExists': true,
                  'setupRequired': false,
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/api/state')) {
              return http.Response(jsonEncode(serverPeopleState()), 200);
            }
            if (request.url.path.endsWith('/api/state/people')) {
              lastPutBody = jsonDecode(request.body) as Map<String, dynamic>;
              final people = (lastPutBody!['people'] as List)
                  .cast<Map<String, dynamic>>();
              return http.Response(
                jsonEncode({
                  ...serverPeopleState(),
                  'people': people
                      .map(
                        (p) => {
                          ...p,
                          'createdAt':
                              p['createdAt'] ?? '2026-08-01T00:00:00.000Z',
                        },
                      )
                      .toList(),
                }),
                200,
              );
            }
            return http.Response('{}', 200);
          }),
        );
        await waitHydrated(container);
        await container
            .read(peopleProvider.notifier)
            .syncFromServerStore(loggedInPersonId: 'admin_1');

        final ana = await hashTestPassword('Import-Horse9!');
        await container
            .read(peopleProvider.notifier)
            .importSettings(
              people: [
                Person(
                  id: 'import_1',
                  name: 'Ana',
                  colorValue: 0xFF3B82F6,
                  role: PersonRole.admin,
                  passwordHash: ana.hash,
                  salt: ana.salt,
                  createdAtIso: '2026-02-01T00:00:00.000Z',
                ),
                Person(
                  id: 'import_2',
                  name: 'Bo',
                  colorValue: 0xFF10B981,
                  passwordHash: 'server',
                  salt: 'server',
                  createdAtIso: '2026-02-02T00:00:00.000Z',
                ),
              ],
              accountOwnerships: const {},
              requirePasswordLogin: true,
            );

        final authImports =
            lastPutBody?['authImports'] as Map<String, dynamic>?;
        expect(authImports, isNotNull);
        expect(
          authImports!.keys.toList(),
          ['import_1'],
          reason: 'server placeholders must not be pushed back as real hashes',
        );
        expect((authImports['import_1'] as Map)['salt'], ana.salt);
        expect((authImports['import_1'] as Map)['passwordHash'], ana.hash);
      },
    );
  });
}

/// Stands in for a device whose keychain refuses writes, and optionally reads.
class _FailingSecureStoragePlatform extends TestFlutterSecureStoragePlatform {
  _FailingSecureStoragePlatform(super.data, {this.failReads = true});

  final bool failReads;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (failReads) throw Exception('keychain read denied');
    return super.read(key: key, options: options);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => throw Exception('keychain write denied');

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => throw Exception('keychain delete denied');
}

class _GatedPrefService extends FakeFireflyService {
  _GatedPrefService({required this.gate, required this.onSet});

  final Completer<void> gate;
  final void Function() onSet;
  var _firstSet = true;

  @override
  Future<void> setPreference(String name, dynamic data) async {
    if (_firstSet) {
      _firstSet = false;
      await gate.future;
    }
    onSet();
    await super.setPreference(name, data);
  }
}
