import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../models/people_models.dart';
import '../providers/people_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/fun_decorated_surface.dart';
import '../widgets/person_avatar.dart';

/// Shown before the app shell whenever people exist and there is no active
/// (or no longer trusted, per `requirePasswordLogin`) session.
///
/// When password login is on: name + password (and optional biometrics).
/// When off: a tappable list of people.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _biometricsAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareBiometrics());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _prepareBiometrics() async {
    final state = ref.read(peopleProvider);
    if (!state.requirePasswordLogin) return;
    final last = state.lastSessionPerson;
    if (last != null && _nameController.text.isEmpty) {
      _nameController.text = last.name;
    }
    final available = await ref
        .read(peopleProvider.notifier)
        .biometricAuth
        .isAvailable;
    if (!mounted) return;
    setState(() => _biometricsAvailable = available);
    if (available && state.canUnlockWithBiometrics) {
      await _unlockWithBiometrics();
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    if (name.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.loginMissingFields);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final person = await ref
        .read(peopleProvider.notifier)
        .login(name, password);
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (person == null) _error = l10n.loginInvalidCredentials;
    });
  }

  Future<void> _unlockWithBiometrics() async {
    final l10n = context.l10n;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final person = await ref
        .read(peopleProvider.notifier)
        .loginWithBiometrics(localizedReason: l10n.biometricUnlockReason);
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (person == null) _error = l10n.biometricUnlockFailed;
    });
  }

  Future<void> _selectPerson(Person person) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final selected = await ref
        .read(peopleProvider.notifier)
        .selectPerson(person.id);
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (selected == null) _error = context.l10n.loginInvalidCredentials;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final peopleState = ref.watch(peopleProvider);
    if (!peopleState.requirePasswordLogin) {
      return _buildPersonPicker(context, peopleState.people);
    }

    final canBiometric =
        _biometricsAvailable && peopleState.canUnlockWithBiometrics;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FunLogo(width: 72, height: 72),
                const SizedBox(height: 16),
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.loginSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.text2, fontSize: 13),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.username),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: colors.danger, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.login),
                  ),
                ),
                if (canBiometric) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isSubmitting ? null : _unlockWithBiometrics,
                    icon: const Icon(LucideIcons.fingerprint, size: 18),
                    label: Text(l10n.unlockWithBiometrics),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonPicker(BuildContext context, List<Person> people) {
    final l10n = context.l10n;
    final colors = context.colors;
    final lastId = ref.watch(peopleProvider).lastSessionPersonId;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FunLogo(width: 72, height: 72),
                const SizedBox(height: 16),
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.selectUserSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.text2, fontSize: 13),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: colors.danger, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                ],
                ...people.map((person) {
                  final isLast = person.id == lastId;
                  return Card(
                    child: ListTile(
                      leading: PersonAvatar(person: person, radius: 22),
                      title: Text(person.name),
                      subtitle: Text(
                        person.role == PersonRole.admin
                            ? l10n.roleAdmin
                            : person.role == PersonRole.user
                            ? l10n.roleUser
                            : l10n.roleViewer,
                      ),
                      trailing: isLast
                          ? Icon(
                              LucideIcons.check,
                              size: 18,
                              color: colors.accent.acc,
                            )
                          : null,
                      onTap: _isSubmitting ? null : () => _selectPerson(person),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
