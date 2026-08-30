import 'package:fireraccoon/providers/auth_provider.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';

import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/providers/write_ahead_provider.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/fixed_accounts_notifier.dart';
import '../helpers/fixed_transactions_notifier.dart';
import '../helpers/static_auth_notifier.dart';
import '../helpers/test_data.dart';

Recurrence _dueRecurrence({bool active = true}) {
  return Recurrence(
    id: 'recurrence-1',
    type: RecurrenceTransactionType.withdrawal,
    title: 'Rent',
    firstDate: DateTime(2020, 1, 1),
    active: active,
    repetitions: const [
      RecurrenceRepetition(type: RecurrenceRepetitionType.daily, moment: '1'),
    ],
    transactions: const [
      RecurrenceTransactionLine(
        description: 'Rent',
        amount: 500,
        currencyCode: 'EUR',
        sourceName: 'Checking',
        destinationName: 'Landlord',
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WriteAheadDaysNotifier', () {
    test('defaults to off (0)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(writeAheadDaysProvider), 0);
    });

    test('persists allowed horizon choices', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(writeAheadDaysProvider.notifier).setDays(30);
      expect(container.read(writeAheadDaysProvider), 30);
      expect(prefs.getInt('recurrenceWriteAheadDays'), 30);

      await container.read(writeAheadDaysProvider.notifier).setDays(3);
      expect(container.read(writeAheadDaysProvider), 30);
    });

    test('runner is a no-op when horizon is off', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final result = await container.read(writeAheadRunnerProvider.future);
      expect(result.created, 0);
      expect(result.failed, 0);
      expect(result.hasFailures, isFalse);
    });

    test('runner is a no-op without valid auth or service', () async {
      SharedPreferences.setMockInitialValues({'recurrenceWriteAheadDays': 7});
      final prefs = await SharedPreferences.getInstance();
      final invalidAuth = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(
            () => StaticAuthNotifier(AuthSettings(isHydrated: true)),
          ),
        ],
      );
      addTearDown(invalidAuth.dispose);

      expect(
        (await invalidAuth.read(writeAheadRunnerProvider.future)).created,
        0,
      );

      final validNoService = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(
            () => StaticAuthNotifier(
              AuthSettings(
                serverUrl: 'https://firefly.example',
                apiToken: 'token',
                isHydrated: true,
              ),
            ),
          ),
          apiServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(validNoService.dispose);
      expect(
        (await validNoService.read(writeAheadRunnerProvider.future)).created,
        0,
      );
    });

    test('runner returns empty result when there are no recurrences', () async {
      SharedPreferences.setMockInitialValues({'recurrenceWriteAheadDays': 7});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(
            () => StaticAuthNotifier(
              AuthSettings(
                serverUrl: 'https://firefly.example',
                apiToken: 'token',
                isHydrated: true,
              ),
            ),
          ),
          apiServiceProvider.overrideWithValue(FakeFireflyService()),
          recurrencesProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(writeAheadRunnerProvider.future);

      expect(result.created, 0);
      expect(result.failed, 0);
    });

    test('runner materializes a due recurrence', () async {
      SharedPreferences.setMockInitialValues({'recurrenceWriteAheadDays': 7});
      final prefs = await SharedPreferences.getInstance();
      final service = FakeFireflyService();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(
            () => StaticAuthNotifier(
              AuthSettings(
                serverUrl: 'https://firefly.example',
                apiToken: 'token',
                isHydrated: true,
              ),
            ),
          ),
          apiServiceProvider.overrideWithValue(service),
          recurrencesProvider.overrideWith((ref) async => [_dueRecurrence()]),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(writeAheadRunnerProvider.future);

      expect(result.created, greaterThan(0));
      expect(result.failed, 0);
      expect(result.hasFailures, isFalse);
    });

    test('runner reports inactive and failed recurrence outcomes', () async {
      SharedPreferences.setMockInitialValues({'recurrenceWriteAheadDays': 7});
      final prefs = await SharedPreferences.getInstance();
      final authOverride = authProvider.overrideWith(
        () => StaticAuthNotifier(
          AuthSettings(
            serverUrl: 'https://firefly.example',
            apiToken: 'token',
            isHydrated: true,
          ),
        ),
      );
      final inactive = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authOverride,
          apiServiceProvider.overrideWithValue(FakeFireflyService()),
          recurrencesProvider.overrideWith(
            (ref) async => [_dueRecurrence(active: false)],
          ),
        ],
      );
      addTearDown(inactive.dispose);
      expect((await inactive.read(writeAheadRunnerProvider.future)).created, 0);

      final service = FakeFireflyService()
        ..createTransactionError = Exception('create failed');
      final failing = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(
            () => StaticAuthNotifier(
              AuthSettings(
                serverUrl: 'https://firefly.example',
                apiToken: 'token',
                isHydrated: true,
              ),
            ),
          ),
          apiServiceProvider.overrideWithValue(service),
          recurrencesProvider.overrideWith((ref) async => [_dueRecurrence()]),
        ],
      );
      addTearDown(failing.dispose);

      final result = await failing.read(writeAheadRunnerProvider.future);

      expect(result.created, 0);
      expect(result.failed, greaterThan(0));
      expect(result.hasFailures, isTrue);
    });

    testWidgets('runWriteAheadNow refreshes lists after creating rows', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'recurrenceWriteAheadDays': 7});
      final prefs = await SharedPreferences.getInstance();
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authProvider.overrideWith(
              () => StaticAuthNotifier(
                AuthSettings(
                  serverUrl: 'https://firefly.example',
                  apiToken: 'token',
                  isHydrated: true,
                ),
              ),
            ),
            apiServiceProvider.overrideWithValue(FakeFireflyService()),
            recurrencesProvider.overrideWith((ref) async => [_dueRecurrence()]),
            accountsProvider.overrideWith(
              () => FixedAccountsNotifier(sampleAccounts),
            ),
            transactionsProvider.overrideWith(
              () => FixedTransactionsNotifier(const []),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, widgetRef, _) {
                ref = widgetRef;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      final result = await runWriteAheadNow(ref);

      expect(result.created, greaterThan(0));
    });
  });
}
