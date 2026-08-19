/// Decimal separator conventions a bank export can use.
enum AmountGrammar {
  /// `1,234.56`: dot decimals, comma grouping.
  dotDecimal,

  /// `1.234,56`: comma decimals, dot grouping.
  commaDecimal,
}

/// Result of reading one amount out of a bank export.
sealed class BankAmount {
  const BankAmount();
}

class BankAmountValue extends BankAmount {
  const BankAmountValue({required this.value, required this.grammar});

  final double value;

  /// An amount carrying no separator at all reports [AmountGrammar.dotDecimal],
  /// Firefly's own wire shape, because no reading of it depends on the choice.
  final AmountGrammar grammar;
}

class BankAmountAmbiguous extends BankAmount {
  const BankAmountAmbiguous(this.candidates);

  /// Grouping reading first, decimal reading second, so `1,234` yields
  /// `[1234.0, 1.234]`.
  final List<double> candidates;
}

class BankAmountUnreadable extends BankAmount {
  const BankAmountUnreadable(this.reason);

  /// Either `double_sign` or `unreadable`.
  final String reason;
}

const String _doubleSignReason = 'double_sign';
const String _unreadableReason = 'unreadable';

/// U+2212, the minus several Nordic exports use instead of a hyphen.
const String _unicodeMinus = '\u2212';

/// `\s` already covers U+00A0 and U+202F, the two grouping spaces banks emit.
final RegExp _whitespace = RegExp(r'\s');

/// A body of digits with separators between them, never leading or trailing.
final RegExp _numericBody = RegExp(r'^\d+(?:[.,]\d+)*$');

/// Reads [raw] under [grammar], or under whichever grammar the text settles by
/// itself when [grammar] is null.
///
/// Not built on `parseBalanceAmount`: that one backs the balance-check field,
/// where a typed `1,234` means 1.234 and tests pin it. A statement row reading
/// `1,234` is undecidable, so it comes back as [BankAmountAmbiguous] and the
/// caller has to handle the branch rather than silently booking a thousandth of
/// the real amount.
BankAmount parseBankAmount(String raw, {AmountGrammar? grammar}) {
  var text = raw.trim().replaceAll(_unicodeMinus, '-');
  var negative = false;
  var signs = 0;

  if (text.startsWith('(') && text.endsWith(')')) {
    negative = true;
    signs++;
    text = text.substring(1, text.length - 1).trim();
  }
  if (text.startsWith('-')) {
    negative = true;
    signs++;
    text = text.substring(1).trimLeft();
  } else if (text.startsWith('+')) {
    signs++;
    text = text.substring(1).trimLeft();
  }
  if (text.endsWith('-')) {
    negative = true;
    signs++;
    text = text.substring(0, text.length - 1).trimRight();
  } else if (text.endsWith('+')) {
    signs++;
    text = text.substring(0, text.length - 1).trimRight();
  }
  if (signs > 1) return const BankAmountUnreadable(_doubleSignReason);

  final body = text.replaceAll(_whitespace, '');
  if (!_numericBody.hasMatch(body)) {
    return const BankAmountUnreadable(_unreadableReason);
  }

  if (grammar != null) return _read(body, grammar, negative);

  final lastDot = body.lastIndexOf('.');
  final lastComma = body.lastIndexOf(',');
  if (lastDot >= 0 && lastComma >= 0) {
    final decimalWins = lastComma > lastDot
        ? AmountGrammar.commaDecimal
        : AmountGrammar.dotDecimal;
    return _read(body, decimalWins, negative);
  }
  if (lastDot < 0 && lastComma < 0) {
    final value = double.parse(body);
    return BankAmountValue(
      value: negative ? -value : value,
      grammar: AmountGrammar.dotDecimal,
    );
  }

  final separator = lastDot >= 0 ? '.' : ',';
  final asDecimal = separator == ','
      ? AmountGrammar.commaDecimal
      : AmountGrammar.dotDecimal;
  final asGrouping = separator == ','
      ? AmountGrammar.dotDecimal
      : AmountGrammar.commaDecimal;
  final decimalReading = _read(body, asDecimal, negative);
  final groupingReading = _read(body, asGrouping, negative);
  final tailDigits = body.length - body.lastIndexOf(separator) - 1;
  if (decimalReading is BankAmountValue &&
      groupingReading is BankAmountValue &&
      tailDigits == 3) {
    return BankAmountAmbiguous([groupingReading.value, decimalReading.value]);
  }
  if (decimalReading is BankAmountValue) return decimalReading;
  return groupingReading;
}

/// The grammar the whole [corpus] agrees on, or null when it carries no
/// evidence either way or contradicts itself.
///
/// A row is evidence for a grammar only when the other grammar cannot read it
/// at all, so `1,234` votes for neither and a corpus of such rows leaves the
/// caller to ask rather than letting a majority of nothing pick a separator.
/// What a corpus of raw amounts says about which separator is the decimal.
///
/// The counts travel with the verdict because a caller has to be able to say
/// what the evidence was, and recomputing it means parsing the corpus twice.
class AmountGrammarInference {
  const AmountGrammarInference({
    required this.grammar,
    required this.dotVotes,
    required this.commaVotes,
    required this.sampled,
  });

  /// Null when nothing in the corpus distinguishes the two grammars.
  final AmountGrammar? grammar;
  final int dotVotes;
  final int commaVotes;
  final int sampled;

  int get decidingVotes => switch (grammar) {
    AmountGrammar.dotDecimal => dotVotes,
    AmountGrammar.commaDecimal => commaVotes,
    null => 0,
  };
}

AmountGrammarInference inferAmountGrammarDetailed(Iterable<String> corpus) {
  var dotVotes = 0;
  var commaVotes = 0;
  var sampled = 0;
  for (final raw in corpus) {
    sampled++;
    final asDot = parseBankAmount(raw, grammar: AmountGrammar.dotDecimal);
    final asComma = parseBankAmount(raw, grammar: AmountGrammar.commaDecimal);
    if (asDot is BankAmountValue && asComma is! BankAmountValue) {
      dotVotes++;
    } else if (asComma is BankAmountValue && asDot is! BankAmountValue) {
      commaVotes++;
    }
  }
  final AmountGrammar? grammar;
  if (dotVotes > 0 && commaVotes == 0) {
    grammar = AmountGrammar.dotDecimal;
  } else if (commaVotes > 0 && dotVotes == 0) {
    grammar = AmountGrammar.commaDecimal;
  } else {
    grammar = null;
  }
  return AmountGrammarInference(
    grammar: grammar,
    dotVotes: dotVotes,
    commaVotes: commaVotes,
    sampled: sampled,
  );
}

AmountGrammar? inferAmountGrammar(Iterable<String> corpus) =>
    inferAmountGrammarDetailed(corpus).grammar;

BankAmount _read(String body, AmountGrammar grammar, bool negative) {
  final decimalSeparator = grammar == AmountGrammar.commaDecimal ? ',' : '.';
  final groupSeparator = grammar == AmountGrammar.commaDecimal ? '.' : ',';

  final cut = body.lastIndexOf(decimalSeparator);
  final integerPart = cut < 0 ? body : body.substring(0, cut);
  final decimalPart = cut < 0 ? '' : body.substring(cut + 1);
  if (integerPart.contains(decimalSeparator) ||
      decimalPart.contains(groupSeparator)) {
    return const BankAmountUnreadable(_unreadableReason);
  }
  if (!_groupingValid(integerPart, groupSeparator)) {
    return const BankAmountUnreadable(_unreadableReason);
  }

  final digits = integerPart.replaceAll(groupSeparator, '');
  final value = double.parse(
    decimalPart.isEmpty ? digits : '$digits.$decimalPart',
  );
  return BankAmountValue(value: negative ? -value : value, grammar: grammar);
}

bool _groupingValid(String integerPart, String groupSeparator) {
  final groups = integerPart.split(groupSeparator);
  if (groups.length == 1) return true;
  if (groups.first.length > 3) return false;
  return groups.skip(1).every((group) => group.length == 3);
}
