import 'package:fireraccoon/providers/app_retry_policy.dart';
import 'package:fireraccoon/store/credential_store_locked_exception.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fireflyProviderRetry', () {
    test('a state nobody has fixed yet is not retried', () {
      // Riverpod's own policy would ask ten more times over forty seconds. For
      // a dozen providers that is a hundred and thirty requests and a
      // screenful of log lines that all say the same thing.
      expect(
        fireflyProviderRetry(0, const FireflyNotConnectedException()),
        isNull,
      );
      expect(
        fireflyProviderRetry(0, const CredentialStoreLockedException()),
        isNull,
      );
    });

    test('a server nothing reached is not retried either', () {
      // The connection poll is already watching for the moment it answers, and
      // it rebuilds every one of these providers when it does.
      expect(
        fireflyProviderRetry(
          0,
          FireflyApiException('no route to host', unreachable: true),
        ),
        isNull,
      );
    });

    test('a refusal Firefly meant is not retried', () {
      for (final status in [400, 401, 403, 404, 422]) {
        expect(
          fireflyProviderRetry(
            0,
            FireflyApiException('refused', statusCode: status),
          ),
          isNull,
          reason: 'HTTP $status is the same answer on the fourth ask',
        );
      }
    });

    test('a server error is a blip worth a few quick tries', () {
      expect(
        fireflyProviderRetry(0, FireflyApiException('boom', statusCode: 503)),
        const Duration(milliseconds: 200),
      );
      expect(
        fireflyProviderRetry(1, FireflyApiException('boom', statusCode: 503)),
        const Duration(milliseconds: 400),
      );
    });

    test('the few tries stop rather than running for forty seconds', () {
      final error = FireflyApiException('boom', statusCode: 500);
      expect(fireflyProviderRetry(2, error), isNotNull);
      expect(fireflyProviderRetry(3, error), isNull);
    });
  });
}
