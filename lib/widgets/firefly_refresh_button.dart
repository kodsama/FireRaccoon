import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/firefly_data_refresh.dart';
import '../theme/app_theme.dart';

/// Re-fetches every Firefly-backed cache, spinning until the data lands.
///
/// Sits in the shell header beside undo and redo, so it is reachable from
/// every page rather than from the three that happened to carry their own. It
/// is shaped like those two for the same reason: a bordered pill with a label
/// read as a page control, which is what it used to be.
///
/// Holds the in-flight flag itself, so a stateless header can host it, and
/// refuses a second tap while a read is running.
///
/// Pass [focusAccount] from a view filtered to one account. Refreshing the
/// all-accounts list does not touch that account's own paginated instance.
class FireflyRefreshButton extends ConsumerStatefulWidget {
  const FireflyRefreshButton({super.key, this.focusAccount});

  final String? focusAccount;

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

    return Tooltip(
      message: context.l10n.tooltipRefreshFromFirefly,
      child: IconButton(
        onPressed: _refreshing ? null : _refresh,
        splashRadius: 20,
        icon: _refreshing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.text2,
                ),
              )
            : Icon(LucideIcons.refreshCw, size: 20, color: colors.text2),
      ),
    );
  }
}
