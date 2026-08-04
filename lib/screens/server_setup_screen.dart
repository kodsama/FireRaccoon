import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/server_session_provider.dart';

/// First-boot admin setup for Docker / server mode.
class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _adminName = TextEditingController();
  final _adminPassword = TextEditingController();
  final _fireflyUrl = TextEditingController();
  final _fireflyToken = TextEditingController();
  bool _allowInsecure = false;
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _adminName.dispose();
    _adminPassword.dispose();
    _fireflyUrl.dispose();
    _fireflyToken.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(serverSessionProvider.notifier)
          .setup(
            adminName: _adminName.text.trim(),
            adminPassword: _adminPassword.text,
            fireflyUrl: _fireflyUrl.text.trim(),
            fireflyToken: _fireflyToken.text.trim(),
            allowInsecure: _allowInsecure,
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
                    'FireRacoon server setup',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create the first admin and connect Firefly III. '
                    'App data is stored encrypted on the server volume.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _adminName,
                    decoration: const InputDecoration(labelText: 'Admin name'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _adminPassword,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Admin password',
                      helperText: 'Min 10 characters',
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
                    controller: _fireflyUrl,
                    decoration: const InputDecoration(
                      labelText: 'Firefly III URL',
                      hintText: 'https://firefly.example',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fireflyToken,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Firefly personal access token',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow insecure HTTP'),
                    value: _allowInsecure,
                    onChanged: (v) => setState(() => _allowInsecure = v),
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
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create admin and connect'),
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
