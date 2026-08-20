import 'dart:math' as math;

/// Shortest folded run that may stand in for a whole name in [prefixMatches].
const int kNameMatchMinPrefix = 4;

/// Company-form tokens dropped from either end of a name before it is compared.
const Set<String> kLegalSuffixes = {
  'ab',
  'a/s',
  'as',
  'ltd',
  'limited',
  'oy',
  'aps',
  'gmbh',
  'bv',
  'plc',
  'inc',
};

/// Below this, dropping a suffix has removed the name itself.
const int _minStrippedLength = 3;

final RegExp _whitespace = RegExp(r'\s+');
final RegExp _nonAlphanumeric = RegExp(r'[^\p{L}\p{N}]', unicode: true);
final RegExp _nonDigit = RegExp(r'[^0-9]');
final RegExp _nonIdentifier = RegExp(r'[^A-Z0-9]');
final RegExp _ibanShape = RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]+$');
final RegExp _leadingZeros = RegExp(r'^0+');

/// ASCII skeleton to the lowercase Latin-1 Supplement (U+00C0-U+00FF) and Latin
/// Extended-A (U+0100-U+017F) letters that fold onto it.
///
/// Only lowercase sources appear, because [foldLatin] lowercases first and
/// Dart's case mapping already covers both blocks.
const Map<String, String> _foldSources = {
  'a': 'àáâãäåāăą',
  'ae': 'æ',
  'c': 'çćĉċč',
  'd': 'ðďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħ',
  'i': 'ìíîïĩīĭįı',
  'ij': 'ĳ',
  'j': 'ĵ',
  'k': 'ķĸ',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉŋ',
  'o': 'òóôõöøōŏő',
  'oe': 'œ',
  'r': 'ŕŗř',
  's': 'śŝşšſ',
  'ss': 'ß',
  't': 'ţťŧ',
  'th': 'þ',
  'u': 'ùúûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

final Map<String, String> _latinFolds = {
  for (final entry in _foldSources.entries)
    for (final source in entry.value.split('')) source: entry.key,
};

/// Lowercases [raw] and maps Latin-1 Supplement (U+00C0-U+00FF) and Latin
/// Extended-A (U+0100-U+017F) letters onto their ASCII skeletons.
///
/// The table is explicit and covers nothing beyond those two blocks: Dart core
/// has no Unicode normalization, and the engine depends only on crypto, http,
/// intl and logging. Greek, Cyrillic, Hebrew and CJK come back lowercased but
/// unfolded, so two such names are compared to each other as written rather
/// than through an approximation of a decomposition this package cannot do.
String foldLatin(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_latinFolds[character] ?? character);
  }
  return buffer.toString();
}

/// Folds an account or payee name to the form names are compared in.
///
/// The legal-suffix token goes while the token boundaries are still there, so
/// `Danfoss A/S` loses `a/s` instead of collapsing to `danfossas` and matching
/// every `as` payee. Both ends are checked, because a Nordic company form is
/// written on either side: `AB Lotteri Bolaget` folds to `lotteribolaget`. A name
/// that is only a suffix, or that would drop below three characters without
/// it, keeps it: `Kebab` folds to `kebab`, not to the empty string that
/// prefix-matches the whole ledger.
String foldAccountName(String raw) {
  var tokens = foldLatin(
    raw,
  ).split(_whitespace).where((token) => token.isNotEmpty).toList();
  if (tokens.length > 1 && kLegalSuffixes.contains(tokens.first)) {
    tokens = _strippedUnlessTooShort(tokens, tokens.sublist(1));
  }
  if (tokens.length > 1 && kLegalSuffixes.contains(tokens.last)) {
    tokens = _strippedUnlessTooShort(
      tokens,
      tokens.sublist(0, tokens.length - 1),
    );
  }
  return _collapse(tokens.join());
}

List<String> _strippedUnlessTooShort(
  List<String> original,
  List<String> stripped,
) => _collapse(stripped.join()).length >= _minStrippedLength
    ? stripped
    : original;

/// Keeps letters and numbers in any script, so a non-Latin payee folds to
/// itself rather than to a blank name.
String _collapse(String folded) => folded.replaceAll(_nonAlphanumeric, '');

/// The ASCII digits of [raw], in order.
String digitsOnly(String raw) => raw.replaceAll(_nonDigit, '');

/// Uppercases [raw] and drops everything a bank prints for legibility, so a
/// spaced IBAN and a hyphenated account number compare as the ledger stores
/// them.
String normalizeIdentifier(String raw) =>
    raw.toUpperCase().replaceAll(_nonIdentifier, '');

/// Whether [raw] has the ISO 13616 shape: country, check digits, then the BBAN.
///
/// A clearing number or a bare account number fails here, which is what keeps
/// [ibanChecksumValid] from reporting mod-97 failure on a string that was never
/// claimed to be an IBAN.
bool isIbanShaped(String raw) => _ibanShape.hasMatch(normalizeIdentifier(raw));

/// Whether [raw] is IBAN-shaped and passes the mod-97 check.
bool ibanChecksumValid(String raw) {
  final normalized = normalizeIdentifier(raw);
  if (!_ibanShape.hasMatch(normalized)) return false;
  final rotated = normalized.substring(4) + normalized.substring(0, 4);
  var remainder = 0;
  for (final unit in rotated.codeUnits) {
    // A-Z carry two digits each, 10 through 35, so the running mod shifts by
    // two places for a letter and one for a digit.
    if (unit >= 0x41) {
      remainder = (remainder * 100 + unit - 0x41 + 10) % 97;
    } else {
      remainder = (remainder * 10 + unit - 0x30) % 97;
    }
  }
  return remainder == 1;
}

/// [raw] without its country and check digits and without the zero padding a
/// domestic account number is widened with, or null when there is nothing left
/// to compare.
///
/// An all-zero remainder returns null rather than the empty string, which would
/// equal the digits of a query that carried no digits at all.
String? ibanBban(String raw) {
  final normalized = normalizeIdentifier(raw);
  if (!_ibanShape.hasMatch(normalized)) return null;
  final bban = normalized.substring(4).replaceFirst(_leadingZeros, '');
  return bban.isEmpty ? null : bban;
}

/// Whether one of [a] and [b] is a prefix of the other over at least
/// [kNameMatchMinPrefix] characters.
///
/// Bidirectional startsWith, not longest common prefix: the bank's truncated
/// `AB LOTTERI B` folds to a prefix of `lotteribolaget`, while the seven
/// characters it shares with `nordiskbank` buy it nothing, so a
/// lottery company is not paid to a bank.
bool prefixMatches(String a, String b) =>
    a.isNotEmpty &&
    b.isNotEmpty &&
    (a.startsWith(b) || b.startsWith(a)) &&
    math.min(a.length, b.length) >= kNameMatchMinPrefix;
