import 'fun_mode.dart';

/// Picks the active fun mode: explicit user choice wins over seasonal defaults.
class FunModeResolver {
  const FunModeResolver._();

  static FunMode resolve(FunMode userMode, [DateTime? now]) {
    if (userMode != FunMode.none) return userMode;

    final date = now ?? DateTime.now();
    if (date.month == 12) return FunMode.christmas;

    return FunMode.none;
  }
}
