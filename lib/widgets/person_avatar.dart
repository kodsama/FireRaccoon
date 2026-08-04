import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/people_models.dart';
import '../providers/people_providers.dart';

/// Circular avatar for a [Person]: custom bytes, bundled preset, or initials.
class PersonAvatar extends ConsumerWidget {
  final Person person;
  final double radius;
  final TextStyle? textStyle;

  /// When set, overrides [person]'s stored avatar for live dialog previews.
  final Uint8List? previewBytes;
  final String? previewPresetId;
  final bool previewCleared;

  const PersonAvatar({
    super.key,
    required this.person,
    this.radius = 20,
    this.textStyle,
    this.previewBytes,
    this.previewPresetId,
    this.previewCleared = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = person.name.isNotEmpty
        ? person.name.substring(0, 1).toUpperCase()
        : '?';
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: person.color,
      child: Text(
        initial,
        style:
            textStyle ??
            TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.85,
            ),
      ),
    );

    if (previewCleared) return fallback;

    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return _imageAvatar(
        radius: radius,
        color: person.color,
        image: MemoryImage(previewBytes!),
        fallback: fallback,
      );
    }

    final presetId =
        previewPresetId ??
        (person.avatarKind == AvatarKind.preset ? person.avatarValue : null);
    if (presetId != null && kAvatarPresets.contains(presetId)) {
      return _imageAvatar(
        radius: radius,
        color: person.color,
        image: AssetImage(avatarPresetAssetPath(presetId)),
        fallback: fallback,
      );
    }

    switch (person.avatarKind) {
      case AvatarKind.none:
      case AvatarKind.preset:
        // Preset without a known id falls back to initials.
        return fallback;
      case AvatarKind.custom:
        return FutureBuilder<Uint8List?>(
          future: ref
              .read(peopleProvider.notifier)
              .resolveCustomAvatarBytes(person),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null || bytes.isEmpty) return fallback;
            return _imageAvatar(
              radius: radius,
              color: person.color,
              image: MemoryImage(bytes),
              fallback: fallback,
            );
          },
        );
    }
  }
}

Widget _imageAvatar({
  required double radius,
  required Color color,
  required ImageProvider image,
  required Widget fallback,
}) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: color.withValues(alpha: 0.2),
    backgroundImage: image,
    onBackgroundImageError: (_, _) {},
  );
}
