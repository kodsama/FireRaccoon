import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fun_modes/fun_mode_registry.dart';
import '../fun_modes/fun_sticker.dart';
import '../providers/theme_provider.dart';

/// Wraps cards and rows with playful corner stickers when a [FunMode] is active.
///
/// Add new modes in [FunModeRegistry] — no changes needed here.
class FunDecoratedSurface extends ConsumerStatefulWidget {
  const FunDecoratedSurface({
    super.key,
    required this.child,
    this.decorationKey,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.compact = false,
  });

  final Widget child;
  final String? decorationKey;
  final BorderRadius borderRadius;
  final bool compact;

  @override
  ConsumerState<FunDecoratedSurface> createState() =>
      _FunDecoratedSurfaceState();
}

class _FunDecoratedSurfaceState extends ConsumerState<FunDecoratedSurface>
    with SingleTickerProviderStateMixin {
  AnimationController? _wiggleController;

  void _syncWiggle({required bool active, required BuildContext context}) {
    final animate =
        active && !MediaQuery.of(context).disableAnimations && !_isFlutterTest;
    if (animate && _wiggleController == null) {
      _wiggleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat(reverse: true);
    } else if (!animate && _wiggleController != null) {
      _wiggleController?.dispose();
      _wiggleController = null;
    }
  }

  @override
  void dispose() {
    _wiggleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = ref.watch(themeProvider).funModeDefinition;
    if (!definition.isActive) {
      _syncWiggle(active: false, context: context);
      return widget.child;
    }

    _syncWiggle(active: true, context: context);

    final seed = Object.hash(
      definition.mode,
      widget.decorationKey ?? widget.child.runtimeType.toString(),
      widget.compact,
    );
    final rng = math.Random(seed);
    final stickerPool = definition.stickers;
    if (stickerPool.isEmpty) return widget.child;

    final stickerCount = widget.compact ? 1 : 1 + rng.nextInt(2);
    final baseSize =
        (widget.compact ? 14.0 : 20.0) * definition.stickerSizeMultiplier;

    final corners = <_StickerCorner>[
      _StickerCorner.topRight,
      _StickerCorner.topLeft,
      _StickerCorner.bottomRight,
      _StickerCorner.bottomLeft,
    ]..shuffle(rng);

    final stickers = <Widget>[
      for (var i = 0; i < stickerCount; i++)
        _positionSticker(
          corner: corners[i],
          size: baseSize,
          stickerId: stickerPool[rng.nextInt(stickerPool.length)],
          wiggle: _wiggleController,
          wiggleAmplitude: definition.wiggleAmplitude,
          phase: rng.nextDouble() * math.pi * 2,
          rotation: (rng.nextDouble() - 0.5) * 0.35,
        ),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [widget.child, ...stickers],
    );
  }

  Widget _positionSticker({
    required _StickerCorner corner,
    required double size,
    required FunStickerId stickerId,
    required AnimationController? wiggle,
    required double wiggleAmplitude,
    required double phase,
    required double rotation,
  }) {
    final sticker = _FunStickerWidget(
      stickerId: stickerId,
      size: size,
      rotation: rotation,
      wiggle: wiggle,
      wiggleAmplitude: wiggleAmplitude,
      phase: phase,
    );

    // VLC-style: perch on the corner, slightly overlapping the surface edge.
    final overlap = size * 0.42;
    return switch (corner) {
      _StickerCorner.topRight => Positioned(
        top: -overlap * 0.55,
        right: -overlap * 0.35,
        child: sticker,
      ),
      _StickerCorner.topLeft => Positioned(
        top: -overlap * 0.55,
        left: -overlap * 0.35,
        child: sticker,
      ),
      _StickerCorner.bottomRight => Positioned(
        bottom: -overlap * 0.35,
        right: -overlap * 0.35,
        child: sticker,
      ),
      _StickerCorner.bottomLeft => Positioned(
        bottom: -overlap * 0.35,
        left: -overlap * 0.35,
        child: sticker,
      ),
    };
  }
}

enum _StickerCorner { topRight, topLeft, bottomRight, bottomLeft }

class _FunStickerWidget extends StatelessWidget {
  const _FunStickerWidget({
    required this.stickerId,
    required this.size,
    required this.rotation,
    required this.wiggle,
    required this.wiggleAmplitude,
    required this.phase,
  });

  final FunStickerId stickerId;
  final double size;
  final double rotation;
  final AnimationController? wiggle;
  final double wiggleAmplitude;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final painter = FunModeRegistry.painterFor(stickerId);
    if (painter == null) return const SizedBox.shrink();

    Widget sticker = Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: painter),
      ),
    );

    if (wiggle != null) {
      sticker = AnimatedBuilder(
        animation: wiggle!,
        builder: (context, child) {
          final wobble =
              math.sin((wiggle!.value * math.pi * 2) + phase) * wiggleAmplitude;
          return Transform.rotate(angle: wobble, child: child);
        },
        child: sticker,
      );
    }

    return sticker;
  }
}

/// VLC-style logo dress-up — hat, party cap, etc. per active fun mode.
class FunLogo extends ConsumerWidget {
  const FunLogo({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = ref.watch(themeProvider).funModeDefinition;
    final scale = definition.logoSizeMultiplier;
    final logoWidth = width * scale;
    final logoHeight = height * scale;

    Widget logo = SizedBox(
      width: logoWidth,
      height: logoHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          definition.logoAsset,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) {
            final scheme = Theme.of(context).colorScheme;
            return ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Icon(
                Icons.pets,
                size: logoWidth * 0.45,
                color: scheme.onSurfaceVariant,
              ),
            );
          },
        ),
      ),
    );

    final overlayId = definition.logoOverlay;
    if (overlayId != null) {
      final overlayPainter = FunModeRegistry.painterFor(overlayId);
      if (overlayPainter != null) {
        logo = Stack(
          clipBehavior: Clip.none,
          children: [
            logo,
            Positioned(
              top: -logoHeight * 0.18,
              left: logoWidth * 0.08,
              right: logoWidth * 0.08,
              height: logoHeight * 0.55,
              child: CustomPaint(painter: overlayPainter),
            ),
          ],
        );
      }
    }

    return logo;
  }
}

/// Back-compat alias — prefer [FunDecoratedSurface].
typedef RacoonDecoratedSurface = FunDecoratedSurface;

bool get _isFlutterTest =>
    WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets');
