import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'budget_form_dialog.dart';

Future<bool?> showBudgetCreateDialog({
  required BuildContext context,
  required WidgetRef ref,
  String? initialName,
}) {
  return showBudgetFormDialog(
    context: context,
    ref: ref,
    initialName: initialName,
  );
}
