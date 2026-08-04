import 'package:flutter/material.dart';

enum AccentColorType {
  green,
  teal,
  blue,
  orange,
  red,
  violet,
  lime,
  sky,
  charcoal,
  silver,
  tan,
  amber,
  slate,
  midnight,
  smoke,
  pearl,
}

class AppAccent {
  final Color acc;
  final Color strong;
  final Color deep;
  final Color hi;
  final Color hiOn;
  final Color onAcc = const Color(0xFFFFFFFF);

  const AppAccent({
    required this.acc,
    required this.strong,
    required this.deep,
    required this.hi,
    required this.hiOn,
  });

  static const green = AppAccent(
    acc: Color(0xFF1F8A5B),
    strong: Color(0xFF177049),
    deep: Color(0xFF103A2B),
    hi: Color(0xFFD4F5A6),
    hiOn: Color(0xFF0B3A26),
  );
  static const teal = AppAccent(
    acc: Color(0xFF028A93),
    strong: Color(0xFF037780),
    deep: Color(0xFF0B4650),
    hi: Color(0xFFE7FFC8),
    hiOn: Color(0xFF0B4650),
  );
  static const blue = AppAccent(
    acc: Color(0xFF2A6FDB),
    strong: Color(0xFF2159BD),
    deep: Color(0xFF132C4F),
    hi: Color(0xFFCFE3FF),
    hiOn: Color(0xFF0B2E63),
  );
  static const orange = AppAccent(
    acc: Color(0xFFE07B29),
    strong: Color(0xFFC4661A),
    deep: Color(0xFF3C2A18),
    hi: Color(0xFFFFE1BF),
    hiOn: Color(0xFF5C3208),
  );
  static const red = AppAccent(
    acc: Color(0xFFD64A4A),
    strong: Color(0xFFBB3A3A),
    deep: Color(0xFF3B1E1E),
    hi: Color(0xFFFFD9D9),
    hiOn: Color(0xFF5C1414),
  );
  static const violet = AppAccent(
    acc: Color(0xFF7A5AD6),
    strong: Color(0xFF6547BD),
    deep: Color(0xFF241C42),
    hi: Color(0xFFE4DBFF),
    hiOn: Color(0xFF2E1D63),
  );
  static const lime = AppAccent(
    acc: Color(0xFF84CC16),
    strong: Color(0xFF65A30D),
    deep: Color(0xFF365314),
    hi: Color(0xFFECFCCB),
    hiOn: Color(0xFF3F6212),
  );
  static const sky = AppAccent(
    acc: Color(0xFF38BDF8),
    strong: Color(0xFF0EA5E9),
    deep: Color(0xFF0C4A6E),
    hi: Color(0xFFE0F2FE),
    hiOn: Color(0xFF075985),
  );
  static const charcoal = AppAccent(
    acc: Color(0xFF525252),
    strong: Color(0xFF3D3D3D),
    deep: Color(0xFF262626),
    hi: Color(0xFFE0E0E0),
    hiOn: Color(0xFF262626),
  );
  static const silver = AppAccent(
    acc: Color(0xFF8C8C8C),
    strong: Color(0xFF737373),
    deep: Color(0xFF525252),
    hi: Color(0xFFF0F0F0),
    hiOn: Color(0xFF404040),
  );
  static const tan = AppAccent(
    acc: Color(0xFFB8956A),
    strong: Color(0xFF8B7355),
    deep: Color(0xFF3D3428),
    hi: Color(0xFFF5E6D3),
    hiOn: Color(0xFF4A3F2F),
  );
  static const amber = AppAccent(
    acc: Color(0xFFD97706),
    strong: Color(0xFFB45309),
    deep: Color(0xFF451A03),
    hi: Color(0xFFFEF3C7),
    hiOn: Color(0xFF78350F),
  );
  static const slate = AppAccent(
    acc: Color(0xFF707070),
    strong: Color(0xFF595959),
    deep: Color(0xFF333333),
    hi: Color(0xFFE8E8E8),
    hiOn: Color(0xFF333333),
  );
  static const midnight = AppAccent(
    acc: Color(0xFF404040),
    strong: Color(0xFF2B2B2B),
    deep: Color(0xFF1A1A1A),
    hi: Color(0xFFD0D0D0),
    hiOn: Color(0xFF1A1A1A),
  );
  static const smoke = AppAccent(
    acc: Color(0xFF666666),
    strong: Color(0xFF525252),
    deep: Color(0xFF333333),
    hi: Color(0xFFEBEBEB),
    hiOn: Color(0xFF333333),
  );
  static const pearl = AppAccent(
    acc: Color(0xFFCCCCCC),
    strong: Color(0xFFA3A3A3),
    deep: Color(0xFF666666),
    hi: Color(0xFFFAFAFA),
    hiOn: Color(0xFF666666),
  );

  static AppAccent fromType(AccentColorType type) {
    switch (type) {
      case AccentColorType.green:
        return green;
      case AccentColorType.teal:
        return teal;
      case AccentColorType.blue:
        return blue;
      case AccentColorType.orange:
        return orange;
      case AccentColorType.red:
        return red;
      case AccentColorType.violet:
        return violet;
      case AccentColorType.lime:
        return lime;
      case AccentColorType.sky:
        return sky;
      case AccentColorType.charcoal:
        return charcoal;
      case AccentColorType.silver:
        return silver;
      case AccentColorType.tan:
        return tan;
      case AccentColorType.amber:
        return amber;
      case AccentColorType.slate:
        return slate;
      case AccentColorType.midnight:
        return midnight;
      case AccentColorType.smoke:
        return smoke;
      case AccentColorType.pearl:
        return pearl;
    }
  }
}

class AppColors extends ThemeExtension<AppColors> {
  static const defaultSuccess = Color(0xFF33A76A);
  static const defaultWarning = Color(0xFFE0A93B);
  static const defaultDanger = Color(0xFFE05656);

  final bool isDark;

  final Color pageBg;
  final Color surface;
  final Color surface2;
  final Color sunken;
  final Color border;
  final Color divider;
  final Color text;
  final Color text2;
  final Color text3;
  final Color headerBg;
  final Color track;
  final Color trackStrong;
  final Color overlay;

  final AppAccent accent;

  // Status
  final Color success;
  final Color warning;
  final Color danger;

  final Color successSoft;
  final Color warningSoft;
  final Color dangerSoft;

  // Derived
  final Color panel2;
  final Color panelMuted;
  final Color sidebarMuted;
  final Color iconBg;
  final Color iconFg;
  final Color chartLine;
  final Color confidenceBandFill;
  final List<Color> categoryRamp;

  AppColors({
    required this.isDark,
    required this.pageBg,
    required this.surface,
    required this.surface2,
    required this.sunken,
    required this.border,
    required this.divider,
    required this.text,
    required this.text2,
    required this.text3,
    required this.headerBg,
    required this.track,
    required this.trackStrong,
    required this.overlay,
    required this.accent,
    List<Color>? categoryRamp,
    Color? success,
    Color? warning,
    Color? danger,
  }) : success = success ?? defaultSuccess,
       warning = warning ?? defaultWarning,
       danger = danger ?? defaultDanger,
       successSoft = isDark
           ? (success ?? defaultSuccess).withAlpha(46)
           : Color.lerp(success ?? defaultSuccess, Colors.white, 0.88)!,
       warningSoft = isDark
           ? (warning ?? defaultWarning).withAlpha(46)
           : Color.lerp(warning ?? defaultWarning, Colors.white, 0.88)!,
       dangerSoft = isDark
           ? (danger ?? defaultDanger).withAlpha(46)
           : Color.lerp(danger ?? defaultDanger, Colors.white, 0.88)!,
       panel2 = Color.lerp(accent.deep, Colors.white, 0.09)!,
       panelMuted = Color.lerp(accent.acc, Colors.white, 0.60)!,
       sidebarMuted = Color.lerp(accent.acc, Colors.white, 0.55)!,
       iconBg = isDark
           ? accent.acc.withAlpha(51)
           : Color.lerp(accent.acc, Colors.white, 0.86)!,
       iconFg = isDark
           ? Color.lerp(accent.acc, Colors.white, 0.32)!
           : accent.acc,
       chartLine = isDark
           ? Color.lerp(accent.acc, Colors.white, 0.18)!
           : accent.acc,
       confidenceBandFill = isDark
           ? accent.acc.withAlpha(61)
           : Color.lerp(accent.acc, Colors.white, 0.74)!,
       categoryRamp = categoryRamp ?? _defaultCategoryRamp(accent);

  static List<Color> _defaultCategoryRamp(AppAccent accent) => [
    accent.acc,
    Color.lerp(accent.acc, Colors.white, 0.30)!,
    Color.lerp(accent.acc, Colors.white, 0.54)!,
    Color.lerp(accent.acc, Colors.white, 0.74)!,
    Color.lerp(accent.acc, Colors.black, 0.30)!,
    Color.lerp(accent.acc, Colors.black, 0.52)!,
  ];

  factory AppColors.light(AppAccent accent) {
    return AppColors(
      isDark: false,
      pageBg: const Color(0xFFECF0F0),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFECF0F0),
      sunken: const Color(0xFFF6F8F8),
      border: const Color(0xFFDCE3E3),
      divider: const Color(0xFFECF0F0),
      text: const Color(0xFF14201F),
      text2: const Color(0xFF3F4C4B),
      text3: const Color(0xFF8A9797),
      headerBg: const Color(0xD8F6F8F8),
      track: const Color(0xFFECF0F0),
      trackStrong: const Color(0xFFC2CCCC),
      overlay: const Color(0x80061414),
      accent: accent,
    );
  }

  factory AppColors.dark(AppAccent accent) {
    return AppColors(
      isDark: true,
      pageBg: const Color(0xFF0E1516),
      surface: const Color(0xFF161E1D),
      surface2: const Color(0xFF0B1211),
      sunken: const Color(0xFF121A19),
      border: const Color(0xFF2A3432),
      divider: const Color(0xFF222B29),
      text: const Color(0xFFEAF1EF),
      text2: const Color(0xFFAEBCB9),
      text3: const Color(0xFF7C8A87),
      headerBg: const Color(0xD10E1516),
      track: const Color(0xFF232D2B),
      trackStrong: const Color(0xFF3A4644),
      overlay: const Color(0x99000000),
      accent: accent,
    );
  }

  @override
  AppColors copyWith({
    AppAccent? accent,
    List<Color>? categoryRamp,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    final nextAccent = accent ?? this.accent;
    return AppColors(
      isDark: isDark,
      pageBg: pageBg,
      surface: surface,
      surface2: surface2,
      sunken: sunken,
      border: border,
      divider: divider,
      text: text,
      text2: text2,
      text3: text3,
      headerBg: headerBg,
      track: track,
      trackStrong: trackStrong,
      overlay: overlay,
      accent: nextAccent,
      categoryRamp: categoryRamp ?? this.categoryRamp,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}
