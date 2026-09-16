import 'dart:math' as math;

/// Decimal places Firefly gives a currency that states none of its own.
const int defaultCurrencyDecimals = 2;

/// [value] rounded to [decimals], so a total made of binary floats reads as
/// the money it is.
///
/// Adding a dozen legs leaves a tail around 1e-12: a gap that is exactly zero
/// compares false against zero, and a payback whose legs sum to 5522.18 comes
/// back as 5522.1799999999985. A caller cannot tell that apart from a real
/// difference without a tolerance of its own, and a tolerance wide enough for
/// float noise is also wide enough to swallow a one-cent error. Rounding where
/// the sum is taken settles the comparison and the reading together.
///
/// Anything not finite is handed back untouched; there is no rounding of an
/// infinity or a NaN that means more than the value itself.
double roundMoney(double value, {int decimals = defaultCurrencyDecimals}) {
  if (!value.isFinite) return value;
  final factor = math.pow(10, decimals).toDouble();
  return (value * factor).roundToDouble() / factor;
}
