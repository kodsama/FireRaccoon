import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import '../helpers/firefly_fixtures.dart';

http.Response jsonHttpResponse(Object body, {int status = 200}) {
  return http.Response.bytes(
    utf8.encode(body is String ? body : jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  const baseUrl = 'https://firefly.test';
  const token = 'test-token';

  group('FireflyApiService', () {
    tearDown(AppLogger.resetForTest);

    test('logs backend request and response details for each call', () async {
      final output = <String>[];
      AppLogger.configure(
        minLevel: Level.FINER,
        sink: output.add,
        secrets: const [token],
      );
      final client = MockClient(
        (_) async => jsonHttpResponse(primaryCurrencyBody()),
      );
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await service.getPrimaryCurrency();

      expect(
        output.any(
          (line) => line.contains('-> GET /api/v1/currencies/primary'),
        ),
        isTrue,
      );
      expect(
        output.any(
          (line) => line.contains('<- GET /api/v1/currencies/primary 200'),
        ),
        isTrue,
      );
      expect(output.any((line) => line.contains('response body=')), isTrue);
      expect(output.any((line) => line.contains(token)), isFalse);
    });

    test('strips trailing slash from server URL', () async {
      final client = MockClient((request) async {
        expect(request.url.origin, 'https://firefly.test');
        expect(request.url.path, '/api/v1/currencies/primary');
        expect(request.headers['Authorization'], 'Bearer $token');
        return jsonHttpResponse(primaryCurrencyBody());
      });

      final service = FireflyApiService(
        serverUrl: '$baseUrl/',
        apiToken: token,
        client: client,
      );

      final currency = await service.getPrimaryCurrency();
      expect(currency.code, 'EUR');
    });

    test('names the server URL when it answers with a web page', () async {
      // A UI host, or one behind single sign-on, redirects to a login page that
      // answers 200. Decoding that as JSON failed on the very first character,
      // so the report was of malformed data when the address was the problem.
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(
          '<!DOCTYPE html>\n<html lang="en"><head><title>Sign in</title>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        // One account type, so the count below is about retries and not about
        // the request this fans out per type.
        service.getAccounts(types: const ['asset']),
        throwsA(
          isA<FireflyApiException>().having(
            (error) => error.toString(),
            'message',
            allOf(contains('web page'), contains('firefly.test')),
          ),
        ),
      );
      // Reads retry, but asking again is served the same page.
      expect(requests, 1);
    });

    test('retries read requests on 5xx before succeeding', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        if (attempts < 3) {
          return http.Response('temporary failure', 503);
        }
        return jsonHttpResponse(primaryCurrencyBody());
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final currency = await service.getPrimaryCurrency();

      expect(currency.code, 'EUR');
      expect(attempts, 3);
    });

    test('read retries can be configured per service instance', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        return http.Response('temporary failure', 503);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
        readMaxAttempts: 2,
      );

      await expectLater(
        service.getPrimaryCurrency(),
        throwsA(isA<Exception>()),
      );
      expect(attempts, 2);
    });

    test('retry jitter can be configured deterministically', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        if (attempts < 3) {
          return http.Response('temporary failure', 503);
        }
        return jsonHttpResponse(primaryCurrencyBody());
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
        readMaxAttempts: 3,
        readRetryBaseDelayMs: 0,
        readRetryJitterMs: 5,
        random: Random(42),
      );

      final currency = await service.getPrimaryCurrency();
      expect(currency.code, 'EUR');
      expect(attempts, 3);
    });

    test('getPrimaryCurrency returns parsed currency', () async {
      final client = MockClient((request) async {
        return jsonHttpResponse(primaryCurrencyBody());
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final currency = await service.getPrimaryCurrency();
      expect(currency.id, '1');
      expect(currency.symbol, '€');
    });

    test('getPrimaryCurrency throws on non-200', () async {
      final client = MockClient((_) async => http.Response('error', 401));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(
        () => service.getPrimaryCurrency(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Network error'),
          ),
        ),
      );
    });

    test('setPrimaryCurrency posts to currencies/{code}/primary', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/currencies/USD/primary');
        return http.Response('', 204);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await service.setPrimaryCurrency('USD');
    });

    test('setPrimaryCurrency throws on non-204', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(
        () => service.setPrimaryCurrency('USD'),
        throwsA(isA<Exception>()),
      );
    });

    test('getCurrentUser returns parsed user', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/about/user');
        return jsonHttpResponse(userBody());
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final user = await service.getCurrentUser();
      expect(user.email, 'admin@local.test');
      expect(user.displayName, 'Admin');
    });

    test('getCurrentUser throws on failure', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(() => service.getCurrentUser(), throwsA(isA<Exception>()));
    });

    test('getAccounts returns parsed accounts', () async {
      final requestedTypes = <String>[];
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/accounts');
        requestedTypes.add(request.url.queryParameters['type'] ?? '');
        return jsonHttpResponse(accountsBody());
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final accounts = await service.getAccounts();
      expect(requestedTypes, containsAllInOrder(['asset', 'liability']));
      expect(accounts, hasLength(4));
      expect(accounts.first.name, 'Checking');
      expect(accounts.last.type, 'liability');
    });

    test('getAccounts throws on non-200', () async {
      final client = MockClient((_) async => http.Response('fail', 403));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(() => service.getAccounts(), throwsA(isA<Exception>()));
    });

    test('single-item reads retry transient connection errors', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        if (attempts == 1) {
          throw http.ClientException('connection reset');
        }
        return jsonHttpResponse({
          'data': {
            'id': '3',
            'attributes': {
              'name': 'Checking',
              'type': 'asset',
              'current_balance': '970.67',
              'currency_symbol': 'kr',
              'currency_code': 'SEK',
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
        readRetryBaseDelayMs: 0,
      );

      final account = await service.getAccount('3');

      expect(account.currentBalance, 970.67);
      expect(attempts, 2);
    });

    test('stalled requests time out and are retried', () async {
      var attempts = 0;
      final client = MockClient((_) {
        attempts++;
        if (attempts == 1) {
          // Never completes: simulates a hung connection.
          return Completer<http.Response>().future;
        }
        return Future.value(jsonHttpResponse(primaryCurrencyBody()));
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
        readRetryBaseDelayMs: 0,
        requestTimeout: const Duration(milliseconds: 50),
      );

      final currency = await service.getPrimaryCurrency();

      expect(currency.code, 'EUR');
      expect(attempts, 2);
    });

    test('stalled writes surface a timeout instead of hanging', () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
        requestTimeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.deleteBudget('9'),
        throwsA(predicate((e) => e.toString().contains('TimeoutException'))),
      );
    });

    test('non-positive request timeout falls back to the default', () {
      final output = <String>[];
      AppLogger.configure(minLevel: Level.INFO, sink: output.add);
      FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: MockClient((_) async => jsonHttpResponse(const {})),
        requestTimeout: Duration.zero,
      );
      expect(output.any((line) => line.contains('requestTimeout=45s')), isTrue);
    });

    test('getAccount returns parsed account with optional date', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/accounts/3');
        expect(request.url.queryParameters['date'], '2026-07-01');
        return jsonHttpResponse({
          'data': {
            'id': '3',
            'attributes': {
              'name': 'Checking',
              'type': 'asset',
              'current_balance': '1234.56',
              'currency_symbol': '€',
              'currency_code': 'EUR',
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final account = await service.getAccount(
        '3',
        date: DateTime(2026, 7, 1, 15, 30),
      );

      expect(account.name, 'Checking');
      expect(account.currentBalance, 1234.56);
    });

    test('getAccountBalanceHistories parses chart response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/chart/balance/balance');
        expect(request.url.queryParameters['start'], '2026-01-01');
        expect(request.url.queryParameters['end'], '2026-07-01');
        expect(request.url.queryParametersAll['accounts[]'], ['3']);
        return jsonHttpResponse([
          {
            'label': 'Checking',
            'entries': {'2026-01-01': '100', '2026-07-01': '500'},
          },
        ]);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final histories = await service.getAccountBalanceHistories(
        accounts: [
          Account(
            id: '3',
            name: 'Checking',
            type: 'asset',
            role: 'defaultAsset',
            currentBalance: 500,
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
        ],
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 7, 1),
      );

      expect(histories['Checking'], [100, 500]);
    });

    test('createLiability sends liability payload', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/accounts');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], 'liability');
        expect(body['liability_type'], 'loan');
        expect(body['opening_balance'], '2500.00');
        return jsonHttpResponse({
          'data': {
            'id': '9',
            'attributes': {
              'name': 'Car Loan',
              'type': 'liabilities',
              'current_balance': '2500.00',
              'currency_symbol': '€',
              'currency_code': 'EUR',
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final account = await service.createLiability(
        const LiabilityInput(
          name: 'Car Loan',
          currencyCode: 'EUR',
          liabilityType: LiabilityType.loan,
          liabilityDirection: LiabilityDirection.credit,
          amountOwed: 2500,
        ),
      );

      expect(account.name, 'Car Loan');
      expect(account.type, 'liability');
    });

    test('getBudgets returns parsed budgets', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/budgets');
        return jsonHttpResponse(budgetsBody());
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final budgets = await service.getBudgets();
      expect(budgets.single.name, 'Food');
      expect(budgets.single.spent, 120);
    });

    test('getBudgets throws on non-200', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(() => service.getBudgets(), throwsA(isA<Exception>()));
    });

    test('getTransactions passes custom start and end dates', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/transactions');
        expect(request.url.queryParameters['start'], '2026-01-01');
        expect(request.url.queryParameters['end'], '2026-12-31');
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem()]),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final transactions = await service.getTransactions(
        start: DateTime(2026, 1, 1),
        end: DateTime(2027, 1, 1),
      );
      expect(transactions.single.description, 'Groceries');
    });

    test('a window open at one end still names the other', () async {
      // An account's transactions endpoint answers a range carrying only one
      // bound with nothing at all, so asking for everything before a date came
      // back empty rather than answering the question.
      final queries = <String>[];
      final client = MockClient((request) async {
        queries.add(request.url.query);
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem()]),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await service.getTransactions(end: DateTime(2026, 8, 22));
      expect(queries.last, contains('start='));
      expect(queries.last, contains('end=2026-08-21'));

      await service.getTransactions(start: DateTime(2026, 1, 1));
      expect(queries.last, contains('start=2026-01-01'));
      expect(queries.last, contains('end='));
    });

    test('an account window open at one end names the other too', () async {
      // This is the endpoint the silence came from.
      final queries = <String>[];
      final client = MockClient((request) async {
        queries.add(request.url.query);
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem()]),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await service.getAccountTransactions('5', end: DateTime(2026, 8, 22));
      expect(queries.last, contains('start='));
      expect(queries.last, contains('end=2026-08-21'));
    });

    test('asking for no window asks for no window', () async {
      final queries = <String>[];
      final client = MockClient((request) async {
        queries.add(request.url.query);
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem()]),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await service.getTransactionsPage(page: 1, limit: 25);
      expect(queries.last, isNot(contains('start=')));
      expect(queries.last, isNot(contains('end=')));
    });

    test('getTransactionsPage fetches single page with start date', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/transactions');
        expect(request.url.query, contains('start='));
        expect(request.url.query, contains('limit=25'));
        expect(request.url.query, contains('page=2'));
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem()]),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final page = await service.getTransactionsPage(
        page: 2,
        limit: 25,
        start: DateTime(2026, 1, 1),
      );
      expect(page.transactions.single.description, 'Groceries');
      expect(page.currentPage, 1);
      expect(page.totalPages, 1);
    });

    test('getTransactionsPage fetches page without date constraint', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/transactions');
        expect(request.url.query, isNot(contains('start=')));
        expect(request.url.query, contains('limit=25'));
        expect(request.url.query, contains('page=2'));
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem()]),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final page = await service.getTransactionsPage(page: 2, limit: 25);
      expect(page.transactions.single.description, 'Groceries');
    });

    test('getTransactionsPage throws on bad status', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(
        () => service.getTransactionsPage(page: 1, limit: 50),
        throwsA(isA<Exception>()),
      );
    });

    test('getTransactions fetches all pages', () async {
      var page = 0;
      final client = MockClient((request) async {
        page++;
        if (page == 1) {
          return jsonHttpResponse(
            transactionsPageBody(
              items: [transactionItem(id: '1')],
              currentPage: 1,
              totalPages: 2,
              total: 2,
            ),
          );
        }
        return jsonHttpResponse(
          transactionsPageBody(
            items: [transactionItem(id: '2', description: 'Rent')],
            currentPage: 2,
            totalPages: 2,
            total: 2,
          ),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final transactions = await service.getTransactions();
      expect(transactions, hasLength(2));
      expect(transactions.map((t) => t.id), containsAll(['1', '2']));
    });

    test('wraps network failures in getTransactions', () async {
      final client = MockClient((_) async => throw Exception('socket'));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.getTransactions(),
        throwsA(
          predicate((Object e) => e.toString().contains('Network error')),
        ),
      );
    });

    test('getAccountTransactionsPage uses account path', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/accounts/5/transactions');
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem()]),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final page = await service.getAccountTransactionsPage(
        '5',
        page: 1,
        limit: 10,
      );
      expect(page.transactions, hasLength(1));
    });

    test('getAccountTransactions fetches all account pages', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/accounts/5/transactions');
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem()]),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final transactions = await service.getAccountTransactions('5');
      expect(transactions, hasLength(1));
    });

    test('getBudgetTransactions fetches budget transaction pages', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/budgets/3/transactions');
        return jsonHttpResponse(
          transactionsPageBody(items: [transactionItem()]),
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final transactions = await service.getBudgetTransactions('3');
      expect(transactions, hasLength(1));
    });

    test('deleteBudget succeeds on 204', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/budgets/3');
        return http.Response('', 204);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(service.deleteBudget('3'), completes);
    });

    test('deleteBudget succeeds on 200', () async {
      final client = MockClient((_) async => http.Response('', 200));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(service.deleteBudget('3'), completes);
    });

    test('deleteBudget throws on failure', () async {
      final client = MockClient((_) async => http.Response('fail', 404));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(() => service.deleteBudget('3'), throwsA(isA<Exception>()));
    });

    test('updateAccount sends PUT with name', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/accounts/5');
        expect(request.headers['Content-Type'], 'application/json');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'Savings');
        return http.Response('', 200);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(service.updateAccount('5', name: 'Savings'), completes);
    });

    test('updateAccount sends PUT with extended attributes', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/accounts/5');
        expect(request.headers['Content-Type'], 'application/json');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'New Name');
        expect(body['currency_code'], 'USD');
        expect(body['include_net_worth'], false);
        expect(body['opening_balance'], '1000.50');
        expect(body['opening_balance_date'], '2026-01-01');
        expect(body['virtual_balance'], '500.00');
        expect(body['interest'], '2.5');
        expect(body['interest_period'], 'monthly');
        return http.Response('', 200);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.updateAccount(
          '5',
          name: 'New Name',
          currencyCode: 'USD',
          includeNetWorth: false,
          openingBalance: 1000.50,
          openingBalanceDate: DateTime(2026, 1, 1),
          virtualBalance: 500.0,
          interest: 2.5,
          interestPeriod: 'monthly',
        ),
        completes,
      );
    });

    test('updateAccount throws on failure', () async {
      final client = MockClient((_) async => http.Response('fail', 422));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(
        () => service.updateAccount('5', name: 'X'),
        throwsA(isA<Exception>()),
      );
    });

    test('updateBudget sends PUT with budget input', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/budgets/3');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'Food');
        expect(body['auto_budget_amount'], '400.00');
        expect(body['auto_budget_type'], 'reset');
        expect(body['auto_budget_period'], 'monthly');
        return http.Response('', 200);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.updateBudget(
          '3',
          const BudgetInput(
            name: 'Food',
            autoBudgetType: AutoBudgetType.reset,
            autoBudgetAmount: 400,
            autoBudgetPeriod: AutoBudgetPeriod.monthly,
            currencyCode: 'EUR',
          ),
        ),
        completes,
      );
    });

    test('updateBudget throws on failure', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(
        () => service.updateBudget(
          '3',
          const BudgetInput(name: 'Food', currencyCode: 'EUR'),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('getBudgetLimits fetches limits with optional date range', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/budgets/3/limits');
        expect(request.url.queryParameters['start'], '2026-01-01');
        expect(request.url.queryParameters['end'], '2026-01-31');
        return jsonHttpResponse({
          'data': [
            {
              'id': '11',
              'attributes': {
                'budget_id': '3',
                'start': '2026-01-01',
                'end': '2026-01-31',
                'amount': '400.00',
                'currency_code': 'EUR',
                'currency_symbol': '€',
              },
            },
          ],
          'meta': {
            'pagination': {'total_pages': 1, 'current_page': 1},
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final limits = await service.getBudgetLimits(
        '3',
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
      );
      expect(limits, hasLength(1));
      expect(limits.single.amount, 400);
      expect(limits.single.budgetId, '3');
    });

    test('getBudgetLimits without dates omits date query params', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/budgets/3/limits');
        expect(request.url.queryParameters.containsKey('start'), isFalse);
        expect(request.url.queryParameters.containsKey('end'), isFalse);
        return jsonHttpResponse({
          'data': <Map<String, dynamic>>[],
          'meta': {
            'pagination': {'total_pages': 1, 'current_page': 1},
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final limits = await service.getBudgetLimits('3');
      expect(limits, isEmpty);
    });

    test('an unbounded window asks for dates Firefly accepts', () async {
      // Firefly validates both ends against 32-bit time and answers 422
      // otherwise: "The start must be a date after 1970-01-02", "The end must
      // be a date before 2038-01-17". Naming both ends of an open window only
      // helps if the ends are ones the server will take, and a 422 here reads
      // as an account holding no transactions at all.
      late Uri asked;
      final client = MockClient((request) async {
        asked = request.url;
        return jsonHttpResponse({
          'data': <Map<String, dynamic>>[],
          'meta': {
            'pagination': {'total_pages': 1, 'current_page': 1},
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      // Open at the start: the sentinel stands in for "everything before".
      await service.getAccountTransactionsPage(
        '5',
        page: 1,
        limit: 20,
        end: DateTime(2026, 8, 24),
      );
      expect(
        DateTime.parse(
          asked.queryParameters['start']!,
        ).isAfter(DateTime(1970, 1, 2)),
        isTrue,
      );

      // Open at the end: the sentinel stands in for "everything after".
      await service.getAccountTransactionsPage(
        '5',
        page: 1,
        limit: 20,
        start: DateTime(2026, 8, 24),
      );
      expect(
        DateTime.parse(
          asked.queryParameters['end']!,
        ).isBefore(DateTime(2038, 1, 17)),
        isTrue,
      );
    });

    test('getBudgetLimits wraps failures', () async {
      final client = MockClient((_) async => throw Exception('socket'));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.getBudgetLimits('3'),
        throwsA(
          predicate((Object e) => e.toString().contains('Network error')),
        ),
      );
    });

    test('createBudgetLimit posts limit payload', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/budgets/3/limits');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['amount'], '400.00');
        expect(body['currency_code'], 'EUR');
        return jsonHttpResponse({
          'data': {
            'id': '11',
            'attributes': {
              'budget_id': '3',
              'start': '2026-01-01',
              'end': '2026-01-31',
              'amount': '400.00',
              'currency_code': 'EUR',
              'currency_symbol': '€',
            },
          },
        }, status: 201);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final limit = await service.createBudgetLimit(
        '3',
        BudgetLimitInput(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 1, 31),
          amount: 400,
          currencyCode: 'EUR',
        ),
      );
      expect(limit.id, '11');
      expect(limit.amount, 400);
    });

    test('createBudgetLimit throws on bad status and network errors', () async {
      final failing = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: MockClient((_) async => http.Response('fail', 500)),
      );
      final throwing = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: MockClient((_) async => throw Exception('socket')),
      );
      final input = BudgetLimitInput(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
        amount: 400,
        currencyCode: 'EUR',
      );

      await expectLater(
        failing.createBudgetLimit('3', input),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        throwing.createBudgetLimit('3', input),
        throwsA(
          predicate((Object e) => e.toString().contains('Network error')),
        ),
      );
    });

    test('updateBudgetLimit sends PUT with limit payload', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/budgets/3/limits/11');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['amount'], '450.00');
        return http.Response('', 200);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.updateBudgetLimit(
          '3',
          '11',
          BudgetLimitInput(
            start: DateTime(2026, 1, 1),
            end: DateTime(2026, 1, 31),
            amount: 450,
            currencyCode: 'EUR',
          ),
        ),
        completes,
      );
    });

    test('updateBudgetLimit throws on bad status and network errors', () async {
      final failing = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: MockClient((_) async => http.Response('fail', 500)),
      );
      final throwing = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: MockClient((_) async => throw Exception('socket')),
      );
      final input = BudgetLimitInput(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31),
        amount: 450,
        currencyCode: 'EUR',
      );

      await expectLater(
        failing.updateBudgetLimit('3', '11', input),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        throwing.updateBudgetLimit('3', '11', input),
        throwsA(
          predicate((Object e) => e.toString().contains('Network error')),
        ),
      );
    });

    test('transaction fetch throws when page request fails', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(
        () => service.getAccountTransactions('5'),
        throwsA(isA<Exception>()),
      );
    });

    test('uses default http client when none is provided', () {
      final service = FireflyApiService(serverUrl: baseUrl, apiToken: token);
      expect(service.serverUrl, baseUrl);
    });

    test('wraps network failures in account transaction page fetch', () async {
      final client = MockClient(
        (_) async => throw const FormatException('bad json'),
      );
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.getAccountTransactionsPage('5', page: 1, limit: 10),
        throwsA(
          predicate((Object e) => e.toString().contains('Network error')),
        ),
      );
    });

    test('wraps network failures in account transaction list fetch', () async {
      final client = MockClient((_) async => throw Exception('socket'));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.getAccountTransactions('5'),
        throwsA(
          predicate((Object e) => e.toString().contains('Network error')),
        ),
      );
    });

    test('wraps network failures in budget transaction fetch', () async {
      final client = MockClient((_) async => throw Exception('socket'));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.getBudgetTransactions('3'),
        throwsA(
          predicate((Object e) => e.toString().contains('Network error')),
        ),
      );
    });

    test('wraps network failures in deleteBudget', () async {
      final client = MockClient((_) async => throw Exception('socket'));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.deleteBudget('3'),
        throwsA(
          predicate((Object e) => e.toString().contains('Network error')),
        ),
      );
    });

    test('wraps network failures in updateBudget', () async {
      final client = MockClient((_) async => throw Exception('socket'));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.updateBudget(
          '3',
          const BudgetInput(name: 'Food', currencyCode: 'EUR'),
        ),
        throwsA(
          predicate((Object e) => e.toString().contains('Network error')),
        ),
      );
    });

    test('createBill sends POST with subscription fields', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/bills');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'Monthly Rent');
        expect(body['amount_min'], '1200.00');
        expect(body['repeat_freq'], 'monthly');
        return jsonHttpResponse({
          'data': {
            'id': '9',
            'attributes': {
              'name': 'Monthly Rent',
              'amount_min': '1200.00',
              'amount_max': '1200.00',
              'amount_avg': '1200.00',
              'currency_code': 'EUR',
              'currency_symbol': '€',
              'date': '2021-03-01',
              'repeat_freq': 'monthly',
              'active': true,
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final bill = await service.createBill(
        BillInput(
          name: 'Monthly Rent',
          amountMin: 1200,
          amountMax: 1200,
          currencyCode: 'EUR',
          date: DateTime(2021, 3, 1),
          repeatFrequency: BillRepeatFrequency.monthly,
        ),
      );

      expect(bill.name, 'Monthly Rent');
    });

    test('updateBill sends PUT with subscription fields', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/bills/9');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['skip'], 1);
        return jsonHttpResponse({
          'data': {
            'id': '9',
            'attributes': {
              'name': 'Monthly Rent',
              'amount_min': '1200.00',
              'amount_max': '1200.00',
              'amount_avg': '1200.00',
              'currency_code': 'EUR',
              'currency_symbol': '€',
              'date': '2021-03-01',
              'repeat_freq': 'monthly',
              'skip': 1,
              'active': true,
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final bill = await service.updateBill(
        '9',
        BillInput(
          name: 'Monthly Rent',
          amountMin: 1200,
          amountMax: 1200,
          currencyCode: 'EUR',
          date: DateTime(2021, 3, 1),
          repeatFrequency: BillRepeatFrequency.monthly,
          skip: 1,
        ),
      );

      expect(bill.skip, 1);
    });

    test('deleteBill succeeds on 204', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/bills/9');
        return http.Response('', 204);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(service.deleteBill('9'), completes);
    });

    test('createPiggyBank sends POST with piggy bank fields', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/piggy-banks');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'New Laptop');
        expect(body['transaction_currency_code'], 'EUR');
        expect(body['accounts'], [
          {'account_id': '1'},
        ]);
        return jsonHttpResponse({
          'data': {
            'id': '4',
            'attributes': {
              'name': 'New Laptop',
              'target_amount': '2500.00',
              'current_amount': '0.00',
              'currency_code': 'EUR',
              'currency_symbol': '€',
              'start_date': '2023-01-01T00:00:00+00:00',
              'accounts': [],
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final piggy = await service.createPiggyBank(
        PiggyBankInput(
          name: 'New Laptop',
          targetAmount: 2500,
          currencyCode: 'EUR',
          accountIds: const ['1'],
          startDate: DateTime(2023, 1, 1),
        ),
      );

      expect(piggy.name, 'New Laptop');
    });

    test('deletePiggyBank succeeds on 204', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/piggy-banks/4');
        return http.Response('', 204);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(service.deletePiggyBank('4'), completes);
    });

    test('createRecurrence sends POST with recurrence fields', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/recurrences');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], 'withdrawal');
        expect(body['title'], 'Salary');
        expect(body['first_date'], '2026-08-08');
        expect(body['repetitions'], hasLength(1));
        expect(body['transactions'], hasLength(1));
        return jsonHttpResponse({
          'data': {
            'id': '12',
            'attributes': {
              'type': 'withdrawal',
              'title': 'Salary',
              'first_date': '2026-08-08',
              'active': true,
              'apply_rules': true,
              'repetitions': [
                {'type': 'monthly', 'moment': '8', 'skip': 0, 'weekend': 1},
              ],
              'transactions': [
                {
                  'id': '55',
                  'description': 'Salary payment',
                  'amount': '3500.00',
                  'currency_code': 'EUR',
                  'currency_symbol': '€',
                  'source_id': '1',
                  'destination_id': '2',
                },
              ],
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final recurrence = await service.createRecurrence(
        RecurrenceInput(
          type: RecurrenceTransactionType.withdrawal,
          title: 'Salary',
          firstDate: DateTime(2026, 8, 8),
          repetitions: const [
            RecurrenceRepetitionInput(
              type: RecurrenceRepetitionType.monthly,
              moment: '8',
            ),
          ],
          transactions: const [
            RecurrenceTransactionInput(
              description: 'Salary payment',
              amount: 3500,
              currencyCode: 'EUR',
              sourceId: '1',
              destinationId: '2',
            ),
          ],
        ),
      );

      expect(recurrence.title, 'Salary');
    });

    test('deleteRecurrence succeeds on 204', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/recurrences/12');
        return http.Response('', 204);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(service.deleteRecurrence('12'), completes);
    });

    test('deleteAccount succeeds on 204 and 200', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/accounts/5');
        return http.Response('', calls == 1 ? 204 : 200);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(service.deleteAccount('5'), completes);
      await expectLater(service.deleteAccount('5'), completes);
    });

    test('deleteAccount throws on non-success status', () async {
      final client = MockClient((_) async => http.Response('fail', 409));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(service.deleteAccount('5'), throwsA(isA<Exception>()));
    });

    test('createAccount sends POST and parses response', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/accounts');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        // Firefly rejects an asset account without a role, so one is defaulted.
        expect(body, {
          'name': 'Savings',
          'type': 'asset',
          'currency_code': 'EUR',
          'account_role': 'defaultAsset',
        });
        return jsonHttpResponse({
          'data': {
            'id': '11',
            'attributes': {
              'name': 'Savings',
              'type': 'asset',
              'current_balance': '0.00',
              'currency_symbol': '€',
              'currency_code': 'EUR',
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final account = await service.createAccount(
        name: 'Savings',
        type: 'asset',
        currencyCode: 'EUR',
      );
      expect(account.id, '11');
      expect(account.name, 'Savings');
    });

    test('createAccount sends no role for a non-asset type', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonHttpResponse({
          'data': {
            'id': '12',
            'attributes': {
              'name': 'Rent',
              'type': 'expense',
              'current_balance': '0.00',
              'currency_symbol': '\u20ac',
              'currency_code': 'EUR',
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await service.createAccount(
        name: 'Rent',
        type: 'expense',
        currencyCode: 'EUR',
      );

      expect(sent!.containsKey('account_role'), isFalse);
    });

    test('createAccount honours an explicit role', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonHttpResponse({
          'data': {
            'id': '13',
            'attributes': {
              'name': 'Card',
              'type': 'asset',
              'current_balance': '0.00',
              'currency_symbol': '\u20ac',
              'currency_code': 'EUR',
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await service.createAccount(
        name: 'Card',
        type: 'asset',
        currencyCode: 'EUR',
        role: 'ccAsset',
      );

      expect(sent!['account_role'], 'ccAsset');
    });

    test('createAccount throws on failure status', () async {
      final client = MockClient((_) async => http.Response('fail', 422));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.createAccount(
          name: 'Savings',
          type: 'asset',
          currencyCode: 'EUR',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('createBudget sends POST and parses response', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/budgets');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'Travel');
        expect(body['auto_budget_amount'], '700.50');
        expect(body['auto_budget_currency_code'], 'EUR');
        expect(body['auto_budget_type'], 'reset');
        expect(body['auto_budget_period'], 'monthly');
        return jsonHttpResponse({
          'data': {
            'id': '12',
            'attributes': {
              'name': 'Travel',
              'active': true,
              'spent': [
                {'sum': '0.00', 'currency_code': 'EUR'},
              ],
              'auto_budget_amount': '700.50',
              'auto_budget_type': 'reset',
              'auto_budget_period': 'monthly',
              'auto_budget_currency_symbol': '€',
              'auto_budget_currency_code': 'EUR',
            },
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final budget = await service.createBudget(
        const BudgetInput(
          name: 'Travel',
          autoBudgetType: AutoBudgetType.reset,
          autoBudgetAmount: 700.5,
          autoBudgetPeriod: AutoBudgetPeriod.monthly,
          currencyCode: 'EUR',
        ),
      );
      expect(budget.name, 'Travel');
      expect(budget.autoBudgetAmount, 700.5);
    });

    test('createBudget throws on failure status', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.createBudget(
          const BudgetInput(
            name: 'Travel',
            autoBudgetType: AutoBudgetType.reset,
            autoBudgetAmount: 1,
            autoBudgetPeriod: AutoBudgetPeriod.monthly,
            currencyCode: 'EUR',
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'getCategories, getTags, getBills and getCurrencies parse lists',
      () async {
        final client = MockClient((request) async {
          switch (request.url.path) {
            case '/api/v1/categories':
              return jsonHttpResponse({
                'data': [
                  {
                    'id': '1',
                    'attributes': {'name': 'Food'},
                  },
                ],
              });
            case '/api/v1/tags':
              return jsonHttpResponse({
                'data': [
                  {
                    'id': '2',
                    'attributes': {'tag': 'urgent'},
                  },
                ],
              });
            case '/api/v1/bills':
              return jsonHttpResponse({
                'data': [
                  {
                    'id': '9',
                    'attributes': {
                      'name': 'Rent',
                      'amount_min': '1200.00',
                      'amount_max': '1200.00',
                      'amount_avg': '1200.00',
                      'currency_code': 'EUR',
                      'currency_symbol': '€',
                      'date': '2021-03-01',
                      'repeat_freq': 'monthly',
                      'active': true,
                    },
                  },
                ],
              });
            case '/api/v1/currencies':
              return jsonHttpResponse({
                'data': [
                  {
                    'id': '1',
                    'attributes': {
                      'code': 'EUR',
                      'name': 'Euro',
                      'symbol': '€',
                    },
                  },
                ],
              });
            default:
              return http.Response('not found', 404);
          }
        });
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );

        final categories = await service.getCategories();
        final tags = await service.getTags();
        final bills = await service.getBills();
        final currencies = await service.getCurrencies();

        expect(categories.single.name, 'Food');
        expect(tags.single.name, 'urgent');
        expect(bills.single.name, 'Rent');
        expect(currencies.single.code, 'EUR');
      },
    );

    test('list helpers throw on non-200', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(service.getCategories(), throwsA(isA<Exception>()));
      await expectLater(service.getTags(), throwsA(isA<Exception>()));
      await expectLater(service.getBills(), throwsA(isA<Exception>()));
      await expectLater(service.getCurrencies(), throwsA(isA<Exception>()));
      await expectLater(service.getRecurrences(), throwsA(isA<Exception>()));
      await expectLater(service.getPiggyBanks(), throwsA(isA<Exception>()));
    });

    test('getRecurrences and getPiggyBanks parse lists', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/recurrences') {
          return jsonHttpResponse({
            'data': [
              {
                'id': '12',
                'attributes': {
                  'type': 'withdrawal',
                  'title': 'Salary',
                  'first_date': '2026-08-08',
                  'active': true,
                  'apply_rules': true,
                  'repetitions': [
                    {'type': 'monthly', 'moment': '8', 'skip': 0, 'weekend': 1},
                  ],
                  'transactions': [
                    {
                      'id': '55',
                      'description': 'Salary payment',
                      'amount': '3500.00',
                      'currency_code': 'EUR',
                      'currency_symbol': '€',
                      'source_id': '1',
                      'destination_id': '2',
                    },
                  ],
                },
              },
            ],
          });
        }
        return jsonHttpResponse({
          'data': [
            {
              'id': '4',
              'attributes': {
                'name': 'New Laptop',
                'target_amount': '2500.00',
                'current_amount': '0.00',
                'currency_code': 'EUR',
                'currency_symbol': '€',
                'start_date': '2023-01-01T00:00:00+00:00',
                'accounts': [],
              },
            },
          ],
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final recurrences = await service.getRecurrences();
      final piggies = await service.getPiggyBanks();

      expect(recurrences.single.title, 'Salary');
      expect(piggies.single.name, 'New Laptop');
    });

    test('mutation endpoints throw on network exceptions', () async {
      final client = MockClient((_) async => throw Exception('socket'));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final tx = Transaction(
        id: '77',
        date: DateTime(2026, 1, 1),
        amount: 12,
        description: 'Coffee',
        type: 'withdrawal',
        sourceName: 'Wallet',
        destinationName: 'Cafe',
        categoryName: 'Food',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );

      await expectLater(
        service.deleteAccount('5'),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        service.createAccount(name: 'A', type: 'asset', currencyCode: 'EUR'),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        service.createBudget(
          const BudgetInput(
            name: 'B',
            autoBudgetType: AutoBudgetType.reset,
            autoBudgetAmount: 1,
            autoBudgetPeriod: AutoBudgetPeriod.monthly,
            currencyCode: 'EUR',
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        service.createTransaction(tx),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        service.updateTransaction(tx),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        service.deleteTransaction('77'),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        service.updateBill(
          '9',
          BillInput(
            name: 'Rent',
            amountMin: 1,
            amountMax: 1,
            currencyCode: 'EUR',
            date: DateTime(2021, 3, 1),
            repeatFrequency: BillRepeatFrequency.monthly,
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        service.createRecurrence(
          RecurrenceInput(
            type: RecurrenceTransactionType.withdrawal,
            title: 'Salary',
            firstDate: DateTime(2026, 8, 8),
            repetitions: const [
              RecurrenceRepetitionInput(
                type: RecurrenceRepetitionType.monthly,
                moment: '8',
              ),
            ],
            transactions: const [
              RecurrenceTransactionInput(
                description: 'Salary payment',
                amount: 3500,
                currencyCode: 'EUR',
                sourceId: '1',
                destinationId: '2',
              ),
            ],
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
    });

    test('getTransaction fetches a single journal by id', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/transactions/88');
        return jsonHttpResponse({'data': transactionItem(id: '88')});
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final transaction = await service.getTransaction('88');
      expect(transaction.id, '88');
    });

    test(
      'create and update transaction use expected method and path',
      () async {
        final responses = <String>[];
        final client = MockClient((request) async {
          responses.add('${request.method} ${request.url.path}');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['transactions'], isA<List<dynamic>>());
          return jsonHttpResponse({
            'data': transactionItem(id: '88', description: 'Edited'),
          });
        });
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );
        final transaction = Transaction(
          id: '88',
          date: DateTime(2026, 1, 1),
          amount: 99,
          description: 'Original',
          type: 'withdrawal',
          sourceName: 'Wallet',
          destinationName: 'Store',
          categoryName: 'Misc',
          currencySymbol: '€',
          currencyCode: 'EUR',
        );

        final created = await service.createTransaction(transaction);
        final updated = await service.updateTransaction(
          transaction.copyWith(reconciled: true),
        );

        expect(created.id, '88');
        expect(updated.description, 'Edited');
        expect(responses, [
          'POST /api/v1/transactions',
          'PUT /api/v1/transactions/88',
        ]);
      },
    );

    test('update transaction sends reconciled flag in payload', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final splits = body['transactions'] as List<dynamic>;
        expect(splits.first['reconciled'], isTrue);
        return jsonHttpResponse({
          'data': transactionItem(id: '88', description: 'Edited'),
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );
      final transaction = Transaction(
        id: '88',
        date: DateTime(2026, 1, 1),
        amount: 99,
        description: 'Original',
        type: 'withdrawal',
        sourceName: 'Wallet',
        destinationName: 'Store',
        categoryName: 'Misc',
        currencySymbol: '€',
        currencyCode: 'EUR',
        reconciled: true,
      );

      await service.updateTransaction(transaction);
    });

    test('create/update transaction throw on non-success status', () async {
      final client = MockClient((_) async => http.Response('fail', 422));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );
      final transaction = Transaction(
        id: '88',
        date: DateTime(2026, 1, 1),
        amount: 99,
        description: 'Original',
        type: 'withdrawal',
        sourceName: 'Wallet',
        destinationName: 'Store',
        categoryName: 'Misc',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );

      await expectLater(
        service.createTransaction(transaction),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        service.updateTransaction(transaction),
        throwsA(isA<Exception>()),
      );
    });

    test('a refused transaction says it once, and is not a network error', () {
      // Firefly repeats one sentence across every candidate field: an
      // unresolved source account comes back over source_id, source_name,
      // source_iban and source_number. All four went to the reader, prefixed
      // "Network error", for a request Firefly had answered.
      const refusal =
          'Could not find a valid source account when searching for ID '
          '"11553" or name "Akademikernas a-kassa".';
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'The given data was invalid.',
            'errors': {
              'transactions.0.source_id': [refusal],
              'transactions.0.source_name': [refusal],
              'transactions.0.source_iban': [refusal],
              'transactions.0.source_number': [refusal],
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );
      final transaction = Transaction(
        id: '88',
        date: DateTime(2026, 1, 1),
        amount: 99,
        description: 'A-kassa',
        type: 'deposit',
        sourceName: 'Akademikernas a-kassa',
        destinationName: 'Wallet',
        categoryName: '',
        currencySymbol: '€',
        currencyCode: 'EUR',
      );

      return expectLater(
        service.updateTransaction(transaction),
        throwsA(
          isA<FireflyApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => refusal.allMatches(e.message).length,
                'times the sentence appears',
                1,
              )
              .having(
                (e) => e.fieldErrors.keys.length,
                'fields Firefly named',
                4,
              )
              .having(
                (e) => e.toString(),
                'toString',
                isNot(contains('Network error')),
              ),
        ),
      );
    });

    test(
      'deleteTransaction supports 204 and 200 and throws otherwise',
      () async {
        var call = 0;
        final client = MockClient((request) async {
          call++;
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v1/transactions/88');
          if (call == 1) return http.Response('', 204);
          if (call == 2) return http.Response('', 200);
          return http.Response('fail', 500);
        });
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );

        await expectLater(service.deleteTransaction('88'), completes);
        await expectLater(service.deleteTransaction('88'), completes);
        await expectLater(
          service.deleteTransaction('88'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'updateRecurrence and updatePiggyBank send PUT and parse responses',
      () async {
        final client = MockClient((request) async {
          if (request.url.path == '/api/v1/recurrences/12') {
            expect(request.method, 'PUT');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['title'], 'Salary Edited');
            return jsonHttpResponse({
              'data': {
                'id': '12',
                'attributes': {
                  'type': 'withdrawal',
                  'title': 'Salary Edited',
                  'first_date': '2026-08-08',
                  'active': true,
                  'apply_rules': true,
                  'repetitions': [
                    {'type': 'monthly', 'moment': '8', 'skip': 0, 'weekend': 1},
                  ],
                  'transactions': [
                    {
                      'id': '55',
                      'description': 'Salary payment',
                      'amount': '3500.00',
                      'currency_code': 'EUR',
                      'currency_symbol': '€',
                      'source_id': '1',
                      'destination_id': '2',
                    },
                  ],
                },
              },
            });
          }

          expect(request.method, 'PUT');
          expect(request.url.path, '/api/v1/piggy-banks/4');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'Laptop 2');
          return jsonHttpResponse({
            'data': {
              'id': '4',
              'attributes': {
                'name': 'Laptop 2',
                'target_amount': '3000.00',
                'current_amount': '200.00',
                'currency_code': 'EUR',
                'currency_symbol': '€',
                'start_date': '2023-01-01T00:00:00+00:00',
                'accounts': [],
              },
            },
          });
        });
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );

        final recurrence = await service.updateRecurrence(
          '12',
          RecurrenceInput(
            type: RecurrenceTransactionType.withdrawal,
            title: 'Salary Edited',
            firstDate: DateTime(2026, 8, 8),
            repetitions: const [
              RecurrenceRepetitionInput(
                type: RecurrenceRepetitionType.monthly,
                moment: '8',
              ),
            ],
            transactions: const [
              RecurrenceTransactionInput(
                id: '55',
                description: 'Salary payment',
                amount: 3500,
                currencyCode: 'EUR',
                sourceId: '1',
                destinationId: '2',
              ),
            ],
          ),
        );

        final piggy = await service.updatePiggyBank(
          '4',
          PiggyBankInput(
            name: 'Laptop 2',
            targetAmount: 3000,
            currencyCode: 'EUR',
            accountIds: const ['1'],
            startDate: DateTime(2023, 1, 1),
          ),
        );

        expect(recurrence.title, 'Salary Edited');
        expect(piggy.name, 'Laptop 2');
      },
    );

    group('a schedule Firefly will not revalidate', () {
      // Firefly checks `repetitions.*.moment` as numeric|max:10 on update and
      // not on store, so a monthly rule falling after the 10th can be created
      // and then never edited, however unrelated the edit. It only validates
      // what the request carries, so an untouched schedule stays off it.
      Map<String, dynamic> attributesOnThe28th({String title = 'Fello'}) => {
        'type': 'withdrawal',
        'title': title,
        'first_date': '2026-08-28',
        'active': true,
        'apply_rules': true,
        'repetitions': [
          {'type': 'monthly', 'moment': '28', 'skip': 0, 'weekend': 1},
        ],
        'transactions': [
          {
            'id': '55',
            'description': 'Fello',
            'amount': '450.00',
            'currency_code': 'SEK',
            'source_id': '1',
            'destination_id': '2',
          },
        ],
      };

      RecurrenceInput inputOnThe(String moment, {String title = 'Fello'}) =>
          RecurrenceInput(
            type: RecurrenceTransactionType.withdrawal,
            title: title,
            firstDate: DateTime(2026, 8, 28),
            repetitions: [
              RecurrenceRepetitionInput(
                type: RecurrenceRepetitionType.monthly,
                moment: moment,
                weekend: RecurrenceWeekendMode.createAnyway,
              ),
            ],
            transactions: const [
              RecurrenceTransactionInput(
                id: '55',
                description: 'Fello',
                amount: 450,
                currencyCode: 'SEK',
                sourceId: '1',
                destinationId: '2',
              ),
            ],
          );

      test('is left off an update that did not touch it', () async {
        Map<String, dynamic>? sent;
        final client = MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonHttpResponse({
            'data': {'id': '111', 'attributes': attributesOnThe28th()},
          });
        });
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );

        await service.updateRecurrence(
          '111',
          inputOnThe('28', title: 'Fello renamed'),
          current: Recurrence.fromJson({
            'id': '111',
            'attributes': attributesOnThe28th(),
          }),
        );

        expect(sent!.containsKey('repetitions'), isFalse);
        expect(sent!['title'], 'Fello renamed');
      });

      test('is sent when the day actually changed', () async {
        Map<String, dynamic>? sent;
        final client = MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonHttpResponse({
            'data': {'id': '111', 'attributes': attributesOnThe28th()},
          });
        });
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );

        await service.updateRecurrence(
          '111',
          inputOnThe('20'),
          current: Recurrence.fromJson({
            'id': '111',
            'attributes': attributesOnThe28th(),
          }),
        );

        expect(sent!['repetitions'], hasLength(1));
        expect((sent!['repetitions'] as List).first['moment'], '20');
      });

      test('says what to do when Firefly refuses the day', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'The given data was invalid.',
              'errors': {
                'repetitions.0.moment': [
                  'The repetitions.0.moment may not be greater than 10.',
                ],
              },
            }),
            422,
            headers: {'content-type': 'application/json'},
          ),
        );
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );

        await expectLater(
          service.updateRecurrence('111', inputOnThe('28')),
          throwsA(
            isA<FireflyApiException>()
                .having(
                  (e) => e.message,
                  'message',
                  allOf(
                    contains('cannot be changed through the API'),
                    contains('Nothing was saved'),
                    contains('may not be greater than 10'),
                  ),
                )
                .having((e) => e.statusCode, 'statusCode', 422)
                .having(
                  (e) => e.fieldErrors['repetitions.0.moment'],
                  'fieldErrors',
                  contains('may not be greater than 10'),
                ),
          ),
        );
      });

      test('a refusal is not reported as a network error', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'The given data was invalid.',
              'errors': {
                'transactions.0.source_id': ['Bad source.'],
              },
            }),
            422,
            headers: {'content-type': 'application/json'},
          ),
        );
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );

        await expectLater(
          service.updateRecurrence('111', inputOnThe('8')),
          throwsA(
            isA<FireflyApiException>().having(
              (e) => e.toString(),
              'toString',
              allOf(
                isNot(contains('Network error')),
                contains('Firefly III refused the request'),
                contains('Bad source.'),
              ),
            ),
          ),
        );
      });
    });

    test('update endpoints throw on bad status', () async {
      final client = MockClient((_) async => http.Response('fail', 500));
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.updateBill(
          '9',
          BillInput(
            name: 'Rent',
            amountMin: 1,
            amountMax: 1,
            currencyCode: 'EUR',
            date: DateTime(2021, 3, 1),
            repeatFrequency: BillRepeatFrequency.monthly,
          ),
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        service.updateRecurrence(
          '12',
          RecurrenceInput(
            type: RecurrenceTransactionType.withdrawal,
            title: 'Salary',
            firstDate: DateTime(2026, 8, 8),
            repetitions: const [
              RecurrenceRepetitionInput(
                type: RecurrenceRepetitionType.monthly,
                moment: '8',
              ),
            ],
            transactions: const [
              RecurrenceTransactionInput(
                id: '55',
                description: 'Salary payment',
                amount: 3500,
                currencyCode: 'EUR',
                sourceId: '1',
                destinationId: '2',
              ),
            ],
          ),
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        service.updatePiggyBank(
          '4',
          PiggyBankInput(
            name: 'Laptop 2',
            targetAmount: 3000,
            currencyCode: 'EUR',
            accountIds: const ['1'],
            startDate: DateTime(2023, 1, 1),
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('create/delete bill error branches are covered', () async {
      final failingClient = MockClient((request) async {
        if (request.method == 'POST') return http.Response('fail', 500);
        return http.Response('fail', 500);
      });
      final throwingClient = MockClient((_) async => throw Exception('socket'));

      final failingService = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: failingClient,
      );
      final throwingService = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: throwingClient,
      );

      await expectLater(
        failingService.createBill(
          BillInput(
            name: 'Rent',
            amountMin: 1,
            amountMax: 1,
            currencyCode: 'EUR',
            date: DateTime(2021, 3, 1),
            repeatFrequency: BillRepeatFrequency.monthly,
          ),
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        throwingService.createBill(
          BillInput(
            name: 'Rent',
            amountMin: 1,
            amountMax: 1,
            currencyCode: 'EUR',
            date: DateTime(2021, 3, 1),
            repeatFrequency: BillRepeatFrequency.monthly,
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        failingService.deleteBill('9'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        throwingService.deleteBill('9'),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
    });

    test('create/delete recurrence error branches are covered', () async {
      final failingClient = MockClient((_) async => http.Response('fail', 500));
      final throwingClient = MockClient((_) async => throw Exception('socket'));
      final input = RecurrenceInput(
        type: RecurrenceTransactionType.withdrawal,
        title: 'Salary',
        firstDate: DateTime(2026, 8, 8),
        repetitions: const [
          RecurrenceRepetitionInput(
            type: RecurrenceRepetitionType.monthly,
            moment: '8',
          ),
        ],
        transactions: const [
          RecurrenceTransactionInput(
            description: 'Salary payment',
            amount: 3500,
            currencyCode: 'EUR',
            sourceId: '1',
            destinationId: '2',
          ),
        ],
      );
      final failingService = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: failingClient,
      );
      final throwingService = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: throwingClient,
      );

      await expectLater(
        failingService.createRecurrence(input),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        throwingService.createRecurrence(input),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        failingService.deleteRecurrence('12'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        throwingService.deleteRecurrence('12'),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
    });

    test('liability and piggy bank error branches are covered', () async {
      final failingClient = MockClient((request) async {
        if (request.method == 'DELETE') return http.Response('fail', 500);
        return http.Response('fail', 500);
      });
      final throwingClient = MockClient((_) async => throw Exception('socket'));
      final failingService = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: failingClient,
      );
      final throwingService = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: throwingClient,
      );

      await expectLater(
        failingService.createLiability(
          const LiabilityInput(
            name: 'Car Loan',
            currencyCode: 'EUR',
            liabilityType: LiabilityType.loan,
            liabilityDirection: LiabilityDirection.credit,
            amountOwed: 2500,
          ),
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        throwingService.createLiability(
          const LiabilityInput(
            name: 'Car Loan',
            currencyCode: 'EUR',
            liabilityType: LiabilityType.loan,
            liabilityDirection: LiabilityDirection.credit,
            amountOwed: 2500,
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );

      await expectLater(
        failingService.createPiggyBank(
          PiggyBankInput(
            name: 'New Laptop',
            targetAmount: 2500,
            currencyCode: 'EUR',
            accountIds: const ['1'],
            startDate: DateTime(2023, 1, 1),
          ),
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        throwingService.createPiggyBank(
          PiggyBankInput(
            name: 'New Laptop',
            targetAmount: 2500,
            currencyCode: 'EUR',
            accountIds: const ['1'],
            startDate: DateTime(2023, 1, 1),
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
      await expectLater(
        failingService.deletePiggyBank('4'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        throwingService.deletePiggyBank('4'),
        throwsA(predicate((e) => e.toString().contains('Network error'))),
      );
    });

    test('create/update/delete category and tag cover CRUD paths', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/categories') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['notes'], 'n');
          return jsonHttpResponse({
            'data': {
              'id': 'c1',
              'attributes': {'name': body['name']},
            },
          }, status: 201);
        }
        if (request.method == 'PUT' &&
            request.url.path == '/api/v1/categories/c1') {
          return jsonHttpResponse({
            'data': {
              'id': 'c1',
              'attributes': {'name': 'Food'},
            },
          });
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/api/v1/categories/c1') {
          return http.Response('', 204);
        }
        if (request.method == 'POST' && request.url.path == '/api/v1/tags') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['description'], 'd');
          return jsonHttpResponse({
            'data': {
              'id': 't1',
              'attributes': {'tag': body['tag']},
            },
          }, status: 201);
        }
        if (request.method == 'PUT' && request.url.path == '/api/v1/tags/t1') {
          return jsonHttpResponse({
            'data': {
              'id': 't1',
              'attributes': {'tag': 'work'},
            },
          });
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/api/v1/tags/t1') {
          return http.Response('', 200);
        }
        return http.Response(
          'unexpected ${request.method} ${request.url}',
          500,
        );
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      final created = await service.createCategory('Food', notes: 'n');
      expect(created.id, 'c1');
      expect((await service.updateCategory('c1', 'Food', notes: 'x')).id, 'c1');
      await service.deleteCategory('c1');

      final tag = await service.createTag('work', description: 'd');
      expect(tag.id, 't1');
      expect(
        (await service.updateTag('t1', 'work', description: 'e')).name,
        'work',
      );
      await service.deleteTag('t1');
    });

    test(
      'category and tag mutations throw on bad status and network',
      () async {
        final failing = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: MockClient((_) async => http.Response('fail', 500)),
        );
        final throwing = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: MockClient((_) async => throw Exception('Network error')),
        );

        await expectLater(
          failing.createCategory('x'),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          throwing.createCategory('x'),
          throwsA(isA<FireflyApiException>()),
        );
        await expectLater(
          failing.updateCategory('1', 'x'),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          throwing.updateCategory('1', 'x'),
          throwsA(isA<FireflyApiException>()),
        );
        await expectLater(
          failing.deleteCategory('1'),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          throwing.deleteCategory('1'),
          throwsA(isA<FireflyApiException>()),
        );
        await expectLater(failing.createTag('x'), throwsA(isA<Exception>()));
        await expectLater(
          throwing.createTag('x'),
          throwsA(isA<FireflyApiException>()),
        );
        await expectLater(
          failing.updateTag('1', 'x'),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          throwing.updateTag('1', 'x'),
          throwsA(isA<FireflyApiException>()),
        );
        await expectLater(failing.deleteTag('1'), throwsA(isA<Exception>()));
        await expectLater(
          throwing.deleteTag('1'),
          throwsA(isA<FireflyApiException>()),
        );
      },
    );

    test('getPreference and setPreference cover read/write paths', () async {
      var postCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/preferences/missing') {
          return http.Response('', 404);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/preferences/locale') {
          return jsonHttpResponse({
            'data': {
              'attributes': {'data': 'en_US'},
            },
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/preferences/bad') {
          return http.Response('fail', 500);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/preferences') {
          postCalls++;
          if (postCalls == 1) return http.Response('', 204);
          return http.Response('fail', 400);
        }
        if (request.method == 'PUT' &&
            request.url.path == '/api/v1/preferences/retry') {
          return http.Response('', 200);
        }
        if (request.method == 'PUT' &&
            request.url.path == '/api/v1/preferences/fail') {
          return http.Response('fail', 500);
        }
        return http.Response('unexpected', 500);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      expect(await service.getPreference('missing'), isNull);
      expect(await service.getPreference('locale'), 'en_US');
      await expectLater(
        service.getPreference('bad'),
        throwsA(isA<Exception>()),
      );

      await service.setPreference('ok', 'v');
      await service.setPreference('retry', 'v');
      await expectLater(
        service.setPreference('fail', 'v'),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'getPreference reads a 401 as unset when the token still reads',
      () async {
        final paths = <String>[];
        final client = MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/api/v1/about') {
            return jsonHttpResponse({
              'data': {'version': '6.6.6'},
            });
          }
          return http.Response(
            '{"message":"Unauthenticated.",'
            '"exception":"AuthenticationException"}',
            401,
          );
        });
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );

        expect(
          await service.getPreference('fireraccoon_people_config'),
          isNull,
        );
        expect(paths, [
          '/api/v1/preferences/fireraccoon_people_config',
          '/api/v1/about',
        ]);
      },
    );

    test(
      'getPreference refuses a 401 when the token no longer reads',
      () async {
        final client = MockClient((request) async {
          return http.Response('{"message":"Unauthenticated."}', 401);
        });
        final service = FireflyApiService(
          serverUrl: baseUrl,
          apiToken: token,
          client: client,
        );

        await expectLater(
          service.getPreference('fireraccoon_people_config'),
          throwsA(
            isA<FireflyApiException>().having(
              (e) => e.statusCode,
              'status',
              401,
            ),
          ),
        );
      },
    );

    test('getPreference refuses a 401 it cannot confirm either way', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/about') {
          throw Exception('connection closed');
        }
        return http.Response('{"message":"Unauthenticated."}', 401);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await expectLater(
        service.getPreference('fireraccoon_people_config'),
        throwsA(isA<FireflyApiException>()),
      );
    });

    test('setPreference sends JSON content type on POST and PUT', () async {
      final contentTypes = <String, String?>{};
      final client = MockClient((request) async {
        contentTypes['${request.method} ${request.url.path}'] =
            request.headers['Content-Type'];
        if (request.method == 'POST') return http.Response('fail', 415);
        return http.Response('', 200);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      await service.setPreference('fireraccoon_people_config', {'a': 1});

      expect(contentTypes['POST /api/v1/preferences'], 'application/json');
      expect(
        contentTypes['PUT /api/v1/preferences/fireraccoon_people_config'],
        'application/json',
      );
    });

    test('getTransactions includes type query when provided', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/transactions');
        expect(request.url.queryParameters['type'], 'withdrawal');
        expect(request.url.queryParameters.containsKey('start'), isTrue);
        return jsonHttpResponse({
          'data': <Object?>[],
          'meta': {
            'pagination': {'total_pages': 1, 'current_page': 1},
          },
        });
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );
      final transactions = await service.getTransactions(
        start: DateTime(2026, 1, 1),
        type: 'withdrawal',
      );
      expect(transactions, isEmpty);
    });

    test('updateAccount sends optional liability banking fields', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['iban'], 'IBAN');
        expect(body['bic'], 'BIC');
        expect(body['account_number'], '123');
        expect(body['notes'], 'n');
        expect(body['active'], isFalse);
        expect(body['account_role'], 'ccAsset');
        expect(body['currency_code'], 'EUR');
        expect(body['liability_type'], 'creditCard');
        expect(body['liability_direction'], 'debit');
        expect(body['include_net_worth'], isTrue);
        expect(body['opening_balance'], '10.00');
        expect(body['opening_balance_date'], '2026-01-02');
        expect(body['virtual_balance'], '1.00');
        expect(body['interest'], '2.5');
        expect(body['interest_period'], 'monthly');
        return http.Response('', 200);
      });
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );
      await service.updateAccount(
        '1',
        name: 'Card',
        type: 'liability',
        iban: 'IBAN',
        bic: 'BIC',
        accountNumber: '123',
        notes: 'n',
        active: false,
        role: 'ccAsset',
        currencyCode: 'EUR',
        liabilityType: 'creditCard',
        liabilityDirection: 'debit',
        includeNetWorth: true,
        openingBalance: 10,
        openingBalanceDate: DateTime(2026, 1, 2),
        virtualBalance: 1,
        interest: 2.5,
        interestPeriod: 'monthly',
      );
    });
    test('a rejected write reports which field Firefly refused', () async {
      final client = MockClient(
        (request) async => jsonHttpResponse({
          'message': 'The given data was invalid.',
          'errors': {
            'transactions.0.destination_id': [
              'The destination account is not an expense account.',
            ],
          },
        }, status: 422),
      );
      final service = FireflyApiService(
        serverUrl: baseUrl,
        apiToken: token,
        client: client,
      );

      // A bare "422" leaves the caller guessing at exactly the moment they need
      // to act, and an agent driving this API cannot correct itself from it.
      await expectLater(
        service.createRecurrence(
          RecurrenceInput(
            type: RecurrenceTransactionType.withdrawal,
            title: 'Rent',
            firstDate: DateTime(2026, 9),
            repetitions: const [
              RecurrenceRepetitionInput(
                type: RecurrenceRepetitionType.monthly,
                moment: '1',
              ),
            ],
            transactions: const [
              RecurrenceTransactionInput(
                description: 'Rent',
                amount: 1200,
                currencyCode: 'EUR',
                sourceId: '5',
                destinationId: '9',
              ),
            ],
          ),
        ),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('422') &&
                e.toString().contains('destination_id') &&
                e.toString().contains('not an expense account'),
          ),
        ),
      );
    });
  });
}
