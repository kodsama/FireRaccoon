import 'package:fireracoon_engine/models/account.dart';
import 'package:fireracoon_engine/services/account_resolution.dart';
import 'package:test/test.dart';

Account _account({
  required String id,
  String name = 'Konto',
  String? iban,
  String? accountNumber,
}) => Account(
  id: id,
  name: name,
  type: 'asset',
  role: 'defaultAsset',
  currentBalance: 0,
  currencySymbol: 'kr',
  currencyCode: 'SEK',
  iban: iban,
  accountNumber: accountNumber,
);

/// Mod-97 valid, and the one the fixtures below deny against.
const _validIban = 'SE45 5000 0000 0583 9825 7466';

void main() {
  group('identifier tiers', () {
    test('ends the search at an identifier hit', () {
      // Regression: a fuzzy tier appended below an identifier hit, so the
      // payee whose name happens to be in the statement text is offered
      // alongside the account the digits already named.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '1', name: 'Sparkonto', accountNumber: '571 343 821'),
          _account(id: '2', name: 'Common Allkonto'),
        ],
        query: 'Common Allkonto 571 343 821',
      );

      expect(resolution.candidates, hasLength(1));
      final only = resolution.candidates.single;
      expect(only.account.id, '1');
      expect(only.matchedOn, ['account_number']);
      expect(only.score, 1.0);
      expect(only.confidence, MatchConfidence.exact);
      expect(only.reasons.single, contains('the digits in the query'));
      expect(resolution.ambiguous, isFalse);
      expect(resolution.collisions, isEmpty);
      expect(resolution.warnings, isEmpty);
    });

    test('matches the account number the caller already holds', () {
      final resolution = resolveAccountCandidates(
        accounts: [_account(id: '1', accountNumber: '5713-43821')],
        query: 'Överföring',
        accountNumber: '571 343 821',
      );

      expect(resolution.candidates.single.matchedOn, ['account_number']);
      expect(
        resolution.candidates.single.reasons.single,
        contains('the account number supplied'),
      );
    });

    test('confirms an iban the caller already holds', () {
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '1', name: 'Lönekonto', iban: _validIban),
          _account(id: '2', name: 'Sparkonto'),
        ],
        query: 'Lönekonto',
        iban: 'se45-5000-0000-0583-9825-7466',
      );

      final only = resolution.candidates.single;
      expect(only.account.id, '1');
      expect(only.matchedOn, ['iban']);
      expect(only.confidence, MatchConfidence.exact);
      expect(resolution.warnings, isEmpty);
    });

    test('confirms an iban pasted as the query', () {
      final resolution = resolveAccountCandidates(
        accounts: [_account(id: '1', name: 'Lönekonto', iban: _validIban)],
        query: _validIban,
      );

      expect(resolution.candidates.single.matchedOn, ['iban']);
      expect(resolution.candidates.single.score, 1.0);
    });

    test('matches the domestic digits against a zero-padded bban', () {
      // Regression: the Swedish BBAN is the account number widened with zeros,
      // so an equality on the stored IBAN never sees the number the statement
      // prints.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(
            id: '1',
            name: 'Vardagskonto',
            iban: 'SE87 0000 0000 0005 7134 3821',
          ),
        ],
        query: 'Common Allkonto 571 343 821',
      );

      final only = resolution.candidates.single;
      expect(only.matchedOn, ['iban_bban']);
      expect(only.score, 0.9);
      expect(only.confidence, MatchConfidence.exact);
    });

    test('reports every identifier tier one account answered on', () {
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(
            id: '1',
            name: 'Vardagskonto',
            accountNumber: '571 343 821',
            iban: 'SE87 0000 0000 0005 7134 3821',
          ),
        ],
        query: 'Betalning 571 343 821',
      );

      final only = resolution.candidates.single;
      expect(only.matchedOn, ['account_number', 'iban_bban']);
      expect(only.reasons, hasLength(2));
      expect(only.score, 1.0);
      expect(only.confidence, MatchConfidence.exact);
    });

    test('does not match a digit run that only sits inside the bban', () {
      // Regression: substring matching over a zero-padded BBAN, which turns
      // every neighbouring account number into a false identifier hit.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(
            id: '1',
            name: 'Vardagskonto',
            iban: 'SE8700000000005713438210',
          ),
        ],
        query: 'Utbetalning 571 343 821',
      );

      expect(resolution.candidates, isEmpty);
      expect(resolution.ambiguous, isFalse);
    });

    test('skips an account that carries no identifiers at all', () {
      final resolution = resolveAccountCandidates(
        accounts: [_account(id: '1', name: 'Sparkonto')],
        query: '571343821',
      );

      expect(resolution.candidates, isEmpty);
    });
  });

  group('collisions', () {
    test('demotes two accounts carrying the same account number', () {
      // Regression: exact issued as a uniqueness promise Firefly does not
      // keep, since nothing stops two accounts holding one number.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '4', name: 'VA SYD', accountNumber: '571343821'),
          _account(
            id: '19',
            name: 'Vasyd Vatten',
            accountNumber: '571 343 821',
          ),
        ],
        query: 'Betalning 571 343 821',
      );

      expect(
        resolution.candidates.map((c) => c.confidence),
        everyElement(MatchConfidence.probable),
      );
      expect(resolution.collisions, {
        'account_number:571343821': ['19', '4'],
      });
      expect(resolution.ambiguous, isTrue);
      // Ties break on id, so a second run of the same ledger ranks the same
      // way and the caller's confirmation stays meaningful.
      expect(resolution.candidates.map((c) => c.account.id), ['19', '4']);
    });

    test('demotes two accounts that fold to the same name', () {
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '4', name: 'VA SYD'),
          _account(id: '19', name: 'Va Syd'),
        ],
        query: 'VASYD',
      );

      expect(resolution.collisions, {
        'name:vasyd': ['19', '4'],
      });
      expect(
        resolution.candidates.map((c) => c.confidence),
        everyElement(MatchConfidence.probable),
      );
      expect(resolution.ambiguous, isTrue);
    });
  });

  group('name tiers', () {
    test('ranks folded equality above a prefix and calls it unambiguous', () {
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '1', name: 'Svenska Spel AB'),
          _account(id: '2', name: 'AB Svenska Spelbutiken'),
        ],
        query: 'SVENSKA SPEL',
      );

      expect(resolution.candidates.map((c) => c.account.id), ['1', '2']);
      expect(resolution.candidates.first.matchedOn, ['name']);
      expect(resolution.candidates.first.score, 0.8);
      expect(resolution.candidates.first.confidence, MatchConfidence.exact);
      expect(resolution.candidates.last.matchedOn, ['name_prefix']);
      expect(resolution.candidates.last.score, 0.6);
      expect(resolution.candidates.last.confidence, MatchConfidence.probable);
      // A whole tier apart is the case the band must not flag.
      expect(resolution.ambiguous, isFalse);
    });

    test('does not pay a lottery company to a bank', () {
      // Regression: longest common prefix instead of bidirectional startsWith,
      // which hands the truncated bank text to whichever name shares letters.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '1', name: 'Svenska Spel'),
          _account(id: '2', name: 'Svenska Handelsbanken'),
        ],
        query: 'AB SVENSKA S',
      );

      expect(resolution.candidates.single.account.id, '1');
      expect(resolution.candidates.single.matchedOn, ['name_prefix']);
    });

    test('holds a folded substring at the weak tier', () {
      final resolution = resolveAccountCandidates(
        accounts: [_account(id: '1', name: 'Malmö ICA Supermarket')],
        query: 'ICA Supermarket',
      );

      final only = resolution.candidates.single;
      expect(only.matchedOn, ['name_substring']);
      expect(only.score, 0.4);
      expect(only.confidence, MatchConfidence.weak);
    });

    test('ignores a run shorter than the substring minimum', () {
      // Pins the five-character floor through behaviour: three folded
      // characters is a fair slice of any ledger.
      final resolution = resolveAccountCandidates(
        accounts: [_account(id: '1', name: 'Malmö ICA Supermarket')],
        query: 'ICA',
      );

      expect(resolution.candidates, isEmpty);
    });

    test('skips and counts a blank-named account', () {
      // Regression: a name that folds to nothing is a prefix of every query,
      // so it is offered for every statement line.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '1', name: '   '),
          _account(id: '2', name: 'Malmö ICA Supermarket'),
        ],
        query: 'ICA Supermarket',
      );

      expect(resolution.candidates.single.account.id, '2');
      expect(resolution.skippedBlankNames, 1);
    });

    test('keeps a blank-named account eligible for the identifier tiers', () {
      final resolution = resolveAccountCandidates(
        accounts: [_account(id: '1', name: '  ', accountNumber: '571343821')],
        query: 'Betalning 571 343 821',
      );

      expect(resolution.candidates.single.account.id, '1');
      expect(resolution.skippedBlankNames, 0);
    });
  });

  group('ambiguity', () {
    test('flags two certain answers reached on different tiers', () {
      // Regression: two accounts both scoring 1.0 on different keys collide on
      // neither, so only the band clause can carry the doubt.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '1', name: 'Sparkonto', accountNumber: '571343821'),
          _account(id: '2', name: 'Lönekonto', iban: _validIban),
        ],
        query: 'Betalning',
        iban: _validIban,
        accountNumber: '571 343 821',
      );

      expect(resolution.candidates.map((c) => c.matchedOn), [
        ['account_number'],
        ['iban'],
      ]);
      expect(resolution.collisions, isEmpty);
      expect(resolution.ambiguous, isTrue);
    });

    test('reports ambiguity the limit dropped', () {
      // Regression: truncation turning a three-way tie into a lone candidate
      // the caller reads as settled.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '1', name: 'Vasyd Vatten'),
          _account(id: '2', name: 'Vasyd Elnat'),
          _account(id: '3', name: 'Vasyd Avfall'),
        ],
        query: 'VASYD',
        limit: 1,
      );

      expect(resolution.candidates, hasLength(1));
      expect(resolution.collisions['name_prefix:vasyd'], ['1', '2', '3']);
      expect(resolution.ambiguous, isTrue);
    });
  });

  group('supplied iban checks', () {
    test('warns and falls back to names when mod-97 fails', () {
      // Regression: a hard failure on a mistyped IBAN discarding a good name
      // match, and an identifier tier trusting the corrupt string.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '1', name: 'Sparkonto', accountNumber: '571343821'),
        ],
        query: 'Sparkonto 571 343 821',
        iban: 'SE45 5000 0000 0583 9825 7467',
      );

      expect(resolution.warnings, [
        'supplied iban failed mod-97; identifier tiers skipped',
      ]);
      final only = resolution.candidates.single;
      expect(only.matchedOn, ['name_prefix']);
      expect(only.score, 0.6);
      expect(only.confidence, MatchConfidence.probable);
    });

    test('does not run mod-97 on a clearing number', () {
      // Regression: a Handelsbanken clearing number reported as a corrupt
      // IBAN, which throws away every identifier tier for the whole call.
      final resolution = resolveAccountCandidates(
        accounts: [
          _account(id: '1', name: 'Sparkonto', accountNumber: '571343821'),
        ],
        query: 'Betalning 571 343 821',
        iban: '6000',
      );

      expect(resolution.warnings, isEmpty);
      expect(resolution.candidates.single.matchedOn, ['account_number']);
    });
  });
}
