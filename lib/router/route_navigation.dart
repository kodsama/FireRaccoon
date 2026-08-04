import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_query.dart';

extension RouteNavigation on BuildContext {
  void goPreservingSearch(String destination) {
    go(RouteQuery.preserveSearch(GoRouterState.of(this).uri, destination));
  }
}
