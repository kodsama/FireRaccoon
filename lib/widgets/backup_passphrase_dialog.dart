import 'package:flutter/material.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_theme.dart';
import '../utils/password_policy.dart';

/// Collects a backup passphrase for sealing or unlocking settings secrets.
Future<String?> showBackupPassphraseDialog({
  required BuildContext context,
  required bool confirm,
}) {
  final l10n = context.l10n;
  final passphraseController = TextEditingController();
  final confirmController = TextEditingController();
  var obscure = true;
  String? error;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              confirm
                  ? l10n.backupPassphraseExportTitle
                  : l10n.backupPassphraseImportTitle,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  confirm
                      ? l10n.backupPassphraseExportMessage
                      : l10n.backupPassphraseImportMessage,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passphraseController,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.backupPassphrase,
                    helperText: confirm ? l10n.passwordRequirements : null,
                    helperMaxLines: 3,
                    suffixIcon: IconButton(
                      tooltip: obscure
                          ? l10n.backupPassphraseShow
                          : l10n.backupPassphraseHide,
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                ),
                if (confirm) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: l10n.confirmNewPassword,
                    ),
                    onChanged: (_) {
                      if (error != null) setState(() => error = null);
                    },
                  ),
                ],
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
              FilledButton(
                onPressed: () {
                  final passphrase = passphraseController.text;
                  if (confirm) {
                    final policy = validatePasswordPolicy(passphrase);
                    if (!policy.isValid) {
                      setState(() {
                        error = l10n.passwordMissingRequirements(
                          policy.missingRequirements
                              .map(
                                (r) => switch (r) {
                                  PasswordRequirement.minLength =>
                                    l10n.passwordReqMinLength,
                                  PasswordRequirement.upper =>
                                    l10n.passwordReqUpper,
                                  PasswordRequirement.lower =>
                                    l10n.passwordReqLower,
                                  PasswordRequirement.digit =>
                                    l10n.passwordReqDigit,
                                  PasswordRequirement.special =>
                                    l10n.passwordReqSpecial,
                                },
                              )
                              .join(', '),
                        );
                      });
                      return;
                    }
                    if (passphrase != confirmController.text) {
                      setState(() => error = l10n.passwordsDoNotMatch);
                      return;
                    }
                  } else if (passphrase.isEmpty) {
                    setState(() => error = l10n.backupPassphraseRequired);
                    return;
                  }
                  Navigator.of(ctx).pop(passphrase);
                },
                child: Text(
                  confirm ? l10n.exportSettings : l10n.importSettings,
                ),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    passphraseController.dispose();
    confirmController.dispose();
  });
}
