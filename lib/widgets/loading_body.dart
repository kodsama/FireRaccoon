import 'package:flutter/material.dart';

/// The spinner a screen shows while its data is on the way.
///
/// Shown on a retry as well as a first load: a screen that keeps the failure
/// from last time on show while it is already asking again reads as stuck, and
/// after connecting a server that is exactly when someone is watching.
class LoadingBody extends StatelessWidget {
  const LoadingBody({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 24 : 40),
        child: const CircularProgressIndicator(),
      ),
    );
  }
}
