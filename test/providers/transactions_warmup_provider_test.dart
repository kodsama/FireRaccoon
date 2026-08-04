import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/paginated_transactions_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import 'package:fireracoon/providers/transactions_warmup_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_firefly_service.dart';
import '../helpers/static_auth_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('warmup starts the all-account transaction cache', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'transactionPageSize': 50});
    final prefs = await SharedPreferences.getInstance();
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith(
            () => StaticAuthNotifier(
              AuthSettings(
                serverUrl: 'https://firefly.test',
                apiToken: 'token',
              ),
            ),
          ),
          apiServiceProvider.overrideWithValue(FakeFireflyService()),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, widgetRef, _) {
              ref = widgetRef;
              widgetRef.watch(transactionsWarmupProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(ref.exists(paginatedTransactionsProvider(null)), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
