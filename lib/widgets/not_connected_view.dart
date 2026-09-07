import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'fun_decorated_surface.dart';

/// What a screen shows when a load failed.
///
/// Having no server connected is not a failure, so it does not get a failure's
/// treatment: it comes with its own screen, and [message] is only for the
/// things that really did go wrong.
class LoadFailureView extends StatelessWidget {
  const LoadFailureView({
    super.key,
    required this.error,
    required this.message,
    this.compact = false,
  });

  final Object error;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (error is FireflyNotConnectedException) {
      return NotConnectedView(compact: compact);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

/// What a screen shows when no Firefly III server is connected.
///
/// Not an error screen. Nothing failed, and the exception text that used to
/// land here read like a crash to anyone who had simply not finished setting
/// up. The raccoon is dimmed and off-kilter, the copy says what to do, and the
/// button goes there.
class NotConnectedView extends ConsumerWidget {
  const NotConnectedView({super.key, this.compact = false});

  /// Trims the art and the copy for a panel rather than a whole screen.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    final logoSize = compact ? 72.0 : 112.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 24 : 40,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SadRaccoon(size: logoSize),
              SizedBox(height: compact ? 16 : 24),
              Text(
                fun.notConnectedTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 17 : 20,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fun.notConnectedBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  height: 1.45,
                  color: colors.text2,
                ),
              ),
              SizedBox(height: compact ? 16 : 24),
              FilledButton.icon(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text(context.l10n.notConnectedAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The logo, greyed out and knocked sideways, with a severed plug over it.
class _SadRaccoon extends StatelessWidget {
  const _SadRaccoon({required this.size});

  final double size;

  /// Luminance weights, so the raccoon reads as drained rather than tinted.
  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: size * 1.25,
      height: size * 1.25,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: 0.55,
            child: ColorFiltered(
              colorFilter: _greyscale,
              child: Transform.rotate(
                angle: -0.09,
                child: FunLogo(width: size, height: size, borderRadius: 20),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: size * 0.06,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.power_off_outlined,
                size: size * 0.22,
                color: colors.text3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
