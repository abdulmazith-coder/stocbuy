import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/stock_details_controller.dart';
import 'package:stocbuy_application/application/models/stock_ohlc.dart';
import 'package:stocbuy_application/application/pages/stock_details/stock_tradingview_page.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_candle_chart.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// TradingView-style chart card shown in the middle column of the Stock
/// Details page.
///
/// Visual breakdown (top → bottom):
///   1. Section tab strip   – Chart / Markets / News / Financials / Peers /
///                            About. Visual selection only; useful as an
///                            anchor / scroll target later.
///   2. Top control toolbar – Price/Mkt Cap segmented toggle + Stocbuy pill
///                            on the left; Compare + range pills (1D / 1W /
///                            1M / … / All) on the right.
///   3. Inner chart shell   – a smaller bordered card containing:
///       a. Mini toolbar    – symbol badge, range badge, NSE chip, chart
///                            type icons, Compare / Indicators inline
///                            buttons, maximize/search icons.
///       b. Two-pane body   – vertical drawing-tools sidebar on the left
///                            (desktop / tablet) + the candlestick chart
///                            (with volume bars and crosshair) on the right.
///
/// On mobile the drawing-tools rail is hidden and the dense toolbar items
/// fall back into a horizontally scrollable strip so the chart still gets
/// the full width.
/// The canonical list of section tabs surfaced at the top of the chart
/// card. The order here also defines the order the matching cards are
/// laid out below the chart on the page, so tapping a tab can scroll
/// linearly to its corresponding card.
const List<String> stockChartSectionTabs = <String>[
  'Chart',
  'About',
  'Peers',
  'Balance Sheet',
  'Income',
  'Cash Flow',
  'Share Holder',
  'Target Price',
  'News',
];

class StockChartCard extends StatefulWidget {
  const StockChartCard({
    super.key,
    required this.controller,
    this.activeSection = 'Chart',
    this.onSectionTap,
  });

  final StockDetailsController controller;

  /// Which section tab should appear highlighted. Driven from the page so
  /// the chart card can stay in lock-step with whichever section the user
  /// last scrolled to.
  final String activeSection;

  /// Fired when the user taps a section tab. The page uses this to scroll
  /// the matching card into view.
  final ValueChanged<String>? onSectionTap;

  @override
  State<StockChartCard> createState() => _StockChartCardState();
}

class _StockChartCardState extends State<StockChartCard> {
  bool _priceMode = true; // true = Price, false = Mkt Cap.
  int _drawingTool = 0;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final tablet = Responsive.isTablet(context);
    final chartHeight = mobile ? 320.0 : (tablet ? 380.0 : 460.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SectionTabBar(
            sections: stockChartSectionTabs,
            active: widget.activeSection,
            onChange: (v) => widget.onSectionTap?.call(v),
            mobile: mobile,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 12 : 18,
              mobile ? 12 : 14,
              mobile ? 12 : 18,
              mobile ? 10 : 12,
            ),
            child: _TopToolbar(
              priceMode: _priceMode,
              onModeChange: (v) => setState(() => _priceMode = v),
              mobile: mobile,
            ),
          ),
          // ── TradingView-style two-row timeframe toolbar ────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 10 : 14,
              0,
              mobile ? 10 : 14,
              mobile ? 10 : 12,
            ),
            child: _TimeframeToolbar(
              controller: widget.controller,
              mobile: mobile,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 10 : 14,
              0,
              mobile ? 10 : 14,
              mobile ? 12 : 16,
            ),
            child: _InnerChartShell(
              controller: widget.controller,
              chartHeight: chartHeight,
              drawingTool: _drawingTool,
              onPickTool: (i) => setState(() => _drawingTool = i),
              mobile: mobile,
            ),
          ),
        ],
      ),
    );
  }
}

// —— Section tabs ————————————————————————————————————————————————————————

class _SectionTabBar extends StatelessWidget {
  const _SectionTabBar({
    required this.sections,
    required this.active,
    required this.onChange,
    required this.mobile,
  });

  final List<String> sections;
  final String active;
  final ValueChanged<String> onChange;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in sections)
              _SectionTab(
                label: s,
                selected: s == active,
                onTap: () => onChange(s),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.lightblue : Colors.transparent,
                width: 2.4,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              color: selected ? AppColors.darkblue : AppColors.grey,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// —— Top toolbar (Price/MktCap + Stocbuy on the left, Compare on the right) ——

class _TopToolbar extends StatelessWidget {
  const _TopToolbar({
    required this.priceMode,
    required this.onModeChange,
    required this.mobile,
  });

  final bool priceMode;
  final ValueChanged<bool> onModeChange;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 10,
      spacing: 10,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SegmentedToggle(
              left: 'Price',
              right: 'Mkt Cap',
              isLeft: priceMode,
              onChange: onModeChange,
              compact: mobile,
            ),
            const _StocbuyPill(),
          ],
        ),
        const _ComparePill(),
      ],
    );
  }
}

// —— TradingView-style two-row timeframe toolbar ————————————————————————————
//
// Top row: interval pills (1m, 2m, 5m, 15m, 30m, 1h, 1D, 5D, 1W, 1M, 3M).
//          The selected one drives the API's `interval` value.
//
// Bottom row: range pills (Auto, 1D, 5D, 1M, 3M, 6M, YTD, 1Y, 2Y, 5Y, 10Y,
//             MAX). `Auto` clears the range (so the toolbar resolves to the
//             quick-read endpoint, or the dedicated 1m live endpoint when
//             the active interval is 1m).
//
// Picking an interval that's too fine for the active range auto-shrinks the
// range (or vice versa) — the controller handles compatibility.

class _TimeframeToolbar extends StatelessWidget {
  const _TimeframeToolbar({required this.controller, required this.mobile});

  final StockDetailsController controller;
  final bool mobile;

  /// Interval pills exposed on the top row. Order is "TradingView-natural":
  /// finest first, daily+ at the end. We hide `60m` because it's the same
  /// as `1h` on the wire — keeping both would just confuse users.
  static const List<ChartInterval> _intervals = <ChartInterval>[
    ChartInterval.m1,
    ChartInterval.m2,
    ChartInterval.m5,
    ChartInterval.m15,
    ChartInterval.m30,
    ChartInterval.h1,
    ChartInterval.m90,
    ChartInterval.d1,
    ChartInterval.d5,
    ChartInterval.wk1,
    ChartInterval.mo1,
    ChartInterval.mo3,
  ];

  /// Range pills exposed on the bottom row. `null` is the leading "Auto"
  /// pill that clears the range.
  static const List<ChartRange?> _ranges = <ChartRange?>[
    null,
    ChartRange.d1,
    ChartRange.d5,
    ChartRange.mo1,
    ChartRange.mo3,
    ChartRange.mo6,
    ChartRange.ytd,
    ChartRange.y1,
    ChartRange.y2,
    ChartRange.y5,
    ChartRange.y10,
    ChartRange.max,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 10, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _IntervalRow(controller: controller),
          const SizedBox(height: 6),
          Container(height: 1, color: AppColors.border.withValues(alpha: 0.45)),
          const SizedBox(height: 6),
          _RangeRow(controller: controller),
        ],
      ),
    );
  }
}

class _IntervalRow extends StatelessWidget {
  const _IntervalRow({required this.controller});
  final StockDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.selectedInterval.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _RowLabel(label: 'Interval'),
            for (final i in _TimeframeToolbar._intervals) ...[
              _TimePill(
                label: i.label,
                selected: i == active,
                onTap: () => controller.setInterval(i),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      );
    });
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({required this.controller});
  final StockDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.selectedRange.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _RowLabel(label: 'Range'),
            for (final r in _TimeframeToolbar._ranges) ...[
              _TimePill(
                label: r?.label ?? 'Auto',
                selected: r == active,
                onTap: () => controller.setRange(r),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      );
    });
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: AppColors.grey,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Single pill used in both rows of [_TimeframeToolbar]. Visually matches
/// the previous `_RangePill` so the rest of the page still feels cohesive.
class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.darkblue : AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.darkblue
                  : AppColors.border.withValues(alpha: 0.85),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.white : AppColors.darkblue,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _StocbuyPill extends StatelessWidget {
  const _StocbuyPill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.candlestick_chart_rounded,
            size: 13,
            color: AppColors.darkblue,
          ),
          const SizedBox(width: 6),
          Text(
            'Stocbuy',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.darkblue,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparePill extends StatelessWidget {
  const _ComparePill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'Compare',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.darkblue,
              letterSpacing: -0.1,
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: AppColors.grey,
          ),
        ],
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.left,
    required this.right,
    required this.isLeft,
    required this.onChange,
    required this.compact,
  });
  final String left;
  final String right;
  final bool isLeft;
  final ValueChanged<bool> onChange;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padH = compact ? 10.0 : 12.0;
    final padV = compact ? 6.0 : 7.0;
    final fs = compact ? 12.0 : 12.5;

    Widget seg(String label, bool selected, VoidCallback onTap) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            decoration: BoxDecoration(
              color: selected ? AppColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.darkblue.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.darkblue : AppColors.grey,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(left, isLeft, () => onChange(true)),
          seg(right, !isLeft, () => onChange(false)),
        ],
      ),
    );
  }
}

// —— Inner chart shell ———————————————————————————————————————————————————

class _InnerChartShell extends StatelessWidget {
  const _InnerChartShell({
    required this.controller,
    required this.chartHeight,
    required this.drawingTool,
    required this.onPickTool,
    required this.mobile,
  });

  final StockDetailsController controller;
  final double chartHeight;
  final int drawingTool;
  final ValueChanged<int> onPickTool;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniToolbar(controller: controller, mobile: mobile),
          Container(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          if (mobile)
            SizedBox(
              height: chartHeight,
              child: _ChartBody(controller: controller),
            )
          else
            // The Row needs a finite cross-axis (height) so that
            // CrossAxisAlignment.stretch can resolve for the drawing-tools
            // sidebar. Otherwise it inherits the outer column's infinite
            // height and throws "BoxConstraints forces an infinite height".
            SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DrawingToolsSidebar(
                    selectedIndex: drawingTool,
                    onPick: onPickTool,
                  ),
                  Container(
                    width: 1,
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                  Expanded(child: _ChartBody(controller: controller)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({required this.controller});
  final StockDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Reads live-merged series so OHLC strip, axis pill, and sidebar match.
      controller.detail.value.currentPrice;
      final candles = controller.chartCandles;
      // Reads both `selectedInterval` and `selectedRange` so Obx rebuilds
      // when either changes (currentSelection is derived from both).
      controller.selectedInterval.value;
      controller.selectedRange.value;
      final selection = controller.currentSelection;
      final hasFetched = controller.hasFetchedChart.value;
      final isLoading = controller.isLoadingChart.value;
      final exchange = controller.detail.value.exchange ?? 'NSE';
      final symbolLabel =
          '${controller.symbol} · ${selection.label} · $exchange';

      // First-load spinner only — after candles arrive (or after the
      // first attempt finishes), keep the existing chart on screen and
      // let values mutate in place when background refreshes complete.
      final bool firstLoad = !hasFetched && candles.isEmpty;
      if (firstLoad && isLoading) {
        return const Center(
          key: ValueKey('chart_loading'),
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(AppColors.lightblue),
            ),
          ),
        );
      }
      if (candles.isEmpty) {
        // Reached the empty state (fetch finished, no rows).
        return const Center(
          key: ValueKey('chart_empty'),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              "Chart data isn't available right now.",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      // Key on the selection's cache key so background refreshes within
      // the same selection update the same chart widget (no flicker), but
      // switching interval / range remounts with the new data.
      return StockCandleChart(
        key: ValueKey<String>('chart_${selection.cacheKey}'),
        candles: candles,
        symbolLabel: symbolLabel,
      );
    });
  }
}

// —— Mini toolbar (inside the chart shell) ———————————————————————————————

class _MiniToolbar extends StatelessWidget {
  const _MiniToolbar({required this.controller, required this.mobile});
  final StockDetailsController controller;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final desktop = Responsive.isDesktop(context);
    return Obx(() {
      final symbol = controller.symbol;
      // Trigger Obx rebuild on either reactive — `currentSelection` is a
      // derived value of both.
      controller.selectedInterval.value;
      controller.selectedRange.value;
      final selectionLabel = controller.currentSelection.label;
      final displayName = controller.detail.value.displayName;
      final exchange = controller.detail.value.exchange ?? 'NSE';

      final leftCluster = <Widget>[
        _MiniBadge(label: symbol, emphasised: true),
        const SizedBox(width: 6),
        _MiniBadge(label: selectionLabel),
        const SizedBox(width: 6),
        _MiniBadge(label: exchange),
        const SizedBox(width: 8),
        const _MiniIcon(Icons.access_time_rounded),
        const SizedBox(width: 2),
        const _MiniIcon(Icons.show_chart_rounded),
        const _MiniIcon(Icons.bar_chart_rounded),
        const _MiniIcon(Icons.candlestick_chart_rounded, active: true),
        const SizedBox(width: 8),
        const _MiniInlineButton(
          icon: Icons.compare_arrows_rounded,
          label: 'Compare',
        ),
        const SizedBox(width: 4),
        const _MiniInlineButton(
          icon: Icons.tune_rounded,
          label: 'Indicators',
          highlighted: true,
        ),
      ];

      final rightCluster = <Widget>[
        const _MiniIcon(Icons.zoom_in_rounded),
        // Fullscreen → opens the TradingView Advanced Chart page. Desktop
        // only since the embedded TradingView UI assumes a wide layout.
        _MiniIcon(
          Icons.fullscreen_rounded,
          tooltip: desktop ? 'Open TradingView chart' : null,
          onTap: desktop
              ? () => openStockTradingView(
                  context,
                  symbol: symbol,
                  displayName: displayName,
                )
              : null,
        ),
        const _MiniIcon(Icons.search_rounded),
      ];

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 10, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: leftCluster),
              ),
            ),
            const SizedBox(width: 8),
            Row(children: rightCluster),
          ],
        ),
      );
    });
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, this.emphasised = false});
  final String label;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: emphasised
            ? AppColors.lightblue.withValues(alpha: 0.10)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: emphasised
              ? AppColors.lightblue.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: emphasised ? AppColors.lightblue : AppColors.darkblue,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon(this.icon, {this.active = false, this.onTap, this.tooltip});
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: active
            ? AppColors.lightblue.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        icon,
        size: 15,
        color: active ? AppColors.lightblue : AppColors.grey,
      ),
    );

    Widget content = onTap == null
        ? iconBox
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              hoverColor: AppColors.surfaceMuted,
              child: iconBox,
            ),
          );

    if (tooltip != null) {
      content = Tooltip(message: tooltip!, child: content);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: content,
    );
  }
}

class _MiniInlineButton extends StatelessWidget {
  const _MiniInlineButton({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });
  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.green : AppColors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.green.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// —— Drawing tools rail ——————————————————————————————————————————————————

class _DrawingToolsSidebar extends StatelessWidget {
  const _DrawingToolsSidebar({
    required this.selectedIndex,
    required this.onPick,
  });

  final int selectedIndex;
  final ValueChanged<int> onPick;

  static const _tools = <IconData>[
    Icons.touch_app_outlined,
    Icons.horizontal_rule_rounded,
    Icons.crop_square_outlined,
    Icons.text_fields_rounded,
    Icons.timeline_outlined,
    Icons.zoom_in_rounded,
    Icons.delete_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _tools.length; i++) ...[
              _DrawingTool(
                icon: _tools[i],
                selected: i == selectedIndex,
                onTap: () => onPick(i),
              ),
              if (i < _tools.length - 1) const SizedBox(height: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawingTool extends StatelessWidget {
  const _DrawingTool({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.lightblue.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? AppColors.lightblue : AppColors.grey,
          ),
        ),
      ),
    );
  }
}
