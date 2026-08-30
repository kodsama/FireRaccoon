import 'package:fireraccoon/l10n/app_localizations.dart';
import 'package:fireraccoon/utils/display_labels.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('displayLabelOrUnknown falls back for empty categories', (
    tester,
  ) async {
    late AppLocalizations l10n;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(displayLabelOrUnknown('', l10n), 'Unknown');
    expect(displayLabelOrUnknown('  ', l10n), 'Unknown');
    expect(displayLabelOrUnknown('Food', l10n), 'Food');
    expect(categoryGroupKey('  Food  '), 'Food');
    final transaction = Transaction(
      id: '1',
      type: 'withdrawal',
      date: DateTime(2026, 1, 1),
      amount: 10,
      description: 'Test',
      sourceName: 'A',
      destinationName: 'B',
      categoryName: '',
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    expect(transaction.displayCategory(l10n), 'Unknown');
    expect(transaction.displayTitle(), 'Test');
    expect(
      transaction.copyWith(groupTitle: ' Split purchase ').displayTitle(),
      'Split purchase',
    );
    expect(
      transaction
          .copyWith(
            splits: [
              transaction.copyWith(categoryName: ''),
              transaction.copyWith(categoryName: '  '),
            ],
          )
          .displayCategorySummary(l10n),
      'Unknown',
    );
    expect(
      transaction
          .copyWith(
            splits: [
              transaction.copyWith(categoryName: 'Food'),
              transaction.copyWith(categoryName: ' Food '),
            ],
          )
          .displayCategorySummary(l10n),
      'Food',
    );
    expect(
      transaction
          .copyWith(
            splits: [
              transaction.copyWith(categoryName: 'Food'),
              transaction.copyWith(categoryName: 'Travel'),
            ],
          )
          .displayCategorySummary(l10n),
      '2 categories',
    );
  });
}
