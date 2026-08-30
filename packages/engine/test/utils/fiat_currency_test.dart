import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:test/test.dart';

void main() {
  group('isStandardFiatCurrencyCode', () {
    test('accepts ISO-style fiat codes', () {
      expect(isStandardFiatCurrencyCode('EUR'), isTrue);
      expect(isStandardFiatCurrencyCode('SEK'), isTrue);
      expect(isStandardFiatCurrencyCode('USD'), isTrue);
    });

    test('rejects Skrooge base-36 share codes', () {
      expect(isStandardFiatCurrencyCode('007'), isFalse);
      expect(isStandardFiatCurrencyCode('00F'), isFalse);
    });
  });

  group('isSelectableFiatCurrency', () {
    test('accepts enabled standard fiat currencies', () {
      const currency = FireflyCurrency(
        id: '1',
        code: 'SEK',
        name: 'Swedish Krona',
        symbol: 'kr',
      );

      expect(isSelectableFiatCurrency(currency), isTrue);
    });

    test('accepts crypto used by cash accounts', () {
      const eth = FireflyCurrency(
        id: '1',
        code: 'ETH',
        name: 'Ethereum',
        symbol: 'Ξ',
      );
      expect(isSelectableFiatCurrency(eth), isTrue);
    });

    test('rejects Skrooge share currencies by code and name', () {
      const byCode = FireflyCurrency(
        id: '1',
        code: '007',
        name: 'SEB Världenfond',
        symbol: '007',
      );
      const byName = FireflyCurrency(
        id: '2',
        code: 'ABC',
        name: 'SEB Världenfond [ABC]',
        symbol: 'ABC',
      );

      expect(isSelectableFiatCurrency(byCode), isFalse);
      expect(isSelectableFiatCurrency(byName), isFalse);
    });

    test('rejects stock tickers that look like ISO codes', () {
      for (final code in ['FDJ', 'NAS', 'AIR', 'JD', 'HM']) {
        final currency = FireflyCurrency(
          id: '1',
          code: code,
          name: 'Some company $code',
          symbol: code,
        );
        expect(
          isSelectableFiatCurrency(currency),
          isFalse,
          reason: '$code must not appear in the picker',
        );
      }
    });

    test('rejects padded short-ticker currencies', () {
      const xhm = FireflyCurrency(
        id: '1',
        code: 'XHM',
        name: 'H&M',
        symbol: 'HM',
      );
      expect(isSelectableFiatCurrency(xhm), isFalse);
    });

    test('rejects disabled currencies', () {
      const currency = FireflyCurrency(
        id: '1',
        code: 'EUR',
        name: 'Euro',
        symbol: '€',
        enabled: false,
      );

      expect(isSelectableFiatCurrency(currency), isFalse);
    });
  });
}
