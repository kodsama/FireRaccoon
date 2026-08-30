import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extensions.dart';
import '../providers/theme_provider.dart';
import '../router/transaction_analytics_route.dart';
import '../utils/create_flows.dart';
import 'transaction_analytics_screen.dart';

class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fun = context.funL10n(ref.watch(themeProvider).isRaccoonMode);
    return TransactionAnalyticsScreen(
      title: fun.transfersTitle,
      route: transfersAnalyticsRoute,
      addButtonLabel: fun.newTransfer,
      onAdd: (ctx, r) => openNewTransactionFlow(
        ctx,
        r,
        type: 'transfer',
        invalidateTransactions: true,
      ),
    );
  }
}
