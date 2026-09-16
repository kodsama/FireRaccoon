import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  test('a sum of legs rounds back to the money it is', () {
    const legs = [
      3850.00,
      133.14,
      326.50,
      120.44,
      157.20,
      42.00,
      370.00,
      77.50,
      382.16,
      63.24,
    ];
    final raw = legs.fold(0.0, (sum, leg) => sum + leg);

    expect(raw, isNot(5522.18));
    expect(roundMoney(raw), 5522.18);
  });

  test('a currency with no decimals rounds to whole units', () {
    expect(roundMoney(1234.49, decimals: 0), 1234);
    expect(roundMoney(1234.5, decimals: 0), 1235);
  });

  test('a three-decimal currency keeps its third decimal', () {
    // Rounding everything to cents would drop a real fils on the currencies
    // that carry three, so the places come from the currency, not a constant.
    expect(roundMoney(12.3456, decimals: 3), 12.346);
  });

  test('a real difference survives rounding', () {
    // The point is to drop float noise, not to swallow a one-cent error.
    expect(roundMoney(0.01), 0.01);
    expect(roundMoney(-0.01), -0.01);
  });

  test('what is not a number is handed back as it is', () {
    expect(roundMoney(double.nan).isNaN, isTrue);
    expect(roundMoney(double.infinity), double.infinity);
  });
}
