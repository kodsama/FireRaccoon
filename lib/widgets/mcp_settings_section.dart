import 'dart:convert';

import 'package:fireraccoon_engine/fireraccoon_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/agent_keys_provider.dart';
import '../providers/mcp_provider.dart';
import '../store/agent_key_store.dart';
import '../services/mcp_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_feedback.dart';
import 'small_loading_indicator.dart';

/// MCP server status and the agent keys that reach it.
///
/// A key is the credential an agent presents instead of a Firefly III token, so
/// this is where one is minted, identified, and revoked. The secret stays
/// readable afterwards, in the keychain that already holds the Firefly token:
/// a key nobody can read back is a key nobody can paste into a client.
class McpSettingsSection extends ConsumerWidget {
  const McpSettingsSection({super.key});

  static final _log = AppLogger.scoped('widgets.mcpSettings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final keys = ref.watch(agentKeysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mcpDesktopSupported) ...[
          _StatusTile(service: ref.watch(mcpServiceProvider)),
          const Divider(height: 1),
          _ConnectionDetails(service: ref.watch(mcpServiceProvider)),
          const Divider(height: 1),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            l10n.mcpAgentKeysHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        keys.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SmallLoadingIndicator(),
          ),
          error: (error, stackTrace) {
            final described = describeAgentKeyFailure(error);
            _log.severe(
              'Loading MCP agent keys failed: $described',
              error,
              stackTrace,
            );
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                described,
                style: TextStyle(color: context.colors.danger),
              ),
            );
          },
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    l10n.mcpNoAgentKeys,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final key in list)
                  _KeyTile(
                    view: key,
                    onReveal: () => _reveal(context, ref, key),
                    onRevoke: () => _revoke(context, ref, key),
                    onForget: () => _forget(context, ref, key),
                  ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: TextButton.icon(
                  icon: const Icon(Icons.key),
                  label: Text(l10n.mcpCreateKey),
                  onPressed: () => _create(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final label = await _promptForLabel(context);
    if (label == null || !context.mounted) return;

    final String secret;
    try {
      secret = await ref.read(agentKeysProvider.notifier).issue(label);
    } on Object catch (error, stackTrace) {
      _log.severe('Issuing MCP agent key failed', error, stackTrace);
      if (!context.mounted) return;
      showErrorToast(context, '$error');
      return;
    }
    if (!context.mounted) return;
    await _showKey(context, ref, label: label, secret: secret);
  }

  /// Reopens a key a person already has, so a mislaid one does not force a
  /// reissue.
  Future<void> _reveal(
    BuildContext context,
    WidgetRef ref,
    AgentKeyView view,
  ) async {
    final String? secret;
    try {
      secret = await ref.read(agentKeysProvider.notifier).revealSecret(view.id);
    } on Object catch (error, stackTrace) {
      _log.severe('Revealing MCP agent key failed', error, stackTrace);
      if (!context.mounted) return;
      showErrorToast(context, '$error');
      return;
    }
    if (!context.mounted) return;
    if (secret == null) {
      showErrorToast(context, context.l10n.mcpKeyNotRecoverable);
      return;
    }
    await _showKey(context, ref, label: view.label, secret: secret);
  }

  Future<String?> _promptForLabel(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const _LabelPrompt(),
    );
  }

  /// Shows a key and a handshake with it already filled in.
  ///
  /// Both copy targets live here because a bare secret still leaves the reader
  /// assembling a config by hand, which is where the placeholder never got
  /// replaced.
  Future<void> _showKey(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String secret,
  }) {
    final l10n = context.l10n;
    final service = ref.read(mcpServiceProvider);

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.mcpKeyIssuedBody),
              const SizedBox(height: 16),
              _CodeBlock(text: secret),
              // Issuing the very first key is what starts the server, so the
              // port is still unbound while this dialog builds. Reading it once
              // left the first key ever issued without a handshake to copy.
              ListenableBuilder(
                listenable: service,
                builder: (ctx, _) {
                  final port = service.port;
                  if (port == null) return const SizedBox.shrink();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        l10n.mcpCopyConnection,
                        style: Theme.of(ctx).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      _CodeBlock(
                        text: mcpConnectionSnippet(
                          port: port,
                          agentKey: secret,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(l10n.mcpCopyKey),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: secret));
              if (!ctx.mounted) return;
              showInfoToast(ctx, l10n.mcpKeyCopied);
            },
          ),
          ListenableBuilder(
            listenable: service,
            builder: (ctx, _) {
              final port = service.port;
              if (port == null) return const SizedBox.shrink();
              return TextButton.icon(
                icon: const Icon(Icons.content_copy),
                label: Text(l10n.mcpCopyConnection),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: mcpConnectionSnippet(port: port, agentKey: secret),
                    ),
                  );
                  if (!ctx.mounted) return;
                  showInfoToast(ctx, l10n.mcpConnectionCopied);
                },
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }

  /// Clears a revoked key's row. No confirmation: the key already stopped
  /// working when it was revoked, so this discards a record, not access.
  Future<void> _forget(
    BuildContext context,
    WidgetRef ref,
    AgentKeyView view,
  ) async {
    try {
      await ref.read(agentKeysProvider.notifier).forget(view.id);
    } on Object catch (error, stackTrace) {
      _log.severe('Forgetting MCP agent key failed', error, stackTrace);
      if (!context.mounted) return;
      showErrorToast(context, '$error');
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    AgentKeyView view,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mcpRevokeKeyTitle),
        content: Text(l10n.mcpRevokeKeyBody(view.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.mcpRevokeKey),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(agentKeysProvider.notifier).revoke(view.id);
    } on Object catch (error, stackTrace) {
      _log.severe('Revoking MCP agent key failed', error, stackTrace);
      if (!context.mounted) return;
      showErrorToast(context, '$error');
    }
  }
}

/// Placeholder used when no key is in hand to substitute.
const String _kKeyPlaceholder = 'PASTE_YOUR_AGENT_KEY';

/// A ready-to-paste client handshake for the server on [port].
///
/// [agentKey] is filled in whenever the caller holds the real secret, so what
/// gets copied works without further editing.
String mcpConnectionSnippet({required int port, String? agentKey}) {
  return const JsonEncoder.withIndent('  ').convert({
    'transport': 'tcp',
    'host': '127.0.0.1',
    'port': port,
    'initialize': {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-06-18',
        'apiKey': agentKey ?? _kKeyPlaceholder,
      },
    },
  });
}

/// Everything an MCP client needs to reach this app.
class _ConnectionDetails extends ConsumerWidget {
  const _ConnectionDetails({required this.service});

  final McpService service;

  static const _host = '127.0.0.1';
  static final _log = AppLogger.scoped('widgets.mcpConnection');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final port = service.port;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _detailRow(
              theme,
              l10n.mcpAddress,
              port == null ? l10n.mcpNotRunning : '$_host:$port',
            ),
            _detailRow(theme, l10n.mcpTransportLabel, l10n.mcpTransportTcp),
            _detailRow(
              theme,
              l10n.mcpAuthParameter,
              'initialize.params.apiKey',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: TextButton.icon(
                  icon: const Icon(Icons.content_copy),
                  label: Text(l10n.mcpCopyConnection),
                  onPressed: port == null
                      ? null
                      : () => _showConnection(context, ref, port),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Asks which key to fill in, then shows the whole handshake.
  ///
  /// Choosing a key is the point: a snippet with a placeholder still leaves the
  /// reader editing JSON by hand, which is where the key never actually got
  /// pasted in. "Without a key" stays available for sharing the shape of the
  /// config without the credential.
  Future<void> _showConnection(
    BuildContext context,
    WidgetRef ref,
    int port,
  ) async {
    final l10n = context.l10n;
    final keys = ref
        .read(agentKeysProvider)
        .asData
        ?.value
        .where((key) => key.isActive && key.hasSecret)
        .toList();

    final choice = await showDialog<AgentKeyView?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.mcpPickKeyTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.key_off),
              title: Text(l10n.mcpWithoutKey),
              subtitle: Text(_kKeyPlaceholder),
            ),
          ),
          for (final key in keys ?? const <AgentKeyView>[])
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(key),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.vpn_key),
                title: Text(key.label),
                subtitle: Text('${key.displayPrefix}…'),
              ),
            ),
        ],
      ),
    );
    if (!context.mounted) return;

    String? secret;
    if (choice != null) {
      try {
        secret = await ref
            .read(agentKeysProvider.notifier)
            .revealSecret(choice.id);
      } on Object catch (error, stackTrace) {
        _log.severe('Reading a key for the snippet failed', error, stackTrace);
        if (!context.mounted) return;
        showErrorToast(context, '$error');
        return;
      }
      if (!context.mounted) return;
      if (secret == null) {
        showErrorToast(context, l10n.mcpKeyNotRecoverable);
        return;
      }
    }

    final snippet = mcpConnectionSnippet(port: port, agentKey: secret);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mcpCopyConnection),
        content: SingleChildScrollView(child: _CodeBlock(text: snippet)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.content_copy),
            label: Text(l10n.mcpCopyKey),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: snippet));
              if (!ctx.mounted) return;
              showInfoToast(ctx, l10n.mcpConnectionCopied);
            },
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.service});

  final McpService service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    // The provider hands back one long-lived instance, so watching it does not
    // rebuild on a status change. Issuing a first key flips this tile from idle
    // to a bound port moments later, and that has to show without navigating
    // away and back.
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final statusColor = service.error != null
            ? colors.danger
            : service.running
            ? colors.success
            : colors.warning;
        return ListTile(
          leading: Icon(Icons.hub, color: statusColor),
          title: Text(l10n.mcpServer),
          subtitle: Text(mcpStatusLabel(l10n, service)),
          trailing: service.running ? Text(':${service.port}') : null,
        );
      },
    );
  }
}

class _KeyTile extends ConsumerWidget {
  const _KeyTile({
    required this.view,
    required this.onReveal,
    required this.onRevoke,
    required this.onForget,
  });

  final AgentKeyView view;
  final VoidCallback onReveal;
  final VoidCallback onRevoke;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dates = DateFormat.yMMMd();
    final owner = ref
        .watch(agentKeyPeopleProvider)
        .where((person) => person.id == view.personId)
        .firstOrNull;

    final lines = <String>[
      '${view.displayPrefix}…',
      if (owner != null) l10n.mcpKeyOwner(owner.name, owner.role),
      if (view.revokedAt != null)
        l10n.mcpKeyRevokedAt(dates.format(view.revokedAt!))
      else
        l10n.mcpKeyCreatedAt(dates.format(view.createdAt)),
      // Whether a client ever actually connected is the first thing anyone
      // debugging one wants to know.
      if (view.isActive)
        if (view.lastUsedAt case final at?)
          l10n.mcpKeyLastUsedAt(dates.format(at))
        else
          l10n.mcpKeyNeverUsed,
    ];

    return ListTile(
      dense: true,
      leading: Icon(
        view.isActive ? Icons.vpn_key : Icons.key_off,
        color: view.isActive
            ? theme.colorScheme.onSurfaceVariant
            : context.colors.danger,
      ),
      title: Text(
        view.label,
        style: view.isActive
            ? null
            : TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              ),
      ),
      subtitle: Text(lines.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: view.isActive
            ? [
                if (view.hasSecret)
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 18),
                    tooltip: l10n.mcpShowKey,
                    onPressed: onReveal,
                  ),
                TextButton(
                  onPressed: onRevoke,
                  child: Text(
                    l10n.mcpRevokeKey,
                    style: TextStyle(color: context.colors.danger),
                  ),
                ),
              ]
            : [
                // A revoked key is already powerless; this only clears the row.
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: l10n.mcpForgetKey,
                  color: context.colors.danger,
                  onPressed: onForget,
                ),
              ],
      ),
    );
  }
}

/// Asks for a label before a key is issued.
///
/// Stateful so the controller's lifetime matches the dialog's. Disposing it when
/// the dialog's future completes is too early: the dismiss animation still
/// rebuilds the TextField, and it throws "used after being disposed".
class _LabelPrompt extends StatefulWidget {
  const _LabelPrompt();

  @override
  State<_LabelPrompt> createState() => _LabelPromptState();
}

class _LabelPromptState extends State<_LabelPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.mcpCreateKey),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.mcpKeyLabel,
          hintText: l10n.mcpKeyLabelHint,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.create)),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
