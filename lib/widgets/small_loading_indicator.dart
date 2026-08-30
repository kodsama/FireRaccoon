import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'fun_decorated_surface.dart';

bool get _isFlutterTest =>
    WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets');

/// Compact loading affordance for list tiles, dialogs, and inline slots.
///
/// Uses a breathing raccoon logo in Raccoon Mode; otherwise a small spinner.
class SmallLoadingIndicator extends ConsumerWidget {
  const SmallLoadingIndicator({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRaccoonMode = ref.watch(themeProvider).isRaccoonMode;
    final colors = context.colors;

    return SizedBox(
      width: size,
      height: size,
      child: isRaccoonMode
          ? _BreathingLogo(size: size)
          : Padding(
              padding: EdgeInsets.all(size * 0.125),
              child: CircularProgressIndicator(
                strokeWidth: size <= 16 ? 2 : 2.5,
                color: colors.accent.acc,
              ),
            ),
    );
  }
}

/// Full-pane loading affordance for screens waiting on the first data fetch.
class PageLoadingIndicator extends ConsumerWidget {
  const PageLoadingIndicator({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final label = message ?? context.l10n.loading;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SmallLoadingIndicator(size: 48),
          const SizedBox(height: 16),
          Text(label, style: TextStyle(color: colors.text3, fontSize: 14)),
        ],
      ),
    );
  }
}

class _BreathingLogo extends StatefulWidget {
  const _BreathingLogo({required this.size});

  final double size;

  @override
  State<_BreathingLogo> createState() => _BreathingLogoState();
}

class _BreathingLogoState extends State<_BreathingLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  void _syncAnimation() {
    // Avoid MediaQuery during initState; inherited lookups belong in
    // didChangeDependencies. Check test mode first to skip the look-up entirely.
    if (_isFlutterTest) {
      _controller?.dispose();
      _controller = null;
      _scale = null;
      return;
    }
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
      _scale = Tween<double>(
        begin: 0.82,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
    } else if (!animate && _controller != null) {
      _controller?.dispose();
      _controller = null;
      _scale = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = FunLogo(
      width: widget.size,
      height: widget.size,
      borderRadius: widget.size * 0.2,
    );

    final scale = _scale;
    if (scale == null) return logo;

    return ScaleTransition(scale: scale, child: logo);
  }
}
