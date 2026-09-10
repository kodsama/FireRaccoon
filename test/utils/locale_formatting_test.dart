import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fireraccoon/utils/locale_formatting.dart';

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

    test('a symbol made of letters is separated from the amount', () {
      // kr16,880.00 runs together and reads as one token.
      expect(formatting.formatMoney(16880, 'kr'), 'kr 16,880.00');
      expect(formatting.formatMoney(-3120, 'kr'), '-kr 3,120.00');
      expect(formatting.formatSignedMoney(5, 'kr'), '+kr 5.00');
      expect(formatting.formatMoney(1, 'SEK'), 'SEK 1.00');
      expect(formatting.formatMoney(1, 'Kč'), 'Kč 1.00');
    });

    test('a punctuation symbol is not', () {
      // Nobody writes € 12.00.
      expect(formatting.formatMoney(12, '€'), '€12.00');
      expect(formatting.formatMoney(12, '\$'), '\$12.00');
      expect(formatting.formatMoney(12, '£'), '£12.00');
      expect(formatting.formatMoney(12, '¥'), '¥12.00');
    });

    test('an absent symbol adds no stray space', () {
      expect(formatting.formatMoney(12, ''), '12.00');
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
