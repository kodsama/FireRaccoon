import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/auth_provider.dart';
import '../providers/cosmos_session_provider.dart';
import '../store/cosmos_login.dart';
import '../store/cosmos_login_factory.dart';
import '../theme/app_theme.dart';

/// Signs in to a Cosmos Cloud route that stands in front of Firefly.
///
/// Only shown once a server is configured: the session is minted for that
/// route's host, so there is nothing to sign in to before one is known.
class CosmosSsoSection extends ConsumerStatefulWidget {
  const CosmosSsoSection({super.key, this.login});

  /// Injected by tests. Left null in the app so the platform decides.
  final CosmosLogin? login;

  @override
  ConsumerState<CosmosSsoSection> createState() => _CosmosSsoSectionState();
}

class _CosmosSsoSectionState extends ConsumerState<CosmosSsoSection> {
  bool _signingIn = false;

  Future<void> _signIn(Uri routeUrl) async {
    final login = widget.login ?? resolveCosmosLogin();
    setState(() => _signingIn = true);
    try {
      final session = await login.signIn(routeUrl);
      if (session == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.cosmosSsoCancelled)),
        );
        return;
      }
      await ref.read(cosmosSessionProvider.notifier).signedIn(session);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final serverUrl = ref.watch(authProvider).serverUrl;
    if (serverUrl.isEmpty) return const SizedBox.shrink();
    final routeUrl = Uri.tryParse(serverUrl);
    if (routeUrl == null || routeUrl.host.isEmpty) {
      return const SizedBox.shrink();
    }

    final session = ref.watch(cosmosSessionProvider);
    final login = widget.login ?? resolveCosmosLogin();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: colors.text2),
                const SizedBox(width: 8),
                Text(
                  l10n.cosmosSsoTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.cosmosSsoExplainer,
              style: TextStyle(fontSize: 12, height: 1.4, color: colors.text2),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    session == null
                        ? l10n.cosmosSsoNotSignedIn
                        : l10n.cosmosSsoSignedIn(session.host),
                    style: TextStyle(
                      fontSize: 13,
                      color: session == null ? colors.text3 : colors.success,
                    ),
                  ),
                ),
                if (session != null)
                  TextButton(
                    onPressed: () =>
                        ref.read(cosmosSessionProvider.notifier).signedOut(),
                    child: Text(l10n.cosmosSsoSignOut),
                  )
                else if (login.isSupported)
                  FilledButton(
                    onPressed: _signingIn ? null : () => _signIn(routeUrl),
                    child: _signingIn
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.cosmosSsoSignIn),
                  ),
              ],
            ),
            if (session == null && !login.isSupported) ...[
              const SizedBox(height: 6),
              Text(
                // On web the browser is already carrying the cookie, which is
                // a different thing from the flow being unavailable.
                kIsWeb ? l10n.cosmosSsoWebNote : l10n.cosmosSsoUnsupported,
                style: TextStyle(fontSize: 12, color: colors.text3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
