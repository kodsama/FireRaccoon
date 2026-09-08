import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/readable_on.dart';

/// The result of a connection test, shown inside the dialog that ran it.
///
/// Inside rather than in a snack bar: the dialog is modal, and its scrim paints
/// over anything the Scaffold puts underneath, which dimmed the message to the
/// point of being unreadable. It also puts the answer where the person already
/// is, next to the field they would have to correct.
class ConnectionTestBanner extends StatelessWidget {
  const ConnectionTestBanner({
    super.key,
    required this.ok,
    required this.message,
    this.action,
  });

  final bool ok;
  final String message;

  /// Offered only for a failure someone can act on from here.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = ok ? colors.success : colors.danger;
    final foreground = onColor(background);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}
