import 'package:fireracoon/fun_modes/fun_mode.dart';
import 'package:fireracoon/fun_modes/fun_mode_registry.dart';
import 'package:fireracoon/fun_modes/fun_mode_resolver.dart';
import 'package:fireracoon/fun_modes/fun_sticker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolver keeps explicit user mode over seasonal default', () {
    expect(
      FunModeResolver.resolve(FunMode.racoon, DateTime(2026, 12, 25)),
      FunMode.racoon,
    );
  });

  test('resolver auto-applies christmas in December when mode is none', () {
    expect(
      FunModeResolver.resolve(FunMode.none, DateTime(2026, 12, 10)),
      FunMode.christmas,
    );
  });

  test('resolver stays off outside december', () {
    expect(
      FunModeResolver.resolve(FunMode.none, DateTime(2026, 7, 6)),
      FunMode.none,
    );
  });

  test('registry defines stickers for every non-none mode', () {
    for (final mode in FunMode.values) {
      if (mode == FunMode.none) continue;
      final definition = FunModeRegistry.get(mode);
      expect(definition.stickers, isNotEmpty);
      for (final sticker in definition.stickers) {
        expect(FunModeRegistry.painterFor(sticker), isNotNull);
      }
    }
  });

  test('racoon mode keeps the standard sidebar logo', () {
    final racoon = FunModeRegistry.get(FunMode.racoon);
    final none = FunModeRegistry.get(FunMode.none);

    expect(racoon.logoAsset, none.logoAsset);
    expect(racoon.logoSizeMultiplier, none.logoSizeMultiplier);
  });

  test('registry maps birthday stickers to painters', () {
    expect(FunModeRegistry.painterFor(FunStickerId.balloon), isNotNull);
    expect(FunModeRegistry.painterFor(FunStickerId.santaHat), isNotNull);
  });
}
