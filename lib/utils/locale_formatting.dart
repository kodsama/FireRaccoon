import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/locale_provider.dart';

/// Locale-aware formatting for numbers, currency, and dates.
///
/// Numbers and dates carry their own locale because the conventions are chosen
/// separately from the interface language: reading the app in English while
/// writing amounts the French way and dates the American way is a combination
/// no single locale expresses.
class LocaleFormatting {
  /// One locale for everything, which is what a caller wants when it has no
  /// preference to honour.
  LocaleFormatting(Locale locale) : numberLocale = locale, dateLocale = locale;

  LocaleFormatting.split({
    required this.numberLocale,
    required this.dateLocale,
  });

  final Locale numberLocale;
  final Locale dateLocale;

  // ICU pattern parsing is expensive (notably on web); formatters are cached
  // per instance, which is safe because localeFormattingProvider creates one
  // instance per pair of locales and formatting happens on the UI thread.
  final Map<int, NumberFormat> _decimalFormats = {};
  final Map<String, DateFormat> _dateFormats = {};

  String get _numberTag => numberLocale.toString();
  String get _dateTag => dateLocale.toString();

  NumberFormat _decimal({required int decimalDigits}) {
    return _decimalFormats.putIfAbsent(decimalDigits, () {
      return NumberFormat.decimalPatternDigits(
        locale: _numberTag,
        decimalDigits: decimalDigits,
      );
    });
  }

  DateFormat _date(String key, DateFormat Function() create) =>
      _dateFormats.putIfAbsent(key, create);

  String formatNumber(double value, {int decimalDigits = 2}) {
    return _decimal(decimalDigits: decimalDigits).format(value);
  }

  String formatPercent(double value, {int decimalDigits = 1}) {
    return _decimal(decimalDigits: decimalDigits).format(value);
  }

  /// Formats a monetary amount with the given symbol prefix (app convention).
  String formatMoney(double amount, String symbol, {int decimalDigits = 2}) {
    final formatted = formatNumber(amount.abs(), decimalDigits: decimalDigits);
    final sign = amount < 0 ? '-' : '';
    return '$sign$symbol$formatted';
  }

  String formatSignedMoney(
    double amount,
    String symbol, {
    int decimalDigits = 2,
  }) {
    final sign = amount >= 0 ? '+' : '-';
    return '$sign$symbol${formatNumber(amount.abs(), decimalDigits: decimalDigits)}';
  }

  String formatMonth(DateTime date) {
    return _date('MMMM', () => DateFormat.MMMM(_dateTag)).format(date);
  }

  String formatShortMonth(DateTime date) {
    return _date('MMM', () => DateFormat.MMM(_dateTag)).format(date);
  }

  String formatMonthYear(DateTime date) {
    return _date('yMMMM', () => DateFormat.yMMMM(_dateTag)).format(date);
  }

  String formatMediumDate(DateTime date) {
    return _date('yMMMd', () => DateFormat.yMMMd(_dateTag)).format(date);
  }

  String formatDateTime(DateTime date) {
    return _date(
      'yMMMd_jm',
      () => DateFormat.yMMMd(_dateTag).add_jm(),
    ).format(date);
  }

  String formatIsoDate(DateTime date) {
    return _date(
      'yyyy-MM-dd',
      () => DateFormat('yyyy-MM-dd', _dateTag),
    ).format(date);
  }

  String formatDateRange(
    DateTime? from,
    DateTime? to, {
    required String ellipsis,
    required String separator,
  }) {
    final fromLabel = from != null ? formatIsoDate(from) : ellipsis;
    final toLabel = to != null ? formatIsoDate(to) : ellipsis;
    return '$fromLabel $separator $toLabel';
  }
}

final localeFormattingProvider = Provider<LocaleFormatting>((ref) {
  return LocaleFormatting.split(
    numberLocale: ref.watch(effectiveNumberLocaleProvider),
    dateLocale: ref.watch(effectiveDateLocaleProvider),
  );
});
