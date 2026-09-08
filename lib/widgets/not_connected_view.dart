import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../store/credential_store_locked_exception.dart';
import '../theme/app_theme.dart';
import 'fun_decorated_surface.dart';

/// What a screen shows when a load failed.
///
/// Two of the ways a load can fail are not failures at all: no server has been
/// connected yet, and the credential store has relocked. Neither gets a
/// failure's treatment. [message] is only for the things that really did go
/// wrong.
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
    if (error is CredentialStoreLockedException) {
      return CredentialsLockedView(compact: compact);
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
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    return SadRaccoonMessage(
      compact: compact,
      badge: Icons.power_off_outlined,
      title: fun.notConnectedTitle,
      body: fun.notConnectedBody,
      action: FilledButton.icon(
        onPressed: () => context.go('/settings'),
        icon: const Icon(Icons.settings_outlined, size: 18),
        label: Text(context.l10n.notConnectedAction),
      ),
    );
  }
}

/// What a screen shows while the credential store will not open.
///
/// The connection is saved and still there; the keychain has simply relocked or
/// its prompt went unanswered. The connection poll already asks again on its
/// own, and the button is for someone who has just unlocked it and does not
/// want to wait for the next poll.
class CredentialsLockedView extends ConsumerStatefulWidget {
  const CredentialsLockedView({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<CredentialsLockedView> createState() =>
      _CredentialsLockedViewState();
}

class _CredentialsLockedViewState extends ConsumerState<CredentialsLockedView> {
  bool _asking = false;

  Future<void> _askAgain() async {
    if (_asking) return;
    setState(() => _asking = true);
    try {
      await ref.read(authProvider.notifier).retryCredentialRead();
    } finally {
      // The read can outlive the screen it was started from: a keychain that
      // answers puts the data back and this view is gone before the await
      // returns.
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    return SadRaccoonMessage(
      compact: widget.compact,
      badge: Icons.lock_outline,
      title: fun.credentialsLockedTitle,
      body: fun.credentialsLockedBody,
      action: FilledButton.icon(
        onPressed: _asking ? null : _askAgain,
        icon: _asking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_open_outlined, size: 18),
        label: Text(
          _asking
              ? l10n.credentialsLockedRetrying
              : l10n.credentialsLockedAction,
        ),
      ),
    );
  }
}

/// The shared shape of both states: dimmed raccoon, a badge, what happened,
/// and the one thing to do about it.
class SadRaccoonMessage extends StatelessWidget {
  const SadRaccoonMessage({
    super.key,
    required this.badge,
    required this.title,
    required this.body,
    required this.action,
    this.compact = false,
  });

  final IconData badge;
  final String title;
  final String body;
  final Widget action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
              _SadRaccoon(size: logoSize, badge: badge),
              SizedBox(height: compact ? 16 : 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 17 : 20,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  height: 1.45,
                  color: colors.text2,
                ),
              ),
              SizedBox(height: compact ? 16 : 24),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

/// The logo, greyed out and knocked sideways, with a badge over it.
class _SadRaccoon extends StatelessWidget {
  const _SadRaccoon({required this.size, required this.badge});

  final double size;
  final IconData badge;

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
              child: Icon(badge, size: size * 0.22, color: colors.text3),
            ),
          ),
        ],
      ),
    );
  }
}
