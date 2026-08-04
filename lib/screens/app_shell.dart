import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';
import '../providers/firefly_connection_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/undo_history_provider.dart';
import '../fun_modes/fun_mode.dart';
import '../providers/data_providers.dart';
import '../providers/suggestion_providers.dart';
import '../providers/dashboard_stats_providers.dart';
import '../providers/transactions_warmup_provider.dart';
import '../providers/write_ahead_provider.dart';
import '../l10n/l10n_extensions.dart';
import '../utils/locale_formatting.dart';
import '../widgets/view_mode_switch.dart';
import '../widgets/person_selector_widget.dart';
import '../widgets/fun_decorated_surface.dart';
import '../widgets/autocomplete_text_field.dart';
import '../models/side_menu_config.dart';
import '../providers/side_menu_config_provider.dart';
import '../router/route_query.dart';

/// Below this width the sidebar is hidden behind a drawer and content uses
/// the full width (stacking cards vertically).
const double kSidebarBreakpoint = 768;

class SidebarExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final sidebarExpandedProvider = NotifierProvider<SidebarExpandedNotifier, bool>(
  SidebarExpandedNotifier.new,
);

class ExpandedSidebarGroupsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {
    'group_accounts',
    'group_budgets',
    'group_stats',
    'group_details',
    'accounts',
    'budgets',
    'stats',
    'details',
  };

  void toggleGroup(String groupId) {
    if (state.contains(groupId)) {
      state = Set.from(state)..remove(groupId);
    } else {
      state = Set.from(state)..add(groupId);
    }
  }
}

final expandedSidebarGroupsProvider =
    NotifierProvider<ExpandedSidebarGroupsNotifier, Set<String>>(
      ExpandedSidebarGroupsNotifier.new,
    );

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late ConfettiController _confettiController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(transactionsWarmupProvider);
    ref.watch(writeAheadRunnerProvider);
    final isExpanded = ref.watch(sidebarExpandedProvider);

    ref.listen(themeProvider, (prev, next) {
      final wasInactive = prev == null || prev.effectiveFunMode == FunMode.none;
      final isActive = next.effectiveFunMode != FunMode.none;
      if (wasInactive && isActive && next.funModeDefinition.celebrateOnEnable) {
        _confettiController.play();
      }
    });

    final confettiColors = ref
        .watch(themeProvider)
        .funModeDefinition
        .confettiColors;

    final isMobile = MediaQuery.sizeOf(context).width < kSidebarBreakpoint;

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          drawer: isMobile
              ? Drawer(width: 246, child: _Sidebar(inDrawer: true))
              : null,
          body: isMobile
              ? Column(
                  children: [
                    _Header(
                      onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    Expanded(child: widget.child),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      width: isExpanded ? 246 : 80,
                      child: const _Sidebar(),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const _Header(),
                          Expanded(child: widget.child),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: confettiColors.isEmpty
                ? const [Color(0xFFFFD700), Color(0xFF3B82F6)]
                : confettiColors,
            numberOfParticles: 60,
          ),
        ),
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({this.inDrawer = false});

  /// When rendered inside the mobile drawer the rail is always expanded and
  /// tapping a destination closes the drawer.
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final format = ref.watch(localeFormattingProvider);
    final String path = GoRouterState.of(context).uri.path;
    final isExpanded = inDrawer || ref.watch(sidebarExpandedProvider);
    final connectionStatus = ref.watch(fireflyConnectionProvider);
    final connectionLabel = switch (connectionStatus) {
      FireflyConnectionStatus.connected => l10n.fireflyConnected,
      FireflyConnectionStatus.checking => l10n.fireflyConnectionChecking,
      _ => l10n.fireflyDisconnected,
    };
    final connectionColor = switch (connectionStatus) {
      FireflyConnectionStatus.connected => colors.sidebarMuted,
      FireflyConnectionStatus.checking => colors.text3,
      _ => colors.danger,
    };
    final accountsAsync = ref.watch(accountsProvider);
    final currencyAsync = ref.watch(primaryCurrencyProvider);
    final userAsync = ref.watch(currentUserProvider);
    final expandedGroups = ref.watch(expandedSidebarGroupsProvider);

    final sideMenuConfig = ref.watch(sideMenuConfigProvider);

    String getItemTitle(SideMenuItem item) {
      switch (item.defaultTitleKey) {
        case 'navDashboard':
          return fun.navDashboard;
        case 'navAccounts':
          return fun.navAccounts;
        case 'navLiabilities':
          return fun.navLiabilities;
        case 'navTransactions':
          return fun.navTransactions;
        case 'navBudgets':
          return fun.navBudgets;
        case 'navPiggyBanks':
          return fun.navPiggyBanks;
        case 'navSubscriptions':
          return fun.navSubscriptions;
        case 'navExpenses':
          return fun.navExpenses;
        case 'navIncome':
          return fun.navIncome;
        case 'navTransfers':
          return fun.navTransfers;
        case 'payees':
          return 'Payees';
        case 'categoriesTags':
          return 'Categories & Tags';
        case 'navProjection':
          return fun.navProjection;
        case 'navHistory':
          return fun.navHistory;
        default:
          return item.defaultTitle;
      }
    }

    Widget navItem(
      String title,
      IconData icon,
      String routePath, {
      String? tooltip,
      bool isChild = false,
    }) {
      final isActive =
          path == routePath || (routePath != '/' && path.startsWith(routePath));
      final child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: InkWell(
          onTap: () {
            context.go(routePath);
            if (inDrawer) Navigator.of(context).maybePop();
          },
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: EdgeInsets.only(
              left: isChild && isExpanded ? 24 : 10,
              right: 10,
              top: 10,
              bottom: 10,
            ),
            decoration: BoxDecoration(
              color: isActive ? colors.accent.acc : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: isChild ? 18 : 20,
                  color: isActive ? Colors.white : colors.sidebarMuted,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: isChild ? 13 : 14,
                        color: isActive ? Colors.white : colors.sidebarMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      return Tooltip(
        message: tooltip ?? l10n.tooltipOpenSection(title),
        child: child,
      );
    }

    Widget navGroup({
      required String groupId,
      required String title,
      required IconData icon,
      required List<Widget> children,
      required List<String> childRoutes,
    }) {
      final isGroupExpanded = expandedGroups.contains(groupId);
      final hasActiveChild = childRoutes.any(
        (r) => path == r || (r != '/' && path.startsWith(r)),
      );

      if (!isExpanded) {
        // In collapsed rail mode (80px), render child items directly
        return Column(children: children);
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: InkWell(
              onTap: () {
                ref
                    .read(expandedSidebarGroupsProvider.notifier)
                    .toggleGroup(groupId);
              },
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: !isGroupExpanded && hasActiveChild
                      ? colors.accent.acc.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: hasActiveChild
                          ? Colors.white
                          : colors.sidebarMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Comfortaa',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: hasActiveChild
                              ? Colors.white
                              : colors.sidebarMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isGroupExpanded
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronRight,
                      size: 16,
                      color: colors.sidebarMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isGroupExpanded) ...children,
        ],
      );
    }

    Widget buildNode(SideMenuNode node) {
      if (node.isHidden) return const SizedBox.shrink();

      if (node.type == SideMenuNodeType.item) {
        final item = node.item!;
        return navItem(
          getItemTitle(item),
          getLucideIcon(item.iconName),
          item.routePath,
        );
      } else {
        final group = node.group!;
        final visibleItems = group.items.where((i) => !i.isHidden).toList();
        if (visibleItems.isEmpty) return const SizedBox.shrink();

        final childRoutes = visibleItems.map((i) => i.routePath).toList();
        final childrenWidgets = visibleItems
            .map(
              (i) => navItem(
                getItemTitle(i),
                getLucideIcon(i.iconName),
                i.routePath,
                isChild: true,
              ),
            )
            .toList();

        if (group.isCollapsible) {
          return navGroup(
            groupId: group.id,
            title: group.title,
            icon: getLucideIcon(group.iconName),
            childRoutes: childRoutes,
            children: childrenWidgets,
          );
        } else {
          if (!isExpanded) {
            return Column(children: childrenWidgets);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      getLucideIcon(group.iconName),
                      size: 14,
                      color: colors.sidebarMuted.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.title.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Comfortaa',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          color: colors.sidebarMuted.withValues(alpha: 0.8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ...childrenWidgets,
            ],
          );
        }
      }
    }

    return Container(
      color: colors.accent.deep,
      child: Column(
        children: [
          const SizedBox(height: 26),
          // Logo Tile
          Tooltip(
            message: l10n.tooltipToggleSidebar,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 0),
              child: InkWell(
                onTap: () =>
                    ref.read(sidebarExpandedProvider.notifier).toggle(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FunLogo(
                      width: isExpanded ? 52 : 44,
                      height: isExpanded ? 52 : 44,
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 10),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Comfortaa',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          text: l10n.appTitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.appTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Comfortaa',
                          fontSize: 10,
                          color: colors.sidebarMuted,
                          height: 1.2,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: sideMenuConfig.nodes.map(buildNode).toList(),
              ),
            ),
          ),
          // Net worth mini-card
          if (isExpanded)
            accountsAsync.when(
              data: (accounts) {
                final netWorth = ref.watch(netWorthBreakdownProvider);
                final currency = currencyAsync.value?.symbol ?? '€';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FunDecoratedSurface(
                    decorationKey: 'sidebar-net-worth',
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.panel2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fun.netWorth,
                            style: TextStyle(
                              fontFamily: 'Comfortaa',
                              fontSize: 12,
                              color: colors.sidebarMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            format.formatMoney(netWorth.netWorth, currency),
                            style: const TextStyle(
                              fontFamily: 'Roboto Slab',
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SidebarNetWorthLine(
                            label: l10n.filterAssetsShort,
                            value: format.formatMoney(
                              netWorth.assets,
                              currency,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _SidebarNetWorthLine(
                            label: l10n.filterLiabilitiesShort,
                            value: format.formatMoney(
                              netWorth.liabilities,
                              currency,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (e, st) => const SizedBox(),
            ),
          const SizedBox(height: 12),
          // Profile row button (Settings)
          Tooltip(
            message: l10n.tooltipOpenSettings,
            child: InkWell(
              onTap: () => context.go('/settings'),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isExpanded ? 16 : 0,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.accent.acc,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          userAsync.value?.displayName.isNotEmpty == true
                              ? userAsync.value!.displayName[0].toUpperCase()
                              : 'F',
                          style: const TextStyle(
                            fontFamily: 'Comfortaa',
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            userAsync.when(
                              loading: () => Text(
                                l10n.loading,
                                style: TextStyle(
                                  fontFamily: 'Comfortaa',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              error: (e, st) => Text(
                                l10n.fireflyUser,
                                style: TextStyle(
                                  fontFamily: 'Comfortaa',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              data: (user) => Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontFamily: 'Comfortaa',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              connectionLabel,
                              style: TextStyle(
                                fontFamily: 'Comfortaa',
                                fontSize: 11,
                                color: connectionColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.settings,
                        size: 18,
                        color: path == '/settings'
                            ? colors.accent.hi
                            : colors.sidebarMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Header extends ConsumerStatefulWidget {
  const _Header({this.onOpenMenu});

  /// When set (mobile layout), a hamburger button is shown that opens the
  /// navigation drawer.
  final VoidCallback? onOpenMenu;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _SidebarNetWorthLine extends StatelessWidget {
  final String label;
  final String value;

  const _SidebarNetWorthLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Comfortaa',
              fontSize: 10,
              color: colors.sidebarMuted,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Roboto Slab',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeaderState extends ConsumerState<_Header> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch(String value) {
    final uri = GoRouterState.of(context).uri;
    final next = RouteQuery.withSearch(uri, value);
    if (next != uri.toString()) {
      context.go(next);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _applySearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final fun = context.funL10n(ref.watch(themeProvider).isRacoonMode);
    final uri = GoRouterState.of(context).uri;
    final String location = uri.toString();
    final query = RouteQuery.searchFrom(uri) ?? '';
    final searchSuggestions = ref.watch(
      contextualSearchTermsProvider(location),
    );

    String contextualHintSubtitle = l10n.searchHintSubtitle;
    if (location.startsWith('/accounts') ||
        location.startsWith('/liabilities')) {
      contextualHintSubtitle =
          'Search by account name, type, role, IBAN, or number.';
    } else if (location.startsWith('/transactions') ||
        location.startsWith('/expenses') ||
        location.startsWith('/income') ||
        location.startsWith('/transfers')) {
      contextualHintSubtitle =
          'Search by description, account, category, tag, or note.';
    } else if (location.startsWith('/budgets')) {
      contextualHintSubtitle = 'Search by budget name or category.';
    } else if (location.startsWith('/subscriptions')) {
      contextualHintSubtitle = 'Search by subscription name or category.';
    } else if (location.startsWith('/piggy-banks')) {
      contextualHintSubtitle = 'Search by piggy bank name.';
    }

    if (_searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    String title = fun.navDashboard;
    if (location.startsWith('/accounts')) title = fun.navAccounts;
    if (location.startsWith('/transactions')) title = fun.navTransactions;
    if (location.startsWith('/categories-tags')) title = 'Categories & Tags';
    if (location.startsWith('/payees')) title = 'Payees';
    if (location.startsWith('/budgets')) title = fun.navBudgets;
    if (location.startsWith('/subscriptions')) title = fun.navSubscriptions;
    if (location.startsWith('/piggy-banks')) title = fun.navPiggyBanks;
    if (location.startsWith('/expenses')) title = fun.navExpenses;
    if (location.startsWith('/income')) title = fun.navIncome;
    if (location.startsWith('/transfers')) title = fun.navTransfers;
    if (location.startsWith('/liabilities')) title = fun.navLiabilities;
    if (location.startsWith('/projection')) title = fun.navProjection;
    if (location.startsWith('/history')) title = fun.navHistory;
    if (location.startsWith('/settings')) title = fun.navSettings;

    final isMobile = widget.onOpenMenu != null;

    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 30),
      color: colors.headerBg,
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              icon: const Icon(LucideIcons.menu),
              tooltip: l10n.tooltipToggleSidebar,
              onPressed: widget.onOpenMenu,
            ),
            const SizedBox(width: 4),
          ],
          if (!isMobile) ...[
            Text(title, style: context.textTheme.titleLarge),
            const SizedBox(width: 24),
          ],
          Expanded(
            child: Tooltip(
              message: l10n.tooltipSearchTransactions,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.search, size: 16, color: colors.text3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AutocompleteTextField(
                        controller: _searchController,
                        suggestions: searchSuggestions,
                        onChanged: _onSearchChanged,
                        onSubmitted: _applySearch,
                        onSelected: _applySearch,
                        style: TextStyle(color: colors.text, fontSize: 13),
                        emptyBuilder: (context) {
                          final currentQuery = _searchController.text.trim();
                          if (currentQuery.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.sparkles,
                                        size: 14,
                                        color: colors.accent.acc,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        l10n.searchHintTitle,
                                        style: TextStyle(
                                          color: colors.text,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    contextualHintSubtitle,
                                    style: TextStyle(
                                      color: colors.text3,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              l10n.noSuggestions,
                              style: TextStyle(
                                color: colors.text3,
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                        decoration: InputDecoration(
                          hintText: fun.search,
                          hintStyle: TextStyle(
                            color: colors.text3,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _applySearch('');
                        },
                        child: Icon(
                          LucideIcons.x,
                          size: 14,
                          color: colors.text3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const PersonSelectorWidget(),
          const SizedBox(width: 12),
          Tooltip(
            message: l10n.tooltipUndo,
            child: IconButton(
              onPressed: ref.watch(undoHistoryProvider).canUndo
                  ? () => ref.read(undoHistoryProvider.notifier).undo()
                  : null,
              icon: Icon(LucideIcons.undo2, size: 20, color: colors.text2),
              splashRadius: 20,
            ),
          ),
          Tooltip(
            message: l10n.tooltipRedo,
            child: IconButton(
              onPressed: ref.watch(undoHistoryProvider).canRedo
                  ? () => ref.read(undoHistoryProvider.notifier).redo()
                  : null,
              icon: Icon(LucideIcons.redo2, size: 20, color: colors.text2),
              splashRadius: 20,
            ),
          ),
          const ViewModeSwitcher(),
        ],
      ),
    );
  }
}
