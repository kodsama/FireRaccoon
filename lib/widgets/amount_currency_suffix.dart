import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/currency.dart';
import '../theme/app_theme.dart';

/// The currency an amount is in, small enough to sit inside the amount field.
///
/// A figure with no currency beside it reads as whatever the person assumes,
/// and this ledger holds several. It is shown where the figure is and changed
/// in the same place, so the two cannot be read apart.
class AmountCurrencySuffix extends StatelessWidget {
  const AmountCurrencySuffix({
    super.key,
    required this.code,
    required this.currencies,
    this.onChanged,
  });

  final String code;

  /// The enabled currencies. Empty while they are still being read, which
  /// leaves the code as a label rather than an empty picker.
  final List<FireflyCurrency> currencies;

  /// Null leaves it as a label, for a figure whose currency is not editable.
  final ValueChanged<String>? onChanged;

  /// The field decoration this belongs in, without the padding an icon slot
  /// would otherwise reserve for a 48-pixel tap target.
  static InputDecoration decorate(InputDecoration decoration, Widget suffix) =>
      decoration.copyWith(
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colors.text2,
    );

    // A currency the ledger has since disabled still has to be showable, or
    // the field would hold a value its own picker cannot represent.
    final known = [for (final currency in currencies) currency.code];
    final codes = known.contains(code) ? known : [code, ...known];

    if (onChanged == null || codes.length < 2) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, right: 10),
        child: Text(code, style: style),
      );
    }

    String label(String wanted) {
      final currency = currencies
          .where((currency) => currency.code == wanted)
          .firstOrNull;
      return currency == null
          ? wanted
          : '${currency.name} (${currency.symbol})';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: code,
          isDense: true,
          style: style,
          borderRadius: BorderRadius.circular(8),
          icon: Icon(LucideIcons.chevronDown, size: 12, color: colors.text3),
          // The button shows the code, where there is room for three letters;
          // the menu it opens says which currency that is.
          selectedItemBuilder: (context) => [
            for (final wanted in codes)
              Align(
                alignment: Alignment.centerRight,
                child: Text(wanted, style: style),
              ),
          ],
          items: [
            for (final wanted in codes)
              DropdownMenuItem(value: wanted, child: Text(label(wanted))),
          ],
          onChanged: (value) {
            if (value != null) onChanged!(value);
          },
        ),
      ),
    );
  }
}
