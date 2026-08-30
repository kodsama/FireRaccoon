import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fireraccoon_engine/models/account.dart';

import '../fun_modes/fun_mode.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extensions.dart';
import '../models/people_models.dart';
import '../providers/locale_provider.dart';
import '../providers/people_providers.dart';
import '../providers/data_providers.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/locale_formatting.dart';
import '../utils/password_policy.dart';
import '../widgets/avatar_crop_dialog.dart';
import '../widgets/person_avatar.dart';

const List<int> kPresetPersonColors = [
  0xFF3B82F6,
  0xFF10B981,
  0xFF8B5CF6,
  0xFFF59E0B,
  0xFFEF4444,
  0xFF06B6D4,
  0xFFEC4899,
  0xFFF97316,
  0xFF6366F1,
];

String _roleLabel(AppLocalizations l10n, PersonRole role) => switch (role) {
  PersonRole.admin => l10n.roleAdmin,
  PersonRole.user => l10n.roleUser,
  PersonRole.viewer => l10n.roleViewer,
};

String _roleDescription(AppLocalizations l10n, PersonRole role) =>
    switch (role) {
      PersonRole.admin => l10n.roleAdminDescription,
      PersonRole.user => l10n.roleUserDescription,
      PersonRole.viewer => l10n.roleViewerDescription,
    };

Future<String?> _validateNewPassword(
  AppLocalizations l10n,
  String password,
) async {
  final policy = validatePasswordPolicy(password);
  if (!policy.isValid) {
    return localizedPasswordPolicyError(l10n, policy);
  }
  final pwned = await isPasswordPwned(password);
  if (pwned == true) {
    return l10n.passwordPwned;
  }
  return null;
}

Future<Uint8List?> _pickAndCropAvatar(BuildContext context) async {
  final l10n = context.l10n;
  // mimeTypes are required for the web/Docker file picker; extensions alone
  // are ignored in browsers and the dialog never opens.
  const typeGroup = XTypeGroup(
    label: 'images',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
  );
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null || !context.mounted) return null;

  final bytes = await file.readAsBytes();
  final error = validateAvatarUploadBytes(Uint8List.fromList(bytes));
  if (error != null) {
    if (!context.mounted) return null;
    final message = switch (error) {
      _ when error.contains('10 KB') => l10n.avatarTooSmall,
      _ when error.contains('5 MB') => l10n.avatarTooLarge,
      _ => l10n.avatarInvalidFormat,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    return null;
  }

  if (!context.mounted) return null;
  return showAvatarCropDialog(context, imageBytes: Uint8List.fromList(bytes));
}

void showAddEditPersonDialog(
  BuildContext context,
  WidgetRef ref, {
  Person? personToEdit,
}) {
  final l10n = context.l10n;
  final nameController = TextEditingController(text: personToEdit?.name ?? '');
  final passwordController = TextEditingController();
  int selectedColor = personToEdit?.colorValue ?? kPresetPersonColors.first;
  PersonRole selectedRole = personToEdit?.role ?? PersonRole.user;
  String? selectedPreset = personToEdit?.avatarKind == AvatarKind.preset
      ? personToEdit?.avatarValue
      : null;
  Uint8List? pendingCustomBytes;
  var clearCustomAvatar = false;
  String? passwordError;
  String? errorText;
  bool isSaving = false;
  bool clearPassword = false;

  // Local preference draft for new/edit (applied on save).
  final theme = ref.read(themeProvider);
  final locale = ref.read(localeProvider);
  var themeModeName =
      personToEdit?.preferences.themeModeName ?? theme.themeMode.name;
  var funModeName = personToEdit?.preferences.funModeName ?? theme.funMode.name;
  var localeCode = personToEdit?.preferences.localeCode ?? locale.languageCode;

  final canManage = ref.read(canManagePeopleProvider);
  final isBootstrap = ref.read(peopleProvider).people.isEmpty;
  final editingSoleAdmin =
      personToEdit != null &&
      isSoleAdmin(ref.read(peopleProvider).people, personToEdit.id);

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> save() async {
          final name = nameController.text.trim();
          if (name.isEmpty) {
            setState(() => errorText = l10n.usernameRequired);
            return;
          }
          final notifier = ref.read(peopleProvider.notifier);
          if (notifier.isNameTaken(name, excludingId: personToEdit?.id)) {
            setState(() => errorText = l10n.usernameTaken);
            return;
          }

          final password = passwordController.text;
          if (password.isNotEmpty) {
            setState(() => isSaving = true);
            final nextPasswordError = await _validateNewPassword(
              l10n,
              password,
            );
            if (nextPasswordError != null) {
              setState(() {
                isSaving = false;
                passwordError = nextPasswordError;
              });
              return;
            }
          }

          final prefs = PersonPreferences(
            themeModeName: themeModeName,
            funModeName: funModeName,
            localeCode: localeCode,
            personFilterId: personToEdit?.preferences.personFilterId,
          );

          try {
            if (personToEdit == null) {
              final created = await notifier.addPerson(
                name: name,
                colorValue: selectedColor,
                role: canManage || isBootstrap ? selectedRole : PersonRole.user,
                password: password.isEmpty ? null : password,
                avatarKind: pendingCustomBytes != null
                    ? AvatarKind.none
                    : (selectedPreset != null
                          ? AvatarKind.preset
                          : AvatarKind.none),
                avatarValue: pendingCustomBytes != null ? null : selectedPreset,
                preferences: prefs,
              );
              if (pendingCustomBytes != null) {
                await notifier.saveCustomAvatar(
                  created.id,
                  pendingCustomBytes!,
                );
              }
            } else {
              if (clearPassword) {
                await notifier.clearPassword(personToEdit.id);
              } else if (password.isNotEmpty) {
                await notifier.setPassword(personToEdit.id, password);
              }

              // Apply avatar first so a following profile write cannot race
              // remote prefs back to the previous avatar.
              if (pendingCustomBytes != null) {
                await notifier.saveCustomAvatar(
                  personToEdit.id,
                  pendingCustomBytes!,
                );
              } else if (selectedPreset != null) {
                await notifier.setPresetAvatar(
                  personToEdit.id,
                  selectedPreset!,
                );
              } else if (clearCustomAvatar) {
                await notifier.clearAvatar(personToEdit.id);
              }

              final latest = ref
                  .read(peopleProvider)
                  .people
                  .firstWhere((p) => p.id == personToEdit.id);
              await notifier.updatePerson(
                latest.copyWith(
                  name: name,
                  colorValue: selectedColor,
                  role: canManage ? selectedRole : personToEdit.role,
                  preferences: prefs,
                  clearPassword: clearPassword,
                ),
              );

              // Re-apply prefs if this is the signed-in person.
              final current = ref.read(currentPersonProvider);
              if (current?.id == personToEdit.id) {
                final themeNotifier = ref.read(themeProvider.notifier);
                final mode = ThemeMode.values.firstWhere(
                  (m) => m.name == themeModeName,
                  orElse: () => ThemeMode.system,
                );
                themeNotifier.setThemeMode(mode);
                final fun = FunMode.values.firstWhere(
                  (m) => m.name == funModeName,
                  orElse: () => FunMode.none,
                );
                themeNotifier.setFunMode(fun);
                ref
                    .read(localeProvider.notifier)
                    .setLocale(AppLocale.fromCode(localeCode));
              }
            }
            if (context.mounted) Navigator.of(ctx).pop();
          } on ArgumentError catch (e) {
            setState(() {
              isSaving = false;
              errorText = e.message?.toString() ?? e.toString();
            });
          } on StateError catch (e) {
            setState(() {
              isSaving = false;
              errorText = e.message;
            });
          }
        }

        return AlertDialog(
          title: Text(personToEdit != null ? l10n.editPerson : l10n.addPerson),
          actionsAlignment: personToEdit != null
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.end,
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: PersonAvatar(
                      key: ValueKey(
                        'preview-${selectedPreset ?? 'none'}-'
                        '${pendingCustomBytes?.length ?? 0}-'
                        '$clearCustomAvatar-$selectedColor',
                      ),
                      person: Person(
                        id: personToEdit?.id ?? 'draft',
                        name: nameController.text.trim().isEmpty
                            ? (personToEdit?.name ?? '?')
                            : nameController.text.trim(),
                        colorValue: selectedColor,
                        avatarKind: clearCustomAvatar
                            ? AvatarKind.none
                            : pendingCustomBytes != null
                            ? AvatarKind.custom
                            : selectedPreset != null
                            ? AvatarKind.preset
                            : (personToEdit?.avatarKind ?? AvatarKind.none),
                        avatarValue: clearCustomAvatar
                            ? null
                            : (selectedPreset ??
                                  (pendingCustomBytes != null
                                      ? null
                                      : personToEdit?.avatarValue)),
                        role: selectedRole,
                        createdAtIso:
                            personToEdit?.createdAtIso ??
                            DateTime.now().toIso8601String(),
                      ),
                      radius: 40,
                      previewBytes: pendingCustomBytes,
                      previewPresetId: selectedPreset,
                      previewCleared: clearCustomAvatar,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        final cropped = await _pickAndCropAvatar(context);
                        if (cropped == null || !context.mounted) return;
                        setState(() {
                          pendingCustomBytes = cropped;
                          selectedPreset = null;
                          clearCustomAvatar = false;
                        });
                      },
                      icon: const Icon(LucideIcons.upload, size: 16),
                      label: Text(l10n.uploadAvatar),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.avatarPresets,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('—'),
                        selected:
                            selectedPreset == null &&
                            pendingCustomBytes == null &&
                            (clearCustomAvatar ||
                                personToEdit?.avatarKind != AvatarKind.custom),
                        onSelected: (_) => setState(() {
                          selectedPreset = null;
                          pendingCustomBytes = null;
                          clearCustomAvatar = true;
                        }),
                      ),
                      ...kAvatarPresets.map((id) {
                        return ChoiceChip(
                          label: CircleAvatar(
                            radius: 14,
                            backgroundImage: AssetImage(
                              avatarPresetAssetPath(id),
                            ),
                          ),
                          selected: selectedPreset == id,
                          onSelected: (_) => setState(() {
                            selectedPreset = id;
                            pendingCustomBytes = null;
                            clearCustomAvatar = false;
                          }),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.personName,
                      hintText: 'e.g. Alex, Sam, Leo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.colorBadge,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: kPresetPersonColors.map((colorVal) {
                      final isSelected = selectedColor == colorVal;
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = colorVal),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(
                                        colorVal,
                                      ).withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  if (canManage || isBootstrap) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PersonRole>(
                      initialValue: selectedRole,
                      decoration: InputDecoration(labelText: l10n.role),
                      items: PersonRole.values
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              enabled:
                                  !editingSoleAdmin || role == PersonRole.admin,
                              child: Text(_roleLabel(l10n, role)),
                            ),
                          )
                          .toList(),
                      onChanged: editingSoleAdmin
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => selectedRole = value);
                              }
                            },
                    ),
                    if (editingSoleAdmin) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.cannotDemoteOnlyAdmin,
                        style: TextStyle(
                          color: context.colors.text2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _roleDescription(l10n, selectedRole),
                      style: TextStyle(
                        color: context.colors.text2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    onChanged: (_) {
                      if (passwordError != null) {
                        setState(() => passwordError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: personToEdit?.hasPassword == true
                          ? l10n.newPassword
                          : l10n.password,
                      helperText: passwordError == null
                          ? l10n.passwordOptionalHint
                          : null,
                      helperMaxLines: 3,
                      errorText: passwordError,
                      errorMaxLines: 3,
                    ),
                  ),
                  if (personToEdit?.hasPassword == true &&
                      !ref.read(peopleProvider).requirePasswordLogin) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.clearPassword),
                      value: clearPassword,
                      onChanged: (v) =>
                          setState(() => clearPassword = v ?? false),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    l10n.personLanguage,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: localeCode,
                    items: AppLocale.supported
                        .map(
                          (loc) => DropdownMenuItem(
                            value: loc.languageCode,
                            child: Text(
                              l10n.languageDisplayName(loc.languageCode),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => localeCode = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.personAppearance,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: themeModeName,
                    decoration: InputDecoration(labelText: l10n.themeStyle),
                    items: ThemeMode.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.name,
                            child: Text(m.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => themeModeName = v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.raccoonMode),
                    value: funModeName == FunMode.raccoon.name,
                    onChanged: (v) {
                      setState(() {
                        funModeName = v
                            ? FunMode.raccoon.name
                            : FunMode.none.name;
                      });
                    },
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: TextStyle(color: context.colors.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (personToEdit != null && canManage)
              TextButton.icon(
                onPressed: editingSoleAdmin
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(peopleProvider.notifier)
                              .removePerson(personToEdit.id);
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } on StateError catch (e) {
                          setState(() => errorText = e.message);
                        }
                      },
                icon: const Icon(LucideIcons.trash2, size: 14),
                label: Text(
                  editingSoleAdmin
                      ? l10n.cannotDeleteOnlyAdmin
                      : l10n.deletePerson,
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

void _showSwitchPersonDialog(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final state = ref.read(peopleProvider);
  final currentId = state.loggedInPersonId;

  if (state.requirePasswordLogin) {
    ref.read(peopleProvider.notifier).logout();
    return;
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.switchUser),
      content: SizedBox(
        width: 360,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: state.people.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final person = state.people[index];
            final isCurrent = person.id == currentId;
            return ListTile(
              leading: PersonAvatar(person: person, radius: 18),
              title: Text(person.name),
              subtitle: Text(_roleLabel(l10n, person.role)),
              trailing: isCurrent
                  ? Icon(
                      LucideIcons.check,
                      size: 18,
                      color: context.colors.accent.acc,
                    )
                  : null,
              onTap: isCurrent
                  ? () => Navigator.of(ctx).pop()
                  : () async {
                      await ref
                          .read(peopleProvider.notifier)
                          .selectPerson(person.id);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}

Future<void> _showChangePasswordDialog(
  BuildContext context,
  WidgetRef ref,
  Person person,
) async {
  final l10n = context.l10n;
  final oldController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(
            person.hasPassword ? l10n.changePassword : l10n.setPassword,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (person.hasPassword)
                TextField(
                  controller: oldController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l10n.currentPassword),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.newPassword,
                  helperText: l10n.passwordRequirements,
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.confirmNewPassword),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: context.colors.danger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newController.text != confirmController.text) {
                  setState(() => error = l10n.passwordsDoNotMatch);
                  return;
                }
                final policyError = await _validateNewPassword(
                  l10n,
                  newController.text,
                );
                if (policyError != null) {
                  setState(() => error = policyError);
                  return;
                }
                final notifier = ref.read(peopleProvider.notifier);
                try {
                  if (person.hasPassword) {
                    final ok = await notifier.changePassword(
                      person.id,
                      oldPassword: oldController.text,
                      newPassword: newController.text,
                    );
                    if (!ok) {
                      setState(() => error = l10n.currentPasswordIncorrect);
                      return;
                    }
                  } else {
                    await notifier.setPassword(person.id, newController.text);
                  }
                } on Object catch (e) {
                  setState(() => error = e.toString());
                  return;
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                final messenger = ScaffoldMessenger.maybeOf(context);
                messenger?.showSnackBar(
                  SnackBar(content: Text(l10n.passwordChanged)),
                );
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    ),
  );
}

class PeopleSettingsSection extends ConsumerWidget {
  const PeopleSettingsSection({super.key});

  void _showCustomSplitDialog(
    BuildContext context,
    WidgetRef ref,
    Account account,
    AccountOwnership ownership,
    List<Person> assignedPeople,
  ) {
    final Map<String, double> shares = Map<String, double>.from(
      ownership.personShares,
    );

    if (shares.isEmpty) {
      final equal = 1.0 / assignedPeople.length;
      for (final p in assignedPeople) {
        shares[p.id] = equal;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          double totalPercent =
              shares.values.fold(0.0, (sum, val) => sum + val) * 100;

          return AlertDialog(
            title: Text('Custom Split: ${account.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set percentage share for each owner (Total must equal 100%):',
                    style: TextStyle(fontSize: 12, color: context.colors.text2),
                  ),
                  const SizedBox(height: 16),
                  ...assignedPeople.map((person) {
                    final currentPercent = (shares[person.id] ?? 0.0) * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PersonAvatar(person: person, radius: 8),
                              const SizedBox(width: 8),
                              Text(
                                person.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${currentPercent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: person.color,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: currentPercent.clamp(0.0, 100.0),
                            min: 0,
                            max: 100,
                            divisions: 100,
                            activeColor: person.color,
                            onChanged: (newVal) {
                              setState(() {
                                shares[person.id] = newVal / 100.0;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.colors.text,
                        ),
                      ),
                      Text(
                        '${totalPercent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: (totalPercent - 100.0).abs() < 0.5
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final equal = 1.0 / assignedPeople.length;
                  final resetShares = <String, double>{
                    for (final p in assignedPeople) p.id: equal,
                  };
                  ref
                      .read(peopleProvider.notifier)
                      .setAccountOwners(account.id, customShares: resetShares);
                  Navigator.of(ctx).pop();
                },
                child: const Text('Reset Equal Split'),
              ),
              ElevatedButton(
                onPressed: (totalPercent - 100.0).abs() < 0.5
                    ? () {
                        final sum = shares.values.fold(0.0, (s, v) => s + v);
                        final normalized = <String, double>{
                          for (final entry in shares.entries)
                            entry.key: entry.value / sum,
                        };
                        ref
                            .read(peopleProvider.notifier)
                            .setAccountOwners(
                              account.id,
                              customShares: normalized,
                            );
                        Navigator.of(ctx).pop();
                      }
                    : null,
                child: const Text('Save Split'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _togglePasswordLogin(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final l10n = context.l10n;
    final missing = await ref
        .read(peopleProvider.notifier)
        .setRequirePasswordLogin(value);
    if (missing.isEmpty || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.peopleMissingPasswordsTitle),
        content: Text(
          l10n.peopleMissingPasswordsMessage(
            missing.map((p) => p.name).join(', '),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final format = ref.watch(localeFormattingProvider);
    final peopleState = ref.watch(peopleProvider);
    final config = peopleState.config;
    final accounts = ref.watch(accountsProvider).asData?.value ?? [];
    final canWrite = ref.watch(canWriteFinancialDataProvider);
    final canManage = ref.watch(canManagePeopleProvider);
    final current = ref.watch(currentPersonProvider);
    final people = config.people;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          leading: const Icon(LucideIcons.users, size: 20),
          title: Text(
            l10n.peopleAndOwnership,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
          subtitle: Text(l10n.peopleAndOwnershipSubtitle),
          children: [
            if (current != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PersonAvatar(person: current, radius: 22),
                title: Text(l10n.signedInAs(current.name)),
                subtitle: Text(_roleLabel(l10n, current.role)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.usersRound, size: 20),
                title: Text(l10n.switchUser),
                onTap: () => _showSwitchPersonDialog(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.keyRound, size: 20),
                title: Text(
                  current.hasPassword ? l10n.changePassword : l10n.setPassword,
                ),
                onTap: () => _showChangePasswordDialog(context, ref, current),
              ),
              if (current.hasPassword)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(LucideIcons.fingerprint, size: 20),
                  title: Text(l10n.unlockWithBiometrics),
                  subtitle: Text(l10n.unlockWithBiometricsDescription),
                  value: current.biometricsEnabled,
                  onChanged: (enabled) async {
                    await ref
                        .read(peopleProvider.notifier)
                        .setBiometricsEnabled(
                          current.id,
                          enabled: enabled,
                          localizedReason: l10n.biometricEnableReason,
                        );
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  LucideIcons.logOut,
                  size: 20,
                  color: colors.danger,
                ),
                title: Text(l10n.logout),
                onTap: () => ref.read(peopleProvider.notifier).logout(),
              ),
              const Divider(),
            ],
            if (canManage && people.isNotEmpty)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.requireLogin),
                subtitle: Text(l10n.requireLoginDescription),
                value: peopleState.requirePasswordLogin,
                onChanged: (v) => _togglePasswordLogin(context, ref, v),
              ),
            if (canManage || people.isEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => showAddEditPersonDialog(context, ref),
                    icon: const Icon(LucideIcons.userPlus, size: 16),
                    label: Text(l10n.addPerson),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (people.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.users, color: colors.text3, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        l10n.enableAppUsersDescription,
                        style: TextStyle(color: colors.text2, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: people.map((person) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: PersonAvatar(person: person, radius: 20),
                    title: Text(person.name),
                    subtitle: Text(
                      '${_roleLabel(l10n, person.role)} · '
                      '${person.hasPassword ? l10n.hasPassword : l10n.noPasswordSet}',
                    ),
                    trailing: canManage
                        ? IconButton(
                            icon: const Icon(LucideIcons.pencil, size: 18),
                            onPressed: () => showAddEditPersonDialog(
                              context,
                              ref,
                              personToEdit: person,
                            ),
                          )
                        : null,
                    onTap: canManage
                        ? () => showAddEditPersonDialog(
                            context,
                            ref,
                            personToEdit: person,
                          )
                        : null,
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            if (people.isNotEmpty && accounts.isNotEmpty) ...[
              Text(
                l10n.accountAssignments,
                style: context.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: accounts.length,
                  separatorBuilder: (ctx, i) => Divider(
                    height: 1,
                    color: colors.border.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (ctx, i) {
                    final account = accounts[i];
                    final ownership =
                        config.accountOwnerships[account.id] ??
                        AccountOwnership(
                          accountId: account.id,
                          personShares: const {},
                        );
                    final assignedPeople = config.getOwnersForAccount(
                      account.id,
                    );
                    final isShared = assignedPeople.length > 1;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      account.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colors.text,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.sunken,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        account.type.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  format.formatMoney(
                                    account.currentBalance,
                                    account.currencySymbol,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: people.map((person) {
                              final isAssigned = ownership.personShares
                                  .containsKey(person.id);
                              final share = ownership.personShares[person.id];
                              final percentStr = share != null
                                  ? '${(share * 100).toStringAsFixed(0)}%'
                                  : '';

                              return FilterChip(
                                label: Text(
                                  isAssigned && isShared
                                      ? '${person.name} ($percentStr)'
                                      : person.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isAssigned
                                        ? Colors.white
                                        : colors.text2,
                                  ),
                                ),
                                selected: isAssigned,
                                selectedColor: person.color,
                                checkmarkColor: Colors.white,
                                onSelected: !canWrite
                                    ? null
                                    : (selected) {
                                        final updatedIds = List<String>.from(
                                          ownership.ownerIds,
                                        );
                                        if (selected) {
                                          if (!updatedIds.contains(person.id)) {
                                            updatedIds.add(person.id);
                                          }
                                        } else {
                                          updatedIds.remove(person.id);
                                        }
                                        ref
                                            .read(peopleProvider.notifier)
                                            .setAccountOwners(
                                              account.id,
                                              ownerIds: updatedIds,
                                            );
                                      },
                              );
                            }).toList(),
                          ),
                          if (isShared) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.slidersHorizontal,
                                size: 16,
                              ),
                              tooltip: l10n.customSplit,
                              onPressed: !canWrite
                                  ? null
                                  : () => _showCustomSplitDialog(
                                      context,
                                      ref,
                                      account,
                                      ownership,
                                      assignedPeople,
                                    ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
