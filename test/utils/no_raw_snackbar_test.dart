import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the rule that failures and confirmations go through `app_feedback`.
///
/// A SnackBar draws inside its Scaffold, which is beneath any dialog route and
/// its scrim, so a message raised from a dialog is invisible exactly when it
/// matters. This was fixed once for transaction saves and grew back everywhere
/// else, which is what a rule nobody can see coming looks like.
void main() {
  test('no screen or widget reaches for a SnackBar directly', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('utils/app_feedback.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('showSnackBar')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These raise feedback through ScaffoldMessenger, which draws under a '
          'modal barrier. Use showInfoToast, showErrorToast or reportError '
          'from utils/app_feedback.dart instead:\n${offenders.join('\n')}',
    );
  });
}
