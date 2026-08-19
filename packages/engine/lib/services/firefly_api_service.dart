import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../logging/app_logger.dart';
import '../models/account.dart';
import '../models/bill.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/currency.dart';
import '../models/firefly_user.dart';
import '../models/liability.dart';
import '../models/piggy_bank.dart';
import '../models/recurrence.dart';
import '../models/tag.dart';
import '../models/transaction.dart';
import '../models/transaction_page.dart';
import '../utils/chart_balance_parser.dart';
import 'firefly_api_exception.dart';
import 'firefly_service.dart';

class FireflyApiService implements FireflyService {
  final String serverUrl;
  final String apiToken;
  final http.Client _client;
  final _log = AppLogger.scoped('api.firefly');
  final int _readMaxAttempts;
  final int _readRetryBaseDelayMs;
  final int _readRetryJitterMs;
  final Duration _requestTimeout;
  final Random _random;
  int _requestCounter = 0;

  FireflyApiService({
    required this.serverUrl,
    required this.apiToken,
    http.Client? client,
    int readMaxAttempts = 3,
    int readRetryBaseDelayMs = 200,
    int readRetryJitterMs = 0,
    Duration requestTimeout = const Duration(seconds: 45),
    Random? random,
  }) : _client = client ?? http.Client(),
       _requestTimeout = requestTimeout <= Duration.zero
           ? const Duration(seconds: 45)
           : requestTimeout,
       _readMaxAttempts = readMaxAttempts < 1 ? 1 : readMaxAttempts,
       _readRetryBaseDelayMs = readRetryBaseDelayMs < 0
           ? 0
           : readRetryBaseDelayMs,
       _readRetryJitterMs = readRetryJitterMs < 0 ? 0 : readRetryJitterMs,
       _random = random ?? Random() {
    _log.info(
      'FireflyApiService retry policy: '
      'readMaxAttempts=$_readMaxAttempts, '
      'readRetryBaseDelayMs=$_readRetryBaseDelayMs, '
      'readRetryJitterMs=$_readRetryJitterMs, '
      'requestTimeout=${_requestTimeout.inSeconds}s',
    );
  }

  int _computeRetryDelayMs(int attempt) {
    final baseDelay = _readRetryBaseDelayMs * attempt;
    if (_readRetryJitterMs == 0) {
      return baseDelay;
    }
    final jitter = _random.nextInt(_readRetryJitterMs + 1);
    return baseDelay + jitter;
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $apiToken',
    'Accept': 'application/vnd.api+json',
    // Browsers may otherwise reuse a cached Firefly GET after an external edit.
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  String get _baseUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;

  static const _pageSize = 500;
  static const _maxPreviewChars = 800;
  static const _defaultLookback = Duration(days: 365);
  // Browsers allow 6 connections per origin; capping the background sync at
  // 3 leaves headroom for interactive fetches (visible page, accounts).
  static const _maxConcurrentPageFetches = 3;

  static String _formatApiDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Query fragment for an inclusive-start, exclusive-end date window,
  /// matching the app-wide [DateRangeBounds] convention.
  String _rangeQuery({DateTime? start, DateTime? end}) {
    final parts = <String>[];
    if (start != null) {
      final startDay = DateTime(start.year, start.month, start.day);
      parts.add('start=${_formatApiDate(startDay)}');
    }
    if (end != null) {
      final inclusiveEnd = end.subtract(const Duration(days: 1));
      parts.add('end=${_formatApiDate(inclusiveEnd)}');
    }
    return parts.join('&');
  }

  String _transactionsPath({DateTime? start, DateTime? end, String? type}) {
    var query = _rangeQuery(start: start, end: end);
    if (type != null && type.isNotEmpty) {
      query = query.isEmpty
          ? 'type=${Uri.encodeQueryComponent(type)}'
          : '$query&type=${Uri.encodeQueryComponent(type)}';
    }
    return query.isEmpty
        ? '/api/v1/transactions'
        : '/api/v1/transactions?$query';
  }

  Future<T> _runLogged<T>(
    String operation,
    Future<T> Function() action, {
    Object? context,
  }) async {
    final startedAt = DateTime.now();
    final contextPart = context == null ? '' : ' context=${_preview(context)}';
    _log.fine('Operation start: $operation$contextPart');
    try {
      final result = await action();
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      _log.fine('Operation success: $operation (${elapsedMs}ms)');
      return result;
    } on FireflyApiException {
      rethrow;
    } on Object catch (error, stackTrace) {
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      _log.severe(
        'Operation failed: $operation (${elapsedMs}ms)$contextPart',
        error,
        stackTrace,
      );
      throw FireflyApiException('$error', operation: operation, cause: error);
    }
  }

  /// Status code plus whatever Firefly said about it.
  ///
  /// A bare `422` tells the caller a write was refused but not which field, so
  /// nobody driving this API can correct themselves without guessing. The body
  /// carries the message and the per-field errors, redacted and truncated like
  /// any other preview.
  String _status(http.Response response) {
    final detail = _validationDetail(response.body);
    return detail == null
        ? '${response.statusCode}'
        : '${response.statusCode} ${_preview(detail)}';
  }

  String? _validationDetail(String body) {
    if (body.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final message = decoded['message'] as String?;
    final errors = decoded['errors'];
    final fields = <String>[
      if (errors is Map)
        for (final entry in errors.entries)
          '${entry.key}: '
              '${entry.value is List && (entry.value as List).isNotEmpty ? (entry.value as List).first : entry.value}',
    ];
    if (fields.isEmpty) return message;
    return message == null
        ? fields.join('; ')
        : '$message (${fields.join('; ')})';
  }

  String _preview(Object? value) {
    if (value == null) return 'null';
    final text = value is String ? value : AppLogger.compactJson(value);
    final redacted = AppLogger.redact(text);
    if (redacted.length <= _maxPreviewChars) {
      return redacted;
    }
    return '${redacted.substring(0, _maxPreviewChars)}...(truncated)';
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    int maxAttempts = 1,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final requestId = ++_requestCounter;
    final query = uri.query.isEmpty ? '' : '?${uri.query}';
    final contentType = (headers ?? _headers)['Content-Type'] ?? 'none';
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    Object? lastError;
    StackTrace? lastStackTrace;

    final requestHeaders = headers ?? _headers;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      final startedAt = DateTime.now();
      _log.finer(
        '[#$requestId] -> $method ${uri.path}$query '
        '(attempt=$attempt/$attempts, contentType=$contentType, body=${_preview(body)})',
      );
      try {
        // _send is private and only ever called with these four methods.
        // A stalled connection must fail fast enough to trigger the retry
        // path (or surface an error) instead of hanging callers forever.
        final Future<http.Response> pending = switch (method) {
          'GET' => _client.get(uri, headers: requestHeaders),
          'POST' => _client.post(uri, headers: requestHeaders, body: body),
          'PUT' => _client.put(uri, headers: requestHeaders, body: body),
          _ => _client.delete(uri, headers: requestHeaders),
        };
        final response = await pending.timeout(_requestTimeout);
        final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
        final message =
            '[#$requestId] <- $method ${uri.path}$query '
            '${response.statusCode} (${elapsedMs}ms, attempt=$attempt/$attempts)';
        final responsePreview = _preview(response.body);
        if (response.statusCode >= 500 || response.statusCode == 429) {
          if (response.statusCode >= 500) {
            _log.severe('$message body=$responsePreview');
          } else {
            _log.warning('$message body=$responsePreview');
          }
          if (attempt < attempts) {
            var delayMs = _computeRetryDelayMs(attempt);
            if (response.statusCode == 429) {
              final retryAfter = int.tryParse(
                response.headers['retry-after'] ?? '',
              );
              if (retryAfter != null && retryAfter >= 0) {
                // Cap so a hostile/buggy Retry-After cannot hang callers.
                delayMs = min(retryAfter * 1000, 30000);
              }
            }
            _log.warning(
              '[#$requestId] retrying $method ${uri.path}$query after HTTP ${response.statusCode} '
              '(nextAttempt=${attempt + 1}/$attempts, backoff=${delayMs}ms)',
            );
            await Future<void>.delayed(Duration(milliseconds: delayMs));
            continue;
          }
        } else if (response.statusCode >= 400) {
          _log.warning('$message body=$responsePreview');
        } else {
          _log.fine(message);
          _log.finer('[#$requestId] response body=$responsePreview');
        }
        return response;
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        _log.severe(
          '[#$requestId] !! $method ${uri.path}$query failed (attempt=$attempt/$attempts)',
          error,
          stackTrace,
        );
        if (attempt < attempts) {
          final delayMs = _computeRetryDelayMs(attempt);
          _log.warning(
            '[#$requestId] retrying $method ${uri.path}$query after exception '
            '(nextAttempt=${attempt + 1}/$attempts, backoff=${delayMs}ms)',
          );
          await Future<void>.delayed(Duration(milliseconds: delayMs));
          continue;
        }
      }
    }

    // The loop only falls through when the final attempt threw.
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<TransactionPageResult> _fetchTransactionPage(
    String path, {
    required int page,
    required int limit,
  }) async {
    final separator = path.contains('?') ? '&' : '?';
    final response = await _send(
      'GET',
      '$path${separator}limit=$limit&page=$page',
      maxAttempts: _readMaxAttempts,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load transactions: ${_status(response)}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>;
    // Map rows in chunks with event-loop yields so a 500-row page does not
    // block the UI thread as one atomic task (isolates are unavailable on
    // web, where this client primarily runs).
    const chunkSize = 100;
    final transactions = <Transaction>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final chunkEnd = i + chunkSize < list.length
          ? i + chunkSize
          : list.length;
      for (var j = i; j < chunkEnd; j++) {
        transactions.add(Transaction.fromJson(list[j] as Map<String, dynamic>));
      }
      if (chunkEnd < list.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    final pagination = data['meta']?['pagination'] as Map<String, dynamic>?;
    return TransactionPageResult(
      transactions: transactions,
      currentPage: pagination?['current_page'] as int? ?? page,
      totalPages: pagination?['total_pages'] as int? ?? 1,
      total: pagination?['total'] as int? ?? transactions.length,
    );
  }

  Future<List<Transaction>> _fetchAllTransactionPages(
    String path, {
    void Function(List<Transaction> firstPage)? onFirstPage,
  }) async {
    final first = await _fetchTransactionPage(path, page: 1, limit: _pageSize);
    if (first.totalPages <= 1) return first.transactions;
    onFirstPage?.call(first.transactions);

    // Fetch remaining pages concurrently (bounded), preserving page order.
    final pages = List<List<Transaction>>.filled(first.totalPages, const []);
    pages[0] = first.transactions;
    var nextPage = 2;
    Future<void> worker() async {
      while (true) {
        final page = nextPage;
        if (page > first.totalPages) return;
        nextPage++;
        final result = await _fetchTransactionPage(
          path,
          page: page,
          limit: _pageSize,
        );
        pages[page - 1] = result.transactions;
        // Concurrent workers can deliver several 500-row parses back to
        // back; yield so the UI thread can paint between them.
        await Future<void>.delayed(Duration.zero);
      }
    }

    final workerCount = _maxConcurrentPageFetches < first.totalPages - 1
        ? _maxConcurrentPageFetches
        : first.totalPages - 1;
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
    return [for (final page in pages) ...page];
  }

  @override
  Future<FireflyCurrency> getPrimaryCurrency() async {
    return _runLogged('getPrimaryCurrency', () async {
      final response = await _send(
        'GET',
        '/api/v1/currencies/primary',
        maxAttempts: _readMaxAttempts,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FireflyCurrency.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw Exception(
        'Failed to load primary currency: ${response.statusCode}',
      );
    });
  }

  @override
  Future<void> setPrimaryCurrency(String code) async {
    return _runLogged('setPrimaryCurrency', () async {
      // Firefly answers 415 without a content type, even though this POST
      // carries no body.
      final response = await _send(
        'POST',
        '/api/v1/currencies/$code/primary',
        headers: {..._headers, 'Content-Type': 'application/json'},
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception(
          'Failed to set primary currency: ${response.statusCode}',
        );
      }
    });
  }

  @override
  Future<FireflyUser> getCurrentUser() async {
    return _runLogged('getCurrentUser', () async {
      final response = await _send(
        'GET',
        '/api/v1/about/user',
        maxAttempts: _readMaxAttempts,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FireflyUser.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw Exception('Failed to load user: ${_status(response)}');
    });
  }

  Future<List<Account>> _fetchAccountsOfType(String type) async {
    final accounts = <Account>[];
    var page = 1;
    while (true) {
      final response = await _send(
        'GET',
        '/api/v1/accounts?type=$type&limit=$_pageSize&page=$page',
        maxAttempts: _readMaxAttempts,
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load $type accounts: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);
      final list = data['data'] as List<dynamic>;
      accounts.addAll(
        list.map((e) => Account.fromJson(e as Map<String, dynamic>)),
      );
      final pagination = data['meta']?['pagination'] as Map<String, dynamic>?;
      final totalPages = pagination?['total_pages'] as int? ?? 1;
      if (page >= totalPages) break;
      page++;
    }
    return accounts;
  }

  @override
  Future<List<Account>> getAccounts({
    List<String> types = const ['asset', 'liability'],
  }) async {
    return _runLogged('getAccounts', () async {
      final results = await Future.wait([
        for (final type in types) _fetchAccountsOfType(type),
      ]);
      return [for (final list in results) ...list];
    }, context: {'types': types});
  }

  @override
  Future<TransactionPageResult> getTransactionsPage({
    required int page,
    required int limit,
    DateTime? start,
    DateTime? end,
  }) async {
    return _runLogged(
      'getTransactionsPage',
      () async {
        return await _fetchTransactionPage(
          _transactionsPath(start: start, end: end),
          page: page,
          limit: limit,
        );
      },
      context: {'page': page, 'limit': limit, 'start': start, 'end': end},
    );
  }

  @override
  Future<Account> getAccount(String accountId, {DateTime? date}) async {
    return _runLogged('getAccount', () async {
      final query = date == null
          ? ''
          : '?date=${_formatApiDate(DateTime(date.year, date.month, date.day))}';
      final response = await _send(
        'GET',
        '/api/v1/accounts/$accountId$query',
        maxAttempts: _readMaxAttempts,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch account: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Account.fromJson(data['data'] as Map<String, dynamic>);
    }, context: {'accountId': accountId, 'date': date});
  }

  @override
  Future<double> getAccountBalanceAtDate(
    String accountId,
    DateTime date,
  ) async {
    final account = await getAccount(accountId, date: date);
    return account.currentBalance;
  }

  @override
  Future<Map<String, List<double>>> getAccountBalanceHistories({
    required List<Account> accounts,
    required DateTime start,
    required DateTime end,
    String period = '1M',
  }) async {
    return _runLogged(
      'getAccountBalanceHistories',
      () async {
        final relevant = accounts
            .where(
              (account) =>
                  account.type == 'asset' || account.type == 'liability',
            )
            .toList();
        if (relevant.isEmpty) return const {};

        final query = StringBuffer(
          'start=${_formatApiDate(start)}&end=${_formatApiDate(end)}&period=$period',
        );
        for (final account in relevant) {
          query.write('&accounts[]=${account.id}');
        }

        final response = await _send(
          'GET',
          '/api/v1/chart/balance/balance?$query',
          maxAttempts: _readMaxAttempts,
        );
        if (response.statusCode != 200) {
          throw Exception(
            'Failed to fetch balance chart: ${response.statusCode}',
          );
        }
        final body = jsonDecode(response.body);
        return parseChartBalanceHistories(body);
      },
      context: {
        'accountCount': accounts.length,
        'start': start,
        'end': end,
        'period': period,
      },
    );
  }

  @override
  Future<List<Transaction>> getTransactions({
    DateTime? start,
    DateTime? end,
    String? type,
    void Function(List<Transaction> firstPage)? onFirstPage,
  }) async {
    final effectiveStart = start ?? DateTime.now().subtract(_defaultLookback);
    return _runLogged(
      'getTransactions',
      () => _fetchAllTransactionPages(
        _transactionsPath(start: effectiveStart, end: end, type: type),
        onFirstPage: onFirstPage,
      ),
      context: {'start': effectiveStart, 'end': end, 'type': type},
    );
  }

  @override
  Future<TransactionPageResult> searchTransactionsPage(
    String query, {
    required int page,
    required int limit,
  }) async {
    return _runLogged(
      'searchTransactionsPage',
      () => _fetchTransactionPage(
        '/api/v1/search/transactions?query=${Uri.encodeQueryComponent(query)}',
        page: page,
        limit: limit,
      ),
      context: {'query': query, 'page': page, 'limit': limit},
    );
  }

  @override
  Future<TransactionPageResult> getBillTransactionsPage(
    String billId, {
    required int page,
    required int limit,
  }) async {
    return _runLogged(
      'getBillTransactionsPage',
      () => _fetchTransactionPage(
        '/api/v1/bills/$billId/transactions',
        page: page,
        limit: limit,
      ),
      context: {'billId': billId, 'page': page, 'limit': limit},
    );
  }

  @override
  Future<TransactionPageResult> getRecurrenceTransactionsPage(
    String recurrenceId, {
    required int page,
    required int limit,
  }) async {
    return _runLogged(
      'getRecurrenceTransactionsPage',
      () => _fetchTransactionPage(
        '/api/v1/recurrences/$recurrenceId/transactions',
        page: page,
        limit: limit,
      ),
      context: {'recurrenceId': recurrenceId, 'page': page, 'limit': limit},
    );
  }

  @override
  Future<TransactionPageResult> getAccountTransactionsPage(
    String accountId, {
    required int page,
    required int limit,
  }) async {
    return _runLogged(
      'getAccountTransactionsPage',
      () => _fetchTransactionPage(
        '/api/v1/accounts/$accountId/transactions',
        page: page,
        limit: limit,
      ),
      context: {'accountId': accountId, 'page': page, 'limit': limit},
    );
  }

  @override
  Future<List<Transaction>> getAccountTransactions(
    String accountId, {
    DateTime? start,
    DateTime? end,
  }) async {
    final range = _rangeQuery(start: start, end: end);
    final path = range.isEmpty
        ? '/api/v1/accounts/$accountId/transactions'
        : '/api/v1/accounts/$accountId/transactions?$range';
    return _runLogged(
      'getAccountTransactions',
      () => _fetchAllTransactionPages(path),
      context: {'accountId': accountId, 'start': start, 'end': end},
    );
  }

  @override
  Future<List<Budget>> getBudgets({DateTime? start, DateTime? end}) async {
    final range = _rangeQuery(start: start, end: end);
    final path = range.isEmpty ? '/api/v1/budgets' : '/api/v1/budgets?$range';
    try {
      final response = await _send('GET', path, maxAttempts: _readMaxAttempts);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List<dynamic>;
        return list
            .map((e) => Budget.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load budgets: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Transaction> getTransaction(String transactionId) async {
    return _runLogged('getTransaction', () async {
      final response = await _send(
        'GET',
        '/api/v1/transactions/$transactionId',
        maxAttempts: _readMaxAttempts,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch transaction: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Transaction.fromJson(data['data'] as Map<String, dynamic>);
    }, context: {'transactionId': transactionId});
  }

  @override
  Future<List<Transaction>> getBudgetTransactions(
    String budgetId, {
    DateTime? start,
    DateTime? end,
  }) async {
    final range = _rangeQuery(start: start, end: end);
    final path = range.isEmpty
        ? '/api/v1/budgets/$budgetId/transactions'
        : '/api/v1/budgets/$budgetId/transactions?$range';
    try {
      return await _fetchAllTransactionPages(path);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> deleteBudget(String budgetId) async {
    try {
      final response = await _send('DELETE', '/api/v1/budgets/$budgetId');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete budget: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> updateAccount(
    String accountId, {
    String? name,
    String? type,
    String? iban,
    String? bic,
    String? accountNumber,
    String? notes,
    bool? active,
    String? role,
    String? currencyCode,
    String? liabilityType,
    String? liabilityDirection,
    bool? includeNetWorth,
    double? openingBalance,
    DateTime? openingBalanceDate,
    double? virtualBalance,
    double? interest,
    String? interestPeriod,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (type != null) body['type'] = type;
      if (iban != null) body['iban'] = iban;
      if (bic != null) body['bic'] = bic;
      if (accountNumber != null) body['account_number'] = accountNumber;
      if (notes != null) body['notes'] = notes;
      if (active != null) body['active'] = active;
      if (role != null) body['account_role'] = role;
      if (currencyCode != null) body['currency_code'] = currencyCode;
      if (liabilityType != null) body['liability_type'] = liabilityType;
      if (liabilityDirection != null) {
        body['liability_direction'] = liabilityDirection;
      }
      if (includeNetWorth != null) body['include_net_worth'] = includeNetWorth;
      if (openingBalance != null) {
        body['opening_balance'] = openingBalance.toStringAsFixed(2);
      }
      if (openingBalanceDate != null) {
        body['opening_balance_date'] =
            '${openingBalanceDate.year.toString().padLeft(4, '0')}-'
            '${openingBalanceDate.month.toString().padLeft(2, '0')}-'
            '${openingBalanceDate.day.toString().padLeft(2, '0')}';
      }
      if (virtualBalance != null) {
        body['virtual_balance'] = virtualBalance.toStringAsFixed(2);
      }
      if (interest != null) body['interest'] = interest.toString();
      if (interestPeriod != null) body['interest_period'] = interestPeriod;

      final response = await _send(
        'PUT',
        '/api/v1/accounts/$accountId',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update account: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    try {
      final response = await _send('DELETE', '/api/v1/accounts/$accountId');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete account: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Account> createAccount({
    required String name,
    required String type,
    required String currencyCode,
    String? role,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'type': type,
        'currency_code': currencyCode,
      };
      // Firefly refuses an asset account without a role: "The account role
      // field is required when type is asset." Default it rather than fail.
      final resolvedRole = role ?? (type == 'asset' ? 'defaultAsset' : null);
      if (resolvedRole != null) body['account_role'] = resolvedRole;
      final response = await _send(
        'POST',
        '/api/v1/accounts',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create account: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Account.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Account> createLiability(LiabilityInput input) async {
    try {
      final response = await _send(
        'POST',
        '/api/v1/accounts',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toCreateJson()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create liability: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Account.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Budget> createBudget(BudgetInput input) async {
    try {
      final response = await _send(
        'POST',
        '/api/v1/budgets',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toJson()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create budget: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Budget.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> updateBudget(String budgetId, BudgetInput input) async {
    try {
      final response = await _send(
        'PUT',
        '/api/v1/budgets/$budgetId',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toJson()),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update budget: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<List<BudgetLimit>> getBudgetLimits(
    String budgetId, {
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      final query = _dateRangeQuery(start: start, end: end);
      final path = query.isEmpty
          ? '/api/v1/budgets/$budgetId/limits'
          : '/api/v1/budgets/$budgetId/limits?$query';
      return await _fetchList(path, BudgetLimit.fromJson);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<BudgetLimit> createBudgetLimit(
    String budgetId,
    BudgetLimitInput input,
  ) async {
    try {
      final response = await _send(
        'POST',
        '/api/v1/budgets/$budgetId/limits',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toJson()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to create budget limit: ${response.statusCode}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return BudgetLimit.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> updateBudgetLimit(
    String budgetId,
    String limitId,
    BudgetLimitInput input,
  ) async {
    try {
      final response = await _send(
        'PUT',
        '/api/v1/budgets/$budgetId/limits/$limitId',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toJson()),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update budget limit: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  String _dateRangeQuery({DateTime? start, DateTime? end}) {
    final params = <String>[];
    if (start != null) {
      params.add('start=${BudgetLimitInput.formatDate(start)}');
    }
    if (end != null) {
      params.add('end=${BudgetLimitInput.formatDate(end)}');
    }
    return params.join('&');
  }

  Future<List<T>> _fetchList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final items = <T>[];
    var page = 1;
    final separator = path.contains('?') ? '&' : '?';
    while (true) {
      final response = await _send(
        'GET',
        '$path${separator}limit=$_pageSize&page=$page',
        maxAttempts: _readMaxAttempts,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load $path: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? [];
      items.addAll(list.map((e) => fromJson(e as Map<String, dynamic>)));
      final pagination = data['meta']?['pagination'] as Map<String, dynamic>?;
      final totalPages = pagination?['total_pages'] as int? ?? 1;
      if (page >= totalPages) break;
      page++;
    }
    return items;
  }

  Future<Transaction> _mutateTransaction(
    String method,
    String path,
    Transaction transaction,
  ) async {
    final isUpdate = method == 'PUT';
    final body = jsonEncode(transaction.toApiPayload(isUpdate: isUpdate));
    final response = await _send(
      method,
      path,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to $method transaction: ${_status(response)}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Transaction.fromJson(data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<Category>> getCategories() async {
    try {
      return await _fetchList('/api/v1/categories', Category.fromJson);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Category> createCategory(String name, {String? notes}) async {
    try {
      final body = <String, dynamic>{'name': name};
      if (notes != null && notes.isNotEmpty) body['notes'] = notes;
      final response = await _send(
        'POST',
        '/api/v1/categories',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create category: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Category.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Category> updateCategory(
    String categoryId,
    String name, {
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{'name': name};
      if (notes != null) body['notes'] = notes;
      final response = await _send(
        'PUT',
        '/api/v1/categories/$categoryId',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update category: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Category.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    try {
      final response = await _send('DELETE', '/api/v1/categories/$categoryId');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete category: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<List<Tag>> getTags() async {
    try {
      return await _fetchList('/api/v1/tags', Tag.fromJson);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Tag> createTag(String tag, {String? description}) async {
    try {
      final body = <String, dynamic>{'tag': tag};
      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }
      final response = await _send(
        'POST',
        '/api/v1/tags',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create tag: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Tag.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Tag> updateTag(String tagId, String tag, {String? description}) async {
    try {
      final body = <String, dynamic>{'tag': tag};
      if (description != null) body['description'] = description;
      final response = await _send(
        'PUT',
        '/api/v1/tags/$tagId',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update tag: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Tag.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> deleteTag(String tagId) async {
    try {
      final response = await _send('DELETE', '/api/v1/tags/$tagId');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete tag: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<List<Bill>> getBills() async {
    try {
      return await _fetchList('/api/v1/bills', Bill.fromJson);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<List<FireflyCurrency>> getCurrencies() async {
    try {
      return await _fetchList('/api/v1/currencies', FireflyCurrency.fromJson);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Bill> createBill(BillInput input) async {
    try {
      final response = await _send(
        'POST',
        '/api/v1/bills',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toJson()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create bill: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Bill.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Bill> updateBill(String billId, BillInput input) async {
    try {
      final response = await _send(
        'PUT',
        '/api/v1/bills/$billId',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toJson()),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update bill: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Bill.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> deleteBill(String billId) async {
    try {
      final response = await _send('DELETE', '/api/v1/bills/$billId');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete bill: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<List<Recurrence>> getRecurrences() async {
    try {
      return await _fetchList('/api/v1/recurrences', Recurrence.fromJson);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Recurrence> createRecurrence(RecurrenceInput input) async {
    try {
      final response = await _send(
        'POST',
        '/api/v1/recurrences',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toJson(isUpdate: false)),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create recurrence: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Recurrence.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Recurrence> updateRecurrence(
    String recurrenceId,
    RecurrenceInput input,
  ) async {
    try {
      final response = await _send(
        'PUT',
        '/api/v1/recurrences/$recurrenceId',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toJson(isUpdate: true)),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update recurrence: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Recurrence.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> deleteRecurrence(String recurrenceId) async {
    try {
      final response = await _send(
        'DELETE',
        '/api/v1/recurrences/$recurrenceId',
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete recurrence: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<List<PiggyBank>> getPiggyBanks() async {
    try {
      return await _fetchList('/api/v1/piggy-banks', PiggyBank.fromJson);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<PiggyBank> createPiggyBank(PiggyBankInput input) async {
    try {
      final response = await _send(
        'POST',
        '/api/v1/piggy-banks',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toCreateJson()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create piggy bank: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PiggyBank.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<PiggyBank> updatePiggyBank(
    String piggyBankId,
    PiggyBankInput input,
  ) async {
    try {
      final response = await _send(
        'PUT',
        '/api/v1/piggy-banks/$piggyBankId',
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(input.toUpdateJson()),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update piggy bank: ${_status(response)}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PiggyBank.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<void> deletePiggyBank(String piggyBankId) async {
    try {
      final response = await _send(
        'DELETE',
        '/api/v1/piggy-banks/$piggyBankId',
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete piggy bank: ${_status(response)}');
      }
    } catch (e) {
      throw FireflyApiException('$e', cause: e);
    }
  }

  @override
  Future<Transaction> createTransaction(Transaction transaction) async {
    return _runLogged(
      'createTransaction',
      () => _mutateTransaction('POST', '/api/v1/transactions', transaction),
      context: {
        'type': transaction.type,
        'amount': transaction.amount,
        'sourceId': transaction.sourceId,
        'destinationId': transaction.destinationId,
      },
    );
  }

  @override
  Future<Transaction> updateTransaction(Transaction transaction) async {
    return _runLogged(
      'updateTransaction',
      () => _mutateTransaction(
        'PUT',
        '/api/v1/transactions/${transaction.id}',
        transaction,
      ),
      context: {
        'id': transaction.id,
        'type': transaction.type,
        'amount': transaction.amount,
      },
    );
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    return _runLogged('deleteTransaction', () async {
      final response = await _send(
        'DELETE',
        '/api/v1/transactions/$transactionId',
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete transaction: ${_status(response)}');
      }
    }, context: {'transactionId': transactionId});
  }

  @override
  Future<dynamic> getPreference(String name) async {
    return _runLogged('getPreference', () async {
      final response = await _send('GET', '/api/v1/preferences/$name');
      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch preference $name: ${response.statusCode}',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        final attributes = data['attributes'];
        if (attributes is Map<String, dynamic>) {
          return attributes['data'];
        }
      }
      return null;
    }, context: {'name': name});
  }

  @override
  Future<void> setPreference(String name, dynamic data) async {
    return _runLogged('setPreference', () async {
      final body = jsonEncode({'name': name, 'data': data});
      final jsonHeaders = {..._headers, 'Content-Type': 'application/json'};
      final response = await _send(
        'POST',
        '/api/v1/preferences',
        body: body,
        headers: jsonHeaders,
      );
      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 204) {
        // Try PUT as fallback if POST returns error
        final putResponse = await _send(
          'PUT',
          '/api/v1/preferences/$name',
          body: body,
          headers: jsonHeaders,
        );
        if (putResponse.statusCode != 200 &&
            putResponse.statusCode != 201 &&
            putResponse.statusCode != 204) {
          throw Exception(
            'Failed to save preference $name: ${response.statusCode} / ${putResponse.statusCode}',
          );
        }
      }
    }, context: {'name': name});
  }
}
