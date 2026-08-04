import 'package:go_router/go_router.dart';

import 'route_query.dart';

class LiabilitiesRoute {
  static const path = '/liabilities';

  static String location({String? account, bool showInactive = false}) {
    return RouteQuery.build(path, {
      'account': account,
      'showInactive': showInactive ? 'true' : null,
    });
  }

  static String? accountFrom(GoRouterState state) => accountFromUri(state.uri);

  static String? accountFromUri(Uri uri) => RouteQuery.param(uri, 'account');

  static bool showInactiveFrom(GoRouterState state) =>
      showInactiveFromUri(state.uri);

  static bool showInactiveFromUri(Uri uri) =>
      RouteQuery.param(uri, 'showInactive') == 'true';
}
