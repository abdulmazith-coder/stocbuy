import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/models/stock_search_result.dart';
import 'package:stocbuy_application/application/navigation/app_routes.dart';
import 'package:stocbuy_application/application/navigation/shell_menu_navigation.dart';
import 'package:stocbuy_application/application/navigation/stock_details_route.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/application_drawer.dart';
import 'package:stocbuy_application/application/widgets/dashboard_market_summary_row.dart';
import 'package:stocbuy_application/application/widgets/dashboard_stock_table_section.dart';
import 'package:stocbuy_application/application/widgets/indian_stock_ticker_strip.dart';
import 'package:stocbuy_application/application/widgets/navbar.dart';
import 'package:stocbuy_application/application/widgets/network_offline_banner.dart';
import 'package:stocbuy_application/application/widgets/stocks_search_overlay.dart';

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final FocusNode _shortcutFocus = FocusNode(
    debugLabel: 'homeSearchShortcut',
    skipTraversal: true,
  );

  /// Anchor for the Markets / IPO panel so the navbar's "IPOs" menu can
  /// both scroll the panel into view AND imperatively switch its inner
  /// tab to "Current IPOs". Same pattern as the section keys on the
  /// Stock Details page.
  final GlobalKey<DashboardStockTableSectionState> _marketsKey =
      GlobalKey<DashboardStockTableSectionState>(debugLabel: 'dashboardMarkets');

  static const int _menuIndexDashboard = AppMenuIndex.dashboard;
  static const int _menuIndexIpos = AppMenuIndex.ipos;

  bool _consumedRouteArgs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _shortcutFocus.requestFocus();
        _maybeOpenIposFromRoute();
      }
    });
  }

  void _maybeOpenIposFromRoute() {
    if (_consumedRouteArgs) return;
    final args = Get.arguments;
    if (args is! Map || args['openIpos'] != true) return;
    _consumedRouteArgs = true;
    _handleMenuTap(_menuIndexIpos);
  }

  @override
  void dispose() {
    _shortcutFocus.dispose();
    super.dispose();
  }

  /// Reacts to a navbar / drawer menu tap.
  ///
  /// For the "IPOs" item we don't push a route — the IPO listings live
  /// inside the Markets panel (alongside Top Gainers / Top Losers).
  /// Tapping the menu both flips the panel's tab to "Current IPOs" and
  /// scrolls it into view so the user lands directly on the data.
  void _handleMenuTap(int index) {
    // IPOs live on the dashboard — scroll/switch tab when already home.
    if (index == _menuIndexIpos && Get.currentRoute == AppRoutes.dashboard) {
      setState(() => _currentIndex = index);
      _marketsKey.currentState?.showIpoTab();
      _scrollToMarkets();
      return;
    }
    if (index == _menuIndexDashboard) {
      setState(() => _currentIndex = _menuIndexDashboard);
      return;
    }
    navigateAppMenu(index);
  }

  void _scrollToMarkets() {
    // Defer to the next frame so we don't fight a freshly-built widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _marketsKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
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

  @override
  Widget build(BuildContext context) {
    // Mark the dashboard tab as "currently selected" by default so the
    // navbar pill renders correctly; tapping any item is handled via
    // [_handleMenuTap] (which scrolls instead of pushing for IPOs).
    final navBar = AppNavBar(
      currentIndex: _currentIndex == _menuIndexIpos
          ? _menuIndexDashboard
          : _currentIndex,
      onMenuTap: _handleMenuTap,
      onSearchTap: _openSearch,
    );

    final topInset = MediaQuery.viewPaddingOf(context).top;
    final headerChromeHeight =
        topInset + navBar.preferredSize.height + IndianStockTickerStrip.layoutHeight;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.slash): _OpenSearchIntent(),
      },
      child: Actions(
        actions: {
          _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
            onInvoke: (_) {
              _openSearch();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _shortcutFocus,
          autofocus: false,
          child: Column(
            children: [
              // Pinned to the very top of the viewport (above the navbar) so
              // the offline state is unmissable on every breakpoint. Collapses
              // to zero height while online, so the layout is untouched.
              const NetworkOfflineBanner(),
              Expanded(
                child: Scaffold(
          // Keep navbar + ticker in the app bar slot so both get the full viewport
          // width. The body region can be inset on web; that was clipping the ticker.
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(headerChromeHeight),
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              removeRight: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: SizedBox(
                      height: navBar.preferredSize.height,
                      width: double.infinity,
                      child: navBar,
                    ),
                  ),
                  SizedBox(
                    height: IndianStockTickerStrip.layoutHeight,
                    width: double.infinity,
                    child: const ClipRect(
                      child: IndianStockTickerStrip(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          drawer: Responsive.value(
            context,
            mobile: ApplicationDrawer(
              currentIndex: _currentIndex,
              onMenuTap: _handleMenuTap,
            ),
            tablet: ApplicationDrawer(
              currentIndex: _currentIndex,
              onMenuTap: _handleMenuTap,
            ),
            desktop: null,
          ),
          body: ColoredBox(
            color: AppColors.white,
            child: SingleChildScrollView(
              child: Padding(
                padding: Responsive.dashboardBodyPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: Responsive.isMobile(context) ? 10 : 16),
                    const DashboardMarketSummaryRow(),
                    SizedBox(height: Responsive.isMobile(context) ? 20 : 24),
                    DashboardStockTableSection(key: _marketsKey),
                    SizedBox(height: Responsive.isMobile(context) ? 24 : 32),
                  ],
                ),
              ),
            ),
          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
