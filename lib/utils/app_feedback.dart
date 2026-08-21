import 'dart:async';

import 'package:flutter/material.dart';

/// How long a confirmation stays before it fades on its own.
const Duration _kInfoDuration = Duration(seconds: 3);

/// Messages go into the root overlay rather than through `ScaffoldMessenger`.
///
/// A SnackBar renders inside its Scaffold, which sits *below* any dialog route
/// and its scrim, so feedback raised from a dialog is invisible exactly when it
/// matters most: the one-time reveal of an agent key is behind a modal, and so
/// is any failure raised while dismissing one. The root overlay is above every
/// route, so these are always readable.
OverlayEntry? _current;
Timer? _timer;

/// Shows [message] as a failure that stays until it is dismissed.
///
/// Errors are not transient status. A failure that fades after a few seconds is
/// one the reader may never have seen, and cannot re-read while acting on it.
void showErrorToast(BuildContext context, String message) {
  _show(context, message, isError: true);
}

/// Shows [message] as a confirmation that clears itself.
void showInfoToast(BuildContext context, String message) {
  _show(context, message, isError: false);
}

void _show(BuildContext context, String message, {required bool isError}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final scheme = Theme.of(context).colorScheme;
  dismissToast();

  final entry = OverlayEntry(
    builder: (context) => _Toast(
      message: message,
      background: isError ? scheme.errorContainer : scheme.inverseSurface,
      foreground: isError ? scheme.onErrorContainer : scheme.onInverseSurface,
      onClose: isError ? dismissToast : null,
    ),
  );
  _current = entry;
  overlay.insert(entry);
  if (!isError) {
    _timer = Timer(_kInfoDuration, dismissToast);
  }
}

/// Removes the visible message, if any.
void dismissToast() {
  _timer?.cancel();
  _timer = null;
  final entry = _current;
  _current = null;
  if (entry != null && entry.mounted) entry.remove();
}

class _Toast extends StatelessWidget {
  const _Toast({
    required this.message,
    required this.background,
    required this.foreground,
    this.onClose,
  });

  final String message;
  final Color background;
  final Color foreground;

  /// Non-null for errors, which need an explicit way out.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: background,
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  onClose == null ? 16 : 4,
                  12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SelectableText(
                        message,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: foreground),
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: foreground,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: onClose,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
