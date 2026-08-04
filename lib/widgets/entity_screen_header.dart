import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Page title row with an optional trailing create button (upper right).
class EntityScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? createLabel;
  final VoidCallback? onCreate;
  final List<Widget> trailing;

  const EntityScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.createLabel,
    this.onCreate,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(color: colors.text3, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (onCreate != null && createLabel != null) ...[
                const SizedBox(width: 12),
                Tooltip(
                  message: createLabel!,
                  child: ElevatedButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: Text(createLabel!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent.acc,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < trailing.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    trailing[i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
