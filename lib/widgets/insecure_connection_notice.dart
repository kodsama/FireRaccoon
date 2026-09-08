import 'package:flutter/material.dart';

import '../l10n/l10n_extensions.dart';
import '../utils/transport_security.dart';
import '../theme/app_theme.dart';

/// Marks a connection that is not encrypted, wherever the server is shown.
///
/// Deliberately persistent. Someone who turned plain http on months ago has
/// long since forgotten, and a warning shown only at setup is one nobody ever
/// sees again.
class InsecureConnectionBadge extends StatelessWidget {
  const InsecureConnectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: context.l10n.insecureConnectionWarning,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colors.warningSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.warning),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_open_outlined, size: 12, color: colors.warning),
            const SizedBox(width: 4),
            Text(
              context.l10n.insecureConnectionBadge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spells out what turning plain http on actually costs, at the moment of
/// turning it on.
class InsecureConnectionWarning extends StatelessWidget {
  const InsecureConnectionWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warningSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.insecureConnectionWarning,
              style: TextStyle(fontSize: 12, height: 1.4, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// A closed green lock or an open red one, next to wherever the connection is
/// reported.
///
/// Shown in both states rather than only the bad one: an indicator that appears
/// only when something is wrong is one you cannot trust the absence of.
class TransportLockIcon extends StatelessWidget {
  const TransportLockIcon({super.key, required this.url, this.size = 12});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final insecure = isUnencryptedUrl(url);
    return Tooltip(
      message: insecure
          ? l10n.insecureConnectionWarning
          : l10n.secureConnectionTooltip,
      child: Icon(
        insecure ? Icons.lock_open_outlined : Icons.lock_outline,
        size: size,
        color: insecure ? colors.danger : colors.success,
      ),
    );
  }
}
