import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fireracoon/utils/password_policy.dart';

void main() {
  group('validatePasswordPolicy', () {
    test('rejects a password missing every requirement', () async {
      final result = validatePasswordPolicy('short');
      expect(result.isValid, isFalse);
      expect(result.hasMinLength, isFalse);
      expect(result.hasUpper, isFalse);
      expect(result.hasDigit, isFalse);
      expect(result.hasSpecial, isFalse);
    });

    test('rejects a password missing only a special character', () async {
      final result = validatePasswordPolicy('LongEnough123');
      expect(result.hasMinLength, isTrue);
      expect(result.hasUpper, isTrue);
      expect(result.hasLower, isTrue);
      expect(result.hasDigit, isTrue);
      expect(result.hasSpecial, isFalse);
      expect(result.isValid, isFalse);
    });

    test('accepts a password meeting every requirement', () async {
      final result = validatePasswordPolicy('Correct-Horse9!');
      expect(result.isValid, isTrue);
      expect(result.missingRequirements, isEmpty);
    });

    test('rejects a 9-character password (below the minimum)', () async {
      final result = validatePasswordPolicy('Short9!aa');
      expect(result.hasMinLength, isFalse);
      expect(result.isValid, isFalse);
    });

    test(
      'reports missing uppercase and digit for a URL-like password',
      () async {
        final result = validatePasswordPolicy('https://racoon.kodsama.com');
        expect(result.hasMinLength, isTrue);
        expect(result.hasLower, isTrue);
        expect(result.hasSpecial, isTrue);
        expect(result.hasUpper, isFalse);
        expect(result.hasDigit, isFalse);
        expect(result.missingRequirements, [
          PasswordRequirement.upper,
          PasswordRequirement.digit,
        ]);
        expect(result.isValid, isFalse);
      },
    );
  });

  group('hashPassword / verifyPassword', () {
    test('verifies the correct password', () async {
      final hashed = await hashPassword('Correct-Horse9!');
      expect(
        await verifyPassword(
          'Correct-Horse9!',
          hash: hashed.hash,
          salt: hashed.salt,
        ),
        isTrue,
      );
    });

    test('rejects an incorrect password', () async {
      final hashed = await hashPassword('Correct-Horse9!');
      expect(
        await verifyPassword(
          'Wrong-Horse9!',
          hash: hashed.hash,
          salt: hashed.salt,
        ),
        isFalse,
      );
    });

    test('never stores the plaintext password', () async {
      final hashed = await hashPassword('Correct-Horse9!');
      expect(hashed.hash, isNot(contains('Correct-Horse9!')));
    });

    test(
      'produces different salts (and hashes) for the same password',
      () async {
        final first = await hashPassword('Correct-Horse9!');
        final second = await hashPassword('Correct-Horse9!');
        expect(first.salt, isNot(equals(second.salt)));
        expect(first.hash, isNot(equals(second.hash)));
      },
    );

    test('reproduces the same hash given the same salt', () async {
      final first = await hashPassword('Correct-Horse9!');
      final second = await hashPassword(
        'Correct-Horse9!',
        saltBase64: first.salt,
      );
      expect(second.hash, first.hash);
    });
  });

  group('isPasswordPwned', () {
    test(
      'returns true when the suffix is present in the range response',
      () async {
        // SHA-1('password') = 5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8
        // (prefix 5BAA6 sent to the API, remaining suffix compared locally).
        final client = MockClient(
          (_) async =>
              http.Response('1E4C9B93F3F0682250B6CF8331B7EE68FD8:37810', 200),
        );
        final result = await isPasswordPwned('password', client: client);
        expect(result, isTrue);
      },
    );

    test('returns false when the suffix is absent', () async {
      final client = MockClient(
        (_) async => http.Response('AAAA111:2\r\nBBBB222:9', 200),
      );
      final result = await isPasswordPwned('password', client: client);
      expect(result, isFalse);
    });

    test('fails open (returns null) on a network error', () async {
      final client = MockClient((_) async => throw Exception('offline'));
      final result = await isPasswordPwned('password', client: client);
      expect(result, isNull);
    });

    test('fails open (returns null) on a non-200 response', () async {
      final client = MockClient((_) async => http.Response('', 503));
      final result = await isPasswordPwned('password', client: client);
      expect(result, isNull);
    });

    test('creates and closes its own client when none is provided', () async {
      // Hits the owns=true path; result depends on network availability.
      final result = await isPasswordPwned('Correct-Horse-Uncommon-9!');
      expect(result, anyOf(isTrue, isFalse, isNull));
    });
  });

  group('derivation cost', () {
    test('a new hash records the count it was derived with', () async {
      final hashed = await hashPassword('Correct-Horse9!');

      final decoded = decodePasswordHash(hashed.hash);
      expect(decoded.iterations, kPbkdf2Iterations);
      expect(passwordHashIsStale(hashed.hash), isFalse);
    });

    test('a hash with no recorded count still verifies', () async {
      // Hashes written before the count was stored are a bare digest. Reading
      // them at today's count would turn every existing password into a wrong
      // one, which is why raising the count needed this first.
      final legacyDigest = base64Encode(
        legacyDeriveForTest('Correct-Horse9!', 'c2FsdHNhbHRzYWx0c2Fs'),
      );

      expect(
        await verifyPassword(
          'Correct-Horse9!',
          hash: legacyDigest,
          salt: 'c2FsdHNhbHRzYWx0c2Fs',
        ),
        isTrue,
      );
      expect(
        await verifyPassword(
          'Wrong-Horse9!',
          hash: legacyDigest,
          salt: 'c2FsdHNhbHRzYWx0c2Fs',
        ),
        isFalse,
      );
    });

    test('an old hash is reported as worth rewriting', () async {
      expect(passwordHashIsStale('bare-legacy-digest'), isTrue);
      expect(
        passwordHashIsStale(encodePasswordHash(kLegacyPbkdf2Iterations, 'x')),
        isTrue,
      );
      expect(
        passwordHashIsStale(encodePasswordHash(kPbkdf2Iterations, 'x')),
        isFalse,
      );
    });
  });
}
