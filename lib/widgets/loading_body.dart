import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fun_decorated_surface.dart';

/// The raccoon a screen shows while its data is on the way.
///
/// Shown on a retry as well as a first load: a screen that keeps the failure
/// from last time on show while it is already asking again reads as stuck, and
/// after connecting a server that is exactly when someone is watching.
class LoadingBody extends StatelessWidget {
  const LoadingBody({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 24 : 40),
        child: RaccoonLoader(size: compact ? 56 : 88),
      ),
    );
  }
}

/// The logo bobbing inside a spinning ring, dressed for the fun mode on.
class RaccoonLoader extends StatefulWidget {
  const RaccoonLoader({super.key, this.size = 88});

  final double size;

  @override
  State<RaccoonLoader> createState() => _RaccoonLoaderState();
}

class _RaccoonLoaderState extends State<RaccoonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final logo = size * 0.62;
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _controller,
              child: CircularProgressIndicator(
                value: 0.28,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                color: context.colors.accent.acc,
                constraints: BoxConstraints.tight(Size.square(size)),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Two hops per turn of the ring, landing as it passes the top.
                final phase = (_controller.value * 2) % 1;
                final hop = 4 * phase * (1 - phase);
                return Transform.translate(
                  offset: Offset(0, -hop * size * 0.07),
                  child: child,
                );
              },
              child: FunLogo(width: logo, height: logo, borderRadius: logo),
            ),
          ],
        ),
      ),
    );
  }
}
