import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../utils/autocomplete_suggestions.dart';

/// Sentinel prefix used to distinguish "Create ..." entries from real
/// suggestions in the dropdown list.
const _createPrefix = '\u200B__create__\u200B';

/// Type-ahead text field backed by [flutter_typeahead].
///
/// Pass [tagMode] for comma-separated multi-value fields (e.g. tags).
///
/// When [onCreateNew] is set and the typed text does not exactly match any
/// suggestion, a "Create ..." item is appended to the dropdown. Selecting it
/// calls [onCreateNew] with the raw typed text.
class AutocompleteTextField extends StatelessWidget {
  const AutocompleteTextField({
    super.key,
    required this.controller,
    required this.suggestions,
    this.decoration,
    this.onChanged,
    this.onSelected,
    this.autofocus = false,
    this.maxLines = 1,
    this.keyboardType,
    this.readOnly = false,
    this.style,
    this.tagMode = false,
    this.obscureText = false,
    this.onSubmitted,
    this.showOnFocus = true,
    this.hideOnEmpty = false,
    this.emptyBuilder,
    this.onCreateNew,
    this.createLabel,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSelected;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool readOnly;
  final TextStyle? style;
  final bool tagMode;
  final bool obscureText;
  final bool showOnFocus;
  final bool hideOnEmpty;
  final WidgetBuilder? emptyBuilder;

  /// Called when the user selects the "Create ..." item. Receives the raw
  /// typed text. After the entity is created, callers should set [controller]
  /// text to the new name.
  final ValueChanged<String>? onCreateNew;

  /// Label template for the create item, e.g. `'Create payee'`. The typed
  /// text is appended in quotes. Defaults to `'Create'`.
  final String? createLabel;

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<String>(
      controller: controller,
      showOnFocus: showOnFocus,
      hideOnEmpty: hideOnEmpty && onCreateNew == null,
      emptyBuilder: onCreateNew != null ? null : emptyBuilder,
      suggestionsCallback: (pattern) {
        if (pattern.trim().isEmpty && emptyBuilder != null) {
          return [];
        }
        List<String> filtered;
        if (tagMode) {
          filtered = AutocompleteSuggestions.tagSuggestions(
            pattern,
            suggestions,
          );
        } else {
          filtered = AutocompleteSuggestions.filterContains(
            pattern,
            suggestions,
          );
        }

        if (onCreateNew != null && !tagMode) {
          final trimmed = pattern.trim();
          if (trimmed.isNotEmpty) {
            final exactMatch = filtered.any(
              (s) => s.toLowerCase() == trimmed.toLowerCase(),
            );
            if (!exactMatch) {
              final label = createLabel ?? 'Create';
              filtered = [...filtered, '$_createPrefix$label "$trimmed"'];
            }
          }
        }

        return filtered;
      },
      builder: (context, fieldController, focusNode) {
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          autofocus: autofocus,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          obscureText: obscureText,
          style: style,
          decoration: decoration,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        );
      },
      itemBuilder: (context, suggestion) {
        if (suggestion.startsWith(_createPrefix)) {
          final label = suggestion.substring(_createPrefix.length);
          return ListTile(
            dense: true,
            leading: const Icon(LucideIcons.plus, size: 16),
            title: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        return ListTile(dense: true, title: Text(suggestion));
      },
      onSelected: (suggestion) {
        if (suggestion.startsWith(_createPrefix)) {
          final typed = controller.text.trim();
          onCreateNew?.call(typed);
          return;
        }
        if (tagMode) {
          controller.text = AutocompleteSuggestions.applyTagSuggestion(
            currentValue: controller.text,
            selectedTag: suggestion,
          );
        } else {
          controller.text = suggestion;
        }
        onChanged?.call(controller.text);
        onSelected?.call(suggestion);
      },
    );
  }
}
