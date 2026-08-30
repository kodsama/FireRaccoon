import 'package:fireraccoon/providers/locale_provider.dart';
import 'package:fireraccoon/providers/theme_provider.dart';
import 'package:fireraccoon/utils/locale_formatting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  test('numbers and dates follow the language until told otherwise', () async {
    final container = await containerWith({'locale': 'fr'});

    expect(container.read(numberLocaleProvider), isNull);
    expect(container.read(dateLocaleProvider), isNull);
    expect(container.read(effectiveNumberLocaleProvider).languageCode, 'fr');
    expect(container.read(effectiveDateLocaleProvider).languageCode, 'fr');
  });

  test('each convention is chosen separately from the language', () async {
    // The combination the setting exists for: read it in English, write
    // amounts the French way, write dates the American way. No single locale
    // says that.
    final container = await containerWith({
      'locale': 'en',
      'numberLocale': 'fr_FR',
      'dateLocale': 'en_US',
    });

    final format = container.read(localeFormattingProvider);

    // French groups with a narrow no-break space and separates decimals with a
    // comma, which is exactly the distinction an English interface would
    // otherwise impose the American way.
    expect(format.formatNumber(1234.56), '1 234,56');
    expect(format.formatMediumDate(DateTime(2026, 3, 4)), 'Mar 4, 2026');
  });

  test('a date locale outside the six the app speaks still formats', () async {
    // flutter_localizations only loads symbols for the languages it ships, so
    // this throws unless every locale's date symbols are initialized.
    final container = await containerWith({
      'locale': 'en',
      'dateLocale': 'de_DE',
    });

    final format = container.read(localeFormattingProvider);

    expect(format.formatMediumDate(DateTime(2026, 3, 4)), contains('2026'));
    expect(format.formatMonth(DateTime(2026, 3, 4)), 'März');
  });

  test(
    'a choice is remembered, and clearing goes back to the language',
    () async {
      final container = await containerWith({'locale': 'en'});
      final prefs = container.read(sharedPreferencesProvider);

      await container
          .read(numberLocaleProvider.notifier)
          .set(const Locale('sv', 'SE'));
      expect(prefs.getString('numberLocale'), 'sv_SE');
      expect(container.read(effectiveNumberLocaleProvider).toString(), 'sv_SE');

      await container.read(numberLocaleProvider.notifier).set(null);
      expect(prefs.getString('numberLocale'), isNull);
      expect(container.read(effectiveNumberLocaleProvider).languageCode, 'en');
    },
  );

  test('a tag nobody offers is not trusted to format anything', () {
    // A hand-edited backup could name a locale with no data behind it, and
    // formatting against one throws rather than falling back.
    expect(parseLocaleTag('xx_YY'), isNull);
    expect(parseLocaleTag(''), isNull);
    expect(parseLocaleTag('   '), isNull);
    expect(parseLocaleTag(null), isNull);
    // A bare language names no region, and the list offers none, so there is
    // nothing to format against.
    expect(parseLocaleTag('fr'), isNull);
    expect(parseLocaleTag('fr-FR').toString(), 'fr_FR');
    expect(parseLocaleTag('sv_SE').toString(), 'sv_SE');
    expect(formatLocaleTag(const Locale('en', 'GB')), 'en_GB');
  });
}
