import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'autocomplete_text_field.dart';

/// The tags on one journal, as chips over the comma-joined text a form saves.
///
/// The value stays in [controller] in the shape the save path already reads,
/// so nothing outside has to know: only the look changes. A plain text field
/// made the separator the person's problem, and taking one tag away meant
/// editing a string in the middle.
class TagInputField extends StatefulWidget {
  const TagInputField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.label,
    required this.addHint,
  });

  final TextEditingController controller;

  /// Every tag the ledger knows, for the box that adds one.
  final List<String> suggestions;
  final String label;

  /// Placeholder on the add box, e.g. "Add a tag".
  final String addHint;

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  final _entry = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _entry.dispose();
    super.dispose();
  }

  /// A tag typed and left sitting there is one the person meant to add.
  /// Waiting for Enter alone threw it away when the form was saved.
  void _onFocusChanged() {
    if (!_focus.hasFocus) {
      _add(_entry.text);
      return;
    }
    setState(() {});
  }

  List<String> get _tags => [
    for (final tag in widget.controller.text.split(','))
      if (tag.trim().isNotEmpty) tag.trim(),
  ];

  void _write(List<String> tags) {
    widget.controller.text = tags.join(', ');
    if (mounted) setState(() {});
  }

  void _add(String raw) {
    final tag = raw.trim();
    _entry.clear();
    final tags = _tags;
    if (tag.isEmpty ||
        tags.any((existing) => existing.toLowerCase() == tag.toLowerCase())) {
      // Nothing to add, but the box emptied, so the field still repaints.
      if (mounted) setState(() {});
      return;
    }
    _write([...tags, tag]);
  }

  void _remove(String tag) => _write([
    for (final existing in _tags)
      if (existing != tag) existing,
  ]);

  /// Tapping a chip takes it back into the box, which is how a typo gets fixed
  /// without retyping the rest of them.
  void _edit(String tag) {
    _remove(tag);
    _entry.text = tag;
    _entry.selection = TextSelection.collapsed(offset: tag.length);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tags = _tags;
    final carried = {for (final tag in tags) tag.toLowerCase()};
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      // The add box is always there, so the label belongs above the field
      // rather than sitting in it as a placeholder.
      isEmpty: false,
      isFocused: _focus.hasFocus,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final tag in tags)
            InputChip(
              label: Text(tag),
              onPressed: () => _edit(tag),
              onDeleted: () => _remove(tag),
              // The app's own cross, rather than whichever one the Material
              // version in use happens to default to.
              deleteIcon: const Icon(LucideIcons.x, size: 14),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          SizedBox(
            width: 132,
            child: AutocompleteTextField(
              controller: _entry,
              focusNode: _focus,
              hideOnEmpty: true,
              suggestions: [
                for (final suggestion in widget.suggestions)
                  if (!carried.contains(suggestion.toLowerCase())) suggestion,
              ],
              decoration: InputDecoration.collapsed(hintText: widget.addHint),
              onSelected: _add,
              onSubmitted: _add,
            ),
          ),
        ],
      ),
    );
  }
}
