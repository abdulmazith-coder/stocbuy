import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/ipo_controller.dart';
import 'package:stocbuy_application/application/controllers/stock_row_aux_controller.dart';
import 'package:stocbuy_application/application/controllers/top_gain_loss_controller.dart';
import 'package:stocbuy_application/application/models/ipo_listings.dart';
import 'package:stocbuy_application/application/models/stock_row_aux.dart';
import 'package:stocbuy_application/application/models/top_company.dart';
import 'package:stocbuy_application/application/navigation/stock_details_route.dart';
import 'package:stocbuy_application/application/pages/auth/auth_page.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/external_url.dart';
import 'package:stocbuy_application/application/widgets/livedot.dart';

/// Active tab in the Dashboard's Markets / IPO panel.
///
/// Public so the homepage can imperatively flip the tab (e.g. when the
/// user taps the "IPOs" item in the top navbar) via
/// [DashboardStockTableSectionState.showIpoTab].
enum StockTab { gainers, losers, ipoUp, ipoCurrent }

/// Markets panel: responsive layout — mobile cards, table (desktop + tablet
/// share the same renderer; tablet scrolls horizontally when narrow).
///
/// Columns (table view): # · Name · Price · Today % · Market cap · EPS ·
/// P/E · Last 7 Days sparkline.
///
/// The top-gain / top-loss API only returns symbol / name / price /
/// change %, so Market cap / EPS / P/E come from per-row `stock-info`
/// fetches and the sparkline comes from per-row 5d daily `history-price`
/// fetches. Both are handled by [StockRowAuxController]:
///
///   • Per-symbol cache with 5-min TTL (info) and 10-min TTL (sparkline)
///   • Auto-poll every minute during market hours (09:15–15:35 IST)
///   • Each row subscribes via [_RowAuxScope] so a single update repaints
///     only that row, not the whole table.
///
/// Tabs drive the dedicated [TopGainLossController] (gainers / losers).
class DashboardStockTableSection extends StatefulWidget {
  const DashboardStockTableSection({super.key});

  @override
  State<DashboardStockTableSection> createState() =>
      DashboardStockTableSectionState();
}

/// Public so the homepage can imperatively switch tabs via a
/// `GlobalKey<DashboardStockTableSectionState>`.
class DashboardStockTableSectionState
    extends State<DashboardStockTableSection> {
  StockTab _tab = StockTab.gainers;
  StockExchange _exchange = StockExchange.nse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureDataForTab(_tab);
    });
  }

  /// External entry point: open one of the IPO tabs from outside the
  /// widget (the navbar's "IPOs" item uses this).
  void showIpoTab({StockTab tab = StockTab.ipoCurrent}) {
    if (!mounted) return;
    if (tab != StockTab.ipoCurrent && tab != StockTab.ipoUp) return;
    _onTab(tab);
  }

  void _ensureDataForTab(StockTab tab) {
    switch (tab) {
      case StockTab.gainers:
        if (Get.isRegistered<TopGainLossController>()) {
          Get.find<TopGainLossController>().ensureGainersLoaded();
        }
      case StockTab.losers:
        if (Get.isRegistered<TopGainLossController>()) {
          Get.find<TopGainLossController>().ensureLosersLoaded();
        }
      case StockTab.ipoUp:
      case StockTab.ipoCurrent:
        if (Get.isRegistered<IpoController>()) {
          Get.find<IpoController>().ensureLoaded();
        }
    }
  }

  void _onTab(StockTab t) {
    if (_tab == t) return;
    setState(() => _tab = t);
    _ensureDataForTab(t);
  }

  void _onExchange(StockExchange e) {
    if (_exchange == e) return;
    setState(() => _exchange = e);
  }

  bool _isIpoTab(StockTab t) =>
      t == StockTab.ipoUp || t == StockTab.ipoCurrent;

  bool _exchangeToggleVisible(bool needsLogin) {
    if (_tab == StockTab.gainers) return true;
    if (_tab == StockTab.losers) return !needsLogin;
    if (_isIpoTab(_tab)) return !needsLogin;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tgl = Get.find<TopGainLossController>();
    final ipoCtl = Get.isRegistered<IpoController>()
        ? Get.find<IpoController>()
        : null;
    final isMobile = Responsive.isMobile(context);

    return Obx(() {
      // Per-tab + per-exchange data; loading is intentionally not surfaced to
      // the body once `fetched == true` (background refresh stays silent).
      //
      // Three different data shapes feed the body:
      //   • Gainers / losers → List<TopCompany> from TopGainLossController.
      //   • IPO tabs         → split list of NseIpoItem / BseIpoItem rows
      //                        from IpoController.
      // We track both `stockRows` (for the gainers/losers branches) and
      // a separate `ipoRowCount` so the "first-load spinner" check works
      // uniformly across tabs.
      final List<TopCompany> stockRows;
      final int ipoRowCount;
      final bool fetched;
      final bool needsLogin;
      switch (_tab) {
        case StockTab.gainers:
          stockRows = tgl.gainersFor(_exchange).toList(growable: false);
          ipoRowCount = 0;
          fetched = tgl.hasFetchedGainers.value;
          needsLogin = false;
        case StockTab.losers:
          stockRows = tgl.losersFor(_exchange).toList(growable: false);
          ipoRowCount = 0;
          fetched = tgl.hasFetchedLosers.value;
          needsLogin = tgl.losersRequiresLogin.value;
        case StockTab.ipoUp:
        case StockTab.ipoCurrent:
          stockRows = const <TopCompany>[];
          final l = ipoCtl?.listings.value ?? const IpoListings.empty();
          final exch = _exchange == StockExchange.nse
              ? IpoExchange.nse
              : IpoExchange.bse;
          final bucket = _tab == StockTab.ipoCurrent
              ? IpoBucket.current
              : IpoBucket.upcoming;
          ipoRowCount = l.countFor(exch, bucket);
          fetched = ipoCtl?.hasFetched.value ?? false;
          needsLogin = ipoCtl?.requiresLogin.value ?? true;
      }

      // First-load spinner only when there is no data yet for this view.
      // Once rows are populated, background refreshes (the 1-min poller, or a
      // user-triggered re-entry that hits a stale cache) NEVER replace the
      // list with the spinner — values mutate in-place instead.
      final bool hasRows =
          _isIpoTab(_tab) ? ipoRowCount > 0 : stockRows.isNotEmpty;
      final bool isFirstLoad = !fetched && !hasRows;

      final Widget bodyChild;
      final String bodyKey;
      if (needsLogin) {
        bodyChild = _LoginRequiredPanel(
          isMobile: isMobile,
          onLogin: () => showAuthDialog(context, initialTab: AuthTab.login),
          onSignup: () =>
              showAuthDialog(context, initialTab: AuthTab.signup),
        );
        bodyKey = 'needsLogin_${_tab.name}_${_exchange.name}';
      } else if (isFirstLoad) {
        bodyChild = _StockLoadingPlaceholder(isMobile: isMobile);
        bodyKey = 'loading_${_tab.name}_${_exchange.name}';
      } else if (!hasRows) {
        bodyChild = _StockEmptyPlaceholder(
          label: _emptyLabel(_tab, _exchange),
          isMobile: isMobile,
        );
        bodyKey = 'empty_${_tab.name}_${_exchange.name}';
      } else if (_isIpoTab(_tab)) {
        bodyChild = _IpoBody(
          listings: ipoCtl?.listings.value ?? const IpoListings.empty(),
          exchange: _exchange == StockExchange.nse
              ? IpoExchange.nse
              : IpoExchange.bse,
          bucket: _tab == StockTab.ipoCurrent
              ? IpoBucket.current
              : IpoBucket.upcoming,
          isMobile: isMobile,
        );
        bodyKey = 'ipo_${_tab.name}_${_exchange.name}';
      } else if (isMobile) {
        bodyChild = _StockListMobile(rows: stockRows);
        bodyKey = 'mobile_${_tab.name}_${_exchange.name}';
      } else {
        // Tablet and desktop share the same table — tablet just scrolls
        // horizontally when the viewport is narrower than the min width.
        bodyChild = _StockTableDesktop(rows: stockRows);
        bodyKey = 'desktop_${_tab.name}_${_exchange.name}';
      }

      final bodyArea = AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.02, 0.025),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<String>(bodyKey),
          child: bodyChild,
        ),
      );

      // Mobile: single rounded "markets" shell for hierarchy; tablet/desktop unchanged.
      final column = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: _toolbarPadding(context),
            child: _Toolbar(
              onTab: _onTab,
              tab: _tab,
              compactActions: isMobile,
              omitFilterColumnsInToolbar: isMobile,
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: isMobile ? 0.5 : 0.55),
          ),
          if (isMobile) ...[
            const _MobileFiltersColumnsRow(),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.4),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _exchangeToggleVisible(needsLogin)
                ? _ExchangeToggleBar(
                    tab: _tab,
                    exchange: _exchange,
                    onChanged: _onExchange,
                    isMobile: isMobile,
                  )
                : const SizedBox(width: double.infinity),
          ),
          bodyArea,
          SizedBox(height: isMobile ? 4 : 6),
        ],
      );

      if (isMobile) {
        return _MobileMarketsShell(child: column);
      }
      return column;
    });
  }
}

class _StockLoadingPlaceholder extends StatelessWidget {
  const _StockLoadingPlaceholder({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 36 : 44,
        horizontal: isMobile ? 18 : 20,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(AppColors.lightblue),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading stocks…',
              style: TextStyle(
                color: AppColors.grey,
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 13 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginRequiredPanel extends StatelessWidget {
  const _LoginRequiredPanel({
    required this.isMobile,
    required this.onLogin,
    required this.onSignup,
  });

  final bool isMobile;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    final double iconBoxSize = isMobile ? 52 : 60;
    final double iconSize = isMobile ? 26 : 30;
    final double titleSize = isMobile ? 15 : 16.5;
    final double bodySize = isMobile ? 12.5 : 13.5;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 32 : 44,
        horizontal: isMobile ? 18 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: AppColors.lightblue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: iconSize,
                  color: AppColors.lightblue,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Login to view Top Losers',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkblue,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Top Losers data is available to signed-in users only. '
                'Sign in or create a free account to unlock it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: bodySize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: onLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lightblue,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 22 : 26,
                        vertical: isMobile ? 12 : 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isMobile ? 13 : 13.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                    child: const Text('Login'),
                  ),
                  OutlinedButton(
                    onPressed: onSignup,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkblue,
                      side: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.95),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 22 : 26,
                        vertical: isMobile ? 12 : 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isMobile ? 13 : 13.5,
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

class _StockEmptyPlaceholder extends StatelessWidget {
  const _StockEmptyPlaceholder({required this.label, required this.isMobile});

  final String label;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 36 : 44,
        horizontal: isMobile ? 18 : 20,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: isMobile ? 28 : 32,
              color: AppColors.grey.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey,
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 13.5 : 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Light container so the markets block reads as one module on small screens.
class _MobileMarketsShell extends StatelessWidget {
  const _MobileMarketsShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

EdgeInsets _toolbarPadding(BuildContext context) {
  final m = Responsive.isMobile(context);
  final t = Responsive.isTablet(context);
  if (m) return const EdgeInsets.fromLTRB(18, 16, 18, 10);
  if (t) return const EdgeInsets.fromLTRB(16, 16, 16, 14);
  return const EdgeInsets.fromLTRB(20, 18, 20, 14);
}

String _emptyLabel(StockTab t, StockExchange exchange) {
  switch (t) {
    case StockTab.ipoUp:
      return 'Upcoming IPOs will appear here.';
    case StockTab.ipoCurrent:
      return 'Current IPOs will appear here.';
    case StockTab.gainers:
    case StockTab.losers:
      final ex = exchange == StockExchange.nse ? 'NSE' : 'BSE';
      return '$ex stocks data is not found.';
  }
}

// —— Exchange toggle (NSE / BSE) ————————————————————————————————————————————

class _ExchangeToggleBar extends StatelessWidget {
  const _ExchangeToggleBar({
    required this.tab,
    required this.exchange,
    required this.onChanged,
    required this.isMobile,
  });

  final StockTab tab;
  final StockExchange exchange;
  final ValueChanged<StockExchange> onChanged;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = isMobile
        ? const EdgeInsets.fromLTRB(18, 12, 18, 6)
        : const EdgeInsets.fromLTRB(20, 14, 20, 4);

    // Pill labels reflect what's being toggled. For IPO tabs the
    // exchange pills show e.g. "NSE current IPOs" / "BSE upcoming IPOs"
    // so the user knows the toggle is selecting the IPO source, not the
    // gainer/loser source.
    final String labelLeft;
    final String labelRight;
    switch (tab) {
      case StockTab.gainers:
        labelLeft = 'NSE top gain stock';
        labelRight = 'BSE top gain stock';
      case StockTab.losers:
        labelLeft = 'NSE top loss stock';
        labelRight = 'BSE top loss stock';
      case StockTab.ipoCurrent:
        labelLeft = 'NSE current IPOs';
        labelRight = 'BSE current IPOs';
      case StockTab.ipoUp:
        labelLeft = 'NSE upcoming IPOs';
        labelRight = 'BSE upcoming IPOs';
    }

    final pills = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ExchangePill(
          label: labelLeft,
          selected: exchange == StockExchange.nse,
          onTap: () => onChanged(StockExchange.nse),
          isMobile: isMobile,
        ),
        SizedBox(width: isMobile ? 8 : 10),
        _ExchangePill(
          label: labelRight,
          selected: exchange == StockExchange.bse,
          onTap: () => onChanged(StockExchange.bse),
          isMobile: isMobile,
        ),
      ],
    );

    final liveChip = DashboardMarketSessionIndicator(isMobile: isMobile);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: pills,
            ),
          ),
          const SizedBox(width: 10),
          liveChip,
        ],
      ),
    );
  }
}

class _ExchangePill extends StatefulWidget {
  const _ExchangePill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isMobile,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isMobile;

  @override
  State<_ExchangePill> createState() => _ExchangePillState();
}

class _ExchangePillState extends State<_ExchangePill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool selected = widget.selected;
    final Color bg = selected
        ? AppColors.lightblue
        : (_hover
            ? AppColors.surfaceMuted.withValues(alpha: 0.85)
            : AppColors.white);
    final Color fg = selected
        ? AppColors.white
        : AppColors.darkblue.withValues(alpha: 0.92);
    final Color borderColor = selected
        ? AppColors.lightblue
        : AppColors.border.withValues(alpha: 0.95);
    final double padH = widget.isMobile ? 12 : 14;
    final double padV = widget.isMobile ? 8 : 9;
    final double fontSize = widget.isMobile ? 11.5 : 12.5;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.lightblue.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(999),
            splashColor: AppColors.lightblue.withValues(alpha: 0.12),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      key: ValueKey<bool>(selected),
                      size: widget.isMobile ? 14 : 15,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: fontSize,
                      color: fg,
                      letterSpacing: -0.1,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// —— Toolbar ——————————————————————————————————————————————————————————————

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onTab,
    required this.tab,
    required this.compactActions,
    this.omitFilterColumnsInToolbar = false,
  });

  final void Function(StockTab) onTab;
  final StockTab tab;
  final bool compactActions;
  /// Mobile: Filters/Columns are shown as full-width buttons below the toolbar.
  final bool omitFilterColumnsInToolbar;

  static const _tabs = <_MarketTabSpec>[
    _MarketTabSpec(
      StockTab.gainers,
      'Top Gainers',
      Icons.trending_up_rounded,
      compactLabel: 'Gainers',
    ),
    _MarketTabSpec(
      StockTab.losers,
      'Top Losers',
      Icons.trending_down_rounded,
      compactLabel: 'Losers',
    ),
    _MarketTabSpec(
      StockTab.ipoUp,
      'Upcoming IPOs',
      Icons.rocket_launch_rounded,
      compactLabel: 'Upcoming',
    ),
    _MarketTabSpec(
      StockTab.ipoCurrent,
      'Current IPOs',
      Icons.event_available_rounded,
      compactLabel: 'Current',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _buildUnderlineTabs(context);

    final actions = _ToolbarActions(
      compact: compactActions,
      omitFilterColumns: omitFilterColumnsInToolbar,
    );

    return LayoutBuilder(
      builder: (context, c) {
        // Wide screens: tabs left + actions right (reference).
        if (c.maxWidth >= 640) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: tabs),
              const SizedBox(width: 12),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tabs,
            SizedBox(height: compactActions ? 10 : 14),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildUnderlineTabs(BuildContext context) {
    final dense = MediaQuery.sizeOf(context).width < 420;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in _tabs)
            _MarketSectionTab(
              label: (omitFilterColumnsInToolbar && t.compactLabel != null)
                  ? t.compactLabel!
                  : t.label,
              icon: t.icon,
              selected: tab == t.tab,
              compact: dense,
              onTap: () => onTab(t.tab),
            ),
        ],
      ),
    );
  }
}

class _MarketTabSpec {
  const _MarketTabSpec(this.tab, this.label, this.icon, {this.compactLabel});

  final StockTab tab;
  final String label;
  final IconData icon;
  /// Shorter label on narrow / mobile toolbar (reference UI).
  final String? compactLabel;
}

class _ToolbarActions extends StatelessWidget {
  const _ToolbarActions({
    required this.compact,
    this.omitFilterColumns = false,
  });

  final bool compact;
  final bool omitFilterColumns;

  @override
  Widget build(BuildContext context) {
    final items = <_ToolbarActionSpec>[
      const _ToolbarActionSpec(Icons.pie_chart_outline_rounded, 'Market cap'),
      const _ToolbarActionSpec(Icons.bar_chart_rounded, 'Volume'),
      if (!omitFilterColumns) ...[
        const _ToolbarActionSpec(Icons.filter_list_rounded, 'Filters'),
        const _ToolbarActionSpec(Icons.view_column_rounded, 'Columns'),
      ],
    ];

    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final it in items) ...[
              _ActionPillButton(
                icon: it.icon,
                label: it.shortLabel,
                compact: true,
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final it in items)
          _ActionPillButton(
            icon: it.icon,
            label: it.label,
            compact: false,
            onPressed: () {},
          ),
      ],
    );
  }
}

class _ToolbarActionSpec {
  const _ToolbarActionSpec(this.icon, this.label);

  final IconData icon;
  final String label;

  String get shortLabel {
    if (label == 'Market cap') return 'M cap';
    return label;
  }
}

class _ActionPillButton extends StatefulWidget {
  const _ActionPillButton({
    required this.icon,
    required this.label,
    required this.compact,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback onPressed;

  @override
  State<_ActionPillButton> createState() => _ActionPillButtonState();
}

class _ActionPillButtonState extends State<_ActionPillButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final padH = widget.compact ? 10.0 : 12.0;
    final padV = widget.compact ? 7.0 : 9.0;
    final fontSize = widget.compact ? 12.0 : 12.5;
    final iconSize = widget.compact ? 15.0 : 16.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _hover ? AppColors.surfaceMuted.withValues(alpha: 0.8) : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: AppColors.darkblue.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(999),
            hoverColor: Colors.transparent,
            splashColor: AppColors.lightblue.withValues(alpha: 0.08),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: iconSize, color: AppColors.grey),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: fontSize,
                      color: AppColors.darkblue,
                      letterSpacing: -0.1,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketSectionTab extends StatefulWidget {
  const _MarketSectionTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_MarketSectionTab> createState() => _MarketSectionTabState();
}

class _MarketSectionTabState extends State<_MarketSectionTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final padRight = widget.compact ? 14.0 : 18.0;
    final fontSize = widget.compact ? 12.5 : 13.5;
    final iconSize = widget.compact ? 15.0 : 16.0;

    final Color textColor;
    if (widget.selected) {
      textColor = AppColors.lightblue;
    } else if (_hover) {
      textColor = AppColors.darkblue.withValues(alpha: 0.82);
    } else {
      textColor = AppColors.grey;
    }

    return Padding(
      padding: EdgeInsets.only(right: padRight),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.surfaceMuted.withValues(alpha: 0.75),
          splashColor: AppColors.lightblue.withValues(alpha: 0.08),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 4 : 6,
              vertical: widget.compact ? 6 : 7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: iconSize, color: textColor),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: fontSize,
                        letterSpacing: -0.12,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.compact ? 8 : 9),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  height: 2,
                  width: widget.selected ? 26 : 0,
                  decoration: BoxDecoration(
                    color: widget.selected ? AppColors.lightblue : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
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

// (Toolbar chip button removed in favor of CoinMarketCap-style pill buttons.)

// —— Mobile: CoinMarketCap-style list (light theme) ——————————————————————————

class _MobileFiltersColumnsRow extends StatelessWidget {
  const _MobileFiltersColumnsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: _MobileWideToolButton(
              icon: Icons.filter_list_rounded,
              label: 'Filters',
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MobileWideToolButton(
              icon: Icons.view_column_rounded,
              label: 'Columns',
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileWideToolButton extends StatelessWidget {
  const _MobileWideToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.95)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.lightblue.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: AppColors.grey.withValues(alpha: 0.92)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.darkblue,
                    letterSpacing: -0.15,
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

/// Per-row layout + typography tuned by viewport width and text scale.
class _MobileStockListMetrics {
  const _MobileStockListMetrics({
    required this.rowPaddingLeft,
    required this.rowPaddingRight,
    required this.rowPaddingVertical,
    required this.rankWidth,
    required this.gapAfterRank,
    required this.gapColumns,
    required this.symbolFontSize,
    required this.nameFontSize,
    required this.priceFontSize,
    required this.metaFontSize,
    required this.rankFontSize,
    required this.starWidth,
    required this.starIconSize,
    required this.leftFlex,
    required this.rightFlex,
  });

  final double rowPaddingLeft;
  final double rowPaddingRight;
  final double rowPaddingVertical;
  final double rankWidth;
  final double gapAfterRank;
  final double gapColumns;
  final double symbolFontSize;
  final double nameFontSize;
  final double priceFontSize;
  final double metaFontSize;
  final double rankFontSize;
  final double starWidth;
  final double starIconSize;
  final int leftFlex;
  final int rightFlex;

  double get dividerIndent => rowPaddingLeft + rankWidth + gapAfterRank;

  double get dividerEndInset => starWidth + rowPaddingRight;

  factory _MobileStockListMetrics.fromContext(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14.0;
    final compactType = textScale > 1.22;

    if (w < 330) {
      return _MobileStockListMetrics(
        rowPaddingLeft: 8,
        rowPaddingRight: 2,
        rowPaddingVertical: compactType ? 12 : 11,
        rankWidth: 22,
        gapAfterRank: 6,
        gapColumns: 6,
        symbolFontSize: compactType ? 13 : 14,
        nameFontSize: compactType ? 11 : 11.5,
        priceFontSize: compactType ? 12.5 : 13,
        metaFontSize: 9.5,
        rankFontSize: 12,
        starWidth: 36,
        starIconSize: 20,
        leftFlex: 56,
        rightFlex: 44,
      );
    }
    if (w < 360) {
      return _MobileStockListMetrics(
        rowPaddingLeft: 10,
        rowPaddingRight: 2,
        rowPaddingVertical: 12,
        rankWidth: 24,
        gapAfterRank: 8,
        gapColumns: 8,
        symbolFontSize: compactType ? 14 : 15,
        nameFontSize: compactType ? 12 : 12.5,
        priceFontSize: compactType ? 13.5 : 14,
        metaFontSize: 10,
        rankFontSize: 12,
        starWidth: 38,
        starIconSize: 21,
        leftFlex: 57,
        rightFlex: 43,
      );
    }
    if (w < 400) {
      return _MobileStockListMetrics(
        rowPaddingLeft: 12,
        rowPaddingRight: 3,
        rowPaddingVertical: 13,
        rankWidth: 28,
        gapAfterRank: 8,
        gapColumns: 8,
        symbolFontSize: 15,
        nameFontSize: 12.5,
        priceFontSize: 14.5,
        metaFontSize: 10.5,
        rankFontSize: 13,
        starWidth: 40,
        starIconSize: 22,
        leftFlex: 58,
        rightFlex: 42,
      );
    }
    if (w < 480) {
      return _MobileStockListMetrics(
        rowPaddingLeft: 16,
        rowPaddingRight: 4,
        rowPaddingVertical: 14,
        rankWidth: 30,
        gapAfterRank: 10,
        gapColumns: 10,
        symbolFontSize: 16,
        nameFontSize: 13,
        priceFontSize: 15,
        metaFontSize: 11,
        rankFontSize: 13,
        starWidth: 40,
        starIconSize: 22,
        leftFlex: 58,
        rightFlex: 42,
      );
    }
    // Large phones & small tablets still under mobile breakpoint (e.g. fold).
    return _MobileStockListMetrics(
      rowPaddingLeft: 18,
      rowPaddingRight: 6,
      rowPaddingVertical: 15,
      rankWidth: 32,
      gapAfterRank: 10,
      gapColumns: 12,
      symbolFontSize: 16,
      nameFontSize: 13,
      priceFontSize: 15,
      metaFontSize: 11,
      rankFontSize: 13,
      starWidth: 42,
      starIconSize: 23,
      leftFlex: 59,
      rightFlex: 41,
    );
  }
}

class _StockListMobile extends StatelessWidget {
  const _StockListMobile({required this.rows});

  final List<TopCompany> rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 14),
      itemCount: rows.length,
      separatorBuilder: (context, index) {
        final m = _MobileStockListMetrics.fromContext(context);
        return Divider(
          height: 1,
          thickness: 1,
          indent: m.dividerIndent,
          endIndent: m.dividerEndInset,
          color: AppColors.border.withValues(alpha: 0.42),
        );
      },
      itemBuilder: (context, i) => _MobileStockRow(
        key: ValueKey<String>('mobile_${rows[i].symbol}'),
        company: rows[i],
        rank: i + 1,
      ),
    );
  }
}

class _MobileStockRow extends StatelessWidget {
  const _MobileStockRow({
    super.key,
    required this.company,
    required this.rank,
  });

  final TopCompany company;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final m = _MobileStockListMetrics.fromContext(context);
    final sym = company.symbol.toUpperCase();
    final name = company.companyName?.trim() ?? '';

    final symbolStyle = TextStyle(
      fontSize: m.symbolFontSize,
      fontWeight: FontWeight.w800,
      color: AppColors.black,
      letterSpacing: 0.15,
      height: 1.15,
    );
    final priceStyle = symbolStyle.copyWith(fontSize: m.priceFontSize);
    final metricLabelStyle = TextStyle(
      fontSize: m.metaFontSize - 0.5,
      fontWeight: FontWeight.w700,
      color: AppColors.grey.withValues(alpha: 0.75),
      letterSpacing: 0.3,
      height: 1.2,
    );
    final metricValueStyle = TextStyle(
      fontSize: m.metaFontSize + 1,
      fontWeight: FontWeight.w800,
      color: AppColors.darkblue,
      height: 1.2,
    );

    Widget metricCell({
      required String label,
      required Widget child,
      CrossAxisAlignment align = CrossAxisAlignment.start,
    }) {
      return Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: metricLabelStyle),
          const SizedBox(height: 3),
          child,
        ],
      );
    }

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: () => openStockDetailsForCompany(context, company),
        hoverColor: AppColors.surfaceMuted.withValues(alpha: 0.45),
        splashColor: AppColors.lightblue.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            m.rowPaddingLeft,
            m.rowPaddingVertical,
            m.rowPaddingRight,
            m.rowPaddingVertical,
          ),
          child: _RowAuxScope(
            symbol: company.symbol,
            builder: (context, aux) {
              final mcapText = Text(
                _compactRupees(company.marketCap),
                style: metricValueStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
              final epsText = Text(
                _formatRatio(company.trailingEps),
                style: metricValueStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
              final peText = Text(
                _formatRatio(company.trailingPE),
                style: metricValueStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1 — rank · ticker · company name · star
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: m.rankWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            '$rank',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: m.rankFontSize,
                              color: AppColors.grey.withValues(alpha: 0.88),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: m.gapAfterRank),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sym,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: symbolStyle,
                            ),
                            if (name.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: m.nameFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.grey.withValues(alpha: 0.92),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(
                        width: m.starWidth,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: m.starWidth,
                            minHeight: 36,
                          ),
                          alignment: Alignment.topCenter,
                          onPressed: () {},
                          icon: Icon(
                            Icons.star_border_rounded,
                            size: m.starIconSize,
                            color: AppColors.grey.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: m.gapColumns > 8 ? 10 : 8),
                  // Row 2 — Price (left) | Today % pill (right)
                  Padding(
                    padding: EdgeInsets.only(left: m.rankWidth + m.gapAfterRank),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _FlashOnChange(
                            value: company.currentPrice,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _fmtPrice(company.currentPrice),
                              maxLines: 1,
                              style: priceStyle,
                            ),
                          ),
                        ),
                        _FlashOnChange(
                          value: company.changePercent,
                          alignment: Alignment.centerRight,
                          child: _mobileChangePill(
                            company.changePercent,
                            fontSize: m.metaFontSize + 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: m.gapColumns > 8 ? 12 : 10),
                  // Row 3 — Mcap / EPS / P/E + 7d sparkline
                  Padding(
                    padding: EdgeInsets.only(left: m.rankWidth + m.gapAfterRank),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: metricCell(label: 'MCAP', child: mcapText),
                        ),
                        Expanded(
                          child: metricCell(label: 'EPS', child: epsText),
                        ),
                        Expanded(
                          child: metricCell(label: 'P/E', child: peText),
                        ),
                        SizedBox(width: m.gapColumns),
                        _SparkCell(
                          size: const Size(72, 26),
                          points: aux.sparkline,
                          loading: aux.sparkIsLoading,
                          failed: aux.sparkFailed,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// —— Tablet: reuse the desktop table (horizontal scroll if needed) ——————————
//
// With the simplified column set (# / Name / Price / Today % / Mcap / EPS /
// P/E / 7d) the desktop layout fits cleanly on most tablets at ~960 px
// min-width. Anything narrower scrolls horizontally just like the desktop
// view does on small browser windows. Removing the separate tablet renderer
// keeps the row implementation in one place.

// —— Desktop: full table ————————————————————————————————————————————————————

class _StockTableDesktop extends StatefulWidget {
  const _StockTableDesktop({required this.rows});

  final List<TopCompany> rows;

  @override
  State<_StockTableDesktop> createState() => _StockTableDesktopState();
}

class _StockTableDesktopState extends State<_StockTableDesktop> {
  static const _hdrStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: AppColors.grey,
    letterSpacing: 0.4,
  );

  late final ScrollController _horizontalScroll;

  @override
  void initState() {
    super.initState();
    _horizontalScroll = ScrollController();
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  /// [Table] + [LayoutBuilder] in cells breaks intrinsic layout; use [TableCellVerticalAlignment.fill] + [Align].
  TableCell _cell(
    Widget child, {
    Alignment alignment = Alignment.centerLeft,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  }) {
    return TableCell(
      child: Padding(
        padding: padding,
        child: Align(alignment: alignment, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    return LayoutBuilder(
      builder: (context, c) {
        final minW = c.maxWidth < 960 ? 960.0 : c.maxWidth;
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: _horizontalScroll,
            primary: false,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 6),
            child: SizedBox(
              // In a horizontal scroll view, maxWidth can be unbounded. Give the
              // header + rows a concrete width so flex widgets (Expanded) lay out.
              width: minW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DesktopHeaderRow(
                    cell: _cell,
                    style: _hdrStyle,
                  ),
                  const SizedBox(height: 2),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border.withValues(alpha: 0.55),
                    ),
                    itemBuilder: (context, i) {
                      return _DesktopStockRow(
                        key: ValueKey<String>('desktop_${rows[i].symbol}'),
                        index: i,
                        company: rows[i],
                        nameCell: _NameCellDesktop(company: rows[i]),
                        cell: _cell,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopHeaderRow extends StatelessWidget {
  const _DesktopHeaderRow({required this.cell, required this.style});

  final TableCell Function(
    Widget child, {
    Alignment alignment,
    EdgeInsets padding,
  }) cell;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.75),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 56, child: Center(child: Text('#', style: style))),
          Expanded(
            flex: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text('Name', style: style),
            ),
          ),
          _HdrCell(width: 120, label: 'Price', style: style, right: true),
          _HdrCell(width: 100, label: 'Today %', style: style, right: true),
          _HdrCell(width: 132, label: 'Market cap', style: style, right: true),
          _HdrCell(width: 96, label: 'EPS', style: style, right: true),
          _HdrCell(width: 96, label: 'P/E', style: style, right: true),
          _HdrCell(width: 116, label: 'Last 7 Days', style: style, center: true),
        ],
      ),
    );
  }
}

class _HdrCell extends StatelessWidget {
  const _HdrCell({
    required this.width,
    required this.label,
    required this.style,
    this.right = false,
    this.center = false,
  });

  final double width;
  final String label;
  final TextStyle style;
  final bool right;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Align(
          alignment: center
              ? Alignment.center
              : (right ? Alignment.centerRight : Alignment.centerLeft),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}

class _DesktopStockRow extends StatefulWidget {
  const _DesktopStockRow({
    super.key,
    required this.index,
    required this.company,
    required this.nameCell,
    required this.cell,
  });

  final int index;
  final TopCompany company;
  final Widget nameCell;
  final TableCell Function(
    Widget child, {
    Alignment alignment,
    EdgeInsets padding,
  }) cell;

  @override
  State<_DesktopStockRow> createState() => _DesktopStockRowState();
}

class _DesktopStockRowState extends State<_DesktopStockRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.company;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        color: _hover ? AppColors.surfaceMuted.withValues(alpha: 0.55) : Colors.transparent,
        child: InkWell(
          onTap: () => openStockDetailsForCompany(context, c),
          hoverColor: Colors.transparent,
          splashColor: AppColors.lightblue.withValues(alpha: 0.06),
          child: _RowAuxScope(
            symbol: c.symbol,
            builder: (context, aux) => Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_border_rounded,
                          size: 18,
                          color: AppColors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text('${widget.index + 1}', style: _rowMuted(12)),
                      ],
                    ),
                  ),
                ),
                Expanded(flex: 28, child: widget.nameCell),
                SizedBox(
                  width: 120,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: _FlashOnChange(
                      value: c.currentPrice,
                      alignment: Alignment.centerRight,
                      child: Text(_fmtPrice(c.currentPrice), style: _rowBold(13)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: _FlashOnChange(
                      value: c.changePercent,
                      alignment: Alignment.centerRight,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _pctCell(c.changePercent),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 132,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _compactRupees(c.marketCap),
                        style: _rowMuted(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatRatio(c.trailingEps),
                        style: _rowMuted(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatRatio(c.trailingPE),
                        style: _rowMuted(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 116,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: _SparkCell(
                        size: const Size(90, 30),
                        points: aux.sparkline,
                        loading: aux.sparkIsLoading,
                        failed: aux.sparkFailed,
                      ),
                    ),
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

class _NameCellDesktop extends StatelessWidget {
  const _NameCellDesktop({required this.company});

  final TopCompany company;

  @override
  Widget build(BuildContext context) {
    final name = company.displayName;
    final ticker = company.symbol;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.darkblue,
              height: 1.25,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            ticker,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini sparkline backed by **real** 5-day daily closes from the
/// `history-price` endpoint. Falls back to a one-off shimmer when the
/// data hasn't landed yet, or a flat dash on failure.
class _SparkCell extends StatelessWidget {
  const _SparkCell({
    required this.size,
    required this.points,
    required this.loading,
    required this.failed,
  });

  final Size size;
  final List<double>? points;
  final bool loading;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: size.height,
        width: size.width,
        child: const _Shimmer(borderRadius: 6),
      );
    }
    if (failed || points == null || points!.length < 2) {
      return SizedBox(
        height: size.height,
        width: size.width,
        child: Center(
          child: Container(
            height: 1.5,
            width: size.width * 0.5,
            color: AppColors.border.withValues(alpha: 0.9),
          ),
        ),
      );
    }
    return SizedBox(
      height: size.height,
      width: size.width,
      child: CustomPaint(
        painter: _RealSparkPainter(points: points!),
      ),
    );
  }
}

// —— Shared formatting ——————————————————————————————————————————————————————

TextStyle _rowMuted(double size) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: AppColors.grey,
    );

TextStyle _rowBold(double size) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      color: AppColors.darkblue,
    );

Widget _pctCell(double pct) {
  final up = pct > 0;
  final down = pct < 0;
  final color = !up && !down ? AppColors.grey : (up ? AppColors.green : AppColors.red);
  final arrow = !up && !down ? '' : (up ? '▲ ' : '▼ ');
  return Text(
    '$arrow${TopCompany.formatChangeLabel(pct)}',
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.right,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color, height: 1.2),
  );
}

/// Rounded pill used on mobile list rows (reference UI).
Widget _mobileChangePill(double pct, {double fontSize = 11.5}) {
  final up = pct > 0;
  final down = pct < 0;
  final flat = !up && !down;
  final bg = flat
      ? AppColors.surfaceMuted
      : (up ? AppColors.greenMutedBg : AppColors.red.withValues(alpha: 0.12));
  final fg = flat ? AppColors.grey : (up ? AppColors.green : AppColors.red);
  var label = TopCompany.formatChangeLabel(pct);
  if (up) label = label.replaceFirst('+', '');
  final padH = fontSize <= 10.5 ? 7.0 : 8.0;
  final padV = fontSize <= 10.5 ? 3.0 : 4.0;
  return Container(
    padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: fg, height: 1.1),
    ),
  );
}

String _fmtPrice(double p) {
  final fixed = p.toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final intPart = fixed.substring(0, dot);
  final dec = fixed.substring(dot + 1);
  return '₹${_commaRawIntString(intPart)}.$dec';
}

String _commaRawIntString(String intPart) {
  final neg = intPart.startsWith('-');
  final s = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

String _commaInt(double p) {
  final s = p.floor().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// —— Flash-on-change ——————————————————————————————————————————————————————
//
// Briefly tints the cell green when [value] increases and red when it
// decreases, then fades back. Used to draw the eye to live price/% updates
// without disrupting layout (real-world fintech feel — Zerodha, Moneycontrol).
class _FlashOnChange extends StatefulWidget {
  const _FlashOnChange({
    required this.value,
    required this.child,
    this.alignment = Alignment.center,
  });

  final num value;
  final Widget child;
  final Alignment alignment;

  @override
  State<_FlashOnChange> createState() => _FlashOnChangeState();
}

class _FlashOnChangeState extends State<_FlashOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Color? _flashColor;

  @override
  void didUpdateWidget(_FlashOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    final diff = widget.value - oldWidget.value;
    if (diff == 0) return;
    _flashColor = diff > 0 ? AppColors.green : AppColors.red;
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Padding is always present so the cell's hit-box never shifts when the
    // flash kicks in / out — only the background color animates.
    return Align(
      alignment: widget.alignment,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = (1 - _ctrl.value).clamp(0.0, 1.0);
          final color = _flashColor;
          final bg = (color == null || _ctrl.isDismissed)
              ? Colors.transparent
              : color.withValues(alpha: 0.20 * t);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Subscribes to one symbol's [StockRowAux] and rebuilds [builder] each
/// time the data lands. Keeps the row's Obx scope narrow — a single
/// symbol's update doesn't repaint the whole table.
class _RowAuxScope extends StatefulWidget {
  const _RowAuxScope({
    required this.symbol,
    required this.builder,
  });

  final String symbol;
  final Widget Function(BuildContext context, StockRowAux aux) builder;

  @override
  State<_RowAuxScope> createState() => _RowAuxScopeState();
}

class _RowAuxScopeState extends State<_RowAuxScope> {
  late final Rx<StockRowAux> _aux;

  @override
  void initState() {
    super.initState();
    _aux = Get.find<StockRowAuxController>().auxFor(widget.symbol);
  }

  @override
  void didUpdateWidget(_RowAuxScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      _aux = Get.find<StockRowAuxController>().auxFor(widget.symbol);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => widget.builder(context, _aux.value));
  }
}

/// Pulsing grey skeleton used by the sparkline cell while the 5-day
/// history is loading. Fills its parent — the [SizedBox] in [_SparkCell]
/// determines its dimensions. Subtle shimmer done with an
/// [AnimationController] so the cell feels alive without dragging in
/// the `shimmer` package.
class _Shimmer extends StatefulWidget {
  const _Shimmer({this.borderRadius = 6});

  final double borderRadius;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final base = AppColors.border.withValues(alpha: 0.42);
        final highlight = AppColors.border.withValues(alpha: 0.18);
        final color = Color.lerp(base, highlight, t) ?? base;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Indian-style compact rupee formatter — picks Cr / L / K automatically
/// so the column never overflows on giants like Reliance (₹17,28,000 Cr).
String _compactRupees(num? raw) {
  if (raw == null) return '—';
  final v = raw.toDouble();
  if (!v.isFinite || v == 0) return '—';
  final abs = v.abs();
  final sign = v < 0 ? '-' : '';
  String fmt(double n, String unit) {
    final s = n >= 100 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
    return '$sign₹${_commaRawIntString(s.contains('.') ? s.substring(0, s.indexOf('.')) : s)}'
        '${s.contains('.') ? s.substring(s.indexOf('.')) : ''} $unit';
  }
  if (abs >= 1e7) return fmt(abs / 1e7, 'Cr');
  if (abs >= 1e5) return fmt(abs / 1e5, 'L');
  if (abs >= 1e3) return fmt(abs / 1e3, 'K');
  return '$sign₹${_commaInt(abs)}';
}

/// EPS / P/E — plain decimal with at most two decimals. Falls back to
/// "—" for missing or NaN values.
String _formatRatio(double? v) {
  if (v == null || !v.isFinite) return '—';
  if (v.abs() >= 1000) return v.toStringAsFixed(0);
  if (v.abs() >= 100) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}

/// Plots a smoothed line from a series of real closing prices.
///
/// • Auto-scales Y to `[min, max]` of the series with a 6 % padding so
///   the curve breathes instead of touching the cell edges.
/// • Stroke colour is green when the last point is higher than the
///   first (uptrend) and red otherwise — same convention as Zerodha
///   Kite / Coinmarketcap.
/// • A faint filled area under the line gives it the "spark" look.
class _RealSparkPainter extends CustomPainter {
  _RealSparkPainter({required this.points});

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final first = points.first;
    final last = points.last;
    final up = last >= first;
    final lineColor = up ? AppColors.green : AppColors.red;

    var lo = double.infinity;
    var hi = -double.infinity;
    for (final v in points) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final span = (hi - lo).abs();
    final pad = span == 0 ? (hi.abs() * 0.01 + 0.5) : span * 0.06;
    final yMin = lo - pad;
    final yMax = hi + pad;
    final yRange = (yMax - yMin) <= 0 ? 1.0 : (yMax - yMin);

    final n = points.length;
    final offsets = List<Offset>.generate(n, (i) {
      final t = n == 1 ? 0.5 : i / (n - 1);
      final x = t * size.width;
      final y = size.height - ((points[i] - yMin) / yRange) * size.height;
      return Offset(x, y.clamp(1.0, size.height - 1));
    }, growable: false);

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final prev = offsets[i - 1];
      final curr = offsets[i];
      final cx = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(
        cx, prev.dy,
        cx, curr.dy,
        curr.dx, curr.dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, size.height)
      ..lineTo(offsets.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.20),
            lineColor.withValues(alpha: 0.00),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      offsets.last,
      2.2,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _RealSparkPainter oldDelegate) =>
      !identical(oldDelegate.points, points);
}

// ═══════════════════════════════════════════════════════════════════════════
// IPO body — renders the Upcoming / Current IPO tabs.
//
// The exchange toggle above the body decides which list of items to feed
// in (NSE vs BSE), and the active tab decides the bucket (current vs
// upcoming). Tapping any row launches the exchange's official IPO page
// in a new browser tab using [openExternalUrl] — matches the product
// spec where the on-app IPO surface is a quick at-a-glance index that
// hands off to the authoritative source for the actual application
// flow.
// ═══════════════════════════════════════════════════════════════════════════

class _IpoBody extends StatelessWidget {
  const _IpoBody({
    required this.listings,
    required this.exchange,
    required this.bucket,
    required this.isMobile,
  });

  final IpoListings listings;
  final IpoExchange exchange;
  final IpoBucket bucket;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (exchange == IpoExchange.nse) {
      final items = bucket == IpoBucket.current
          ? listings.nseCurrent
          : listings.nseUpcoming;
      return _IpoNseList(items: items, isMobile: isMobile);
    }
    final items = bucket == IpoBucket.current
        ? listings.bseCurrent
        : listings.bseUpcoming;
    return _IpoBseList(items: items, isMobile: isMobile);
  }
}

// —— NSE list ———————————————————————————————————————————————————————————

class _IpoNseList extends StatelessWidget {
  const _IpoNseList({required this.items, required this.isMobile});

  final List<NseIpoItem> items;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border.withValues(alpha: 0.42),
        ),
        itemBuilder: (context, i) => _IpoNseMobileCard(item: items[i]),
      );
    }
    return _IpoTableShell(
      exchange: IpoExchange.nse,
      header: const _IpoTableHeader(columns: [
        _IpoCol('#', 40, _IpoAlign.center),
        _IpoCol('Symbol', 120, _IpoAlign.start),
        _IpoCol('Company', 320, _IpoAlign.start, grow: true),
        _IpoCol('Series', 88, _IpoAlign.center),
        _IpoCol('Status', 96, _IpoAlign.center),
        _IpoCol('Opens', 116, _IpoAlign.start),
        _IpoCol('Closes', 116, _IpoAlign.start),
        _IpoCol('Subscribed', 110, _IpoAlign.end),
      ]),
      rows: [
        for (var i = 0; i < items.length; i++)
          _IpoNseRow(
            item: items[i],
            rank: i + 1,
            isLast: i == items.length - 1,
          ),
      ],
    );
  }
}

class _IpoNseRow extends StatelessWidget {
  const _IpoNseRow({
    required this.item,
    required this.rank,
    required this.isLast,
  });

  final NseIpoItem item;
  final int rank;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _IpoRowShell(
      exchange: IpoExchange.nse,
      isLast: isLast,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.grey,
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                item.symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkblue,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            Expanded(
              child: Text(
                item.companyName ?? item.symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkblue,
                ),
              ),
            ),
            SizedBox(
              width: 88,
              child: Center(
                child: _IpoChip(
                  text: item.series ?? '—',
                  tone: _IpoChipTone.neutral,
                ),
              ),
            ),
            SizedBox(
              width: 96,
              child: Center(
                child: _IpoChip(
                  text: item.status ?? '—',
                  tone: _statusTone(item.status),
                ),
              ),
            ),
            SizedBox(
              width: 116,
              child: Text(
                item.issueStartDate ?? '—',
                style: _dateStyle,
              ),
            ),
            SizedBox(
              width: 116,
              child: Text(
                item.issueEndDate ?? '—',
                style: _dateStyle,
              ),
            ),
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerRight,
                child: _SubscribedText(times: item.subscribedTimes),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _IpoNseMobileCard extends StatelessWidget {
  const _IpoNseMobileCard({required this.item});

  final NseIpoItem item;

  @override
  Widget build(BuildContext context) {
    return _IpoRowShell(
      exchange: IpoExchange.nse,
      isLast: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkblue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    item.symbol,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkblue,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.companyName ?? item.symbol,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkblue,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: AppColors.grey,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (item.series != null)
                  _IpoChip(text: item.series!, tone: _IpoChipTone.neutral),
                if (item.status != null)
                  _IpoChip(
                    text: item.status!,
                    tone: _statusTone(item.status),
                  ),
                Text(
                  _formatDateRange(item.issueStartDate, item.issueEndDate),
                  style: _dateStyle,
                ),
              ],
            ),
            if (item.subscribedTimes != null) ...[
              const SizedBox(height: 8),
              _SubscribedText(times: item.subscribedTimes),
            ],
          ],
        ),
      ),
    );
  }
}

// —— BSE list ———————————————————————————————————————————————————————————

class _IpoBseList extends StatelessWidget {
  const _IpoBseList({required this.items, required this.isMobile});

  final List<BseIpoItem> items;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border.withValues(alpha: 0.42),
        ),
        itemBuilder: (context, i) => _IpoBseMobileCard(item: items[i]),
      );
    }
    return _IpoTableShell(
      exchange: IpoExchange.bse,
      header: const _IpoTableHeader(columns: [
        _IpoCol('#', 40, _IpoAlign.center),
        _IpoCol('Company', 360, _IpoAlign.start, grow: true),
        _IpoCol('Platform', 116, _IpoAlign.center),
        _IpoCol('Type', 76, _IpoAlign.center),
        _IpoCol('Opens', 116, _IpoAlign.start),
        _IpoCol('Closes', 116, _IpoAlign.start),
        _IpoCol('Offer Price', 132, _IpoAlign.end),
        _IpoCol('Status', 108, _IpoAlign.center),
      ]),
      rows: [
        for (var i = 0; i < items.length; i++)
          _IpoBseRow(
            item: items[i],
            rank: i + 1,
            isLast: i == items.length - 1,
          ),
      ],
    );
  }
}

class _IpoBseRow extends StatelessWidget {
  const _IpoBseRow({
    required this.item,
    required this.rank,
    required this.isLast,
  });

  final BseIpoItem item;
  final int rank;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _IpoRowShell(
      exchange: IpoExchange.bse,
      isLast: isLast,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.grey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                _titleCase(item.securityName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkblue,
                ),
              ),
            ),
            SizedBox(
              width: 116,
              child: Center(
                child: _IpoChip(
                  text: item.exchangePlatform ?? '—',
                  tone: _IpoChipTone.neutral,
                ),
              ),
            ),
            SizedBox(
              width: 76,
              child: Center(
                child: _IpoChip(
                  text: item.typeOfIssue ?? '—',
                  tone: _IpoChipTone.muted,
                ),
              ),
            ),
            SizedBox(
              width: 116,
              child: Text(item.startDate ?? '—', style: _dateStyle),
            ),
            SizedBox(
              width: 116,
              child: Text(item.endDate ?? '—', style: _dateStyle),
            ),
            SizedBox(
              width: 132,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  item.offerPrice == null ? '—' : '₹${item.offerPrice}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkblue,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 108,
              child: Center(
                child: _IpoChip(
                  text: item.issueStatus ?? '—',
                  tone: _statusTone(item.issueStatus),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _IpoBseMobileCard extends StatelessWidget {
  const _IpoBseMobileCard({required this.item});

  final BseIpoItem item;

  @override
  Widget build(BuildContext context) {
    return _IpoRowShell(
      exchange: IpoExchange.bse,
      isLast: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _titleCase(item.securityName),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkblue,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: AppColors.grey,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (item.exchangePlatform != null)
                  _IpoChip(
                    text: item.exchangePlatform!,
                    tone: _IpoChipTone.neutral,
                  ),
                if (item.typeOfIssue != null)
                  _IpoChip(text: item.typeOfIssue!, tone: _IpoChipTone.muted),
                if (item.issueStatus != null)
                  _IpoChip(
                    text: item.issueStatus!,
                    tone: _statusTone(item.issueStatus),
                  ),
                Text(
                  _formatDateRange(item.startDate, item.endDate),
                  style: _dateStyle,
                ),
              ],
            ),
            if (item.offerPrice != null) ...[
              const SizedBox(height: 8),
              Text(
                '₹${item.offerPrice}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkblue,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// —— Shared chrome ————————————————————————————————————————————————————————

class _IpoTableShell extends StatelessWidget {
  const _IpoTableShell({
    required this.exchange,
    required this.header,
    required this.rows,
  });

  final IpoExchange exchange;
  final _IpoTableHeader header;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Min table width = sum of column widths. If the viewport is
        // narrower, the table scrolls horizontally — same UX as the
        // gainers / losers table when the tablet column shrinks.
        final tableW =
            header.columns.fold<double>(0, (s, col) => s + col.width) + 60;
        final useScroll = tableW > c.maxWidth;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            ...rows,
          ],
        );
        if (useScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: tableW, child: body),
          );
        }
        return body;
      },
    );
  }
}

class _IpoTableHeader extends StatelessWidget {
  const _IpoTableHeader({required this.columns});

  final List<_IpoCol> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.55),
        border: Border(
          bottom:
              BorderSide(color: AppColors.border.withValues(alpha: 0.55)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 11, 30, 11),
      child: Row(
        children: [
          for (final col in columns)
            col.grow
                ? Expanded(child: _headerLabel(col))
                : SizedBox(width: col.width, child: _headerLabel(col)),
        ],
      ),
    );
  }

  Widget _headerLabel(_IpoCol col) {
    return Align(
      alignment: col.align.alignment,
      child: Text(
        col.label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.grey,
          letterSpacing: 0.4,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _IpoCol {
  const _IpoCol(this.label, this.width, this.align, {this.grow = false});

  final String label;
  final double width;
  final _IpoAlign align;
  final bool grow;
}

enum _IpoAlign {
  start,
  center,
  end;

  Alignment get alignment => switch (this) {
        _IpoAlign.start => Alignment.centerLeft,
        _IpoAlign.center => Alignment.center,
        _IpoAlign.end => Alignment.centerRight,
      };
}

class _IpoRowShell extends StatefulWidget {
  const _IpoRowShell({
    required this.exchange,
    required this.isLast,
    required this.child,
  });

  final IpoExchange exchange;
  final bool isLast;
  final Widget child;

  @override
  State<_IpoRowShell> createState() => _IpoRowShellState();
}

class _IpoRowShellState extends State<_IpoRowShell> {
  bool _hover = false;

  Future<void> _open() async {
    await openExternalUrl(
      widget.exchange.officialIpoListingUrl,
      context: context,
      failureMessage:
          'Could not open the ${widget.exchange.label} IPO page in your browser.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _hover
              ? AppColors.lightblue.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            bottom: widget.isLast
                ? BorderSide.none
                : BorderSide(
                    color: AppColors.border.withValues(alpha: 0.45),
                  ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _open,
            hoverColor: Colors.transparent,
            splashColor: AppColors.lightblue.withValues(alpha: 0.06),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// —— Small bits ————————————————————————————————————————————————————————

enum _IpoChipTone { neutral, muted, success, warning }

class _IpoChip extends StatelessWidget {
  const _IpoChip({required this.text, required this.tone});

  final String text;
  final _IpoChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      _IpoChipTone.neutral => (
          AppColors.lightblue,
          AppColors.lightblue.withValues(alpha: 0.1),
        ),
      _IpoChipTone.muted => (
          AppColors.grey,
          AppColors.grey.withValues(alpha: 0.1),
        ),
      _IpoChipTone.success => (
          AppColors.green,
          AppColors.green.withValues(alpha: 0.1),
        ),
      _IpoChipTone.warning => (
          AppColors.red,
          AppColors.red.withValues(alpha: 0.1),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SubscribedText extends StatelessWidget {
  const _SubscribedText({required this.times});

  final double? times;

  @override
  Widget build(BuildContext context) {
    if (times == null) {
      return const Text(
        '—',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppColors.grey,
        ),
      );
    }
    final hot = times! >= 1;
    final color = hot ? AppColors.green : AppColors.grey;
    return Text(
      '${times!.toStringAsFixed(2)}×',
      maxLines: 1,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.2,
      ),
    );
  }
}

// —— Formatting helpers ————————————————————————————————————————————————

const _dateStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: AppColors.grey,
  letterSpacing: 0.1,
);

String _formatDateRange(String? start, String? end) {
  if (start == null && end == null) return '';
  if (start != null && end != null) return '$start  →  $end';
  return start ?? end ?? '';
}

/// `JAGSONPAL PHARMACEUTICALS LTD` → `Jagsonpal Pharmaceuticals Ltd`. The
/// BSE feed shouts every name in caps; lower-case + capitalise the first
/// letter of each word looks far cleaner in the row.
String _titleCase(String input) {
  if (input.isEmpty) return input;
  return input
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) {
        final lower = w.toLowerCase();
        return lower[0].toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

_IpoChipTone _statusTone(String? status) {
  if (status == null) return _IpoChipTone.muted;
  final s = status.toLowerCase();
  if (s.contains('active') || s.contains('live') || s.contains('open')) {
    return _IpoChipTone.success;
  }
  if (s.contains('closed')) return _IpoChipTone.muted;
  if (s.contains('forthcoming') || s.contains('upcoming')) {
    return _IpoChipTone.neutral;
  }
  return _IpoChipTone.muted;
}
