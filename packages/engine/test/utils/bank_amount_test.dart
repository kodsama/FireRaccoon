import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

const String nbsp = '\u00A0';
const String narrowNbsp = '\u202F';
const String unicodeMinus = '\u2212';

BankAmountValue _value(BankAmount amount) {
  expect(amount, isA<BankAmountValue>());
  return amount as BankAmountValue;
}

void main() {
  group('parseBalanceAmount', () {
    test('reads 1.234 and 1,234 alike as 1.234', () {
      // Pins the balance-check UI parser: a later refactor must not move that
      // field onto the bank grammar, where 1,234 is undecidable.
      expect(parseBalanceAmount('1.234'), 1.234);
      expect(parseBalanceAmount('1,234'), 1.234);
    });
  });

  group('parseBankAmount', () {
    test('returns both readings for a bare 1,234', () {
      // Catches a statement row silently valued at a thousandth of its amount.
      final amount = parseBankAmount('1,234');
      expect(amount, isA<BankAmountAmbiguous>());
      expect((amount as BankAmountAmbiguous).candidates, [1234.0, 1.234]);
    });

    test('keeps the sign on both readings of an ambiguous amount', () {
      // Catches a parenthesised debit coming back as a positive candidate pair.
      final amount = parseBankAmount('(1,234)');
      expect(amount, isA<BankAmountAmbiguous>());
      expect((amount as BankAmountAmbiguous).candidates, [-1234.0, -1.234]);
    });

    test('reads plain, NBSP and narrow NBSP grouping the same way', () {
      // Catches a bank grammar whose grouping space is not U+0020.
      for (final space in [' ', nbsp, narrowNbsp]) {
        final amount = _value(parseBankAmount('1${space}234,56'));
        expect(amount.value, 1234.56);
        expect(amount.grammar, AmountGrammar.commaDecimal);
      }
    });

    test('lets the last separator settle the grammar', () {
      // Catches 1.234,56 and 1,234.56 collapsing onto one separator rule.
      final comma = _value(parseBankAmount('1.234,56'));
      expect(comma.value, 1234.56);
      expect(comma.grammar, AmountGrammar.commaDecimal);

      final dot = _value(parseBankAmount('1,234.56'));
      expect(dot.value, 1234.56);
      expect(dot.grammar, AmountGrammar.dotDecimal);
    });

    test('reads a trailing minus and a parenthesised amount as negative', () {
      // Catches a debit row being booked as a credit.
      expect(_value(parseBankAmount('9${nbsp}889,00-')).value, -9889.00);
      expect(_value(parseBankAmount('(9${nbsp}889,00)')).value, -9889.00);
    });

    test('reads U+2212 as a minus', () {
      // Catches the Unicode minus falling through to the unreadable branch.
      expect(_value(parseBankAmount('${unicodeMinus}9889.00')).value, -9889.00);
    });

    test('reads a trailing and a leading plus as positive', () {
      // Catches half of a trailing-sign export being unreadable.
      expect(_value(parseBankAmount('1${nbsp}234,56+')).value, 1234.56);
      expect(_value(parseBankAmount('+1${nbsp}234,56')).value, 1234.56);
    });

    test('leaves the canonical Firefly shape unchanged', () {
      // Catches the bank grammar breaking the shape the ledger already uses.
      final amount = _value(parseBankAmount('-9889.00'));
      expect(amount.value, -9889.00);
      expect(amount.grammar, AmountGrammar.dotDecimal);
    });

    test('surfaces a double sign instead of guessing at it', () {
      final amount = parseBankAmount('-9${nbsp}889,00-');
      expect(amount, isA<BankAmountUnreadable>());
      expect((amount as BankAmountUnreadable).reason, 'double_sign');
    });

    test('resolves the bare 1,234 under a supplied grammar', () {
      // Catches the corpus grammar being ignored once one is resolved.
      expect(
        _value(
          parseBankAmount('1,234', grammar: AmountGrammar.commaDecimal),
        ).value,
        1.234,
      );
      expect(
        _value(
          parseBankAmount('1,234', grammar: AmountGrammar.dotDecimal),
        ).value,
        1234.0,
      );
    });

    test('rejects a row written in the other grammar', () {
      // Catches a stray comma-decimal row being misread inside a dot-decimal
      // export rather than landing in needs_input.
      expect(
        parseBankAmount('1,234.56', grammar: AmountGrammar.commaDecimal),
        isA<BankAmountUnreadable>(),
      );
      expect(
        parseBankAmount('1.234.567', grammar: AmountGrammar.dotDecimal),
        isA<BankAmountUnreadable>(),
      );
    });

    test('reads a repeated separator as grouping', () {
      // Catches 1.234.567 being read as a decimal and throwing on parse.
      final amount = _value(parseBankAmount('1.234.567'));
      expect(amount.value, 1234567.0);
      expect(amount.grammar, AmountGrammar.commaDecimal);
    });

    test('rejects a grouping run that is not three digits', () {
      // Catches 1.2345,67 quietly reading as 12345.67.
      expect(parseBankAmount('1.2345,67'), isA<BankAmountUnreadable>());
    });

    test('settles on a decimal when grouping cannot explain the digits', () {
      // Catches 12345,67 being reported as ambiguous with no second reading.
      expect(_value(parseBankAmount('12345,67')).value, 12345.67);
    });

    test('reads a separator-free amount under the Firefly dot grammar', () {
      final amount = _value(parseBankAmount('1234'));
      expect(amount.value, 1234.0);
      expect(amount.grammar, AmountGrammar.dotDecimal);
      expect(_value(parseBankAmount('-1234')).value, -1234.0);
    });

    test('refuses text, empty input and a leading separator', () {
      // Catches currency text being stripped and the row valued anyway.
      for (final raw in ['', '   ', 'abc', ',50', 'SEK 1${nbsp}234,56']) {
        final amount = parseBankAmount(raw);
        expect(amount, isA<BankAmountUnreadable>(), reason: raw);
        expect((amount as BankAmountUnreadable).reason, 'unreadable');
      }
    });
  });

  group('inferAmountGrammarDetailed', () {
    test('carries the votes behind its verdict', () {
      // The caller has to be able to say what the evidence was, and
      // recomputing it means parsing the whole corpus a second time.
      final result = inferAmountGrammarDetailed(const [
        '1234,56',
        '9 889,00-',
        '1234',
      ]);

      expect(result.grammar, AmountGrammar.commaDecimal);
      expect(result.commaVotes, 2);
      expect(result.dotVotes, 0);
      expect(result.sampled, 3);
      expect(result.decidingVotes, 2);
    });

    test('an undecidable corpus reports no deciding votes', () {
      final result = inferAmountGrammarDetailed(const ['1234', '1,234']);

      expect(result.grammar, isNull);
      expect(result.decidingVotes, 0);
      expect(result.sampled, 2);
    });
  });

  group('inferAmountGrammar', () {
    test('returns null when the corpus carries no evidence', () {
      // Catches a default separator being assumed over rows that decide
      // nothing, which values every 1,234 row a thousandfold out.
      expect(inferAmountGrammar(const ['1234', '1,234', '']), isNull);
    });

    test('returns null when rows contradict each other', () {
      // Catches a mixed export being forced onto whichever row came first.
      expect(inferAmountGrammar(const ['1234,56', '1234.56']), isNull);
    });

    test('infers the comma grammar from rows only it can read', () {
      expect(
        inferAmountGrammar(['1${nbsp}234,56', '9${nbsp}889,00-', '1,234']),
        AmountGrammar.commaDecimal,
      );
    });

    test('infers the dot grammar from rows only it can read', () {
      expect(
        inferAmountGrammar(const ['1,234.56', '10.50', '1234']),
        AmountGrammar.dotDecimal,
      );
    });
  });
}
