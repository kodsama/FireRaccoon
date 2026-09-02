import 'package:flutter/material.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_theme.dart';
import '../utils/password_policy.dart';

/// Collects a backup passphrase for sealing or unlocking settings secrets.
Future<String?> showBackupPassphraseDialog({
  required BuildContext context,
  required bool confirm,
  String? confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) =>
        _PassphrasePrompt(confirm: confirm, confirmLabel: confirmLabel),
  );
}

/// Owns its controllers so they outlive the dialog's dismissal.
///
/// Disposing them when `showDialog`'s future completes is too early: the future
/// completes at pop time while the route is still animating out and the fields
/// still rebuild as focus leaves them, which reads a disposed controller.
class _PassphrasePrompt extends StatefulWidget {
  const _PassphrasePrompt({required this.confirm, this.confirmLabel});

  final bool confirm;

  /// What the accepting button says. The settings export named itself, and a
  /// backup asking for a password should not offer to export settings.
  final String? confirmLabel;

  @override
  State<_PassphrasePrompt> createState() => _PassphrasePromptState();
}

class _PassphrasePromptState extends State<_PassphrasePrompt> {
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  String _missingRequirements(PasswordPolicyResult policy) {
    final l10n = context.l10n;
    return l10n.passwordMissingRequirements(
      policy.missingRequirements
          .map(
            (r) => switch (r) {
              PasswordRequirement.minLength => l10n.passwordReqMinLength,
              PasswordRequirement.upper => l10n.passwordReqUpper,
              PasswordRequirement.lower => l10n.passwordReqLower,
              PasswordRequirement.digit => l10n.passwordReqDigit,
              PasswordRequirement.special => l10n.passwordReqSpecial,
            },
          )
          .join(', '),
    );
  }

  void _submit() {
    final l10n = context.l10n;
    final passphrase = _passphrase.text;
    if (widget.confirm) {
      final policy = validatePasswordPolicy(passphrase);
      if (!policy.isValid) {
        setState(() => _error = _missingRequirements(policy));
        return;
      }
      if (passphrase != _confirmation.text) {
        setState(() => _error = l10n.passwordsDoNotMatch);
        return;
      }
    } else if (passphrase.isEmpty) {
      setState(() => _error = l10n.backupPassphraseRequired);
      return;
    }
    Navigator.of(context).pop(passphrase);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final confirm = widget.confirm;

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
            controller: _passphrase,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.backupPassphrase,
              helperText: confirm ? l10n.passwordRequirements : null,
              helperMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: _obscure
                    ? l10n.backupPassphraseShow
                    : l10n.backupPassphraseHide,
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            onChanged: (_) => _clearError(),
          ),
          if (confirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmation,
              obscureText: _obscure,
              decoration: InputDecoration(labelText: l10n.confirmNewPassword),
              onChanged: (_) => _clearError(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.colors.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.confirmLabel ??
                (confirm ? l10n.exportSettings : l10n.importSettings),
          ),
        ),
      ],
    );
  }
}
