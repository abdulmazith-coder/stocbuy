import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/stock_details_controller.dart';
import 'package:stocbuy_application/application/models/stock_search_result.dart';
import 'package:stocbuy_application/application/navigation/shell_menu_navigation.dart';
import 'package:stocbuy_application/application/navigation/stock_details_route.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_about_card.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat_fab.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_chart_card.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_details_header.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_financials_card.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_metrics_sidebar.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_peers_card.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_target_price_card.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/pages/auth/auth_page.dart';
import 'package:stocbuy_application/application/widgets/application_drawer.dart';
import 'package:stocbuy_application/application/widgets/navbar.dart';
import 'package:stocbuy_application/application/widgets/network_offline_banner.dart';
import 'package:stocbuy_application/application/widgets/stocks_search_overlay.dart';

/// The Stock Details page.
///
/// Layout breakdown:
///   • Desktop (≥1100px): three-column grid where **each column scrolls
///     independently** — the page itself never scrolls. Left = ratios /
///     company info, Middle = chart + about + financial cards (one card
///     each — balance sheet, income, cash flow, shareholding, news),
///     Right = AI chat.
///   • Tablet (≥768, <1100): single scrollable column with the same card
///     order.
///   • Mobile (<768): same single-column flow as tablet with denser
///     typography and tighter padding.
///
/// The section tabs at the top of the chart card (Chart · About · Peers ·
/// Balance Sheet · Income · Cash Flow · Share Holder · News) double as
/// anchor links: tapping a tab scrolls the matching card into view using a
/// [GlobalKey] per section. The active tab follows whichever section was
/// last clicked.
class StockDetailsPage extends StatefulWidget {
  const StockDetailsPage({super.key, required this.args});

  final StockDetailsArgs args;

  @override
  State<StockDetailsPage> createState() => _StockDetailsPageState();
}

class _StockDetailsPageState extends State<StockDetailsPage> {
  late final String _tag;
  late final StockDetailsController _controller;
  bool _watchlisted = false;
  String _activeSection = 'Chart';

  /// One [GlobalKey] per section so the chart card's tab strip can scroll
  /// straight to the matching card via [Scrollable.ensureVisible]. Created
  /// once in [initState] so the identity is stable across rebuilds.
  late final Map<String, GlobalKey> _sectionKeys = {
    for (final s in stockChartSectionTabs) s: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _tag = widget.args.symbol;
    _controller = Get.put<StockDetailsController>(
      StockDetailsController(
        symbol: widget.args.symbol,
        initialCompanyName: widget.args.companyName,
        initialPrice: widget.args.initialPrice,
        initialChangePercent: widget.args.initialChangePercent,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<StockDetailsController>(tag: _tag);
    super.dispose();
  }

  Future<void> _openSearch() async {
    final result = await showStocksSearchOverlay(context);
    if (!mounted || result == null) return;
    await openStockDetails(
      context,
      symbol: result.symbol,
      companyName: _companyNameOf(result),
    );
  }

  String? _companyNameOf(StockSearchResult r) {
    final long = r.longname?.trim();
    if (long != null && long.isNotEmpty) return long;
    final short = r.shortname?.trim();
    if (short != null && short.isNotEmpty) return short;
    return null;
  }

  void _onSectionTap(String section) {
    setState(() => _activeSection = section);
    final key = _sectionKeys[section];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final desktop = Responsive.isDesktop(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    final navBar = AppNavBar(
      currentIndex: AppMenuIndex.none,
      onMenuTap: navigateAppMenu,
      onSearchTap: _openSearch,
      onLogoTap: () => navigateAppMenu(AppMenuIndex.dashboard),
    );

    return Column(
      children: [
        // Pinned to the very top of the viewport. Collapses to zero height
        // while online so the page chrome is unchanged in the normal case.
        const NetworkOfflineBanner(),
        Expanded(
          child: Scaffold(
            backgroundColor: AppColors.white,
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(
                topInset + navBar.preferredSize.height,
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: true,
                removeRight: true,
                child: Padding(
                  padding: EdgeInsets.only(top: topInset),
                  child: SizedBox(
                    height: navBar.preferredSize.height,
                    width: double.infinity,
                    child: navBar,
                  ),
                ),
              ),
            ),
            drawer: Responsive.value<Widget?>(
              context,
              mobile: ApplicationDrawer(
                currentIndex: AppMenuIndex.none,
                onMenuTap: navigateAppMenu,
              ),
              tablet: ApplicationDrawer(
                currentIndex: AppMenuIndex.none,
                onMenuTap: navigateAppMenu,
              ),
              desktop: null,
            ),
            body: Obx(() {
              if (_controller.requiresLogin.value) {
                return _StockLoginRequiredPanel(
                  symbol: _controller.symbol,
                  displayName: _controller.detail.value.displayName,
                  mobile: mobile,
                );
              }

              final detail = _controller.detail.value;
              final body = desktop
                  ? _DesktopLayout(
                      controller: _controller,
                      watchlisted: _watchlisted,
                      onToggleWatchlist: () =>
                          setState(() => _watchlisted = !_watchlisted),
                      activeSection: _activeSection,
                      onSectionTap: _onSectionTap,
                      sectionKeys: _sectionKeys,
                    )
                  : _StackedLayout(
                      controller: _controller,
                      watchlisted: _watchlisted,
                      onToggleWatchlist: () =>
                          setState(() => _watchlisted = !_watchlisted),
                      activeSection: _activeSection,
                      onSectionTap: _onSectionTap,
                      sectionKeys: _sectionKeys,
                    );

              return Stack(
                children: [
                  Positioned.fill(child: body),
                  if (!desktop)
                    Positioned(
                      right: mobile ? 16 : 24,
                      bottom: mobile ? 20 : 28,
                      child: StockAiChatFab(
                        symbol: detail.symbol,
                        displayName: detail.displayName,
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// —— Section list builder ————————————————————————————————————————————————

/// Builds the ordered list of section cards (Chart → News) used by both the
/// desktop and stacked layouts. Each card is wrapped in a [KeyedSubtree]
/// using its section's [GlobalKey] so the tab strip can scroll to it.
List<Widget> _buildSectionColumn({
  required BuildContext context,
  required StockDetailsController controller,
  required String activeSection,
  required ValueChanged<String> onSectionTap,
  required Map<String, GlobalKey> sectionKeys,
}) {
  final detail = controller.detail.value;
  const gap = SizedBox(height: 16);

  return [
    KeyedSubtree(
      key: sectionKeys['Chart'],
      child: StockChartCard(
        controller: controller,
        activeSection: activeSection,
        onSectionTap: onSectionTap,
      ),
    ),
    gap,
    KeyedSubtree(
      key: sectionKeys['About'],
      child: StockAboutCard(detail: detail),
    ),
    gap,
    KeyedSubtree(
      key: sectionKeys['Peers'],
      child: StockPeersCard(controller: controller),
    ),
    gap,
    KeyedSubtree(
      key: sectionKeys['Balance Sheet'],
      child: StockBalanceSheetCard(controller: controller),
    ),
    gap,
    KeyedSubtree(
      key: sectionKeys['Income'],
      child: StockIncomeStatementCard(controller: controller),
    ),
    gap,
    KeyedSubtree(
      key: sectionKeys['Cash Flow'],
      child: StockCashFlowCard(controller: controller),
    ),
    gap,
    KeyedSubtree(
      key: sectionKeys['Share Holder'],
      child: StockShareholdingCard(controller: controller),
    ),
    gap,
          KeyedSubtree(
        key: sectionKeys['Target Price'],
        child: StockTargetPriceCard(controller: controller),
      ),
    gap,
    KeyedSubtree(
      key: sectionKeys['News'],
      child: StockNewsCard(controller: controller),
    ),
  ];
}

// —— Desktop layout (three independent-scroll columns) ————————————————————

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.controller,
    required this.watchlisted,
    required this.onToggleWatchlist,
    required this.activeSection,
    required this.onSectionTap,
    required this.sectionKeys,
  });

  final StockDetailsController controller;
  final bool watchlisted;
  final VoidCallback onToggleWatchlist;
  final String activeSection;
  final ValueChanged<String> onSectionTap;
  final Map<String, GlobalKey> sectionKeys;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 300,
                child: _IndependentScroll(
                  child: Obx(() {
                    final detail = controller.detail.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeaderCard(
                          controller: controller,
                          watchlisted: watchlisted,
                          onToggleWatchlist: onToggleWatchlist,
                        ),
                        const SizedBox(height: 12),
                        StockMetricsSidebar(detail: detail),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _IndependentScroll(
                  child: Obx(() {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: _buildSectionColumn(
                        context: context,
                        controller: controller,
                        activeSection: activeSection,
                        onSectionTap: onSectionTap,
                        sectionKeys: sectionKeys,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 340,
                child: Padding(
                  // The chat panel manages its own internal scroll, so we
                  // don't wrap it in [_IndependentScroll]; just give it
                  // vertical breathing room and let it fill the height.
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Obx(() {
                    final detail = controller.detail.value;
                    return StockAiChatPanel(
                      symbol: detail.symbol,
                      displayName: detail.displayName,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a column's contents in its own scroll view + scrollbar so each
/// desktop column can be scrolled independently of the others.
class _IndependentScroll extends StatefulWidget {
  const _IndependentScroll({required this.child});

  final Widget child;

  @override
  State<_IndependentScroll> createState() => _IndependentScrollState();
}

class _IndependentScrollState extends State<_IndependentScroll> {
  late final ScrollController _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _ctrl,
      thumbVisibility: false,
      thickness: 6,
      radius: const Radius.circular(8),
      child: SingleChildScrollView(
        controller: _ctrl,
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: widget.child,
      ),
    );
  }
}

// —— Mobile / tablet stacked layout ——————————————————————————————————————

class _StackedLayout extends StatelessWidget {
  const _StackedLayout({
    required this.controller,
    required this.watchlisted,
    required this.onToggleWatchlist,
    required this.activeSection,
    required this.onSectionTap,
    required this.sectionKeys,
  });

  final StockDetailsController controller;
  final bool watchlisted;
  final VoidCallback onToggleWatchlist;
  final String activeSection;
  final ValueChanged<String> onSectionTap;
  final Map<String, GlobalKey> sectionKeys;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final horizontal = mobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        mobile ? 14 : 18,
        horizontal,
        mobile ? 120 : 140,
      ),
      child: Obx(() {
        final detail = controller.detail.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderCard(
              controller: controller,
              watchlisted: watchlisted,
              onToggleWatchlist: onToggleWatchlist,
            ),
            const SizedBox(height: 14),
            // Sidebar cards stack directly under the header on mobile /
            // tablet (the "left side moves below" rule).
            StockMetricsSidebar(detail: detail),
            const SizedBox(height: 14),
            ..._buildSectionColumn(
              context: context,
              controller: controller,
              activeSection: activeSection,
              onSectionTap: onSectionTap,
              sectionKeys: sectionKeys,
            ),
          ],
        );
      }),
    );
  }
}

// —— Header block (symbol / name / price / change / star) ————————————————
//
// Rendered flat on the page background — no card border / shadow — so the
// company name reads as the primary headline above the grouped metric
// cards that follow. Internal padding only on mobile so the column lines
// up with the rest of the stacked content.

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.controller,
    required this.watchlisted,
    required this.onToggleWatchlist,
  });

  final StockDetailsController controller;
  final bool watchlisted;
  final VoidCallback onToggleWatchlist;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 2 : 4,
        mobile ? 4 : 6,
        mobile ? 2 : 4,
        mobile ? 6 : 10,
      ),
      child: Obx(() {
        // Rebuild when candles or interval change so the badge colour
        // tracks the latest bar (same logic as the chart OHLC strip).
        controller.candles.length;
        controller.detail.value.currentPrice;
        controller.selectedInterval.value;
        controller.selectedRange.value;
        final quote = controller.headerQuoteChange;
        return StockDetailsHeader(
          detail: controller.detail.value,
          displayPrice: controller.headerDisplayPrice,
          changeAbs: quote.changeAbs,
          changePct: quote.changePct,
          watchlisted: watchlisted,
          onToggleWatchlist: onToggleWatchlist,
        );
      }),
    );
  }
}

// —— Login required panel (shown when any of the three endpoints 401s) ——

class _StockLoginRequiredPanel extends StatelessWidget {
  const _StockLoginRequiredPanel({
    required this.symbol,
    required this.displayName,
    required this.mobile,
  });

  final String symbol;
  final String displayName;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 22 : 28,
            vertical: mobile ? 28 : 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: mobile ? 60 : 68,
                height: mobile ? 60 : 68,
                decoration: BoxDecoration(
                  color: AppColors.lightblue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: mobile ? 28 : 32,
                  color: AppColors.lightblue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Login to view this stock',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: mobile ? 16 : 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkblue,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Detailed financials, ratios and live charts for '
                '$displayName ($symbol) are available to signed-in users '
                'only. Sign in or create a free account to unlock them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: mobile ? 12.5 : 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () =>
                        showAuthDialog(context, initialTab: AuthTab.login),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lightblue,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: mobile ? 24 : 30,
                        vertical: mobile ? 12 : 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: mobile ? 13 : 13.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                    child: const Text('Login'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        showAuthDialog(context, initialTab: AuthTab.signup),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkblue,
                      side: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.95),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: mobile ? 24 : 30,
                        vertical: mobile ? 12 : 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: mobile ? 13 : 13.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                    child: const Text('Sign up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
