import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fireracoon_engine/fireracoon_engine.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/l10n_extensions.dart';
import '../theme/app_theme.dart';
import '../utils/locale_formatting.dart';

/// Optional credit-card payback fields shown during balance-check reconcile.
class CreditCardPaybackFields {
  const CreditCardPaybackFields({
    required this.paymentAccounts,
    required this.selectedPaymentAccountId,
    required this.onPaymentAccountChanged,
    required this.paybackDate,
    required this.onPaybackDateChanged,
    required this.paybackTotal,
    required this.hasEligiblePurchases,
  });

  final List<Account> paymentAccounts;
  final String? selectedPaymentAccountId;
  final ValueChanged<String?> onPaymentAccountChanged;
  final DateTime paybackDate;
  final ValueChanged<DateTime> onPaybackDateChanged;
  final double paybackTotal;
  final bool hasEligiblePurchases;

  bool get isReady =>
      hasEligiblePurchases &&
      selectedPaymentAccountId != null &&
      paymentAccounts.any((account) => account.id == selectedPaymentAccountId);

  Account? get selectedPaymentAccount {
    final id = selectedPaymentAccountId;
    if (id == null) return null;
    for (final account in paymentAccounts) {
      if (account.id == id) return account;
    }
    return null;
  }
}

/// Compares a user-entered statement balance against the expected ledger balance.
class AccountBalanceCheckPanel extends StatefulWidget {
  const AccountBalanceCheckPanel({
    super.key,
    required this.expectedBalance,
    required this.currencySymbol,
    required this.format,
    this.compact = false,
    this.expectedBalanceLabel,
    this.onReconcile,
    this.isReconciling = false,
    this.hasPendingReconcileWork = true,
    this.reconcileLabel,
    this.creditCardPayback,
  });

  final double expectedBalance;
  final String currencySymbol;
  final LocaleFormatting format;
  final bool compact;
  final String? expectedBalanceLabel;
  final VoidCallback? onReconcile;
  final bool isReconciling;

  /// False when the current selection would not change any reconcile flags.
  final bool hasPendingReconcileWork;
  final String? reconcileLabel;
  final CreditCardPaybackFields? creditCardPayback;

  @override
  State<AccountBalanceCheckPanel> createState() =>
      _AccountBalanceCheckPanelState();
}

class _AccountBalanceCheckPanelState extends State<AccountBalanceCheckPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Rebuild so hintText can clear on focus. On web, Flutter's hint and the
    // DOM input placeholder both paint when styles diverge, ghosting the text.
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final result = compareBalances(
      expected: widget.expectedBalance,
      enteredText: _controller.text,
    );
    final payback = widget.creditCardPayback;
    final canReconcile =
        result.isMatch &&
        widget.onReconcile != null &&
        widget.hasPendingReconcileWork &&
        (payback == null || payback.isReady);

    final status = _statusFor(result, colors, l10n);
    final fieldStyle = TextStyle(
      fontFamily: AppTypography.figureFont,
      fontWeight: FontWeight.w600,
      color: colors.text,
    );

    return Container(
      width: widget.compact ? null : double.infinity,
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status?.borderColor ?? colors.border,
          width: status?.borderColor != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(LucideIcons.circleCheck, size: 16, color: colors.text2),
              const SizedBox(width: 8),
              Text(
                l10n.balanceCheckMode,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: widget.compact ? 13 : 14,
                ),
              ),
            ],
          ),
          SizedBox(height: widget.compact ? 10 : 12),
          _BalanceRow(
            label: widget.expectedBalanceLabel ?? l10n.balanceCheckExpected,
            value: widget.format.formatMoney(
              widget.expectedBalance,
              widget.currencySymbol,
            ),
            colors: colors,
            compact: widget.compact,
          ),
          SizedBox(height: widget.compact ? 8 : 10),
          Text(
            l10n.balanceCheckStatement,
            style: TextStyle(
              color: colors.text3,
              fontSize: widget.compact ? 12 : 13,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,\s]')),
            ],
            decoration: InputDecoration(
              // Omit hint while focused so the web DOM placeholder cannot
              // stack on top of Flutter's hint (double / ghosted text).
              hintText: _focusNode.hasFocus
                  ? null
                  : l10n.balanceCheckStatementHint,
              hintStyle: fieldStyle.copyWith(color: colors.text3),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              prefixText: widget.currencySymbol,
              prefixStyle: fieldStyle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.accent.acc, width: 1.5),
              ),
            ),
            style: fieldStyle,
            onChanged: (_) => setState(() {}),
          ),
          if (status != null) ...[
            SizedBox(height: widget.compact ? 8 : 10),
            status.widget,
          ],
          if (payback != null) ...[
            SizedBox(height: widget.compact ? 10 : 12),
            Text(
              l10n.balanceCheckPaymentAccount,
              style: TextStyle(
                color: colors.text3,
                fontSize: widget.compact ? 12 : 13,
              ),
            ),
            const SizedBox(height: 6),
            if (payback.paymentAccounts.isEmpty)
              Text(
                l10n.balanceCheckNoPaymentAccounts,
                style: TextStyle(
                  color: colors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: payback.selectedPaymentAccountId,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
                hint: Text(l10n.balanceCheckSelectPaymentAccount),
                items: [
                  for (final account in payback.paymentAccounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(
                        account.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: payback.onPaymentAccountChanged,
              ),
            SizedBox(height: widget.compact ? 8 : 10),
            Text(
              l10n.balanceCheckPaybackDate,
              style: TextStyle(
                color: colors.text3,
                fontSize: widget.compact ? 12 : 13,
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: payback.paybackDate,
                  firstDate: DateTime(1970),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  payback.onPaybackDateChanged(picked);
                }
              },
              icon: Icon(LucideIcons.calendar, size: 16, color: colors.text2),
              label: Text(widget.format.formatMediumDate(payback.paybackDate)),
            ),
            if (payback.hasEligiblePurchases &&
                payback.selectedPaymentAccount != null) ...[
              SizedBox(height: widget.compact ? 8 : 10),
              Text(
                l10n.balanceCheckPaybackSummary(
                  widget.format.formatMoney(
                    payback.paybackTotal,
                    widget.currencySymbol,
                  ),
                  payback.selectedPaymentAccount!.name,
                  widget.format.formatMediumDate(payback.paybackDate),
                ),
                style: TextStyle(
                  color: colors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (!payback.hasEligiblePurchases) ...[
              SizedBox(height: widget.compact ? 8 : 10),
              Text(
                l10n.balanceCheckNoEligiblePurchases,
                style: TextStyle(
                  color: colors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
          if (result.isMatch && widget.onReconcile != null) ...[
            SizedBox(height: widget.compact ? 10 : 12),
            if (!widget.hasPendingReconcileWork)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.balanceCheckNothingToReconcile,
                  style: TextStyle(
                    color: colors.text2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: widget.isReconciling || !canReconcile
                    ? null
                    : widget.onReconcile,
                icon: widget.isReconciling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(LucideIcons.circleCheck, size: 16),
                label: Text(
                  widget.reconcileLabel ?? l10n.balanceCheckReconcile,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _BalanceCheckStatus? _statusFor(
    BalanceCheckResult result,
    dynamic colors,
    dynamic l10n,
  ) {
    return switch (result) {
      BalanceCheckNoInput() => _BalanceCheckStatus(
        widget: Text(
          l10n.balanceCheckEnterBalance,
          style: TextStyle(color: colors.text3, fontSize: 12),
        ),
      ),
      BalanceCheckInvalidInput() => _BalanceCheckStatus(
        borderColor: colors.warning,
        widget: Row(
          children: [
            Icon(LucideIcons.circleAlert, size: 16, color: colors.warning),
            const SizedBox(width: 6),
            Text(
              l10n.balanceCheckInvalidAmount,
              style: TextStyle(
                color: colors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      BalanceCheckMatch(:final entered) => _BalanceCheckStatus(
        borderColor: colors.success,
        widget: Row(
          children: [
            Icon(LucideIcons.circleCheck, size: 16, color: colors.success),
            const SizedBox(width: 6),
            Text(
              l10n.balanceCheckMatch,
              style: TextStyle(
                color: colors.success,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              widget.format.formatMoney(entered, widget.currencySymbol),
              style: TextStyle(
                fontFamily: 'Roboto Slab',
                color: colors.success,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      BalanceCheckMismatch(:final difference) => _BalanceCheckStatus(
        borderColor: colors.danger,
        widget: Row(
          children: [
            Icon(LucideIcons.circleX, size: 16, color: colors.danger),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.balanceCheckDifference(
                  widget.format.formatSignedMoney(
                    difference,
                    widget.currencySymbol,
                  ),
                ),
                style: TextStyle(
                  color: colors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    };
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.value,
    required this.colors,
    required this.compact,
  });

  final String label;
  final String value;
  final dynamic colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.text3, fontSize: compact ? 12 : 13),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'Roboto Slab',
              fontWeight: FontWeight.w700,
              fontSize: compact ? 14 : 16,
              color: colors.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCheckStatus {
  const _BalanceCheckStatus({required this.widget, this.borderColor});

  final Widget widget;
  final Color? borderColor;
}

/// Toggle button for enabling balance check mode in screen headers.
class AccountBalanceCheckToggle extends StatelessWidget {
  const AccountBalanceCheckToggle({
    super.key,
    required this.enabled,
    required this.onToggle,
  });

  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Tooltip(
      message: l10n.tooltipBalanceCheckMode,
      child: Material(
        color: enabled
            ? colors.accent.acc.withValues(alpha: 0.12)
            : colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled ? colors.accent.acc : colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.circleCheck,
                  size: 16,
                  color: enabled ? colors.accent.acc : colors.text,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.balanceCheckMode,
                  style: TextStyle(
                    color: enabled ? colors.accent.acc : colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
