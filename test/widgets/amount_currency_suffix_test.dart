import 'package:fireraccoon/theme/app_colors.dart';
import 'package:fireraccoon/theme/app_theme.dart';
import 'package:fireraccoon/widgets/amount_currency_suffix.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sek = FireflyCurrency(
  id: '1',
  code: 'SEK',
  name: 'Swedish krona',
  symbol: 'kr',
);
const _eur = FireflyCurrency(id: '2', code: 'EUR', name: 'Euro', symbol: '€');

Future<void> _pump(
  WidgetTester tester, {
  required String code,
  List<FireflyCurrency> currencies = const [_sek, _eur],
  ValueChanged<String>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.buildTheme(
        false,
        AppAccent.fromType(AccentColorType.orange),
      ),
      home: Scaffold(
        body: TextField(
          decoration: AmountCurrencySuffix.decorate(
            const InputDecoration(labelText: 'Amount'),
            AmountCurrencySuffix(
              code: code,
              currencies: currencies,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the code sits in the field the figure is in', (tester) async {
    await _pump(tester, code: 'SEK', onChanged: (_) {});

    expect(find.text('SEK'), findsOneWidget);
  });

  testWidgets('the menu says which currency the code is', (tester) async {
    await _pump(tester, code: 'SEK', onChanged: (_) {});

    await tester.tap(find.text('SEK'));
    await tester.pumpAndSettle();

    // Three letters fit in the field; the menu has room to say what they mean.
    expect(find.text('Euro (€)'), findsOneWidget);
    expect(find.text('Swedish krona (kr)'), findsOneWidget);
  });

  testWidgets('picking one reports the code', (tester) async {
    String? picked;
    await _pump(tester, code: 'SEK', onChanged: (code) => picked = code);

    await tester.tap(find.text('SEK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Euro (€)').last);
    await tester.pumpAndSettle();

    expect(picked, 'EUR');
  });

  testWidgets('a currency the ledger no longer enables is still shown', (
    tester,
  ) async {
    // The field would otherwise hold a value its own picker cannot show, which
    // is an assertion rather than a blank.
    await _pump(
      tester,
      code: 'DKK',
      currencies: const [_sek, _eur],
      onChanged: (_) {},
    );

    expect(find.text('DKK'), findsOneWidget);
  });

  testWidgets('with nothing to change it to, it is a label', (tester) async {
    await _pump(tester, code: 'SEK', currencies: const [_sek]);

    expect(find.text('SEK'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
  });
}
