import 'dart:math' as math;

import '../models/account.dart';
import '../utils/name_matching.dart';

/// Score gap under which two candidates are not separable.
///
/// Every gap in the tier table below is 0.1 or wider, so a pair inside this
/// band is a pair that matched on the same tier and nothing else told them
/// apart.
const double kAmbiguityBand = 0.05;

/// How far a candidate can be trusted without a human confirming it.
enum MatchConfidence { exact, probable, weak }

class AccountCandidate {
  const AccountCandidate({
    required this.account,
    required this.score,
    required this.confidence,
    required this.matchedOn,
    required this.reasons,
  });

  final Account account;

  final double score;

  final MatchConfidence confidence;

  /// Tier names that produced the match, strongest first: `account_number`,
  /// `iban`, `iban_bban`, `name`, `name_prefix` or `name_substring`.
  final List<String> matchedOn;

  final List<String> reasons;
}

class AccountResolution {
  const AccountResolution({
    required this.candidates,
    required this.ambiguous,
    required this.skippedBlankNames,
    required this.collisions,
    required this.warnings,
  });

  /// Ranked and truncated to the caller's limit.
  final List<AccountCandidate> candidates;

  final bool ambiguous;

  /// Accounts left out of the name tiers because their name folded to nothing.
  final int skippedBlankNames;

  /// Match key to the ids of every account that answered to it, for keys more
  /// than one account answered to.
  ///
  /// A key carries the value that matched, which is only ever a value the
  /// caller already sent: an identifier tier compares against the query or the
  /// caller's own argument, so a key discloses nothing the caller did not
  /// write.
  final Map<String, List<String>> collisions;

  final List<String> warnings;
}

/// Shortest folded run that may stand in for a name at the substring tier.
///
/// One character longer than [kNameMatchMinPrefix]: a run that is not anchored
/// at either end is weaker evidence than one that is.
const int _minSubstring = 5;

const String _ibanChecksumWarning =
    'supplied iban failed mod-97; identifier tiers skipped';

/// Ranks [accounts] against a raw bank string and whatever identifiers the
/// caller already holds.
///
/// Tiers run in a fixed order with fixed scores: the account number's digits
/// (1.0), the IBAN (1.0), then the IBAN's BBAN without its padding against the
/// digits in the query (0.9). An identifier hit ends the search, so a fuzzy
/// tier is never appended below one and a name coincidence cannot dilute an
/// answer the ledger already gave. Only when all three miss do the name tiers
/// run: folded equality (0.8), a bidirectional prefix (0.6), then a folded
/// substring (0.4, never stronger than [MatchConfidence.weak]).
///
/// Nothing here promises uniqueness that Firefly does not enforce: two accounts
/// can carry the same account number, and when they do both come back
/// [MatchConfidence.probable] under [AccountResolution.collisions] rather than
/// one of them coming back exact.
AccountResolution resolveAccountCandidates({
  required Iterable<Account> accounts,
  required String query,
  String? iban,
  String? accountNumber,
  int limit = 5,
}) {
  final pool = accounts.toList(growable: false);
  final warnings = <String>[];
  final queryDigits = digitsOnly(query);
  final queryIdentifier = normalizeIdentifier(query);
  final queryName = foldAccountName(query);
  final suppliedDigits = digitsOnly(accountNumber ?? '');
  final suppliedIban = normalizeIdentifier(iban ?? '');

  // A clearing number or a bare account number is not a corrupt IBAN, so
  // mod-97 only speaks for a string shaped like one.
  final identifiersUsable =
      iban == null || !isIbanShaped(iban) || ibanChecksumValid(iban);
  if (!identifiersUsable) warnings.add(_ibanChecksumWarning);

  final matches = <_Match>[];
  if (identifiersUsable) {
    for (final account in pool) {
      final hits = _identifierHits(
        account,
        suppliedDigits: suppliedDigits,
        suppliedIban: suppliedIban,
        queryDigits: queryDigits,
        queryIdentifier: queryIdentifier,
      );
      if (hits.isNotEmpty) matches.add(_Match(account, hits));
    }
  }

  var skippedBlankNames = 0;
  if (matches.isEmpty) {
    for (final account in pool) {
      final folded = foldAccountName(account.name);
      if (folded.isEmpty) {
        // An empty folded name is a prefix of every query, so it is counted
        // and dropped rather than matched.
        skippedBlankNames++;
        continue;
      }
      final hit = _nameHit(folded, queryName);
      if (hit != null) matches.add(_Match(account, [hit]));
    }
  }

  matches.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.account.id.compareTo(b.account.id);
  });

  final idsByKey = <String, List<String>>{};
  for (final match in matches) {
    for (final hit in match.hits) {
      idsByKey.putIfAbsent(hit.key, () => <String>[]).add(match.account.id);
    }
  }
  final collisions = <String, List<String>>{
    for (final entry in idsByKey.entries)
      if (entry.value.length > 1) entry.key: List.unmodifiable(entry.value),
  };

  final ranked = <AccountCandidate>[
    for (final match in matches)
      AccountCandidate(
        account: match.account,
        score: match.score,
        confidence: _confidenceFor(
          match.score,
          !match.hits.any((hit) => collisions.containsKey(hit.key)),
          match.cap,
        ),
        matchedOn: List.unmodifiable(match.hits.map((hit) => hit.tier)),
        reasons: List.unmodifiable(match.hits.map((hit) => hit.reason)),
      ),
  ];

  // Read off the full ranking, not the truncated one: a limit of 1 must not
  // hide the second candidate that made the first one doubtful.
  final ambiguous =
      collisions.isNotEmpty ||
      (ranked.length > 1 &&
          (ranked[0].score - ranked[1].score).abs() < kAmbiguityBand);

  return AccountResolution(
    candidates: List.unmodifiable(ranked.take(limit)),
    ambiguous: ambiguous,
    skippedBlankNames: skippedBlankNames,
    collisions: Map.unmodifiable(collisions),
    warnings: List.unmodifiable(warnings),
  );
}

List<_Hit> _identifierHits(
  Account account, {
  required String suppliedDigits,
  required String suppliedIban,
  required String queryDigits,
  required String queryIdentifier,
}) {
  final hits = <_Hit>[];

  final number = digitsOnly(account.accountNumber ?? '');
  if (number.isNotEmpty) {
    if (number == suppliedDigits) {
      hits.add(
        _Hit(
          tier: 'account_number',
          value: number,
          score: 1.0,
          reason: 'account number $number equals the account number supplied',
        ),
      );
    } else if (number == queryDigits) {
      hits.add(
        _Hit(
          tier: 'account_number',
          value: number,
          score: 1.0,
          reason: 'account number $number equals the digits in the query',
        ),
      );
    }
  }

  final ledgerIban = normalizeIdentifier(account.iban ?? '');
  if (ledgerIban.isNotEmpty) {
    if (ledgerIban == suppliedIban) {
      hits.add(
        _Hit(
          tier: 'iban',
          value: ledgerIban,
          score: 1.0,
          reason: 'the iban supplied is this account iban',
        ),
      );
    } else if (ledgerIban == queryIdentifier) {
      hits.add(
        _Hit(
          tier: 'iban',
          value: ledgerIban,
          score: 1.0,
          reason: 'the query is this account iban',
        ),
      );
    }
  }

  final bban = ibanBban(account.iban ?? '');
  if (bban != null && bban == queryDigits) {
    hits.add(
      _Hit(
        tier: 'iban_bban',
        value: bban,
        score: 0.9,
        reason:
            'the digits in the query equal this account iban without its '
            'country code and padding',
      ),
    );
  }

  return hits;
}

_Hit? _nameHit(String folded, String queryName) {
  if (folded == queryName) {
    return _Hit(
      tier: 'name',
      value: queryName,
      score: 0.8,
      reason: 'the folded name equals the folded query $queryName',
    );
  }
  if (prefixMatches(folded, queryName)) {
    return _Hit(
      tier: 'name_prefix',
      value: queryName,
      score: 0.6,
      reason:
          'the folded name $folded and the folded query $queryName are '
          'prefixes of one another',
    );
  }
  if (math.min(folded.length, queryName.length) >= _minSubstring &&
      (folded.contains(queryName) || queryName.contains(folded))) {
    return _Hit(
      tier: 'name_substring',
      value: queryName,
      score: 0.4,
      cap: MatchConfidence.weak,
      reason:
          'one of the folded name $folded and the folded query $queryName '
          'contains the other',
    );
  }
  return null;
}

/// [MatchConfidence.exact] is a uniqueness claim as much as a score claim, so
/// it needs [unique] as well as 0.8. [cap] is what holds the substring tier at
/// weak by construction rather than by arithmetic a later score change could
/// undo.
/// Confidence from a score, never better than [cap].
///
/// The enum runs exact, probable, weak, so the higher index is the weaker
/// claim and max picks the more cautious of the two. A collision caps at
/// probable; it must not lift a weak match up to probable on the way.
MatchConfidence _confidenceFor(double score, bool unique, MatchConfidence cap) {
  final byScore = score >= 0.8 && unique
      ? MatchConfidence.exact
      : score >= 0.5
      ? MatchConfidence.probable
      : MatchConfidence.weak;
  return MatchConfidence.values[math.max(byScore.index, cap.index)];
}

class _Hit {
  const _Hit({
    required this.tier,
    required this.value,
    required this.score,
    required this.reason,
    this.cap = MatchConfidence.exact,
  });

  final String tier;
  final String value;
  final double score;
  final String reason;
  final MatchConfidence cap;

  String get key => '$tier:$value';
}

class _Match {
  _Match(this.account, this.hits);

  final Account account;
  final List<_Hit> hits;

  _Hit get _best => hits.reduce((a, b) => b.score > a.score ? b : a);

  double get score => _best.score;

  MatchConfidence get cap => _best.cap;
}
