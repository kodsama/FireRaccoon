import 'package:flutter/material.dart';

import '../l10n/l10n_extensions.dart';

/// Asks for filter words, starting from [words]. Answers the words typed,
/// an empty string for Clear, or `null` when dismissed.
Future<String?> showWordsFilterDialog(BuildContext context, {String? words}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _WordsFilterDialog(words: words),
    );

class _WordsFilterDialog extends StatefulWidget {
  final String? words;

  const _WordsFilterDialog({required this.words});

  @override
  State<_WordsFilterDialog> createState() => _WordsFilterDialogState();
}

class _WordsFilterDialogState extends State<_WordsFilterDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.words,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.filterWords),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.filterWordsHint),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text(l10n.clear),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.applyFilter),
        ),
      ],
    );
  }
}
