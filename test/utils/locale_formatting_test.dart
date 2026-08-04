import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireracoon/utils/locale_formatting.dart';

void main() {
  group('LocaleFormatting', () {
    final formatting = LocaleFormatting(const Locale('en'));

    test('formatNumber uses locale decimal pattern', () {
      expect(formatting.formatNumber(1234.5), '1,234.50');
    });

    test('formatPercent formats with decimal digits', () {
      expect(formatting.formatPercent(12.34), '12.3');
    });

    test('formatMoney prefixes symbol and handles negatives', () {
      expect(formatting.formatMoney(-42.5, '€'), '-€42.50');
      expect(formatting.formatMoney(10, '\$'), '\$10.00');
    });

    test('formatSignedMoney includes explicit sign', () {
      expect(formatting.formatSignedMoney(5, '€'), '+€5.00');
      expect(formatting.formatSignedMoney(-5, '€'), '-€5.00');
    });

    test('formatMonth and short month labels', () {
      final date = DateTime(2026, 7, 6);
      expect(formatting.formatMonth(date), 'July');
      expect(formatting.formatShortMonth(date), 'Jul');
    });

    test('formatMonthYear and medium date', () {
      final date = DateTime(2026, 7, 6);
      expect(formatting.formatMonthYear(date), contains('2026'));
      expect(formatting.formatMonthYear(date), contains('July'));
      expect(formatting.formatMediumDate(date), contains('2026'));
    });

    test('formatMediumDate omits time that formatDateTime includes', () {
      final date = DateTime(2026, 6, 30, 22, 45);
      final medium = formatting.formatMediumDate(date);
      final withTime = formatting.formatDateTime(date);
      expect(medium, isNot(equals(withTime)));
      expect(medium, isNot(contains(':')));
      expect(withTime, contains(medium));
    });

    test('formatIsoDate uses yyyy-MM-dd', () {
      expect(formatting.formatIsoDate(DateTime(2026, 7, 6)), '2026-07-06');
    });

    test('formatDateRange handles open bounds', () {
      expect(
        formatting.formatDateRange(
          DateTime(2026, 1, 1),
          null,
          ellipsis: '…',
          separator: '→',
        ),
        '2026-01-01 → …',
      );
      expect(
        formatting.formatDateRange(
          null,
          DateTime(2026, 12, 31),
          ellipsis: '…',
          separator: '→',
        ),
        '… → 2026-12-31',
      );
    });
  });
}
