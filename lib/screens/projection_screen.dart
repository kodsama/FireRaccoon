import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'prognosis_screen.dart';

/// Projection screen: the balance forecast.
class ProjectionScreen extends StatelessWidget {
  const ProjectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.pageBg,
      body: const PrognosisView(),
    );
  }
}
