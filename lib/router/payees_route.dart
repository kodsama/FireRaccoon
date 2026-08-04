import 'package:go_router/go_router.dart';

import 'route_query.dart';

class PayeesRoute {
  static const path = '/payees';

  static String location({String? search}) {
    return RouteQuery.build(path, {'search': search});
  }

  static String? searchFrom(GoRouterState state) =>
      RouteQuery.searchFrom(state.uri);
}
