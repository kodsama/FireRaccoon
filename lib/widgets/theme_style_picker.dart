import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/theme_provider.dart';
import '../providers/undo_history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_palette.dart';
import 'tooltip_helpers.dart';

void showThemeStylePicker(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => const ThemeStylePickerSheet(),
  );
}

class ThemeStylePickerSheet extends ConsumerStatefulWidget {
  const ThemeStylePickerSheet({super.key});

  @override
  ConsumerState<ThemeStylePickerSheet> createState() =>
      _ThemeStylePickerSheetState();
}

class _ThemeStylePickerSheetState extends ConsumerState<ThemeStylePickerSheet> {
  late ThemeMode _previewMode;
  late ThemePaletteType _previewPalette;
  late AccentColorType _previewAccent;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(themeProvider);
    _previewMode = settings.themeMode == ThemeMode.system
        ? ThemeMode.light
        : settings.themeMode;
    _previewPalette = settings.paletteType;
    _previewAccent = settings.accentType;
  }

  void _applyPreview() {
    final previous = ref.read(themeProvider);
    ref
        .read(themeProvider.notifier)
        .applyStyle(
          themeMode: _previewMode,
          paletteType: _previewPalette,
          accentType: _previewAccent,
        );
    final next = ref.read(themeProvider);
    if (previous.themeMode != next.themeMode) {
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Theme mode changed',
            details:
                'Theme mode: ${previous.themeMode.name} -> ${next.themeMode.name}',
            type: UndoActionType.themeMode,
            undoPayload: {'mode': previous.themeMode.name},
            redoPayload: {'mode': next.themeMode.name},
          );
    }
    if (previous.paletteType != next.paletteType) {
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Theme palette changed',
            details:
                'Theme palette: ${previous.paletteType.name} -> ${next.paletteType.name}',
            type: UndoActionType.themePalette,
            undoPayload: {'palette': previous.paletteType.name},
            redoPayload: {'palette': next.paletteType.name},
          );
    }
    if (previous.accentType != next.accentType) {
      ref
          .read(undoHistoryProvider.notifier)
          .record(
            title: 'Theme accent changed',
            details:
                'Theme accent: ${previous.accentType.name} -> ${next.accentType.name}',
            type: UndoActionType.themeAccent,
            undoPayload: {'accent': previous.accentType.name},
            redoPayload: {'accent': next.accentType.name},
          );
    }
  }

  void _setPalette(ThemePaletteType palette) {
    setState(() {
      _previewPalette = palette;
      _previewAccent = ThemePalette.normalizeAccent(palette, _previewAccent);
    });
    _applyPreview();
  }

  void _setAccent(AccentColorType accent) {
    setState(() => _previewAccent = accent);
    _applyPreview();
  }

  void _setBrightness(bool isDark) {
    setState(() => _previewMode = isDark ? ThemeMode.dark : ThemeMode.light);
    _applyPreview();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = _previewMode == ThemeMode.dark;
    final previewTheme = AppTheme.buildFromSettings(
      isDark: isDark,
      palette: _previewPalette,
      accentType: _previewAccent,
    );

    return Theme(
      data: previewTheme,
      child: Builder(
        builder: (context) {
          final colors = context.colors;
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.9,
              child: Material(
                color: colors.surface,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.themeStyle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.themeStyleSubtitle,
                      style: TextStyle(color: colors.text3, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(l10n.themeBrightness),
                    const SizedBox(height: 10),
                    _BrightnessToggle(
                      isDark: isDark,
                      onChanged: _setBrightness,
                      lightLabel: l10n.themeLight,
                      darkLabel: l10n.themeDark,
                      lightTooltip: l10n.tooltipThemeLight,
                      darkTooltip: l10n.tooltipThemeDark,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(l10n.themePalette),
                    const SizedBox(height: 10),
                    _PaletteSelector(
                      selected: _previewPalette,
                      onSelected: _setPalette,
                      classicLabel: l10n.paletteClassic,
                      spectrumLabel: l10n.paletteSpectrum,
                      raccoonLabel: l10n.paletteRaccoon,
                      classicTooltip: l10n.tooltipThemePaletteClassic,
                      spectrumTooltip: l10n.tooltipThemePaletteSpectrum,
                      raccoonTooltip: l10n.tooltipThemePaletteRaccoon,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(l10n.themeAccentColor),
                    const SizedBox(height: 10),
                    withTooltip(
                      l10n.tooltipThemeAccent,
                      _AccentSelector(
                        palette: _previewPalette,
                        selected: _previewAccent,
                        onSelected: _setAccent,
                        labelFor: _accentLabel,
                        tooltipFor: (type) =>
                            l10n.tooltipThemeAccentOption(_accentLabel(type)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(l10n.themePreview),
                    const SizedBox(height: 10),
                    const _ThemePreview(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: withTooltip(
                        l10n.tooltipThemeDone,
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.accent.acc,
                            foregroundColor: colors.accent.onAcc,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(l10n.done),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _accentLabel(AccentColorType type) {
    final l10n = context.l10n;
    return switch (type) {
      AccentColorType.green => l10n.accentGreen,
      AccentColorType.teal => l10n.accentTeal,
      AccentColorType.blue => l10n.accentBlue,
      AccentColorType.orange => l10n.accentOrange,
      AccentColorType.red => l10n.accentRed,
      AccentColorType.violet => l10n.accentViolet,
      AccentColorType.lime => l10n.accentLime,
      AccentColorType.sky => l10n.accentSky,
      AccentColorType.charcoal => l10n.accentCharcoal,
      AccentColorType.silver => l10n.accentSilver,
      AccentColorType.tan => l10n.accentTan,
      AccentColorType.amber => l10n.accentAmber,
      AccentColorType.slate => l10n.accentSlate,
      AccentColorType.midnight => l10n.accentMidnight,
      AccentColorType.smoke => l10n.accentSmoke,
      AccentColorType.pearl => l10n.accentPearl,
    };
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 0.06,
        fontWeight: FontWeight.w600,
        color: context.colors.text3,
      ),
    );
  }
}

class _BrightnessToggle extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;
  final String lightLabel;
  final String darkLabel;
  final String lightTooltip;
  final String darkTooltip;

  const _BrightnessToggle({
    required this.isDark,
    required this.onChanged,
    required this.lightLabel,
    required this.darkLabel,
    required this.lightTooltip,
    required this.darkTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: withTooltip(
              lightTooltip,
              _ToggleOption(
                icon: Icons.light_mode_outlined,
                label: lightLabel,
                selected: !isDark,
                onTap: () => onChanged(false),
              ),
            ),
          ),
          Expanded(
            child: withTooltip(
              darkTooltip,
              _ToggleOption(
                icon: Icons.dark_mode_outlined,
                label: darkLabel,
                selected: isDark,
                onTap: () => onChanged(true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.overlay.withValues(alpha: 0.08),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? colors.text : colors.text3),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? colors.text : colors.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteSelector extends StatelessWidget {
  final ThemePaletteType selected;
  final ValueChanged<ThemePaletteType> onSelected;
  final String classicLabel;
  final String spectrumLabel;
  final String raccoonLabel;
  final String classicTooltip;
  final String spectrumTooltip;
  final String raccoonTooltip;

  const _PaletteSelector({
    required this.selected,
    required this.onSelected,
    required this.classicLabel,
    required this.spectrumLabel,
    required this.raccoonLabel,
    required this.classicTooltip,
    required this.spectrumTooltip,
    required this.raccoonTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: withTooltip(
            classicTooltip,
            _PaletteCard(
              label: classicLabel,
              colors: const [
                Color(0xFF1F8A5B),
                Color(0xFF028A93),
                Color(0xFF2A6FDB),
              ],
              selected: selected == ThemePaletteType.classic,
              onTap: () => onSelected(ThemePaletteType.classic),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: withTooltip(
            spectrumTooltip,
            _PaletteCard(
              label: spectrumLabel,
              colors: ThemePaletteTypeX.spectrumCategoryRamp.take(3).toList(),
              selected: selected == ThemePaletteType.spectrum,
              onTap: () => onSelected(ThemePaletteType.spectrum),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: withTooltip(
            raccoonTooltip,
            _PaletteCard(
              label: raccoonLabel,
              colors: ThemePaletteTypeX.raccoonCategoryRamp.take(3).toList(),
              selected: selected == ThemePaletteType.raccoon,
              onTap: () => onSelected(ThemePaletteType.raccoon),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteCard({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: themeColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? themeColors.accent.acc : themeColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: colors
                  .map(
                    (c) => Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? themeColors.text : themeColors.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentSelector extends StatelessWidget {
  final ThemePaletteType palette;
  final AccentColorType selected;
  final ValueChanged<AccentColorType> onSelected;
  final String Function(AccentColorType) labelFor;
  final String Function(AccentColorType) tooltipFor;

  const _AccentSelector({
    required this.palette,
    required this.selected,
    required this.onSelected,
    required this.labelFor,
    required this.tooltipFor,
  });

  @override
  Widget build(BuildContext context) {
    final options = palette.accentOptions;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((type) {
        final accent = AppAccent.fromType(type);
        final isSelected = type == selected;
        return withTooltip(
          tooltipFor(type),
          GestureDetector(
            onTap: () => onSelected(type),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.acc,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? context.colors.text
                          : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: accent.acc.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  labelFor(type),
                  style: TextStyle(fontSize: 10.5, color: context.colors.text2),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return SizedBox(
      height: 168,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 88,
                color: colors.accent.deep,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colors.accent.hi,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appTitle,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PreviewNavItem(
                      colors: colors,
                      active: true,
                      label: l10n.navDashboardShort,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: colors.pageBg,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.navDashboard,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _PreviewKpi(
                                colors: colors,
                                label: l10n.income,
                                value: '\$4,200',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PreviewKpi(
                                colors: colors,
                                label: l10n.spending,
                                value: '\$2,850',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(6, (i) {
                              final h = [14.0, 26.0, 18.0, 32.0, 22.0, 28.0][i];
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      height: h,
                                      decoration: BoxDecoration(
                                        color:
                                            colors.categoryRamp[i %
                                                colors.categoryRamp.length],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewNavItem extends StatelessWidget {
  final AppColors colors;
  final bool active;
  final String label;

  const _PreviewNavItem({
    required this.colors,
    required this.active,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: active ? colors.accent.acc : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : colors.sidebarMuted,
        ),
      ),
    );
  }
}

class _PreviewKpi extends StatelessWidget {
  final AppColors colors;
  final String label;
  final String value;

  const _PreviewKpi({
    required this.colors,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 8, color: colors.text3)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Roboto Slab',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

String themeStyleSummary(
  BuildContext context, {
  required ThemeMode mode,
  required ThemePaletteType palette,
  required AccentColorType accent,
}) {
  final l10n = context.l10n;
  final brightness = mode == ThemeMode.dark
      ? l10n.themeDark
      : mode == ThemeMode.light
      ? l10n.themeLight
      : l10n.systemDefault;
  final paletteName = switch (palette) {
    ThemePaletteType.classic => l10n.paletteClassic,
    ThemePaletteType.spectrum => l10n.paletteSpectrum,
    ThemePaletteType.raccoon => l10n.paletteRaccoon,
  };
  final accentName = switch (accent) {
    AccentColorType.green => l10n.accentGreen,
    AccentColorType.teal => l10n.accentTeal,
    AccentColorType.blue => l10n.accentBlue,
    AccentColorType.orange => l10n.accentOrange,
    AccentColorType.red => l10n.accentRed,
    AccentColorType.violet => l10n.accentViolet,
    AccentColorType.lime => l10n.accentLime,
    AccentColorType.sky => l10n.accentSky,
    AccentColorType.charcoal => l10n.accentCharcoal,
    AccentColorType.silver => l10n.accentSilver,
    AccentColorType.tan => l10n.accentTan,
    AccentColorType.amber => l10n.accentAmber,
    AccentColorType.slate => l10n.accentSlate,
    AccentColorType.midnight => l10n.accentMidnight,
    AccentColorType.smoke => l10n.accentSmoke,
    AccentColorType.pearl => l10n.accentPearl,
  };
  return '$paletteName · $accentName · $brightness';
}
