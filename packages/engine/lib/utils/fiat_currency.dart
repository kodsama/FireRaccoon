import '../models/currency.dart';

/// ISO 4217-style fiat codes: exactly three uppercase Latin letters.
final RegExp standardFiatCurrencyCodePattern = RegExp(r'^[A-Z]{3}$');

/// Skrooge2Firefly share currencies append a base-36 code in brackets, e.g.
/// `SEB Världenfond [007]`.
final RegExp skroogeShareCurrencyNameSuffix = RegExp(r'\[[0-9A-Za-z]{3}\]$');

/// Base-36 share codes from the old fund/stock-account import (digit present).
final RegExp skroogeShareBase36CodePattern = RegExp(r'^[0-9A-Z]{3}$');

/// Common ISO 4217 fiat codes plus crypto used by cash accounts (e.g. Kraken).
///
/// Share tickers like FDJ/NAS/HM look like 3-letter ISO codes, so the picker
/// uses this allowlist instead of "any A-Z{3}".
const Set<String> selectableCurrencyCodeAllowlist = {
  // Common fiat
  'AED', 'AFN', 'ALL', 'AMD', 'ANG', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN', 'BAM',
  'BBD', 'BDT', 'BGN', 'BHD', 'BIF', 'BMD', 'BND', 'BOB', 'BRL', 'BSD', 'BTN',
  'BWP', 'BYN', 'BZD', 'CAD', 'CDF', 'CHF', 'CLP', 'CNY', 'COP', 'CRC', 'CUP',
  'CVE', 'CZK', 'DJF', 'DKK', 'DOP', 'DZD', 'EGP', 'ERN', 'ETB', 'EUR', 'FJD',
  'FKP', 'GBP', 'GEL', 'GHS', 'GIP', 'GMD', 'GNF', 'GTQ', 'GYD', 'HKD', 'HNL',
  'HRK', 'HTG', 'HUF', 'IDR', 'ILS', 'INR', 'IQD', 'IRR', 'ISK', 'JMD', 'JOD',
  'JPY', 'KES', 'KGS', 'KHR', 'KMF', 'KPW', 'KRW', 'KWD', 'KYD', 'KZT', 'LAK',
  'LBP', 'LKR', 'LRD', 'LSL', 'LYD', 'MAD', 'MDL', 'MGA', 'MKD', 'MMK', 'MNT',
  'MOP', 'MRU', 'MUR', 'MVR', 'MWK', 'MXN', 'MYR', 'MZN', 'NAD', 'NGN', 'NIO',
  'NOK', 'NPR', 'NZD', 'OMR', 'PAB', 'PEN', 'PGK', 'PHP', 'PKR', 'PLN', 'PYG',
  'QAR', 'RON', 'RSD', 'RUB', 'RWF', 'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD',
  'SHP', 'SLE', 'SOS', 'SRD', 'SSP', 'STN', 'SVC', 'SYP', 'SZL', 'THB', 'TJS',
  'TMT', 'TND', 'TOP', 'TRY', 'TTD', 'TWD', 'TZS', 'UAH', 'UGX', 'USD', 'UYU',
  'UZS', 'VES', 'VND', 'VUV', 'WST', 'XAF', 'XCD', 'XOF', 'XPF', 'YER', 'ZAR',
  'ZMW', 'ZWL',
  // Crypto used by real cash accounts (Kraken)
  'BTC', 'ETH', 'LTC', 'DOT', 'XLM', 'XMR', 'BCH',
};

/// Whether [code] looks like a standard fiat currency code (EUR, SEK, USD, …).
bool isStandardFiatCurrencyCode(String code) {
  return standardFiatCurrencyCodePattern.hasMatch(code);
}

bool _looksLikeSkroogeShareCode(String code) {
  if (!skroogeShareBase36CodePattern.hasMatch(code)) return false;
  // Old holding codes always include a digit (007, 00F, 01Z).
  return code.contains(RegExp(r'[0-9]'));
}

/// Enabled real currencies suitable for the primary-currency picker.
///
/// Uses an ISO+crypto allowlist so share tickers such as FDJ/NAS/HM (valid
/// A-Z{3} but not fiat) never appear. Also rejects Skrooge2Firefly holding
/// units (base-36 `007` / names ending with `[CODE]`).
bool isSelectableFiatCurrency(FireflyCurrency currency) {
  if (!currency.enabled) return false;
  final code = currency.code.trim().toUpperCase();
  if (!selectableCurrencyCodeAllowlist.contains(code)) return false;
  if (_looksLikeSkroogeShareCode(code)) return false;
  if (skroogeShareCurrencyNameSuffix.hasMatch(currency.name.trim())) {
    return false;
  }
  return true;
}
