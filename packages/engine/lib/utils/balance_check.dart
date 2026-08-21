/// Result of comparing a user-entered statement balance to the ledger balance.
sealed class BalanceCheckResult {
  const BalanceCheckResult();

  double get expected;
  double? get entered;
  double? get difference;
  bool get hasEntered => entered != null;
  bool get isMatch => false;
}

class BalanceCheckNoInput extends BalanceCheckResult {
  const BalanceCheckNoInput(this.expected);

  @override
  final double expected;

  @override
  double? get entered => null;

  @override
  double? get difference => null;
}

class BalanceCheckInvalidInput extends BalanceCheckResult {
  const BalanceCheckInvalidInput(this.expected);

  @override
  final double expected;

  @override
  double? get entered => null;

  @override
  double? get difference => null;
}

class BalanceCheckMatch extends BalanceCheckResult {
  const BalanceCheckMatch({required this.expected, required this.entered});

  @override
  final double expected;

  @override
  final double entered;

  @override
  double? get difference => 0;

  @override
  bool get isMatch => true;
}

class BalanceCheckMismatch extends BalanceCheckResult {
  const BalanceCheckMismatch({
    required this.expected,
    required this.entered,
    required this.difference,
  });

  @override
  final double expected;

  @override
  final double entered;

  @override
  final double difference;

  @override
  bool get isMatch => false;
}

/// Parses a free-form amount string (supports comma or dot decimals).
double? parseBalanceAmount(String? text) {
  if (text == null) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  return double.tryParse(normalized);
}

/// Compares [enteredText] against [expected], using [tolerance] for equality.
BalanceCheckResult compareBalances({
  required double expected,
  required String? enteredText,
  double tolerance = kAmountEqualityTolerance,
}) {
  final entered = parseBalanceAmount(enteredText);
  if (enteredText == null || enteredText.trim().isEmpty) {
    return BalanceCheckNoInput(expected);
  }
  if (entered == null) {
    return BalanceCheckInvalidInput(expected);
  }
  final difference = entered - expected;
  if (difference.abs() <= tolerance) {
    return BalanceCheckMatch(expected: expected, entered: entered);
  }
  return BalanceCheckMismatch(
    expected: expected,
    entered: entered,
    difference: difference,
  );
}

/// Two amounts are the same when they agree to the cent.
///
/// The statement matcher and the balance check both decide "same amount", and a
/// second copy of this number would let them drift apart silently.
const double kAmountEqualityTolerance = 0.005;
