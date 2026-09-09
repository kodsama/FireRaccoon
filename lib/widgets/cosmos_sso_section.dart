import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/auth_provider.dart';
import '../providers/cosmos_gate_provider.dart';
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
      final session = await login.signIn(context, routeUrl);
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
    final renewing = ref.watch(cosmosGateProvider) == CosmosGate.renewing;
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
                    renewing
                        ? l10n.cosmosSsoRenewing
                        : session == null
                        ? l10n.cosmosSsoNotSignedIn
                        : l10n.cosmosSsoSignedIn(session.host),
                    style: TextStyle(
                      fontSize: 13,
                      color: session == null ? colors.text3 : colors.success,
                    ),
                  ),
                ),
                if (renewing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (session != null)
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
            if (session == null && !renewing && !login.isSupported) ...[
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

/// Starts the Cosmos sign-in from wherever it is needed, such as the connection
/// dialog that has just met a Cosmos sign-in page.
class CosmosSignInButton extends ConsumerStatefulWidget {
  const CosmosSignInButton({
    super.key,
    required this.serverUrl,
    this.onSignedIn,
    this.login,
  });

  final String serverUrl;
  final VoidCallback? onSignedIn;

  /// Injected by tests. Left null in the app so the platform decides.
  final CosmosLogin? login;

  @override
  ConsumerState<CosmosSignInButton> createState() => _CosmosSignInButtonState();
}

class _CosmosSignInButtonState extends ConsumerState<CosmosSignInButton> {
  bool _signingIn = false;
  String? _failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final login = widget.login ?? resolveCosmosLogin();
    final routeUrl = Uri.tryParse(widget.serverUrl);
    if (routeUrl == null || routeUrl.host.isEmpty || !login.isSupported) {
      return const SizedBox.shrink();
    }

    final button = FilledButton.icon(
      onPressed: _signingIn
          ? null
          : () async {
              setState(() {
                _signingIn = true;
                _failure = null;
              });
              try {
                final session = await login.signIn(context, routeUrl);
                if (session == null) return;
                await ref
                    .read(cosmosSessionProvider.notifier)
                    .signedIn(session);
                widget.onSignedIn?.call();
              } on Object catch (error) {
                // A window that never opened is not a decision the person
                // made, so it has to be said rather than swallowed.
                if (mounted) setState(() => _failure = '$error');
              } finally {
                if (mounted) setState(() => _signingIn = false);
              }
            },
      icon: _signingIn
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.shield_outlined, size: 18),
      label: Text(l10n.cosmosSsoSignInAction),
    );

    final failure = _failure;
    if (failure == null) return button;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        button,
        const SizedBox(height: 8),
        Text(
          failure,
          style: TextStyle(fontSize: 12, color: context.colors.text),
        ),
      ],
    );
  }
}
