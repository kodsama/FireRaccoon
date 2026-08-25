import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/firefly_data_refresh.dart';
import '../theme/app_theme.dart';

/// Re-fetches every Firefly-backed cache, spinning until the data lands.
///
/// Holds the in-flight flag itself so a stateless screen can host it. Pass
/// [focusAccount] from a view filtered to one account: refreshing the
/// all-accounts list does not touch that account's own paginated instance.
class FireflyRefreshButton extends ConsumerStatefulWidget {
  const FireflyRefreshButton({
    super.key,
    this.focusAccount,
    this.backgroundColor,
  });

  final String? focusAccount;

  /// Fill behind the pill, for a bar whose other controls sit on `surface2`.
  final Color? backgroundColor;

  @override
  ConsumerState<FireflyRefreshButton> createState() =>
      _FireflyRefreshButtonState();
}

class _FireflyRefreshButtonState extends ConsumerState<FireflyRefreshButton> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await refreshFireflyData(ref, focusAccount: widget.focusAccount);
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Tooltip(
      message: l10n.tooltipRefreshFromFirefly,
      child: Material(
        color: widget.backgroundColor ?? colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _refreshing ? null : _refresh,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_refreshing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.text,
                    ),
                  )
                else
                  Icon(LucideIcons.refreshCw, size: 16, color: colors.text),
                const SizedBox(width: 8),
                Text(
                  l10n.refreshFromFirefly,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
