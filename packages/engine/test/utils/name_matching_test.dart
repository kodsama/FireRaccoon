import 'package:fireraccoon_engine/utils/name_matching.dart';
import 'package:test/test.dart';

void main() {
  group('foldLatin', () {
    test('folds a diacritic onto its ASCII skeleton', () {
      // Regression: the table dropped for a Unicode normalization Dart core
      // cannot do, leaving Malmö and Malmo as two different payees.
      expect(foldLatin('Malmö'), 'malmo');
      expect(foldLatin('Ærø Bagerí'), 'aero bageri');
    });

    test('expands the multi-character folds', () {
      expect(foldLatin('Straße'), 'strasse');
      expect(foldLatin('Œuf'), 'oeuf');
    });

    test('lowercases scripts the table does not cover', () {
      // Regression: an unmapped rune dropped instead of passed through, which
      // would blank every non-Latin name.
      expect(foldLatin('ЭЛЕКТРО'), 'электро');
      expect(foldLatin('招行代理店'), '招行代理店');
    });
  });

  group('foldAccountName', () {
    test('keeps a bare name that is not a suffix', () {
      // Regression: suffix stripping applied after space collapse ate the
      // real name, folding Kebab to the empty string.
      expect(foldAccountName('Kebab'), 'kebab');
    });

    test('strips a trailing legal suffix token', () {
      expect(foldAccountName('Kebab AB'), 'kebab');
    });

    test('strips a suffix that only exists before the collapse', () {
      // Regression: token-wise stripping regressing to substring stripping,
      // which cannot see a/s once the slash is gone.
      expect(foldAccountName('Danfoss A/S'), 'danfoss');
    });

    test('strips a leading company form', () {
      // Regression: only the last token checked, leaving abnordisklotto to be
      // compared against a statement line that prints the form on one side
      // only.
      expect(foldAccountName('AB Nordisk Lotto'), 'nordisklotto');
      expect(foldAccountName('AB Nordisk Lotto AB'), 'nordisklotto');
    });

    test(
      'keeps the suffix when the name would drop below three characters',
      () {
        expect(foldAccountName('XY AB'), 'xyab');
      },
    );

    test('keeps a name made of nothing but suffixes', () {
      expect(foldAccountName('AB'), 'ab');
      expect(foldAccountName('AB Oy'), 'aboy');
      expect(foldAccountName('  '), '');
    });

    test('strips every suffix the constant lists', () {
      // Regression: an entry added to kLegalSuffixes in a form the token
      // comparison cannot see, such as an uppercase or spaced one.
      for (final suffix in kLegalSuffixes) {
        expect(foldAccountName('Nordvest $suffix'), 'nordvest', reason: suffix);
        expect(foldAccountName('$suffix Nordvest'), 'nordvest', reason: suffix);
      }
    });

    test('keeps non-Latin names non-empty', () {
      // Regression: an ASCII character class reducing a real account to a
      // blank name, which then prefix-matches every query.
      expect(foldAccountName('Электро'), 'электро');
      expect(foldAccountName('招行代理店'), '招行代理店');
    });

    test('drops separators and case from the compared form', () {
      expect(
        foldAccountName('E.ON  Försäljning-Sverige'),
        'eonforsaljningsverige',
      );
    });
  });

  group('foldAccountNameWithoutNumber', () {
    test('sets aside the number a bank prints after the label', () {
      // Regression: the whole account line folded as one string, so the digits
      // went into the name comparison and matched no ledger name at all.
      expect(
        foldAccountNameWithoutNumber('Joint Current 12 345 678'),
        'jointcurrent',
      );
    });

    test('reads a number whatever it is grouped or punctuated as', () {
      // 3-3-3 and 2-3-3 both occur on one bank's exports, and a clearing
      // number is written onto the front with a hyphen.
      expect(
        foldAccountNameWithoutNumber('Vardagskonto 98 765 432'),
        'vardagskonto',
      );
      expect(
        foldAccountNameWithoutNumber('Lönekonto 1234-87654321'),
        'lonekonto',
      );
    });

    test('folds the label the way a name is folded', () {
      expect(foldAccountNameWithoutNumber('Nordvest AB 12345'), 'nordvest');
    });

    test('leaves a line with no trailing number alone', () {
      expect(foldAccountNameWithoutNumber('E.ON Försäljning'), isNull);
    });

    test('leaves an interior digit run alone', () {
      // Only a trailing run is an account number; digits in the middle are
      // part of the name.
      expect(foldAccountNameWithoutNumber('Konto 24 Timmar'), isNull);
    });

    test('has no label for a line that is nothing but a number', () {
      expect(foldAccountNameWithoutNumber('12345678'), isNull);
      expect(foldAccountNameWithoutNumber('1234-56789012'), isNull);
    });

    test('rejects a label shorter than the prefix minimum', () {
      // Equality is the only tier a two-character label could reach, and it
      // would answer outright on evidence this thin.
      expect(foldAccountNameWithoutNumber('XY 12345'), isNull);
    });
  });

  group('prefixMatches', () {
    test('accepts a truncated bank name against the full name', () {
      expect(prefixMatches('nordiskl', 'nordisklotto'), isTrue);
    });

    test('rejects a shared run that is not a prefix of the shorter string', () {
      // Regression: longest common prefix implemented instead of bidirectional
      // startsWith, which merges a lottery company with a bank.
      expect(prefixMatches('nordiskl', 'nordiskbank'), isFalse);
    });

    test('rejects a prefix shorter than the minimum', () {
      // Pins kNameMatchMinPrefix at 4 through behaviour: two folded characters
      // in common is half the payees in a ledger.
      expect(prefixMatches('va', 'vattn'), isFalse);
      expect(prefixMatches('vat', 'vattn'), isFalse);
      expect(prefixMatches('vatt', 'vattn'), isTrue);
    });

    test('rejects an empty side', () {
      // Regression: a blank folded name being a prefix of everything.
      expect(prefixMatches('', 'vattn'), isFalse);
      expect(prefixMatches('vattn', ''), isFalse);
    });
  });

  group('digitsOnly and normalizeIdentifier', () {
    test('keeps the digits a bank prints with spaces', () {
      expect(digitsOnly('Joint Current 123 456 789'), '123456789');
      expect(digitsOnly('no digits'), '');
    });

    test('uppercases and unspaces an identifier', () {
      expect(
        normalizeIdentifier('se45 5000-0000 0583 9825 7466'),
        'SE4550000000058398257466',
      );
      expect(normalizeIdentifier('Ö'), '');
    });
  });

  group('IBAN', () {
    const swedish = 'SE45 5000 0000 0583 9825 7466';

    test('recognises the ISO 13616 shape', () {
      expect(isIbanShaped(swedish), isTrue);
      expect(isIbanShaped('6000 123456789'), isFalse);
    });

    test('validates mod-97 across countries', () {
      expect(ibanChecksumValid(swedish), isTrue);
      expect(ibanChecksumValid('GB82 WEST 1234 5698 7654 32'), isTrue);
      expect(ibanChecksumValid('NO9386011117947'), isTrue);
    });

    test('rejects a transposed check digit', () {
      expect(ibanChecksumValid('SE4550000000058398257467'), isFalse);
    });

    test(
      'reports a clearing number as failing the shape, not the checksum',
      () {
        // Regression: mod-97 run on a bank clearing number that was
        // never claimed to be an IBAN, which reads as a corrupt IBAN.
        expect(isIbanShaped('6000'), isFalse);
        expect(ibanChecksumValid('6000'), isFalse);
      },
    );

    test('strips country, check digits and the domestic zero padding', () {
      // Regression: the zero-padded Swedish BBAN never equalling the digits a
      // statement prints for the same account.
      expect(ibanBban('SE87 0000 0000 0001 2345 6789'), '123456789');
      expect(ibanBban(swedish), '50000000058398257466');
    });

    test('has no BBAN for a non-IBAN or an all-zero body', () {
      expect(ibanBban('123456789'), isNull);
      expect(ibanBban('SE000000'), isNull);
    });
  });
}
