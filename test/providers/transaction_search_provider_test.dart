import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon/providers/data_providers.dart';
import 'package:fireraccoon/providers/transaction_search_provider.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns server matches for a query', () async {
    final fake = FakeFireflyService(transactions: sampleTransactions);
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final results = await container.read(
      serverSearchResultsProvider('salary').future,
    );

    expect(results, isNotEmpty);
    expect(
      results.every((t) => t.description.toLowerCase().contains('salary')),
      isTrue,
    );
  });

  test('empty query returns no results without calling the API', () async {
    final fake = FakeFireflyService(transactions: sampleTransactions)
      ..throwOn = Exception('should not be called');
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final results = await container.read(
      serverSearchResultsProvider('   ').future,
    );

    expect(results, isEmpty);
  });

  test('search failures degrade to empty results', () async {
    final fake = FakeFireflyService(transactions: sampleTransactions)
      ..throwOn = Exception('server down');
    final container = ProviderContainer(
      overrides: [apiServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final results = await container.read(
      serverSearchResultsProvider('salary').future,
    );

    expect(results, isEmpty);
  });
}
