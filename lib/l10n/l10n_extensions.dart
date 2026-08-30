import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fireraccoon_engine/fireraccoon_engine.dart'
    hide prognosisEndOfNextMonth;

import 'app_localizations.dart';
import 'fun_l10n.dart';
import '../providers/undo_history_provider.dart';
import '../router/dashboard_route.dart';
import '../router/expenses_route.dart';
import '../router/projection_route.dart';
import '../utils/locale_formatting.dart';
import '../utils/password_policy.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  LocaleFormatting get format =>
      ProviderScope.containerOf(this).read(localeFormattingProvider);

  /// Raccoon Mode labels when [isRaccoon] is true.
  FunL10n funL10n(bool isRaccoon) => FunL10n(l10n, isRaccoon: isRaccoon);
}

/// Human-readable, localized label for a Firefly account role
/// (`defaultAsset`, `sharedAsset`, `savingAsset`, `ccAsset`). Unknown or
/// empty roles fall back to the raw value.
String localizedAccountRole(AppLocalizations l10n, String role) {
  switch (role) {
    case 'defaultAsset':
      return l10n.accountRoleDefault;
    case 'sharedAsset':
      return l10n.accountRoleShared;
    case 'savingAsset':
      return l10n.accountRoleSaving;
    case 'ccAsset':
      return l10n.accountRoleCreditCard;
    default:
      return role;
  }
}

String _deltaArrow(double percent) => percent >= 0 ? '↑ ' : '↓ ';

String localizedDashboardComparisonLabel(
  AppLocalizations l10n,
  LocaleFormatting format, {
  required DashboardPeriod period,
  DateTime? customFrom,
  DateTime? customTo,
  DateTime? reference,
}) {
  if (customFrom != null || customTo != null) {
    final comparison = previousDashboardPeriodRange(
      period: period,
      customFrom: customFrom,
      customTo: customTo,
      reference: reference,
    );
    if (comparison?.start == null) {
      return l10n.deltaComparisonCustomPeriod;
    }
    final inclusiveEnd = comparison!.end != null
        ? comparison.end!.subtract(const Duration(days: 1))
        : null;
    return format.formatDateRange(
      comparison.start,
      inclusiveEnd,
      ellipsis: l10n.dateEllipsis,
      separator: l10n.dateRangeSeparator,
    );
  }

  return switch (period) {
    DashboardPeriod.thisWeek ||
    DashboardPeriod.lastWeek => l10n.deltaComparisonPreviousWeek,
    DashboardPeriod.thisMonth ||
    DashboardPeriod.lastMonth => l10n.deltaComparisonPreviousMonth,
    DashboardPeriod.thisQuarter ||
    DashboardPeriod.lastQuarter => l10n.deltaComparisonPreviousQuarter,
    DashboardPeriod.thisYear ||
    DashboardPeriod.lastYear => l10n.deltaComparisonPreviousYear,
    DashboardPeriod.last2Years => l10n.deltaComparisonPrevious2Years,
    DashboardPeriod.last5Years => l10n.deltaComparisonPrevious5Years,
    DashboardPeriod.last10Years => l10n.deltaComparisonPrevious10Years,
    DashboardPeriod.all => l10n.deltaComparisonCustomPeriod,
  };
}

String formatDeltaLabel(
  AppLocalizations l10n,
  LocaleFormatting format,
  DeltaResult delta, {
  String? comparisonPeriodLabel,
}) {
  if (comparisonPeriodLabel != null) {
    return switch (delta.kind) {
      DeltaKind.noChange => l10n.noChangeVsComparisonPeriod(
        comparisonPeriodLabel,
      ),
      DeltaKind.newActivity => l10n.newActivityVsComparisonPeriod(
        comparisonPeriodLabel,
      ),
      DeltaKind.percent => l10n.percentVsComparisonPeriod(
        _deltaArrow(delta.percent!),
        format.formatPercent(delta.percent!.abs()),
        comparisonPeriodLabel,
      ),
    };
  }

  return switch (delta.kind) {
    DeltaKind.noChange => l10n.noChangeVsLastMonth,
    DeltaKind.newActivity => l10n.newActivityThisMonth,
    DeltaKind.percent => l10n.percentVsLastMonth(
      _deltaArrow(delta.percent!),
      format.formatPercent(delta.percent!.abs()),
    ),
  };
}

extension DashboardPeriodL10n on DashboardPeriod {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    DashboardPeriod.thisWeek => l10n.dashboardPeriodThisWeek,
    DashboardPeriod.lastWeek => l10n.dashboardPeriodLastWeek,
    DashboardPeriod.thisMonth => l10n.dashboardPeriodThisMonth,
    DashboardPeriod.lastMonth => l10n.dashboardPeriodLastMonth,
    DashboardPeriod.thisQuarter => l10n.dashboardPeriodThisQuarter,
    DashboardPeriod.lastQuarter => l10n.dashboardPeriodLastQuarter,
    DashboardPeriod.thisYear => l10n.dashboardPeriodThisYear,
    DashboardPeriod.lastYear => l10n.dashboardPeriodLastYear,
    DashboardPeriod.last2Years => l10n.dashboardPeriodLast2Years,
    DashboardPeriod.last5Years => l10n.dashboardPeriodLast5Years,
    DashboardPeriod.last10Years => l10n.dashboardPeriodLast10Years,
    DashboardPeriod.all => l10n.dashboardPeriodAll,
  };
}

extension DashboardRouteFiltersL10n on DashboardRouteFilters {
  String localizedPeriodLabel(AppLocalizations l10n, LocaleFormatting format) {
    if (hasCustomDateRange) {
      return format.formatDateRange(
        from,
        to,
        ellipsis: l10n.dateEllipsis,
        separator: l10n.dateRangeSeparator,
      );
    }
    return period.localizedLabel(l10n);
  }
}

extension ExpensePeriodL10n on ExpensePeriod {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ExpensePeriod.week => l10n.expensePeriodWeek,
    ExpensePeriod.month => l10n.expensePeriodMonth,
    ExpensePeriod.lastMonth => l10n.dashboardPeriodLastMonth,
    ExpensePeriod.quarter => l10n.expensePeriodQuarter,
    ExpensePeriod.semester => l10n.expensePeriodSemester,
    ExpensePeriod.year => l10n.expensePeriodYear,
    ExpensePeriod.all => l10n.expensePeriodAll,
  };
}

extension AutoBudgetPeriodL10n on AutoBudgetPeriod {
  String localizedCadence(AppLocalizations l10n) => switch (this) {
    AutoBudgetPeriod.daily => l10n.budgetCadenceDaily,
    AutoBudgetPeriod.weekly => l10n.budgetCadenceWeekly,
    AutoBudgetPeriod.monthly => l10n.budgetCadenceMonthly,
    AutoBudgetPeriod.quarterly => l10n.budgetCadenceQuarterly,
    AutoBudgetPeriod.halfYear => l10n.budgetCadenceHalfYear,
    AutoBudgetPeriod.yearly => l10n.budgetCadenceYearly,
  };

  String localizedPeriodLabel(AppLocalizations l10n) => switch (this) {
    AutoBudgetPeriod.daily => l10n.budgetPeriodDaily,
    AutoBudgetPeriod.weekly => l10n.budgetPeriodWeekly,
    AutoBudgetPeriod.monthly => l10n.budgetPeriodMonthly,
    AutoBudgetPeriod.quarterly => l10n.budgetPeriodQuarterly,
    AutoBudgetPeriod.halfYear => l10n.budgetPeriodHalfYear,
    AutoBudgetPeriod.yearly => l10n.budgetPeriodYearly,
  };
}

extension AutoBudgetTypeL10n on AutoBudgetType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    AutoBudgetType.none => l10n.budgetAutoTypeNone,
    AutoBudgetType.reset => l10n.budgetAutoTypeReset,
    AutoBudgetType.rollover => l10n.budgetAutoTypeRollover,
    AutoBudgetType.adjusted => l10n.budgetAutoTypeAdjusted,
  };
}

extension TransactionTypeFilterL10n on TransactionTypeFilter {
  String localizedLabel(AppLocalizations l10n, {bool isRaccoon = false}) {
    final fun = FunL10n(l10n, isRaccoon: isRaccoon);
    return switch (this) {
      TransactionTypeFilter.all => l10n.allTypes,
      TransactionTypeFilter.expense => fun.expensesFilter,
      TransactionTypeFilter.income => fun.income,
      TransactionTypeFilter.transfer => fun.transfers,
    };
  }

  String localizedTotalLabel(AppLocalizations l10n, {bool isRaccoon = false}) {
    final fun = FunL10n(l10n, isRaccoon: isRaccoon);
    return switch (this) {
      TransactionTypeFilter.expense => fun.totalForFilter('expense'),
      TransactionTypeFilter.income => fun.totalForFilter('income'),
      TransactionTypeFilter.transfer => fun.totalForFilter('transfer'),
      TransactionTypeFilter.all => l10n.totalPeriod,
    };
  }
}

extension ProjectionPeriodL10n on ProjectionPeriod {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ProjectionPeriod.m3 => l10n.projectionPeriod3Months,
    ProjectionPeriod.m6 => l10n.projectionPeriod6Months,
    ProjectionPeriod.y1 => l10n.projectionPeriod1Year,
    ProjectionPeriod.y3 => l10n.projectionPeriod3Years,
  };
}

extension ProjectionTypeL10n on ProjectionType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ProjectionType.savings => l10n.projectionTypeSavings,
    ProjectionType.compound => l10n.projectionTypeCompound,
    ProjectionType.portfolio => l10n.projectionTypePortfolio,
    ProjectionType.cashflow => l10n.projectionTypeCashflow,
  };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
    ProjectionType.savings => l10n.projectionTypeSavingsDesc,
    ProjectionType.compound => l10n.projectionTypeCompoundDesc,
    ProjectionType.portfolio => l10n.projectionTypePortfolioDesc,
    ProjectionType.cashflow => l10n.projectionTypeCashflowDesc,
  };
}

extension ProjectionChartStyleL10n on ProjectionChartStyle {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    ProjectionChartStyle.fan => l10n.chartStyleFan,
    ProjectionChartStyle.lines => l10n.chartStyleLines,
    ProjectionChartStyle.scenarios => l10n.chartStyleScenarios,
  };
}

extension ExpenseRouteFiltersL10n on ExpenseRouteFilters {
  String localizedPeriodLabel(AppLocalizations l10n, LocaleFormatting format) {
    if (hasCustomDateRange) {
      return format.formatDateRange(
        from,
        to,
        ellipsis: l10n.dateEllipsis,
        separator: l10n.dateRangeSeparator,
      );
    }
    return period.localizedLabel(l10n);
  }
}

String localizedTransactionType(
  String type,
  AppLocalizations l10n, {
  bool isRaccoon = false,
}) {
  return FunL10n(l10n, isRaccoon: isRaccoon).transactionType(type);
}

extension UndoActionTypeL10n on UndoActionType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    UndoActionType.themeMode => l10n.undoActionTypeThemeMode,
    UndoActionType.themePalette => l10n.undoActionTypeThemePalette,
    UndoActionType.themeAccent => l10n.undoActionTypeThemeAccent,
    UndoActionType.themeFunMode => l10n.undoActionTypeThemeFunMode,
    UndoActionType.locale => l10n.undoActionTypeLocale,
    UndoActionType.viewMode => l10n.undoActionTypeViewMode,
    UndoActionType.transactionPageSize =>
      l10n.undoActionTypeTransactionPageSize,
    UndoActionType.prognosisMode => l10n.undoActionTypePrognosisMode,
    UndoActionType.prognosisHorizon => l10n.undoActionTypePrognosisHorizon,
    UndoActionType.prognosisInclusion => l10n.undoActionTypePrognosisInclusion,
    UndoActionType.prognosisMarginPercent =>
      l10n.undoActionTypePrognosisMarginPercent,
    UndoActionType.accountCreate => l10n.undoActionTypeAccountCreate,
    UndoActionType.accountUpdate => l10n.undoActionTypeAccountUpdate,
    UndoActionType.accountDelete => l10n.undoActionTypeAccountDelete,
    UndoActionType.budgetCreate => l10n.undoActionTypeBudgetCreate,
    UndoActionType.budgetUpdate => l10n.undoActionTypeBudgetUpdate,
    UndoActionType.budgetDelete => l10n.undoActionTypeBudgetDelete,
    UndoActionType.transactionCreate => l10n.undoActionTypeTransactionCreate,
    UndoActionType.transactionUpdate => l10n.undoActionTypeTransactionUpdate,
    UndoActionType.transactionDelete => l10n.undoActionTypeTransactionDelete,
    UndoActionType.billCreate => l10n.undoActionTypeBillCreate,
    UndoActionType.billUpdate => l10n.undoActionTypeBillUpdate,
    UndoActionType.billDelete => l10n.undoActionTypeBillDelete,
    UndoActionType.recurrenceCreate => l10n.undoActionTypeRecurrenceCreate,
    UndoActionType.recurrenceUpdate => l10n.undoActionTypeRecurrenceUpdate,
    UndoActionType.recurrenceDelete => l10n.undoActionTypeRecurrenceDelete,
    UndoActionType.piggyBankCreate => l10n.undoActionTypePiggyBankCreate,
    UndoActionType.piggyBankUpdate => l10n.undoActionTypePiggyBankUpdate,
    UndoActionType.piggyBankDelete => l10n.undoActionTypePiggyBankDelete,
    UndoActionType.liabilityCreate => l10n.undoActionTypeLiabilityCreate,
  };
}

extension AppLocaleL10n on AppLocalizations {
  String languageDisplayName(String languageCode) => switch (languageCode) {
    'fr' => languageFrench,
    'sv' => languageSwedish,
    'pt' => languagePortuguese,
    'zh' => languageChinese,
    'ja' => languageJapanese,
    _ => languageEnglish,
  };

  String labelForPrognosisHorizon(PrognosisHorizon horizon) =>
      switch (horizon) {
        PrognosisHorizon.endOfMonth => prognosisHorizonEndOfMonth,
        PrognosisHorizon.endOfNextMonth => prognosisHorizonEndOfNextMonth,
        PrognosisHorizon.twoMonths => prognosisHorizonTwoMonths,
        PrognosisHorizon.threeMonths => prognosisHorizonThreeMonths,
        PrognosisHorizon.sixMonths => prognosisHorizonSixMonths,
        PrognosisHorizon.oneYear => prognosisHorizonOneYear,
        PrognosisHorizon.threeYears => prognosisHorizonThreeYears,
        PrognosisHorizon.fiveYears => prognosisHorizonFiveYears,
        PrognosisHorizon.tenYears => prognosisHorizonTenYears,
      };

  String labelForPrognosisMilestone(PrognosisMilestone milestone) {
    switch (milestone) {
      case PrognosisMilestone.endOfMonth:
        return projectedEndOfMonth;
      case PrognosisMilestone.endOfNextMonth:
        return prognosisEndOfNextMonth;
      case PrognosisMilestone.threeMonths:
        return prognosisMilestoneThreeMonths;
      case PrognosisMilestone.sixMonths:
        return prognosisMilestoneSixMonths;
      case PrognosisMilestone.oneYear:
        return prognosisMilestoneOneYear;
    }
  }
}

/// Localized explanation of which [PasswordPolicyResult] clauses are still
/// missing. Call only when [result.isValid] is false.
String localizedPasswordPolicyError(
  AppLocalizations l10n,
  PasswordPolicyResult result,
) {
  final parts = result.missingRequirements.map((requirement) {
    return switch (requirement) {
      PasswordRequirement.minLength => l10n.passwordReqMinLength,
      PasswordRequirement.upper => l10n.passwordReqUpper,
      PasswordRequirement.lower => l10n.passwordReqLower,
      PasswordRequirement.digit => l10n.passwordReqDigit,
      PasswordRequirement.special => l10n.passwordReqSpecial,
    };
  }).toList();
  if (parts.isEmpty) return l10n.passwordTooWeak;
  return l10n.passwordMissingRequirements(parts.join(', '));
}
