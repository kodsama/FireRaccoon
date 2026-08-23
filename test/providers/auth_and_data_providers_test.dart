import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/static_auth_notifier.dart';
import '../helpers/test_data.dart';

Future<Map<String, String>> _noEnv() async => const {};

class _DelayedTransactionsService extends FakeFireflyService {
  final Completer<void> gate = Completer<void>();

  @override
  Future<List<Transaction>> getTransactions({
    DateTime? start,
    DateTime? end,
    String? type,
    void Function(List<Transaction> firstPage)? onFirstPage,
  }) async {
    await gate.future;
    return super.getTransactions(
      start: start,
      end: end,
      type: type,
      onFirstPage: onFirstPage,
    );
  }
}

/// Secure storage that always fails, simulating a broken macOS Keychain
/// (errSecMissingEntitlement / -34018).
class _ThrowingStoragePlatform extends TestFlutterSecureStoragePlatform {
  _ThrowingStoragePlatform() : super({});

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => throw Exception('keychain unavailable (-34018)');

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => throw Exception('keychain unavailable (-34018)');
}

/// Secure storage that answers, counting how often it was asked.
class _FlakyStoragePlatform extends TestFlutterSecureStoragePlatform {
  _FlakyStoragePlatform(super.storage);

  int reads = 0;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    reads++;
    return super.read(key: key, options: options);
  }
}

/// Secure storage whose read never completes, the way a keychain prompt that
/// nobody types into never returns.
class _HangingStoragePlatform extends TestFlutterSecureStoragePlatform {
  _HangingStoragePlatform() : super({});

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) => Completer<String?>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStorage;

  setUp(() {
    secureStorage = {};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      secureStorage,
    );
  });

  FlutterSecureStorage testStorage() => const FlutterSecureStorage();

  group('AuthSettings', () {
    test('isValid requires url and token', () {
      expect(AuthSettings().isValid, isFalse);
      expect(
        AuthSettings(serverUrl: 'https://x.test', apiToken: 'tok').isValid,
        isTrue,
      );
    });

    test('starts unhydrated until storage load completes', () {
      expect(AuthSettings().isHydrated, isFalse);
      expect(
        AuthSettings(
          serverUrl: 'https://x.test',
          apiToken: 'tok',
          isHydrated: true,
        ).isHydrated,
        isTrue,
      );
    });

    test('uses value equality and matching hash codes', () {
      final first = AuthSettings(
        serverUrl: 'https://x.test',
        apiToken: 'tok',
        authMode: AuthMode.oauth2,
        allowInsecure: true,
        isHydrated: true,
      );
      final second = AuthSettings(
        serverUrl: 'https://x.test',
        apiToken: 'tok',
        authMode: AuthMode.oauth2,
        allowInsecure: true,
        isHydrated: true,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(AuthSettings()));
    });
  });

  group('AuthNotifier', () {
    test('testConnection returns true on 200', () async {
      final client = MockClient(
        (_) async => http.Response('{"version":"6"}', 200),
      );
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              httpClient: client,
              storage: testStorage(),
              debugEnvLoader: _noEnv,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(authProvider.notifier)
          .testConnection('https://firefly.test', 'token', false);
      expect(ok, isTrue);
    });

    test('testConnection returns false on network error', () async {
      final client = MockClient((_) async => throw Exception('offline'));
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              httpClient: client,
              storage: testStorage(),
              debugEnvLoader: _noEnv,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(authProvider.notifier)
          .testConnection('https://firefly.test', 'token', false);
      expect(ok, isFalse);
    });

    test('testConnection returns false on non-200 response', () async {
      final client = MockClient(
        (_) async => http.Response('unauthorized', 401),
      );
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              httpClient: client,
              storage: testStorage(),
              debugEnvLoader: _noEnv,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(authProvider.notifier)
          .testConnection('https://firefly.test', 'token', false);
      expect(ok, isFalse);
    });

    test('testConnection retries once after a transient failure', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        if (attempts == 1) throw Exception('connection reset');
        return http.Response('{"version":"6"}', 200);
      });
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              httpClient: client,
              storage: testStorage(),
              debugEnvLoader: _noEnv,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(authProvider.notifier)
          .testConnection('https://firefly.test', 'token', false);
      expect(ok, isTrue);
      expect(attempts, 2);
    });

    test('testConnection does not retry auth failures', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        return http.Response('unauthorized', 401);
      });
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              httpClient: client,
              storage: testStorage(),
              debugEnvLoader: _noEnv,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(authProvider.notifier)
          .testConnection('https://firefly.test', 'token', false);
      expect(ok, isFalse);
      expect(attempts, 1);
    });

    test('testConnection retries server errors before giving up', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        return http.Response('bad gateway', 502);
      });
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              httpClient: client,
              storage: testStorage(),
              debugEnvLoader: _noEnv,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(authProvider.notifier)
          .testConnection('https://firefly.test', 'token', false);
      expect(ok, isFalse);
      expect(attempts, 2);
    });

    test('testConnection blocks insecure HTTP when not allowed', () async {
      final notifier = AuthNotifier(
        storage: testStorage(),
        debugEnvLoader: _noEnv,
      );
      try {
        await notifier.testConnection('http://firefly.test', 'token', false);
        fail('expected exception');
      } on Exception catch (e) {
        expect(e.toString(), contains('Insecure HTTP'));
      }
    });

    /// Pumps until hydration settles, or gives up so a failure reads as a
    /// wrong value rather than a hang.
    Future<AuthSettings> hydrated(ProviderContainer container) async {
      // A real interval, not Duration.zero: a read deadline only elapses if
      // the clock actually moves.
      for (var i = 0; i < 400; i++) {
        if (container.read(authProvider).isHydrated) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      return container.read(authProvider);
    }

    test('a keychain that fails the read is unavailable, not empty', () async {
      FlutterSecureStoragePlatform.instance = _ThrowingStoragePlatform();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(storage: testStorage(), debugEnvLoader: _noEnv),
          ),
        ],
      );
      addTearDown(container.dispose);

      final settings = await hydrated(container);
      // Hydration has to finish either way, or every screen loads forever with
      // nothing to say why.
      expect(settings.isHydrated, isTrue);
      expect(settings.isValid, isFalse);
      // The distinction the UI needs: unreadable, not unconfigured.
      expect(settings.storageUnavailable, isTrue);
    });

    test('a keychain that holds nothing is not called unavailable', () async {
      FlutterSecureStoragePlatform.instance = _FlakyStoragePlatform({});
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(storage: testStorage(), debugEnvLoader: _noEnv),
          ),
        ],
      );
      addTearDown(container.dispose);

      final settings = await hydrated(container);
      expect(settings.isHydrated, isTrue);
      // Nothing stored is what a first run looks like, and "open Settings" is
      // the right thing to say about it.
      expect(settings.storageUnavailable, isFalse);
    });

    test('a read that never answers still finishes hydration', () async {
      // A keychain prompt nobody types into never returns. Waiting on it
      // forever leaves every screen loading with nothing to say why.
      FlutterSecureStoragePlatform.instance = _HangingStoragePlatform();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              storage: testStorage(),
              debugEnvLoader: _noEnv,
              readTimeout: const Duration(milliseconds: 50),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final settings = await hydrated(container);
      expect(settings.isHydrated, isTrue);
      expect(settings.storageUnavailable, isTrue);
    });

    test('saveSettings and clearSettings update state', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(storage: testStorage(), debugEnvLoader: _noEnv),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .saveSettings('https://firefly.test', 'secret', true);
      expect(container.read(authProvider).isValid, isTrue);
      expect(container.read(authProvider).serverUrl, 'https://firefly.test');

      await container.read(authProvider.notifier).clearSettings();
      expect(container.read(authProvider).isValid, isFalse);
    });

    test(
      'falls back to debug .env credentials when storage is empty',
      () async {
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(
              () => AuthNotifier(
                storage: testStorage(),
                debugEnvLoader: () async => {
                  'FIREFLY_URL': 'https://env.example.com',
                  'FIREFLY_TOKEN': 'env-token',
                  'FIREFLY_ALLOW_INSECURE': 'true',
                },
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
          if (container.read(authProvider).isHydrated) break;
        }
        final settings = container.read(authProvider);
        expect(settings.serverUrl, 'https://env.example.com');
        expect(settings.apiToken, 'env-token');
        expect(settings.allowInsecure, isTrue);
      },
    );

    test('prefers stored credentials over the .env fallback', () async {
      final storage = testStorage();
      await storage.write(
        key: 'serverUrl',
        value: 'https://stored.example.com',
      );
      await storage.write(key: 'apiToken', value: 'stored-token');
      var loaderCalled = false;
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              storage: storage,
              debugEnvLoader: () async {
                loaderCalled = true;
                return const {};
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
        if (container.read(authProvider).isHydrated) break;
      }
      final settings = container.read(authProvider);
      expect(settings.serverUrl, 'https://stored.example.com');
      expect(loaderCalled, isFalse);
    });

    test('uses .env fallback when secure storage read fails', () async {
      FlutterSecureStoragePlatform.instance = _ThrowingStoragePlatform();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              storage: testStorage(),
              debugEnvLoader: () async => {
                'FIREFLY_URL': 'https://env.example.com',
                'FIREFLY_TOKEN': 'env-token',
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
        if (container.read(authProvider).isHydrated) break;
      }
      final settings = container.read(authProvider);
      expect(settings.isHydrated, isTrue);
      expect(settings.serverUrl, 'https://env.example.com');
      expect(settings.apiToken, 'env-token');
    });

    test(
      'saveSettings keeps credentials in memory when persistence fails',
      () async {
        FlutterSecureStoragePlatform.instance = _ThrowingStoragePlatform();
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(
              () =>
                  AuthNotifier(storage: testStorage(), debugEnvLoader: _noEnv),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Must not throw even though the underlying write fails.
        await container
            .read(authProvider.notifier)
            .saveSettings('https://firefly.test', 'secret', false);
        final settings = container.read(authProvider);
        expect(settings.serverUrl, 'https://firefly.test');
        expect(settings.apiToken, 'secret');
        expect(settings.isValid, isTrue);
      },
    );

    test('authenticateOAuth blocks insecure HTTP when not allowed', () async {
      final notifier = AuthNotifier(
        storage: testStorage(),
        debugEnvLoader: _noEnv,
      );
      try {
        await notifier.authenticateOAuth(
          'http://firefly.test',
          'client-id',
          false,
        );
        fail('expected exception');
      } on Exception catch (e) {
        expect(e.toString(), contains('Insecure HTTP'));
      }
    });

    test('loads oauth settings from storage', () async {
      final storage = testStorage();
      await storage.write(key: 'serverUrl', value: 'https://firefly.test');
      await storage.write(key: 'apiToken', value: 'oauth-token');
      await storage.write(key: 'authMode', value: 'oauth2');
      await storage.write(key: 'allowInsecure', value: 'false');

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(storage: storage)),
        ],
      );
      addTearDown(container.dispose);

      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        final settings = container.read(authProvider);
        if (settings.authMode == AuthMode.oauth2) {
          expect(settings.apiToken, 'oauth-token');
          return;
        }
      }
      fail('oauth settings were not loaded from storage');
    });
  });

  group('data providers', () {
    test('apiServiceProvider is null when auth invalid', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => StaticAuthNotifier(AuthSettings())),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(apiServiceProvider), isNull);
    });

    test('accountsProvider uses FireflyService', () async {
      final fake = FakeFireflyService(accounts: sampleAccounts);
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final accounts = await container.read(accountsProvider.future);
      expect(accounts.single.name, 'Checking');
    });

    test('a load waits for the credential read rather than erroring', () async {
      // A keychain read can be outstanding for as long as it takes to type a
      // password. Reporting "connect your server" during that wait told people
      // to reconnect a server they had already connected.
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => StaticAuthNotifier(AuthSettings(), hydrated: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(accountsProvider, (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(container.read(accountsProvider).isLoading, isTrue);
      expect(container.read(accountsProvider).hasError, isFalse);
    });

    test('an unreadable keychain is named as the reason', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => StaticAuthNotifier(AuthSettings(storageUnavailable: true)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(accountsProvider, (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final value = container.read(accountsProvider);
      expect(value.hasError, isTrue);
      // "Open Settings and connect your server" is the wrong instruction when
      // the server is configured and the keychain simply would not answer.
      expect(value.error.toString(), contains('keychain'));
    });

    test(
      'counterpartyAccountsProvider fetches expense and revenue accounts',
      () async {
        final expense = Account(
          id: 'e1',
          name: 'Grocery Store',
          type: 'expense',
          role: '',
          currentBalance: 0,
          currencySymbol: '€',
          currencyCode: 'EUR',
        );
        final revenue = Account(
          id: 'r1',
          name: 'Employer',
          type: 'revenue',
          role: '',
          currentBalance: 0,
          currencySymbol: '€',
          currencyCode: 'EUR',
        );
        final fake = FakeFireflyService(
          accounts: [...sampleAccounts, expense, revenue],
        );
        final container = ProviderContainer(
          overrides: [apiServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final counterparties = await container.read(
          counterpartyAccountsProvider.future,
        );
        final assets = await container.read(accountsProvider.future);

        expect(counterparties.map((a) => a.type).toSet(), {
          'expense',
          'revenue',
        });
        // The main accounts list stays asset/liability only.
        expect(assets.every((a) => a.type != 'expense'), isTrue);
      },
    );

    test('transactionsProvider sorts by date descending', () async {
      final fake = FakeFireflyService(transactions: sampleTransactions);
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final txs = await container.read(transactionsProvider.future);
      expect(txs.first.date.isAfter(txs.last.date), isTrue);
    });

    test('TransactionsNotifier upsert patches cache without refetch', () async {
      final fake = FakeFireflyService(transactions: sampleTransactions);
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final before = await container.read(transactionsProvider.future);
      final added = before.first.copyWith(
        id: 'patched-new',
        description: 'Patched in',
      );

      container.read(transactionsProvider.notifier).upsert(added);

      final after = container.read(transactionsProvider).requireValue;
      expect(after.length, before.length + 1);
      expect(after.map((t) => t.id), contains('patched-new'));
      // List stays sorted by date descending after the patch.
      for (var i = 1; i < after.length; i++) {
        expect(after[i - 1].date.isBefore(after[i].date), isFalse);
      }

      // Replacing the same id does not grow the list.
      container
          .read(transactionsProvider.notifier)
          .upsert(added.copyWith(description: 'Replaced'));
      final replaced = container.read(transactionsProvider).requireValue;
      expect(replaced.length, after.length);
      expect(
        replaced.firstWhere((t) => t.id == 'patched-new').description,
        'Replaced',
      );
    });

    test('TransactionsNotifier remove drops the row from the cache', () async {
      final fake = FakeFireflyService(transactions: sampleTransactions);
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final before = await container.read(transactionsProvider.future);
      final victim = before.first.id;

      container.read(transactionsProvider.notifier).remove(victim);

      final after = container.read(transactionsProvider).requireValue;
      expect(after.length, before.length - 1);
      expect(after.map((t) => t.id), isNot(contains(victim)));
    });

    test('accountTransactionsProvider resolves account by name', () async {
      final fake = FakeFireflyService(
        accounts: sampleAccounts,
        transactions: sampleTransactions,
      );
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final txs = await container.read(
        accountTransactionsProvider('Checking').future,
      );
      expect(txs, hasLength(2));
    });

    test(
      'accountTransactionsProvider reports missing account as error',
      () async {
        final fake = FakeFireflyService(
          accounts: sampleAccounts,
          transactions: sampleTransactions,
        );
        final container = ProviderContainer(
          overrides: [apiServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final provider = accountTransactionsProvider('Missing');
        for (var i = 0; i < 40; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
          final value = container.read(provider);
          if (value.hasError) {
            expect(value.error.toString(), contains('not found'));
            return;
          }
        }
        fail('expected missing account error');
      },
    );

    test('budgetsProvider returns budgets', () async {
      final fake = FakeFireflyService(budgets: sampleBudgets);
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final budgets = await container.read(budgetsProvider.future);
      expect(budgets.single.name, 'Food');
    });

    test('categoriesProvider and tagsProvider return values', () async {
      final fake = FakeFireflyService();
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final categories = await container.read(categoriesProvider.future);
      final tags = await container.read(tagsProvider.future);
      expect(categories, isEmpty);
      expect(tags, isEmpty);
    });

    test('primaryCurrencyProvider returns currency', () async {
      final fake = FakeFireflyService();
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final currency = await container.read(primaryCurrencyProvider.future);
      expect(currency.code, 'EUR');
    });

    test('currentUserProvider returns user', () async {
      final fake = FakeFireflyService();
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final user = await container.read(currentUserProvider.future);
      expect(user.email, 'admin@local.test');
    });

    test('apiServiceProvider creates service when auth is valid', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => StaticAuthNotifier(
              AuthSettings(
                serverUrl: 'https://firefly.test',
                apiToken: 'secret',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(apiServiceProvider), isNotNull);
    });

    test(
      'AccountsNotifier applyTransactionDelta updates account balance immediately',
      () async {
        final fake = FakeFireflyService(
          accounts: sampleAccounts,
          transactions: sampleTransactions,
        );
        final container = ProviderContainer(
          overrides: [apiServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        await container.read(accountsProvider.future);
        await container.read(transactionsProvider.future);
        final initialChecking = container
            .read(accountsProvider)
            .value!
            .firstWhere((a) => a.name == 'Checking');
        expect(initialChecking.currentBalance, 2500.0);

        final newExpense = Transaction(
          id: 'new_tx_1',
          date: DateTime.now(),
          description: 'Coffee',
          amount: 5.0,
          type: 'withdrawal',
          sourceId: '1',
          sourceName: 'Checking',
          destinationId: '99',
          destinationName: 'Coffee Shop',
          categoryName: '',
          currencySymbol: '€',
          currencyCode: 'EUR',
        );

        container
            .read(accountsProvider.notifier)
            .applyTransactionDelta(upsert: newExpense);
        final updatedChecking = container
            .read(accountsProvider)
            .value!
            .firstWhere((a) => a.name == 'Checking');
        expect(updatedChecking.currentBalance, 2495.0);

        final existing = sampleTransactions.first;
        container
            .read(accountsProvider.notifier)
            .applyTransactionDelta(
              upsert: existing.copyWith(amount: existing.amount + 10),
            );
        container
            .read(accountsProvider.notifier)
            .applyTransactionDelta(remove: existing);
        expect(container.read(accountsProvider).value, isNotEmpty);
      },
    );

    test('TransactionsNotifier remove during loading schedules a refresh', () {
      final fake = _DelayedTransactionsService();
      final container = ProviderContainer(
        overrides: [apiServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(() {
        if (!fake.gate.isCompleted) fake.gate.complete();
        container.dispose();
      });

      container.read(transactionsProvider.notifier).remove('missing');

      expect(container.read(transactionsProvider).isLoading, isTrue);
    });
  });

  group('the accounts view balance date', () {
    test('defaults to the last moment of the current month', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Nothing picked yet, so the view reports what it always reported.
      expect(container.read(accountBalanceDateProvider), isNull);
      final resolved = container.read(resolvedAccountBalanceDateProvider);
      expect(resolved, endOfMonthFor(DateTime.now()));
      // The last moment of the day, or a balance "at" a date would miss
      // everything dated that day.
      expect(resolved.hour, 23);
      expect(resolved.minute, 59);
      expect(resolved.second, 59);
    });

    test('endOfMonthFor lands on the last day of the month', () {
      expect(endOfMonthFor(DateTime(2026, 2, 3)).day, 28);
      expect(endOfMonthFor(DateTime(2028, 2, 3)).day, 29);
      expect(
        endOfMonthFor(DateTime(2026, 12, 1)),
        DateTime(2026, 12, 31, 23, 59, 59),
      );
    });

    test('a picked date is carried to the end of that day', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(accountBalanceDateProvider.notifier)
          .select(DateTime(2027, 3, 15, 9));

      expect(
        container.read(resolvedAccountBalanceDateProvider),
        DateTime(2027, 3, 15, 23, 59, 59),
      );
    });

    test('reset goes back to the end of the current month', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(accountBalanceDateProvider.notifier)
          .select(DateTime(2027, 3, 15));
      container.read(accountBalanceDateProvider.notifier).reset();

      expect(container.read(accountBalanceDateProvider), isNull);
      expect(
        container.read(resolvedAccountBalanceDateProvider),
        endOfMonthFor(DateTime.now()),
      );
    });

    test('selecting null is the same as resetting', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(accountBalanceDateProvider.notifier)
          .select(DateTime(2027, 3, 15));
      container.read(accountBalanceDateProvider.notifier).select(null);

      expect(container.read(accountBalanceDateProvider), isNull);
    });
  });

  group('AccountBalanceDateKey', () {
    test('two keys for the same account and day are one cache entry', () {
      final march15 = DateTime(2027, 3, 15);
      final a = AccountBalanceDateKey(accountId: '1', date: march15);
      final b = AccountBalanceDateKey(accountId: '1', date: march15);
      final otherAccount = AccountBalanceDateKey(accountId: '2', date: march15);
      final otherDay = AccountBalanceDateKey(
        accountId: '1',
        date: DateTime(2027, 3, 16),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(otherAccount));
      expect(a, isNot(otherDay));
      expect(a == Object(), isFalse);
    });
  });
}
