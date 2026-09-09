import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counts the times the Firefly connection has come back.
///
/// Watched by everything Firefly-backed, so a load that failed while the
/// server was away runs again instead of leaving the failure on screen after
/// the sidebar has gone back to saying connected.
///
/// Pushed into by the connection poll rather than read from it. The poll owns
/// a timer and makes real requests; having every data provider watch it
/// directly started a poll in every test that read one, and turned the suite
/// into twenty minutes of them.
class FireflyReconnectNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// The connection settled as working after having settled as broken.
  void reconnected() => state = state + 1;
}

final fireflyReconnectProvider =
    NotifierProvider<FireflyReconnectNotifier, int>(
      FireflyReconnectNotifier.new,
    );
