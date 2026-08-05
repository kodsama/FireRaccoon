import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/data_providers.dart';
import '../providers/theme_provider.dart';
import '../router/categories_tags_route.dart';
import '../router/route_query.dart';
import '../router/transactions_route.dart';
import '../theme/app_theme.dart';
import '../widgets/category_form_dialog.dart';
import '../widgets/tag_form_dialog.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/entity_header_actions.dart';
import '../widgets/entity_linking_dialog.dart';
import '../widgets/entity_list_layout.dart';
import '../widgets/entity_screen_header.dart';

class CategoriesTagsScreen extends ConsumerWidget {
  const CategoriesTagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final state = GoRouterState.of(context);
    final activeTab = CategoriesTagsRoute.tabFrom(state);
    final searchQuery = RouteQuery.searchFrom(state.uri) ?? '';

    final categoriesAsync = ref.watch(categoriesProvider);
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntityScreenHeader(
              title: 'Categories & Tags',
              subtitle: 'Organize your spending by category and custom tags.',
              createLabel: activeTab == CategoriesTagsTab.categories
                  ? 'New Category'
                  : 'New Tag',
              onCreate: () {
                if (activeTab == CategoriesTagsTab.categories) {
                  showCategoryFormDialog(context: context, ref: ref);
                } else {
                  showTagFormDialog(context: context, ref: ref);
                }
              },
              trailing: [
                _CategoriesTagsSearchBox(
                  searchQuery: searchQuery,
                  uri: GoRouterState.of(context).uri,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Tab Selector
            Row(
              children: [
                SegmentedButton<CategoriesTagsTab>(
                  segments: const [
                    ButtonSegment(
                      value: CategoriesTagsTab.categories,
                      label: Text('Categories'),
                      icon: Icon(LucideIcons.folder, size: 16),
                    ),
                    ButtonSegment(
                      value: CategoriesTagsTab.tags,
                      label: Text('Tags'),
                      icon: Icon(LucideIcons.tag, size: 16),
                    ),
                  ],
                  selected: {activeTab},
                  onSelectionChanged: (newSelection) {
                    final tab = newSelection.first;
                    context.go(
                      CategoriesTagsRoute.location(
                        tab: tab,
                        search: searchQuery.isNotEmpty ? searchQuery : null,
                      ),
                    );
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? colors.accent.acc
                          : colors.surface,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.white
                          : colors.text2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (activeTab == CategoriesTagsTab.categories)
              categoriesAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) =>
                    Center(child: Text(l10n.errorGeneric(e.toString()))),
                data: (categories) {
                  final filtered = categories
                      .where(
                        (c) =>
                            searchQuery.isEmpty ||
                            c.name.toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            ),
                      )
                      .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          searchQuery.isEmpty
                              ? 'No categories found. Create your first category!'
                              : 'No categories matching "$searchQuery".',
                          style: TextStyle(color: colors.text3, fontSize: 14),
                        ),
                      ),
                    );
                  }
                  return EntityListLayout(
                    gridItems: filtered
                        .map((c) => _CategoryCard(category: c))
                        .toList(),
                    compactItems: filtered
                        .map((c) => _CategoryRow(category: c))
                        .toList(),
                  );
                },
              )
            else
              tagsAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) =>
                    Center(child: Text(l10n.errorGeneric(e.toString()))),
                data: (tags) {
                  final filtered = tags
                      .where(
                        (t) =>
                            searchQuery.isEmpty ||
                            t.name.toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            ),
                      )
                      .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          searchQuery.isEmpty
                              ? 'No tags found. Create your first tag!'
                              : 'No tags matching "$searchQuery".',
                          style: TextStyle(color: colors.text3, fontSize: 14),
                        ),
                      ),
                    );
                  }
                  return EntityListLayout(
                    gridItems: filtered.map((t) => _TagCard(tag: t)).toList(),
                    compactItems: filtered.map((t) => _TagRow(tag: t)).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final Category category;
  const _CategoryCard({required this.category});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Category',
      message:
          'Are you sure you want to delete the category "${category.name}"? It will be removed from all transactions.',
      confirmLabel: 'Delete Category',
    );
    if (confirmed == true) {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        try {
          await service.deleteCategory(category.id);
          ref.invalidate(categoriesProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete category: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Card(
      color: colors.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: () =>
            context.go(TransactionsRoute.location(category: category.name)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.accent.acc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.folder,
                      color: colors.accent.acc,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  EntityHeaderActions(
                    onLink: () => showEntityLinkingDialog(
                      context: context,
                      ref: ref,
                      sourceType: EntityLinkingSourceType.category,
                      sourceName: category.name,
                    ),
                    onEdit: () => showCategoryFormDialog(
                      context: context,
                      ref: ref,
                      category: category,
                    ),
                    onDelete: () => _delete(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  final Category category;
  const _CategoryRow({required this.category});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Category',
      message:
          'Are you sure you want to delete the category "${category.name}"? It will be removed from all transactions.',
      confirmLabel: 'Delete Category',
    );
    if (confirmed == true) {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        try {
          await service.deleteCategory(category.id);
          ref.invalidate(categoriesProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete category: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.go(TransactionsRoute.location(category: category.name)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.folder, color: colors.accent.acc, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontFamily: 'Comfortaa',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colors.text,
                  ),
                ),
              ),
              EntityHeaderActions(
                onLink: () => showEntityLinkingDialog(
                  context: context,
                  ref: ref,
                  sourceType: EntityLinkingSourceType.category,
                  sourceName: category.name,
                ),
                onEdit: () => showCategoryFormDialog(
                  context: context,
                  ref: ref,
                  category: category,
                ),
                onDelete: () => _delete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagCard extends ConsumerWidget {
  final Tag tag;
  const _TagCard({required this.tag});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Tag',
      message:
          'Are you sure you want to delete the tag "${tag.name}"? It will be removed from all transactions.',
      confirmLabel: 'Delete Tag',
    );
    if (confirmed == true) {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        try {
          await service.deleteTag(tag.id);
          ref.invalidate(tagsProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to delete tag: $e')));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Card(
      color: colors.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: () => context.go(
          RouteQuery.build(TransactionsRoute.path, {'q': tag.name}),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.accent.hi.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.tag,
                      color: colors.accent.hi,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '#${tag.name}',
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  EntityHeaderActions(
                    onLink: () => showEntityLinkingDialog(
                      context: context,
                      ref: ref,
                      sourceType: EntityLinkingSourceType.tag,
                      sourceName: tag.name,
                    ),
                    onEdit: () =>
                        showTagFormDialog(context: context, ref: ref, tag: tag),
                    onDelete: () => _delete(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagRow extends ConsumerWidget {
  final Tag tag;
  const _TagRow({required this.tag});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Tag',
      message:
          'Are you sure you want to delete the tag "${tag.name}"? It will be removed from all transactions.',
      confirmLabel: 'Delete Tag',
    );
    if (confirmed == true) {
      final service = ref.read(apiServiceProvider);
      if (service != null) {
        try {
          await service.deleteTag(tag.id);
          ref.invalidate(tagsProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to delete tag: $e')));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(
          RouteQuery.build(TransactionsRoute.path, {'q': tag.name}),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.tag, color: colors.accent.hi, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '#${tag.name}',
                  style: TextStyle(
                    fontFamily: 'Comfortaa',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colors.text,
                  ),
                ),
              ),
              EntityHeaderActions(
                onLink: () => showEntityLinkingDialog(
                  context: context,
                  ref: ref,
                  sourceType: EntityLinkingSourceType.tag,
                  sourceName: tag.name,
                ),
                onEdit: () =>
                    showTagFormDialog(context: context, ref: ref, tag: tag),
                onDelete: () => _delete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoriesTagsSearchBox extends ConsumerStatefulWidget {
  final String searchQuery;
  final Uri uri;

  const _CategoriesTagsSearchBox({
    required this.searchQuery,
    required this.uri,
  });

  @override
  ConsumerState<_CategoriesTagsSearchBox> createState() =>
      _CategoriesTagsSearchBoxState();
}

class _CategoriesTagsSearchBoxState
    extends ConsumerState<_CategoriesTagsSearchBox> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _CategoriesTagsSearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text &&
        widget.searchQuery != oldWidget.searchQuery) {
      _controller.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    context.go(RouteQuery.withSearch(widget.uri, val));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);

    return SizedBox(
      width: 220,
      height: 36,
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        style: TextStyle(color: colors.text, fontSize: 13),
        decoration: InputDecoration(
          hintText: fun.search,
          hintStyle: TextStyle(color: colors.text3, fontSize: 13),
          prefixIcon: Icon(LucideIcons.search, size: 15, color: colors.text3),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x, size: 14, color: colors.text3),
                  onPressed: () {
                    _controller.clear();
                    _onSearchChanged('');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          filled: true,
          fillColor: colors.surface2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.accent.acc, width: 1.5),
          ),
        ),
      ),
    );
  }
}
