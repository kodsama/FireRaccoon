import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/mcp_port_provider.dart';
import '../theme/app_theme.dart';

/// Chooses where the MCP server starts looking for a free port.
///
/// The server already walks up from the base until one binds, so a taken port
/// is not a failure. What it cannot do is find a port somewhere else entirely,
/// and an agent is configured with a number, so the range has to be movable.
class McpPortField extends ConsumerStatefulWidget {
  const McpPortField({super.key});

  @override
  ConsumerState<McpPortField> createState() => _McpPortFieldState();
}

class _McpPortFieldState extends ConsumerState<McpPortField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${ref.read(mcpBasePortProvider)}',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final l10n = context.l10n;
    final parsed = int.tryParse(raw.trim());
    if (parsed == null ||
        parsed < kMinMcpBasePort ||
        parsed > kMaxMcpBasePort) {
      setState(
        () =>
            _error = l10n.mcpBasePortInvalid(kMinMcpBasePort, kMaxMcpBasePort),
      );
      return;
    }
    setState(() => _error = null);
    ref.read(mcpBasePortProvider.notifier).setBasePort(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    // Rewritten from the source of truth, so a reset or a clamp is reflected
    // rather than leaving the field showing what was typed.
    final current = ref.watch(mcpBasePortProvider);
    if (_controller.text != '$current' && _error == null) {
      _controller.text = '$current';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.mcpBasePortLabel,
                    isDense: true,
                    errorText: _error,
                  ),
                  onSubmitted: _submit,
                  onEditingComplete: () => _submit(_controller.text),
                ),
              ),
              const SizedBox(width: 8),
              if (current != kDefaultMcpBasePort)
                TextButton(
                  onPressed: () {
                    setState(() => _error = null);
                    ref.read(mcpBasePortProvider.notifier).reset();
                  },
                  child: Text(l10n.mcpBasePortReset),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.mcpBasePortHelp(kMcpPortRange),
            style: TextStyle(fontSize: 12, color: colors.text3),
          ),
        ],
      ),
    );
  }
}
