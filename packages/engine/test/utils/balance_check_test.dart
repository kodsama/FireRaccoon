import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('parseBalanceAmount', () {
    test('parses dot decimals', () {
      expect(parseBalanceAmount('1234.56'), 1234.56);
    });

    test('parses comma decimals', () {
      expect(parseBalanceAmount('1234,56'), 1234.56);
    });

    test('returns null for empty or invalid input', () {
      expect(parseBalanceAmount(''), isNull);
      expect(parseBalanceAmount('abc'), isNull);
    });
  });

  group('compareBalances', () {
    test('returns no input when text is empty', () {
      final result = compareBalances(expected: 100, enteredText: '');
      expect(result, isA<BalanceCheckNoInput>());
      expect(result.expected, 100);
    });

    test('returns invalid input for non-numeric text', () {
      final result = compareBalances(expected: 100, enteredText: 'foo');
      expect(result, isA<BalanceCheckInvalidInput>());
      expect(result.entered, isNull);
      expect(result.difference, isNull);
    });

    test('returns match within tolerance', () {
      final result = compareBalances(expected: 100, enteredText: '100.004');
      expect(result, isA<BalanceCheckMatch>());
      expect(result.isMatch, isTrue);
    });

    test('returns mismatch with signed difference', () {
      final result = compareBalances(expected: 100, enteredText: '95');
      expect(result, isA<BalanceCheckMismatch>());
      expect(result.difference, -5);
    });

    test('null entered text yields no input state', () {
      final result = compareBalances(expected: 100, enteredText: null);
      expect(result, isA<BalanceCheckNoInput>());
      expect(result.hasEntered, isFalse);
      expect(result.isMatch, isFalse);
    });
  });

  group('BalanceCheckResult subclasses', () {
    test('expose typed getters on each variant', () {
      const noInput = BalanceCheckNoInput(100);
      const invalid = BalanceCheckInvalidInput(100);
      const match = BalanceCheckMatch(expected: 100, entered: 100);
      const mismatch = BalanceCheckMismatch(
        expected: 100,
        entered: 90,
        difference: -10,
      );

      expect(noInput.expected, 100);
      expect(noInput.entered, isNull);
      expect(noInput.difference, isNull);
      expect(invalid.entered, isNull);
      expect(match.entered, 100);
      expect(match.difference, 0);
      expect(match.isMatch, isTrue);
      expect(mismatch.isMatch, isFalse);
      expect(mismatch.difference, -10);
    });
  });
}
