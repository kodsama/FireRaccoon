import 'dart:convert';
import 'dart:io';

import 'package:fireracoon_app_backend/fireracoon_app_backend.dart';
import 'package:fireracoon_app_backend/src/http/attempt_limiter.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers/test_store.dart';

void main() {
  group('AttemptLimiter', () {
    final start = DateTime.utc(2026, 8, 24, 12);

    test('allows attempts up to the limit, then refuses', () {
      final limiter = AttemptLimiter(
        maxAttempts: 3,
        lockout: const Duration(minutes: 15),
        window: const Duration(minutes: 15),
      );

      expect(limiter.retryAfter('a', now: start), isNull);
      limiter.recordFailure('a', now: start);
      limiter.recordFailure('a', now: start);
      expect(limiter.retryAfter('a', now: start), isNull);

      limiter.recordFailure('a', now: start);
      expect(limiter.retryAfter('a', now: start), isNotNull);
    });

    test('a lockout expires', () {
      final limiter = AttemptLimiter(
        maxAttempts: 1,
        lockout: const Duration(minutes: 15),
        window: const Duration(minutes: 15),
      );
      limiter.recordFailure('a', now: start);

      expect(limiter.retryAfter('a', now: start), isNotNull);
      expect(
        limiter.retryAfter('a', now: start.add(const Duration(minutes: 16))),
        isNull,
      );
    });

    test('failures older than the window stop counting', () {
      // An occasional typo months apart must never add up to a lockout.
      final limiter = AttemptLimiter(
        maxAttempts: 2,
        lockout: const Duration(minutes: 15),
        window: const Duration(minutes: 5),
      );
      limiter.recordFailure('a', now: start);
      limiter.recordFailure('a', now: start.add(const Duration(hours: 1)));

      expect(
        limiter.retryAfter('a', now: start.add(const Duration(hours: 1))),
        isNull,
      );
    });

    test('one identity being locked out leaves another alone', () {
      final limiter = AttemptLimiter(
        maxAttempts: 1,
        lockout: const Duration(minutes: 15),
        window: const Duration(minutes: 15),
      );
      limiter.recordFailure('a', now: start);

      expect(limiter.retryAfter('a', now: start), isNotNull);
      expect(limiter.retryAfter('b', now: start), isNull);
    });

    test('a success clears the failures behind it', () {
      final limiter = AttemptLimiter(
        maxAttempts: 2,
        lockout: const Duration(minutes: 15),
        window: const Duration(minutes: 15),
      );
      limiter.recordFailure('a', now: start);
      limiter.recordSuccess('a');
      limiter.recordFailure('a', now: start);

      expect(limiter.retryAfter('a', now: start), isNull);
    });
  });

  group('login attempts over HTTP', () {
    late Directory tmp;
    const password = 'Store-Password1!';

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('fireracoon-attempts');
    });

    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    Future<AppServer> ready() async {
      final app = await openTestServer(
        ServerConfig(
          mode: FireracoonMode.server,
          dataDir: tmp.path,
          dataPassword: password,
          port: 0,
          webRoot: tmp.path,
        ),
      );
      await app.repository.setup(
        adminName: 'Alex',
        adminPassword: 'Password1!',
        fireflyUrl: 'https://firefly.example',
        fireflyToken: 'ff-token-secret',
      );
      return app;
    }

    Future<Response> attemptLogin(AppServer app, String password) async {
      return await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/login'),
          body: jsonEncode({'name': 'Alex', 'password': password}),
          headers: {'content-type': 'application/json'},
        ),
      );
    }

    test('a wrong password stops being answered after five tries', () async {
      // Guessing over HTTP is only expensive if something makes it expensive,
      // and the derivation caps the rate rather than the total.
      final app = await ready();

      for (var attempt = 1; attempt <= 5; attempt++) {
        final response = await attemptLogin(app, 'Wrong-Password$attempt!');
        expect(response.statusCode, 401, reason: 'attempt $attempt');
      }

      final refused = await attemptLogin(app, 'Wrong-PasswordAgain1!');
      expect(refused.statusCode, 429);
      expect(refused.headers['retry-after'], isNotNull);

      // And the right password is refused too while the lockout stands, or the
      // limit would be worth nothing.
      final correct = await attemptLogin(app, 'Password1!');
      expect(correct.statusCode, 429);
    });

    test('the right password still works below the limit', () async {
      final app = await ready();

      expect((await attemptLogin(app, 'Wrong1!aaaa')).statusCode, 401);
      final ok = await attemptLogin(app, 'Password1!');
      expect(ok.statusCode, 200);
    });

    test('a success clears the attempts behind it', () async {
      final app = await ready();

      for (var attempt = 1; attempt <= 4; attempt++) {
        expect((await attemptLogin(app, 'Wrong$attempt!aaa')).statusCode, 401);
      }
      expect((await attemptLogin(app, 'Password1!')).statusCode, 200);

      // Four failures then a success must not leave the account one typo from
      // being locked.
      expect((await attemptLogin(app, 'Wrong9!aaaa')).statusCode, 401);
      expect((await attemptLogin(app, 'Password1!')).statusCode, 200);
    });
  });
}
