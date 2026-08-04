import 'package:go_router/go_router.dart';

import '../providers/undo_history_provider.dart';
import 'route_query.dart';

class HistoryRoute {
  static const path = '/history';

  static String location({String? search, UndoActionType? type}) {
    return RouteQuery.build(path, {'search': search, 'type': type?.name});
  }

  static String? searchFrom(GoRouterState state) =>
      RouteQuery.searchFrom(state.uri);

  static UndoActionType? typeFrom(GoRouterState state) =>
      typeFromUri(state.uri);

  static UndoActionType? typeFromUri(Uri uri) {
    final typeName = RouteQuery.param(uri, 'type');
    if (typeName == null || typeName.isEmpty) return null;
    return UndoActionType.values.where((t) => t.name == typeName).firstOrNull;
  }
}
