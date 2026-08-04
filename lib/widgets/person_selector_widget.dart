import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/people_models.dart';
import '../providers/people_providers.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n_extensions.dart';

class PersonSelectorWidget extends ConsumerWidget {
  const PersonSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final config = ref.watch(peopleSettingsProvider);
    final activePersonId = ref.watch(activePersonFilterProvider);

    final people = config.people;

    // Find active person
    final Person? activePerson = people.isEmpty
        ? null
        : people.cast<Person?>().firstWhere(
            (p) => p?.id == activePersonId,
            orElse: () => null,
          );

    final activeLabel = activePerson != null
        ? activePerson.name
        : l10n.allPeople;
    final activeColor = activePerson?.color ?? colors.accent.acc;

    return PopupMenuButton<String?>(
      tooltip: l10n.filterByPersonTooltip,
      initialValue: activePersonId,
      onSelected: (selectedId) {
        ref
            .read(activePersonFilterProvider.notifier)
            .setPersonFilter(selectedId);
      },
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colors.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: activePersonId == null
              ? colors.sunken
              : activeColor.withValues(alpha: 0.15),
          border: Border.all(
            color: activePersonId == null
                ? colors.border
                : activeColor.withValues(alpha: 0.5),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              activeLabel,
              style: TextStyle(
                fontFamily: 'Comfortaa',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: colors.text,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 14, color: colors.text3),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors.accent.acc,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.allPeople,
                  style: TextStyle(
                    fontFamily: 'Comfortaa',
                    fontWeight: activePersonId == null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: colors.text,
                  ),
                ),
              ),
              if (activePersonId == null)
                Icon(LucideIcons.check, size: 16, color: colors.accent.acc),
            ],
          ),
        ),
        if (people.isNotEmpty) const PopupMenuDivider(),
        ...people.map(
          (person) => PopupMenuItem<String?>(
            value: person.id,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: person.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    person.name,
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontWeight: activePersonId == person.id
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: colors.text,
                    ),
                  ),
                ),
                if (activePersonId == person.id)
                  Icon(LucideIcons.check, size: 16, color: person.color),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
