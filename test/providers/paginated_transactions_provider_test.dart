import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:fireracoon/providers/auth_provider.dart';
import 'package:fireracoon/providers/data_providers.dart';
import 'package:fireracoon/providers/paginated_transactions_provider.dart';
import 'package:fireracoon/providers/transaction_page_size_provider.dart';
import 'package:fireracoon/providers/theme_provider.dart';
import '../helpers/mock_firefly_service.dart';
import '../helpers/paginated_test_helpers.dart';
import '../helpers/static_auth_notifier.dart';
import '../helpers/test_data.dart';

Transaction _tx(String id, DateTime date, {String description = 'tx'}) =>
    Transaction(
      id: id,
      type: 'withdrawal',
      date: date,
      amount: 10,
      description: description,
      sourceName: 'Checking',
      destinationName: 'Store',
      categoryName: 'Food',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );

Future<ProviderContainer> _readyContainer(FakeFireflyService fake) async {
  SharedPreferences.setMockInitialValues({'transactionPageSize': 50});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      authProvider.overrideWith(
        () => StaticAuthNotifier(
          AuthSettings(serverUrl: 'https://firefly.test', apiToken: 'token'),
        ),
      ),
      apiServiceProvider.overrideWithValue(fake),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a container disposed mid-fetch is left alone, not written to', () async {
    // The generation counter lives on the notifier, which outlives disposal, so
    // it still matched and the state write threw out of a future nobody awaits.
    // That failed the page load for no visible reason and landed an uncaught
    // error on whatever happened to be running.
    final fake = FakeFireflyService(
      accounts: sampleAccounts,
      transactions: [_tx('1', DateTime(2026, 8, 1))],
    );
    fake.responseDelay = const Duration(milliseconds: 120);
    final container = await _readyContainer(fake);

    container.read(paginatedTransactionsProvider(null));
    // Long enough for the fetch to be in flight, short enough that it has not
    // returned.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    container.dispose();

    // Long enough for every gap in the fetch to complete.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });

  test('PaginatedTransactionsState hasMore and copyWith', () {
    const state = PaginatedTransactionsState(totalPages: 3, loadedPages: {1});
    expect(state.hasMore, isTrue);
    expect(state.isLoadingMore, isFalse);

    final next = state.copyWith(error: 'oops', clearError: true);
    expect(next.error, isNull);
  });

  test('PaginatedTransactionsState hasMore is false when all pages loaded', () {
    const state = PaginatedTransactionsState(
      totalPages: 2,
      loadedPages: {1, 2},
    );
    expect(state.hasMore, isFalse);
  });

  test('loads pages and merges transactions by id', () async {
    final fake = FakeFireflyService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [_tx('1', DateTime(2026, 7, 10))],
          currentPage: 1,
          totalPages: 2,
          total: 2,
        ),
        2: TransactionPageResult(
          transactions: [
            _tx('3', DateTime(2026, 7, 8)),
            _tx('2', DateTime(2026, 7, 9)),
          ],
          currentPage: 2,
          totalPages: 2,
          total: 3,
        ),
      },
    );

    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider(null));
    final state = await waitForPaginatedLoad(
      container,
      null,
      loadedPages: {1, 2},
    );

    expect(state.transactions, hasLength(3));
    expect(state.loadedPages, containsAll([1, 2]));
    expect(state.isInitialLoading, isFalse);
  });

  test('onScroll loads additional pages when near bottom', () async {
    final fake = FakeFireflyService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [_tx('1', DateTime(2026, 7, 10))],
          currentPage: 1,
          totalPages: 3,
          total: 3,
        ),
        2: TransactionPageResult(
          transactions: [_tx('2', DateTime(2026, 7, 9))],
          currentPage: 2,
          totalPages: 3,
          total: 3,
        ),
        3: TransactionPageResult(
          transactions: [_tx('3', DateTime(2026, 7, 8))],
          currentPage: 3,
          totalPages: 3,
          total: 3,
        ),
      },
    );

    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider(null));
    await waitForPaginatedLoad(container, null);

    container
        .read(paginatedTransactionsProvider(null).notifier)
        .onScroll(5000, 5200);
    await waitForPaginatedLoad(container, null);

    final state = container.read(paginatedTransactionsProvider(null));
    expect(state.transactions.length, greaterThanOrEqualTo(2));
  });

  test('onScroll prefetches when content is shorter than viewport', () async {
    final fake = FakeFireflyService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [_tx('1', DateTime(2026, 7, 10))],
          currentPage: 1,
          totalPages: 3,
          total: 3,
        ),
        2: TransactionPageResult(
          transactions: [_tx('2', DateTime(2026, 7, 9))],
          currentPage: 2,
          totalPages: 3,
          total: 3,
        ),
        3: TransactionPageResult(
          transactions: [_tx('3', DateTime(2026, 7, 8))],
          currentPage: 3,
          totalPages: 3,
          total: 3,
        ),
      },
    );

    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider(null));
    await waitForPaginatedLoad(container, null);

    container
        .read(paginatedTransactionsProvider(null).notifier)
        .onScroll(0, 100);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      container.read(paginatedTransactionsProvider(null)).transactions.length,
      greaterThanOrEqualTo(2),
    );
  });

  test('account filter loads account transactions', () async {
    final fake = FakeFireflyService(
      accounts: sampleAccounts,
      accountTransactionPages: {
        '1': {
          1: TransactionPageResult(
            transactions: [sampleTransactions.first],
            currentPage: 1,
            totalPages: 2,
            total: 2,
          ),
          2: TransactionPageResult(
            transactions: [sampleTransactions.last],
            currentPage: 2,
            totalPages: 2,
            total: 2,
          ),
        },
      },
    );

    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider('Checking'));
    final state = await waitForPaginatedLoad(
      container,
      'Checking',
      loadedPages: {1, 2},
    );

    expect(state.accountName, 'Checking');
    expect(state.transactions, hasLength(2));
  });

  test(
    'reloads when auth becomes available after async storage load',
    () async {
      final fake = FakeFireflyService(
        transactionPages: {
          1: TransactionPageResult(
            transactions: [_tx('1', DateTime(2026, 7, 10))],
            currentPage: 1,
            totalPages: 1,
            total: 1,
          ),
        },
      );

      SharedPreferences.setMockInitialValues({'transactionPageSize': 50});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_DelayedAuthNotifier.new),
          apiServiceProvider.overrideWith((ref) {
            final auth = ref.watch(authProvider);
            return auth.isValid ? fake : null;
          }),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      container.read(paginatedTransactionsProvider(null));
      final state = await waitForPaginatedLoad(container, null);

      expect(state.error, isNull);
      expect(state.transactions, hasLength(1));
    },
  );

  test(
    'stays loading while auth hydrates instead of showing not connected',
    () async {
      SharedPreferences.setMockInitialValues({'transactionPageSize': 50});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_SlowHydratingAuthNotifier.new),
          apiServiceProvider.overrideWithValue(null),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      container.read(paginatedTransactionsProvider(null));
      // Flush the microtask scheduled by auth listen so a raced early return
      // from _fetchPage cannot silently clear the initial loading flag.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final state = container.read(paginatedTransactionsProvider(null));

      expect(state.error, isNull);
      expect(state.isInitialLoading, isTrue);
      expect(state.transactions, isEmpty);
    },
  );

  test('surfaces error when Firefly service is unavailable', () async {
    SharedPreferences.setMockInitialValues({'transactionPageSize': 50});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => StaticAuthNotifier(
            AuthSettings(
              serverUrl: 'https://firefly.test',
              apiToken: 'token',
              isHydrated: true,
            ),
          ),
        ),
        apiServiceProvider.overrideWithValue(null),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider(null));
    final state = await waitForPaginatedLoad(container, null);

    expect(state.error, isNotNull);
    expect(state.error, contains('Not connected'));
  });

  test('deduplicates transactions when pages overlap', () async {
    final shared = _tx('1', DateTime(2026, 7, 10), description: 'Updated');
    final fake = FakeFireflyService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [shared],
          currentPage: 1,
          totalPages: 2,
          total: 2,
        ),
        2: TransactionPageResult(
          transactions: [shared, _tx('2', DateTime(2026, 7, 9))],
          currentPage: 2,
          totalPages: 2,
          total: 2,
        ),
      },
    );

    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider(null));
    final state = await waitForPaginatedLoad(container, null);

    expect(state.transactions.map((t) => t.id).toSet(), hasLength(2));
    expect(state.transactions.first.description, 'Updated');
  });

  test('prefetches previous pages when near top', () async {
    final fake = FakeFireflyService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [_tx('1', DateTime(2026, 7, 10))],
          currentPage: 1,
          totalPages: 4,
          total: 4,
        ),
        2: TransactionPageResult(
          transactions: [_tx('2', DateTime(2026, 7, 9))],
          currentPage: 2,
          totalPages: 4,
          total: 4,
        ),
        3: TransactionPageResult(
          transactions: [_tx('3', DateTime(2026, 7, 8))],
          currentPage: 3,
          totalPages: 4,
          total: 4,
        ),
        4: TransactionPageResult(
          transactions: [_tx('4', DateTime(2026, 7, 7))],
          currentPage: 4,
          totalPages: 4,
          total: 4,
        ),
      },
    );
    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider(null));
    await waitForPaginatedLoad(container, null);

    final notifier = container.read(
      paginatedTransactionsProvider(null).notifier,
    );
    notifier.onScroll(2000, 2600); // bottom -> load 3/4
    await Future<void>.delayed(const Duration(milliseconds: 200));
    notifier.onScroll(0, 2600); // top -> load 1/2
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final state = container.read(paginatedTransactionsProvider(null));
    expect(state.loadedPages, containsAll([1, 2, 3, 4]));
  });

  test('returns account-not-found error for unknown account filter', () async {
    final fake = FakeFireflyService(accounts: sampleAccounts);
    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider('Missing Account'));
    final state = await waitForPaginatedLoad(container, 'Missing Account');

    expect(state.error, contains('not found'));
  });

  test('prefetch errors do not set terminal error state', () async {
    final fake = _PageTwoFailingService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [_tx('1', DateTime(2026, 7, 10))],
          currentPage: 1,
          totalPages: 2,
          total: 2,
        ),
      },
    );

    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider(null));
    await waitForPaginatedLoad(container, null);

    final state = container.read(paginatedTransactionsProvider(null));
    expect(state.error, isNull);
    expect(state.loadingPages, isEmpty);
  });

  test('onScroll near top triggers previous-page loading path', () async {
    final fake = FakeFireflyService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [_tx('1', DateTime(2026, 7, 10))],
          currentPage: 1,
          totalPages: 5,
          total: 5,
        ),
        2: TransactionPageResult(
          transactions: [_tx('2', DateTime(2026, 7, 9))],
          currentPage: 2,
          totalPages: 5,
          total: 5,
        ),
        3: TransactionPageResult(
          transactions: [_tx('3', DateTime(2026, 7, 8))],
          currentPage: 3,
          totalPages: 5,
          total: 5,
        ),
      },
    );
    final container = await _readyContainer(fake);
    addTearDown(container.dispose);
    final notifier = container.read(
      paginatedTransactionsProvider(null).notifier,
    );

    notifier.state = const PaginatedTransactionsState(
      transactions: [],
      loadedPages: {3},
      loadingPages: {},
      totalPages: 5,
      totalCount: 5,
      isInitialLoading: false,
    );
    notifier.onScroll(0, 2000);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final state = container.read(paginatedTransactionsProvider(null));
    expect(state.loadedPages, contains(2));
  });

  test('skip fetch when target page is already loading', () async {
    final fake = FakeFireflyService(
      transactionPages: {
        2: TransactionPageResult(
          transactions: [_tx('2', DateTime(2026, 7, 9))],
          currentPage: 2,
          totalPages: 3,
          total: 3,
        ),
      },
    );
    final container = await _readyContainer(fake);
    addTearDown(container.dispose);
    final notifier = container.read(
      paginatedTransactionsProvider(null).notifier,
    );

    notifier.state = const PaginatedTransactionsState(
      loadedPages: {1},
      loadingPages: {2},
      totalPages: 3,
      totalCount: 3,
      isInitialLoading: false,
    );
    notifier.onScroll(5000, 5200);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final state = container.read(paginatedTransactionsProvider(null));
    expect(state.loadedPages, contains(1));
    expect(state.error, isNull);
  });

  test('reloads when transaction page size preference changes', () async {
    final fake = FakeFireflyService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [_tx('1', DateTime(2026, 7, 10))],
          currentPage: 1,
          totalPages: 1,
          total: 1,
        ),
      },
    );
    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider(null));
    await waitForPaginatedLoad(container, null);

    await container.read(transactionPageSizeProvider.notifier).setPageSize(100);
    await waitForPaginatedLoad(container, null);

    final state = container.read(paginatedTransactionsProvider(null));
    expect(state.isInitialLoading, isFalse);
    expect(state.transactions, isNotEmpty);
  });

  test(
    'upsertTransaction inserts new rows sorted and bumps totalCount',
    () async {
      final fake = FakeFireflyService(
        transactionPages: {
          1: TransactionPageResult(
            transactions: [
              _tx('1', DateTime(2026, 7, 10)),
              _tx('2', DateTime(2026, 7, 8)),
            ],
            currentPage: 1,
            totalPages: 1,
            total: 2,
          ),
        },
      );
      final container = await _readyContainer(fake);
      addTearDown(container.dispose);

      final notifier = container.read(
        paginatedTransactionsProvider(null).notifier,
      );
      await waitForPaginatedLoad(container, null);

      notifier.upsertTransaction(_tx('3', DateTime(2026, 7, 9)));

      final state = container.read(paginatedTransactionsProvider(null));
      expect(state.transactions.map((t) => t.id).toList(), ['1', '3', '2']);
      expect(state.totalCount, 3);

      // Upserting an existing id replaces instead of duplicating.
      notifier.upsertTransaction(
        _tx('3', DateTime(2026, 7, 9), description: 'updated'),
      );
      final replaced = container.read(paginatedTransactionsProvider(null));
      expect(replaced.transactions, hasLength(3));
      expect(
        replaced.transactions.firstWhere((t) => t.id == '3').description,
        'updated',
      );
      expect(replaced.totalCount, 3);
    },
  );

  test('removeTransaction removes row and decrements totalCount', () async {
    final fake = FakeFireflyService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [
            _tx('1', DateTime(2026, 7, 10)),
            _tx('2', DateTime(2026, 7, 8)),
          ],
          currentPage: 1,
          totalPages: 1,
          total: 2,
        ),
      },
    );
    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    final notifier = container.read(
      paginatedTransactionsProvider(null).notifier,
    );
    await waitForPaginatedLoad(container, null);

    notifier.removeTransaction('1');

    final state = container.read(paginatedTransactionsProvider(null));
    expect(state.transactions.map((t) => t.id).toList(), ['2']);
    expect(state.totalCount, 1);
  });

  test(
    'per-account instances dispose when unwatched; all-accounts stays warm',
    () async {
      final fake = FakeFireflyService(
        accounts: sampleAccounts,
        transactionPages: {
          1: TransactionPageResult(
            transactions: [_tx('1', DateTime(2026, 7, 10))],
            currentPage: 1,
            totalPages: 1,
            total: 1,
          ),
        },
      );
      final container = await _readyContainer(fake);
      addTearDown(container.dispose);
      final accountName = sampleAccounts.first.name;

      final accountSub = container.listen(
        paginatedTransactionsProvider(accountName),
        (_, _) {},
      );
      final nullSub = container.listen(
        paginatedTransactionsProvider(null),
        (_, _) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      accountSub.close();
      nullSub.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        container.exists(paginatedTransactionsProvider(accountName)),
        isFalse,
      );
      expect(container.exists(paginatedTransactionsProvider(null)), isTrue);
    },
  );

  test(
    'refresh reloads page one and queues auth changes during loading',
    () async {
      final fake = FakeFireflyService(
        transactionPages: {
          1: TransactionPageResult(
            transactions: [_tx('1', DateTime(2026, 7, 10))],
            currentPage: 1,
            totalPages: 1,
            total: 1,
          ),
        },
      )..responseDelay = const Duration(milliseconds: 50);
      final container = await _readyContainer(fake);
      addTearDown(container.dispose);
      final notifier = container.read(
        paginatedTransactionsProvider(null).notifier,
      );
      container.read(paginatedTransactionsProvider(null));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await container.read(authProvider.notifier).clearSettings();
      await Future<void>.delayed(const Duration(milliseconds: 150));

      await notifier.refresh();

      expect(
        container
            .read(paginatedTransactionsProvider(null))
            .transactions
            .single
            .id,
        '1',
      );
    },
  );

  test('upsert that moves a row off the filtered account evicts it', () async {
    final fake = FakeFireflyService(
      accounts: sampleAccounts,
      accountTransactionPages: {
        sampleAccounts.first.id: {
          1: TransactionPageResult(
            transactions: [_tx('1', DateTime(2026, 7, 10))],
            currentPage: 1,
            totalPages: 1,
            total: 1,
          ),
        },
      },
    );
    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    final accountName = sampleAccounts.first.name;
    final notifier = container.read(
      paginatedTransactionsProvider(accountName).notifier,
    );
    await waitForPaginatedLoad(container, accountName);

    // Same id, but neither source nor destination touches the account.
    final movedAway = Transaction(
      id: '1',
      type: 'withdrawal',
      date: DateTime(2026, 7, 10),
      amount: 10,
      description: 'moved',
      sourceName: 'Another Account',
      destinationName: 'Store',
      categoryName: 'Food',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    notifier.upsertTransaction(movedAway);

    final state = container.read(paginatedTransactionsProvider(accountName));
    expect(state.transactions, isEmpty);
  });

  test('upsert skips rows older than the all-accounts window', () async {
    final fake = FakeFireflyService(
      transactionPages: {
        1: TransactionPageResult(
          transactions: [_tx('1', DateTime(2026, 7, 10))],
          currentPage: 1,
          totalPages: 1,
          total: 1,
        ),
      },
    );
    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    final notifier = container.read(
      paginatedTransactionsProvider(null).notifier,
    );
    await waitForPaginatedLoad(container, null);

    notifier.upsertTransaction(
      _tx('ancient', DateTime.now().subtract(const Duration(days: 400))),
    );

    final state = container.read(paginatedTransactionsProvider(null));
    expect(state.transactions.map((t) => t.id).toList(), ['1']);
    expect(state.totalCount, 1);
  });

  test(
    'account-filtered instance ignores upserts for other accounts',
    () async {
      final fake = FakeFireflyService(
        accounts: sampleAccounts,
        accountTransactionPages: {
          sampleAccounts.first.id: {
            1: TransactionPageResult(
              transactions: [_tx('1', DateTime(2026, 7, 10))],
              currentPage: 1,
              totalPages: 1,
              total: 1,
            ),
          },
        },
      );
      final container = await _readyContainer(fake);
      addTearDown(container.dispose);

      final accountName = sampleAccounts.first.name;
      final notifier = container.read(
        paginatedTransactionsProvider(accountName).notifier,
      );
      await waitForPaginatedLoad(container, accountName);

      final unrelated = Transaction(
        id: 'other',
        type: 'withdrawal',
        date: DateTime(2026, 7, 9),
        amount: 5,
        description: 'unrelated',
        sourceName: 'Some Other Account',
        destinationName: 'Store',
        categoryName: 'Food',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );
      notifier.upsertTransaction(unrelated);

      final state = container.read(paginatedTransactionsProvider(accountName));
      expect(state.transactions.map((t) => t.id).toList(), ['1']);
    },
  );

  test('resolves counterparty payee accounts correctly', () async {
    final payeeAccount = Account(
      id: 'payee-99',
      name: 'Supermarket',
      type: 'expense',
      role: 'expense',
      currentBalance: 0,
      active: true,
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    final fake = FakeFireflyService(
      accounts: [payeeAccount],
      accountTransactionPages: {
        'payee-99': {
          1: TransactionPageResult(
            transactions: [
              _tx(
                'tx-payee-1',
                DateTime(2026, 7, 24),
                description: 'Groceries',
              ),
            ],
            currentPage: 1,
            totalPages: 1,
            total: 1,
          ),
        },
      },
    );

    final container = await _readyContainer(fake);
    addTearDown(container.dispose);

    container.read(paginatedTransactionsProvider('Supermarket'));
    final state = await waitForPaginatedLoad(
      container,
      'Supermarket',
      loadedPages: {1},
    );

    expect(state.transactions, hasLength(1));
    expect(state.transactions.first.id, 'tx-payee-1');
  });
}

/// Simulates [AuthNotifier] loading credentials from storage after first frame.
class _DelayedAuthNotifier extends AuthNotifier {
  @override
  AuthSettings build() {
    Future.microtask(
      () => state = AuthSettings(
        serverUrl: 'https://firefly.test',
        apiToken: 'token',
        isHydrated: true,
      ),
    );
    return AuthSettings();
  }
}

/// Keeps auth unhydrated until an explicit delayed hydration is needed in tests.
class _SlowHydratingAuthNotifier extends AuthNotifier {
  @override
  AuthSettings build() => AuthSettings();
}

class _PageTwoFailingService extends FakeFireflyService {
  _PageTwoFailingService({required super.transactionPages});

  @override
  Future<TransactionPageResult> getTransactionsPage({
    required int page,
    required int limit,
    DateTime? start,
    DateTime? end,
  }) async {
    if (page == 2) throw Exception('prefetch failed');
    return super.getTransactionsPage(
      page: page,
      limit: limit,
      start: start,
      end: end,
    );
  }
}
