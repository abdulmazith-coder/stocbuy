import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/india_vix_controller.dart';
import 'package:stocbuy_application/application/controllers/index_data_controller.dart';
import 'package:stocbuy_application/application/controllers/market_breadth_controller.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Breakpoint helper
// ─────────────────────────────────────────────────────────────────────────────

T _responsive<T>(
  BuildContext context, {
  required T mobile,
  required T tablet,
  required T desktop,
}) {
  final w = MediaQuery.of(context).size.width;
  if (w < 600) return mobile;
  if (w < 1024) return tablet;
  return desktop;
}

// Card height per breakpoint
double _cardHeight(BuildContext context) =>
    _responsive<double>(context, mobile: 160, tablet: 172, desktop: 165);

// ─────────────────────────────────────────────────────────────────────────────
// DashboardMarketSummaryRow
// ─────────────────────────────────────────────────────────────────────────────

class DashboardMarketSummaryRow extends StatelessWidget {
  const DashboardMarketSummaryRow({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;
    final isTablet = w >= 600 && w < 1024;
    final cardH = _cardHeight(context);

    // 5 cards total (news card removed)
    final cards = <Widget>[
      // ── Nifty 50 ──────────────────────────────────────────────────────────
      GetX<IndexDataController>(
        builder: (ctrl) {
          final nifty = ctrl.nifty.value;
          return _IndexCard(
            title: 'Nifty 50',
            value: nifty?.formattedPrice ?? '--',
            changeLabel: nifty?.formattedChangeLabel ?? '--',
            up: nifty?.isUp ?? false,
          );
        },
      ),
      // ── Sensex ────────────────────────────────────────────────────────────
      GetX<IndexDataController>(
        builder: (ctrl) {
          final sensex = ctrl.sensex.value;
          return _IndexCard(
            title: 'Sensex',
            value: sensex?.formattedPrice ?? '--',
            changeLabel: sensex?.formattedChangeLabel ?? '--',
            up: sensex?.isUp ?? false,
          );
        },
      ),
      // ── India VIX ─────────────────────────────────────────────────────────
      GetX<IndiaVixController>(
        builder: (ctrl) {
          final vix = ctrl.indiaVix.value;
          return _VixCard(
            value: vix?.vix,
            label:
                vix?.marketCondition ??
                vix?.sentiment ??
                vix?.riskLevel ??
                'Low Volatility',
          );
        },
      ),
      // ── Market Breadth ────────────────────────────────────────────────────
      GetX<MarketBreadthController>(
        builder: (ctrl) {
          final b = ctrl.marketBreadth.value;
          return _BreadthCard(
            ratio: b?.breadthRatio ?? 1.0,
            advancers: b?.advancers ?? 25,
            decliners: b?.decliners ?? 25,
            total: b?.totalStocks ?? 50,
            unchanged: b?.unchanged ?? 0,
            breadthScore: (b?.breadthScore ?? 0).toDouble(),
            sentiment: b?.sentiment ?? 'NEUTRAL',
            marketStatus: b?.marketStatus ?? 'POSITIVE_MARKET',
          );
        },
      ),
      // ── Nifty RSI ─────────────────────────────────────────────────────────
      const _RsiCard(),
    ];

    // ── Mobile: horizontal scroll, fixed card width ────────────────────────
    if (isMobile) {
      // Each card = roughly 48% of screen width so 2 cards are partially
      // visible, hinting there's more to scroll.
      final mobileCardW = (w * 0.48).clamp(155.0, 200.0);
      return SizedBox(
        height: cardH,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) =>
              SizedBox(width: mobileCardW, height: cardH, child: cards[index]),
        ),
      );
    }

    // ── Tablet: 3 + 2 two-row grid ────────────────────────────────────────
    if (isTablet) {
      const gap = 10.0;
      const rows = 2;
      final totalH = cardH * rows + gap;
      return SizedBox(
        height: totalH,
        child: Column(
          children: [
            // Row 1: Nifty 50 | Sensex | India VIX
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(child: cards[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: gap),
            // Row 2: Market Breadth | Nifty RSI
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 3; i < cards.length; i++) ...[
                    if (i > 3) const SizedBox(width: gap),
                    Expanded(child: cards[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Desktop: all 5 in a single row ────────────────────────────────────
    return SizedBox(
      height: cardH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _IndexCard  ← dark card, large edge-to-edge bottom sparkline
// ─────────────────────────────────────────────────────────────────────────────

class _IndexCard extends StatelessWidget {
  const _IndexCard({
    required this.title,
    required this.value,
    required this.changeLabel,
    required this.up,
  });

  final String title;
  final String value;
  final String changeLabel;
  final bool up;

  static const _cardBg = Color(0xFF0F1629);

  Color get _lineColor =>
      up ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final radius = _responsive<double>(
      context,
      mobile: 16,
      tablet: 15,
      desktop: 14,
    );

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top content: title, price, change ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row  +  "● Today" pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Today',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Price — FittedBox so it never overflows on narrow mobile
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Change row
                  Row(
                    children: [
                      Icon(
                        up
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: _lineColor,
                      ),
                      Flexible(
                        child: Text(
                          changeLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _lineColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Large edge-to-edge sparkline ───────────────────────────────
            Expanded(
              child: CustomPaint(
                painter: _LargeSparklinePainter(
                  up: up,
                  lineColor: _lineColor,
                  fillColor: up
                      ? const Color(0xFF22C55E).withValues(alpha: 0.18)
                      : const Color(0xFFEF4444).withValues(alpha: 0.18),
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VixCard
// ─────────────────────────────────────────────────────────────────────────────

class _VixCard extends StatelessWidget {
  const _VixCard({required this.value, required this.label});

  final double? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const _CardTitle(title: 'India VIX'),
          Expanded(
            child: CustomPaint(
              painter: _VixGaugePainter(
                normalized: ((value ?? 0) / 40).clamp(0.0, 1.0),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value != null ? value!.toStringAsFixed(2) : '--',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkblue,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BreadthCard
// ─────────────────────────────────────────────────────────────────────────────

class _BreadthCard extends StatelessWidget {
  const _BreadthCard({
    required this.ratio,
    required this.advancers,
    required this.decliners,
    required this.total,
    this.unchanged = 0,
    this.breadthScore = 0,
    this.sentiment = 'NEUTRAL',
    this.marketStatus = 'POSITIVE_MARKET',
  });

  final double ratio;
  final int advancers;
  final int decliners;
  final int total;
  final int unchanged;
  final double breadthScore;
  final String sentiment;
  final String marketStatus;

  int get _safe => total > 0 ? total : 1;
  double get _advPct => advancers / _safe;
  double get _decPct => decliners / _safe;
  double get _unchPct => unchanged / _safe;
  String _pct(double v) => '${(v * 100).round()}%';

  Color get _sentimentColor {
    switch (sentiment.toUpperCase()) {
      case 'BULLISH':
        return AppColors.green;
      case 'BEARISH':
        return AppColors.red;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Color get _statusColor {
    final s = marketStatus.toUpperCase();
    if (s.contains('POSITIVE') || s.contains('BULL')) return AppColors.green;
    if (s.contains('NEGATIVE') || s.contains('BEAR')) return AppColors.red;
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return _SummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // HEADER
          Row(
            children: [
              const Expanded(child: _CardTitle(title: 'Market Breadth')),
              const SizedBox(width: 6),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _PillBadge(
                    label: sentiment,
                    color: _sentimentColor,
                    bgColor: _sentimentColor.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ],
          ),

          // RATIO + SCORE
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ratio.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkblue,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  'A/D Ratio',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    breadthScore.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkblue,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'Score',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ADV / UNCH / DEC
          Row(
            children: [
              Expanded(
                child: _BreadthStat(
                  value: '$advancers',
                  label: 'Adv ${_pct(_advPct)}',
                  color: AppColors.green,
                ),
              ),
              if (unchanged > 0)
                Expanded(
                  child: Center(
                    child: _BreadthStat(
                      value: '$unchanged',
                      label: 'Unch',
                      color: AppColors.grey,
                    ),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _BreadthStat(
                    value: '$decliners',
                    label: 'Dec ${_pct(_decPct)}',
                    color: AppColors.red,
                    alignEnd: true,
                  ),
                ),
              ),
            ],
          ),

          // PROGRESS BAR
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (_advPct * 1000).round().clamp(1, 1000),
                    child: Container(color: AppColors.green),
                  ),
                  if (unchanged > 0) ...[
                    const SizedBox(width: 1),
                    Expanded(
                      flex: (_unchPct * 1000).round().clamp(1, 200),
                      child: Container(
                        color: AppColors.grey.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(width: 1),
                  ],
                  Expanded(
                    flex: (_decPct * 1000).round().clamp(1, 1000),
                    child: Container(color: AppColors.red.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ),

          // STATUS CHIP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    marketStatus.replaceAll('_', ' '),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreadthStat extends StatelessWidget {
  const _BreadthStat({
    required this.value,
    required this.label,
    required this.color,
    this.alignEnd = false,
  });

  final String value;
  final String label;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final boxAlign =
        alignEnd ? Alignment.centerRight : Alignment.centerLeft;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: boxAlign,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: boxAlign,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RsiCard
// ─────────────────────────────────────────────────────────────────────────────

class _RsiCard extends StatelessWidget {
  const _RsiCard();

  @override
  Widget build(BuildContext context) {
    return GetX<IndexDataController>(
      builder: (ctrl) {
        final selected = ctrl.selectedRsi;
        final title = ctrl.selectedRsiTitle;
        final rsiValue = selected?.rsi ?? 0.0;
        final trackFraction = (rsiValue / 100).clamp(0.0, 1.0);
        const trackH = 3.0;
        const thumb = 12.0;
        const laneH = 14.0;

        return _SummaryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RsiToggleButton(
                    title: 'Nifty',
                    selected: ctrl.selectedRsiIndex.value == RsiIndex.nifty,
                    onTap: () => ctrl.setSelectedRsiIndex(RsiIndex.nifty),
                  ),
                  _RsiToggleButton(
                    title: 'Sensex',
                    selected: ctrl.selectedRsiIndex.value == RsiIndex.sensex,
                    onTap: () => ctrl.setSelectedRsiIndex(RsiIndex.sensex),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CardTitle(title: title),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  selected != null ? selected.formattedRsi : '--',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkblue,
                  ),
                ),
              ),
              SizedBox(
                height: laneH,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final avail = math.max(0.0, w - thumb);
                    final left = (trackFraction * avail).clamp(0.0, avail);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            height: trackH,
                            width: w,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: (laneH - thumb) / 2,
                          child: Container(
                            width: thumb,
                            height: thumb,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.dashboardAccent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.darkblue.withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Signal: ${selected?.signal ?? '--'}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkblue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      selected?.marketTrend ?? '--',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkblue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RsiToggleButton extends StatelessWidget {
  const _RsiToggleButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.dashboardAccent : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.dashboardAccent : AppColors.border,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.darkblue,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.grey),
      ],
    );
  }
}

/// White rounded card — used by all cards EXCEPT _IndexCard.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = _responsive<double>(context, mobile: 12, tablet: 13, desktop: 14);
    final radius = _responsive<double>(context, mobile: 16, tablet: 15, desktop: 14);
    final blur = _responsive<double>(context, mobile: 20, tablet: 18, desktop: 16);
    final alpha = _responsive<double>(context, mobile: 0.045, tablet: 0.04, desktop: 0.035);

    return Container(
      height: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: alpha),
            blurRadius: blur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

class _LargeSparklinePainter extends CustomPainter {
  const _LargeSparklinePainter({
    required this.up,
    required this.lineColor,
    required this.fillColor,
  });

  final bool up;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(up ? 42 : 77);
    const n = 40;
    final pts = <Offset>[];

    var y = size.height * (up ? 0.65 : 0.35);
    for (var i = 0; i < n; i++) {
      final x = size.width * (i / (n - 1));
      y +=
          (rnd.nextDouble() - 0.48) * (size.height * 0.18) +
          (up ? -size.height * 0.008 : size.height * 0.008);
      y = y.clamp(size.height * 0.05, size.height * 0.92);
      pts.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final cx = (pts[i].dx + pts[i + 1].dx) / 2;
      linePath.cubicTo(
        cx, pts[i].dy, cx, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.30),
            lineColor.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final last = pts.last;
    canvas.drawCircle(last, 6, Paint()..color = lineColor.withValues(alpha: 0.25));
    canvas.drawCircle(last, 3.5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _LargeSparklinePainter old) =>
      old.up != up || old.lineColor != lineColor;
}

class _VixGaugePainter extends CustomPainter {
  const _VixGaugePainter({required this.normalized});
  final double normalized;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.92);
    final r = size.width * 0.42;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi, math.pi, false,
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi, math.pi * normalized, false,
      Paint()
        ..color = AppColors.dashboardAccent
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final angle = math.pi + math.pi * normalized;
    final needleLen = r * 0.72;
    canvas.drawLine(
      c,
      Offset(c.dx + needleLen * math.cos(angle), c.dy + needleLen * math.sin(angle)),
      Paint()
        ..color = AppColors.darkblue
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _VixGaugePainter old) =>
      old.normalized != normalized;
}