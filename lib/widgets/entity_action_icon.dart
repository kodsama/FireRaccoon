import 'package:flutter/material.dart';

/// Tappable icon used in entity card and row headers (edit, delete, etc.).
class EntityActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final double size;

  const EntityActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
