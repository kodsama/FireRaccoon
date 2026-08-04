import 'package:go_router/go_router.dart';

import 'route_query.dart';

enum AccountTypeFilter {
  all,
  asset,
  savings,
  creditCard,
  investment,
  liability,
}

class AccountsRoute {
  static const path = '/accounts';

  static String location({
    AccountTypeFilter type = AccountTypeFilter.all,
    String? account,
    bool showInactive = false,
  }) {
    return RouteQuery.build(path, {
      'type': type != AccountTypeFilter.all ? type.name : null,
      'account': account,
      'showInactive': showInactive ? 'true' : null,
    });
  }

  static String? accountFrom(GoRouterState state) =>
      RouteQuery.param(state.uri, 'account');

  static AccountTypeFilter typeFrom(GoRouterState state) =>
      typeFromUri(state.uri);

  static AccountTypeFilter typeFromUri(Uri uri) {
    return RouteQuery.enumFrom(
      uri,
      'type',
      AccountTypeFilter.values,
      AccountTypeFilter.all,
    );
  }

  static bool showInactiveFrom(GoRouterState state) =>
      showInactiveFromUri(state.uri);

  static bool showInactiveFromUri(Uri uri) =>
      RouteQuery.param(uri, 'showInactive') == 'true';
}
