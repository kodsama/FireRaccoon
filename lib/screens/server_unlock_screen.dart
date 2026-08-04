import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/server_session_provider.dart';

/// Server-mode storage gate.
///
/// - Empty DATA_DIR: one-time create (password + confirm). After that, set
///   `DATA_PASSWORD` so restarts unlock automatically.
/// - Existing locked DATA_DIR: do **not** ask end users for the storage
///   password — instruct the operator to set `DATA_PASSWORD` (with an
///   emergency unlock for recovery).
class ServerUnlockScreen extends ConsumerStatefulWidget {
  const ServerUnlockScreen({super.key});

  @override
  ConsumerState<ServerUnlockScreen> createState() => _ServerUnlockScreenState();
}

class _ServerUnlockScreenState extends ConsumerState<ServerUnlockScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _showEmergencyUnlock = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit({
    required bool creating,
    String? confirmPassword,
  }) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(serverSessionProvider.notifier)
          .unlockStore(
            password: _password.text,
            confirmPassword: confirmPassword,
          );
      if (!mounted) return;
      context.go('/');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(serverSessionProvider);

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text('Could not reach server: $error'))),
      data: (session) {
        final storeExists = session?.storeExists ?? false;
        if (storeExists) {
          return _buildNeedsEnvPassword(theme);
        }
        return _buildCreateForm(theme);
      },
    );
  }

  /// Existing encrypted volume: unlock via DATA_PASSWORD on boot.
  Widget _buildNeedsEnvPassword(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text('Storage locked', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Encrypted data was found on this server. Set '
                    'DATA_PASSWORD in your Docker Compose (or secrets) to '
                    'the storage password and restart the container. After '
                    'that, users only sign in with their own account password.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    'environment:\n'
                    '  DATA_PASSWORD: your-storage-password',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(
                      () => _showEmergencyUnlock = !_showEmergencyUnlock,
                    ),
                    child: Text(
                      _showEmergencyUnlock
                          ? 'Hide emergency unlock'
                          : 'Emergency unlock (operator)',
                    ),
                  ),
                  if (_showEmergencyUnlock) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Unlocks this process only. Prefer DATA_PASSWORD '
                      'so the next restart does not need this again.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Storage password',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submit(creating: false),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _submitting
                          ? null
                          : () => _submit(creating: false),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock once'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// First boot with empty DATA_DIR and no DATA_PASSWORD.
  Widget _buildCreateForm(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Create encrypted storage',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No encrypted data was found. Choose a storage password, '
                    'then set the same value as DATA_PASSWORD in Compose '
                    'so restarts unlock automatically. Users will only enter '
                    'their account password after that.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'New storage password',
                      helperText: 'At least 10 characters',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                    ),
                    onSubmitted: (_) =>
                        _submit(creating: true, confirmPassword: _confirm.text),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting
                        ? null
                        : () => _submit(
                            creating: true,
                            confirmPassword: _confirm.text,
                          ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create storage'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
