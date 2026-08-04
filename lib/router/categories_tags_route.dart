import 'package:go_router/go_router.dart';

import 'route_query.dart';

enum CategoriesTagsTab { categories, tags }

class CategoriesTagsRoute {
  static const path = '/categories-tags';

  static String location({
    CategoriesTagsTab tab = CategoriesTagsTab.categories,
    String? search,
  }) {
    return RouteQuery.build(path, {
      'tab': tab != CategoriesTagsTab.categories ? tab.name : null,
      'search': search,
    });
  }

  static CategoriesTagsTab tabFrom(GoRouterState state) =>
      tabFromUri(state.uri);

  static CategoriesTagsTab tabFromUri(Uri uri) {
    return RouteQuery.enumFrom(
      uri,
      'tab',
      CategoriesTagsTab.values,
      CategoriesTagsTab.categories,
    );
  }

  static String? searchFrom(GoRouterState state) =>
      RouteQuery.searchFrom(state.uri);
}
