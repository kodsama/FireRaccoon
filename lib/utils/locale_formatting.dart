import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/locale_provider.dart';

/// Locale-aware formatting for numbers, currency, and dates.
class LocaleFormatting {
  LocaleFormatting(this.locale);

  final Locale locale;

  // ICU pattern parsing is expensive (notably on web); formatters are cached
  // per instance, which is safe because localeFormattingProvider creates one
  // instance per locale and formatting happens on the UI thread.
  final Map<int, NumberFormat> _decimalFormats = {};
  final Map<String, DateFormat> _dateFormats = {};

  String get _localeTag => locale.toString();

  NumberFormat _decimal({int? decimalDigits}) {
    return _decimalFormats.putIfAbsent(decimalDigits ?? -1, () {
      if (decimalDigits != null) {
        return NumberFormat.decimalPatternDigits(
          locale: _localeTag,
          decimalDigits: decimalDigits,
        );
      }
      return NumberFormat.decimalPattern(_localeTag);
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
    return _date('MMMM', () => DateFormat.MMMM(_localeTag)).format(date);
  }

  String formatShortMonth(DateTime date) {
    return _date('MMM', () => DateFormat.MMM(_localeTag)).format(date);
  }

  String formatMonthYear(DateTime date) {
    return _date('yMMMM', () => DateFormat.yMMMM(_localeTag)).format(date);
  }

  String formatMediumDate(DateTime date) {
    return _date('yMMMd', () => DateFormat.yMMMd(_localeTag)).format(date);
  }

  String formatDateTime(DateTime date) {
    return _date(
      'yMMMd_jm',
      () => DateFormat.yMMMd(_localeTag).add_jm(),
    ).format(date);
  }

  String formatIsoDate(DateTime date) {
    return _date(
      'yyyy-MM-dd',
      () => DateFormat('yyyy-MM-dd', _localeTag),
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
  final appLocale = ref.watch(localeProvider);
  return LocaleFormatting(appLocale.locale);
});
