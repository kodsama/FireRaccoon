import 'dart:convert';

import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import '../helpers/firefly_fixtures.dart';

http.Response jsonHttpResponse(
  Object body, {
  int status = 200,
  Map<String, String>? headers,
}) {
  return http.Response.bytes(
    utf8.encode(body is String ? body : jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
  );
}

void main() {
  const baseUrl = 'https://firefly.test';
  const token = 'test-token';

  FireflyApiService serviceWith(MockClient client) => FireflyApiService(
    serverUrl: baseUrl,
    apiToken: token,
    client: client,
    readRetryBaseDelayMs: 0,
  );

  group('concurrent pagination', () {
    test('getTransactions preserves page order across many pages', () async {
      const totalPages = 5;
      final client = MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        return jsonHttpResponse(
          transactionsPageBody(
            items: [transactionItem(id: 'tx-$page')],
            currentPage: page,
            totalPages: totalPages,
            total: totalPages,
          ),
        );
      });

      final transactions = await serviceWith(client).getTransactions();

      expect(transactions.map((t) => t.id).toList(), [
        'tx-1',
        'tx-2',
        'tx-3',
        'tx-4',
        'tx-5',
      ]);
    });

    test('getTransactions fails when any page fails', () async {
      final client = MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        if (page == 3) {
          return jsonHttpResponse({'message': 'boom'}, status: 500);
        }
        return jsonHttpResponse(
          transactionsPageBody(
            items: [transactionItem(id: 'tx-$page')],
            currentPage: page,
            totalPages: 4,
            total: 4,
          ),
        );
      });

      await expectLater(serviceWith(client).getTransactions(), throwsException);
    });
  });

  group('ranged fetches', () {
    test(
      'getAccountTransactions passes inclusive-start exclusive-end range',
      () async {
        late Uri firstUri;
        final client = MockClient((request) async {
          firstUri = request.url;
          return jsonHttpResponse(
            transactionsPageBody(items: [transactionItem(id: '1')]),
          );
        });

        await serviceWith(client).getAccountTransactions(
          '42',
          start: DateTime(2026, 6, 1),
          end: DateTime(2026, 7, 1),
        );

        expect(firstUri.path, '/api/v1/accounts/42/transactions');
        expect(firstUri.queryParameters['start'], '2026-06-01');
        // Exclusive end converts to the inclusive previous day for the API.
        expect(firstUri.queryParameters['end'], '2026-06-30');
      },
    );

    test('getAccountTransactions asks a one-day window Firefly will '
        'accept', () async {
      // Regression: a single date converted to start == end, which Firefly
      // refuses with "the start must be a date before end", so a statement
      // covering one day could not be reconciled at all.
      late Uri firstUri;
      final client = MockClient((request) async {
        firstUri = request.url;
        return jsonHttpResponse(
          transactionsPageBody(
            items: [
              transactionItem(id: '1', date: '2026-09-01'),
              transactionItem(id: '2', date: '2026-09-02'),
            ],
            total: 2,
          ),
        );
      });

      final result = await serviceWith(client).getAccountTransactions(
        '42',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 2),
      );

      expect(firstUri.queryParameters['start'], '2026-09-01');
      expect(firstUri.queryParameters['end'], '2026-09-02');
      // The day the widening pulled in is not the caller's, so it goes back.
      expect(result.map((t) => t.id), ['1']);
    });

    test('getTransactions trims a widened one-day window too', () async {
      final client = MockClient((request) async {
        return jsonHttpResponse(
          transactionsPageBody(
            items: [
              transactionItem(id: '1', date: '2026-09-01'),
              transactionItem(id: '2', date: '2026-09-02'),
            ],
            total: 2,
          ),
        );
      });

      final result = await serviceWith(
        client,
      ).getTransactions(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 2));

      expect(result.map((t) => t.id), ['1']);
    });

    test('a window wider than a day is returned as Firefly answered', () async {
      // Callers that pad on purpose rely on getting the padding back.
      final client = MockClient((request) async {
        return jsonHttpResponse(
          transactionsPageBody(
            items: [
              transactionItem(id: '1', date: '2026-09-01'),
              transactionItem(id: '2', date: '2026-09-05'),
            ],
            total: 2,
          ),
        );
      });

      final result = await serviceWith(client).getAccountTransactions(
        '42',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 4),
      );

      expect(result.map((t) => t.id), ['1', '2']);
    });

    test('getBudgetTransactions passes range', () async {
      late Uri firstUri;
      final client = MockClient((request) async {
        firstUri = request.url;
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem(id: '1')]),
        );
      });

      await serviceWith(client).getBudgetTransactions(
        '3',
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 7, 1),
      );

      expect(firstUri.path, '/api/v1/budgets/3/transactions');
      expect(firstUri.queryParameters['start'], '2026-06-01');
      expect(firstUri.queryParameters['end'], '2026-06-30');
    });

    test('getBudgets passes range so spent is period-scoped', () async {
      late Uri uri;
      final client = MockClient((request) async {
        uri = request.url;
        return jsonHttpResponse(budgetsBody());
      });

      final budgets = await serviceWith(
        client,
      ).getBudgets(start: DateTime(2026, 6, 1), end: DateTime(2026, 7, 1));

      expect(uri.path, '/api/v1/budgets');
      expect(uri.queryParameters['start'], '2026-06-01');
      expect(uri.queryParameters['end'], '2026-06-30');
      expect(budgets.single.spent, 120.0);
    });

    test('getBudgets without range sends no date params', () async {
      late Uri uri;
      final client = MockClient((request) async {
        uri = request.url;
        return jsonHttpResponse(budgetsBody());
      });

      await serviceWith(client).getBudgets();

      expect(uri.queryParameters.containsKey('start'), isFalse);
      expect(uri.queryParameters.containsKey('end'), isFalse);
    });
  });

  group('accounts', () {
    test(
      'getAccounts requests asset and liability types with paging',
      () async {
        final requested = <String>[];
        final client = MockClient((request) async {
          requested.add(request.url.query);
          return jsonHttpResponse(accountsBody());
        });

        final accounts = await serviceWith(client).getAccounts();

        expect(requested, hasLength(2));
        expect(requested.any((q) => q.contains('type=asset')), isTrue);
        expect(requested.any((q) => q.contains('type=liability')), isTrue);
        expect(requested.every((q) => q.contains('limit=')), isTrue);
        expect(accounts, hasLength(4));
      },
    );
  });

  group('retry policy', () {
    test('retries GET on 429 and honours Retry-After seconds', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return jsonHttpResponse(
            {'message': 'slow down'},
            status: 429,
            headers: {'retry-after': '0'},
          );
        }
        return jsonHttpResponse(primaryCurrencyBody());
      });

      final currency = await serviceWith(client).getPrimaryCurrency();

      expect(calls, 2);
      expect(currency.code, 'EUR');
    });
  });

  group('accounts extras', () {
    test('getAccounts follows pagination meta across pages', () async {
      final client = MockClient((request) async {
        final type = request.url.queryParameters['type']!;
        final page = int.parse(request.url.queryParameters['page'] ?? '1');
        if (type == 'liability') {
          return jsonHttpResponse({'data': <Object?>[]});
        }
        return jsonHttpResponse({
          'data': [
            {
              'id': 'a$page',
              'type': 'accounts',
              'attributes': {
                'name': 'Account $page',
                'type': 'asset',
                'current_balance': '1.00',
                'currency_symbol': '€',
                'currency_code': 'EUR',
              },
            },
          ],
          'meta': {
            'pagination': {'current_page': page, 'total_pages': 2},
          },
        });
      });

      final accounts = await serviceWith(client).getAccounts();

      expect(accounts.map((a) => a.id).toList(), ['a1', 'a2']);
    });

    test('getCurrencies follows pagination meta across pages', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/currencies');
        final page = int.parse(request.url.queryParameters['page'] ?? '1');
        final limit = request.url.queryParameters['limit'];
        expect(limit, isNotNull);
        if (page == 1) {
          return jsonHttpResponse({
            'data': [
              {
                'id': '1044',
                'type': 'currencies',
                'attributes': {
                  'code': '007',
                  'name': 'SEB Världenfond [007]',
                  'symbol': '007',
                  'enabled': true,
                },
              },
            ],
            'meta': {
              'pagination': {'current_page': 1, 'total_pages': 2},
            },
          });
        }
        return jsonHttpResponse({
          'data': [
            {
              'id': '1',
              'type': 'currencies',
              'attributes': {
                'code': 'EUR',
                'name': 'Euro',
                'symbol': '€',
                'enabled': true,
              },
            },
          ],
          'meta': {
            'pagination': {'current_page': 2, 'total_pages': 2},
          },
        });
      });

      final currencies = await serviceWith(client).getCurrencies();

      expect(currencies.map((c) => c.code).toList(), ['007', 'EUR']);
    });

    test(
      'getAccount passes date and getAccountBalanceAtDate reads balance',
      () async {
        late Uri uri;
        final client = MockClient((request) async {
          uri = request.url;
          return jsonHttpResponse({
            'data': {
              'id': '5',
              'type': 'accounts',
              'attributes': {
                'name': 'Checking',
                'type': 'asset',
                'current_balance': '123.45',
                'currency_symbol': '€',
                'currency_code': 'EUR',
              },
            },
          });
        });

        final balance = await serviceWith(
          client,
        ).getAccountBalanceAtDate('5', DateTime(2026, 6, 15));

        expect(uri.path, '/api/v1/accounts/5');
        expect(uri.queryParameters['date'], '2026-06-15');
        expect(balance, 123.45);
      },
    );

    test('getAccount throws on failure status', () async {
      final client = MockClient(
        (_) async => jsonHttpResponse({'message': 'nope'}, status: 404),
      );

      await expectLater(serviceWith(client).getAccount('5'), throwsException);
    });

    test('getAccountBalanceHistories parses chart datasets', () async {
      late Uri uri;
      final client = MockClient((request) async {
        uri = request.url;
        return jsonHttpResponse([
          {
            'label': 'Checking',
            'entries': {'2026-06-01': '10.0', '2026-06-02': '11.5'},
          },
        ]);
      });

      final accounts = [
        Account(
          id: '5',
          name: 'Checking',
          type: 'asset',
          role: 'defaultAsset',
          currentBalance: 0,
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
      ];
      final histories = await serviceWith(client).getAccountBalanceHistories(
        accounts: accounts,
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );

      expect(uri.path, '/api/v1/chart/balance/balance');
      expect(histories['Checking'], [10.0, 11.5]);
    });

    test('getAccountBalanceHistories throws on failure status', () async {
      final client = MockClient(
        (_) async => jsonHttpResponse({'message': 'nope'}, status: 500),
      );

      final accounts = [
        Account(
          id: '5',
          name: 'Checking',
          type: 'asset',
          role: 'defaultAsset',
          currentBalance: 0,
          currencySymbol: '€',
          currencyCode: 'EUR',
        ),
      ];
      await expectLater(
        serviceWith(client).getAccountBalanceHistories(
          accounts: accounts,
          start: DateTime(2026, 6, 1),
          end: DateTime(2026, 6, 30),
        ),
        throwsException,
      );
    });

    test('getAccountBalanceHistories skips non-balance accounts', () async {
      final client = MockClient((_) async => jsonHttpResponse(<Object?>[]));

      final histories = await serviceWith(client).getAccountBalanceHistories(
        accounts: [
          Account(
            id: '9',
            name: 'Groceries',
            type: 'expense',
            role: '',
            currentBalance: 0,
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
        ],
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );

      expect(histories, isEmpty);
    });
  });

  group('transaction extras', () {
    test('getTransaction throws on failure status', () async {
      final client = MockClient(
        (_) async => jsonHttpResponse({'message': 'nope'}, status: 404),
      );

      await expectLater(
        serviceWith(client).getTransaction('7'),
        throwsException,
      );
    });
  });

  group('logging extras', () {
    test('long response bodies are truncated in log previews', () async {
      final longDescription = 'x' * 2000;
      final client = MockClient(
        (_) async => jsonHttpResponse(
          transactionsPageBody(
            items: [transactionItem(id: '1', description: longDescription)],
          ),
        ),
      );

      final transactions = await serviceWith(client).getTransactions();

      expect(transactions.single.description, longDescription);
    });
  });

  group('search and type filters', () {
    test(
      'searchTransactionsPage hits the search endpoint with encoded query',
      () async {
        late Uri uri;
        final client = MockClient((request) async {
          uri = request.url;
          return jsonHttpResponse(
            transactionsPageBody(
              items: [transactionItem(id: 's1', description: 'Coffee shop')],
            ),
          );
        });

        final result = await serviceWith(
          client,
        ).searchTransactionsPage('coffee shop', page: 1, limit: 50);

        expect(uri.path, '/api/v1/search/transactions');
        expect(uri.queryParameters['query'], 'coffee shop');
        expect(uri.queryParameters['limit'], '50');
        expect(uri.queryParameters['page'], '1');
        expect(result.transactions.single.id, 's1');
      },
    );

    test('getTransactions passes server-side type filter', () async {
      late Uri firstUri;
      final client = MockClient((request) async {
        firstUri = request.url;
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem(id: '1')]),
        );
      });

      await serviceWith(client).getTransactions(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 7, 1),
        type: 'withdrawal',
      );

      expect(firstUri.queryParameters['type'], 'withdrawal');
    });
  });

  group('progressive loading', () {
    test(
      'onFirstPage fires with page 1 before remaining pages complete',
      () async {
        const totalPages = 3;
        final client = MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          return jsonHttpResponse(
            transactionsPageBody(
              items: [transactionItem(id: 'tx-$page')],
              currentPage: page,
              totalPages: totalPages,
              total: totalPages,
            ),
          );
        });

        List<String>? firstPageIds;
        final all = await serviceWith(client).getTransactions(
          onFirstPage: (firstPage) {
            firstPageIds = firstPage.map((t) => t.id).toList();
          },
        );

        expect(firstPageIds, ['tx-1']);
        expect(all.map((t) => t.id).toList(), ['tx-1', 'tx-2', 'tx-3']);
      },
    );

    test('onFirstPage is skipped for single-page results', () async {
      final client = MockClient(
        (_) async => jsonHttpResponse(
          transactionsPageBody(items: [transactionItem(id: '1')]),
        ),
      );

      var called = false;
      await serviceWith(client).getTransactions(
        onFirstPage: (_) {
          called = true;
        },
      );

      expect(called, isFalse);
    });
  });

  test('pages larger than one parse chunk are fully mapped', () async {
    final items = [for (var i = 0; i < 250; i++) transactionItem(id: 'tx-$i')];
    final client = MockClient(
      (_) async => jsonHttpResponse(
        transactionsPageBody(items: items, total: items.length),
      ),
    );

    final transactions = await serviceWith(client).getTransactions();

    expect(transactions, hasLength(250));
    expect(transactions.first.id, 'tx-0');
    expect(transactions.last.id, 'tx-249');
  });

  group('linked transaction pages', () {
    test(
      'getBillTransactionsPage hits the bill transactions endpoint',
      () async {
        late Uri uri;
        final client = MockClient((request) async {
          uri = request.url;
          return jsonHttpResponse(
            transactionsPageBody(items: [transactionItem(id: 'b1')]),
          );
        });

        final page = await serviceWith(
          client,
        ).getBillTransactionsPage('9', page: 1, limit: 20);

        expect(uri.path, '/api/v1/bills/9/transactions');
        expect(uri.queryParameters['limit'], '20');
        expect(page.transactions.single.id, 'b1');
      },
    );

    test(
      'getRecurrenceTransactionsPage hits the recurrence endpoint',
      () async {
        late Uri uri;
        final client = MockClient((request) async {
          uri = request.url;
          return jsonHttpResponse(
            transactionsPageBody(items: [transactionItem(id: 'r1')]),
          );
        });

        final page = await serviceWith(
          client,
        ).getRecurrenceTransactionsPage('4', page: 1, limit: 20);

        expect(uri.path, '/api/v1/recurrences/4/transactions');
        expect(page.transactions.single.id, 'r1');
      },
    );

    test('linked transaction pages surface failure statuses', () async {
      final client = MockClient(
        (_) async => jsonHttpResponse({'message': 'nope'}, status: 500),
      );

      await expectLater(
        serviceWith(client).getBillTransactionsPage('9', page: 1, limit: 20),
        throwsException,
      );
      await expectLater(
        serviceWith(
          client,
        ).getRecurrenceTransactionsPage('4', page: 1, limit: 20),
        throwsException,
      );
    });

    test('getAccounts custom types are requested verbatim', () async {
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.queryParameters['type']!);
        return jsonHttpResponse({'data': <Object?>[]});
      });

      await serviceWith(
        client,
      ).getAccounts(types: const ['expense', 'revenue']);

      expect(requested, containsAll(['expense', 'revenue']));
    });
  });
}
