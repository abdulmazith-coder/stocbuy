import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/market_status_controller.dart';
import 'package:stocbuy_application/application/models/market_session_status.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// Yellow used for PRE_OPEN — matches the ticker pill.
const Color kMarketPreOpenYellow = Color(0xFFEAB308);

/// Accent colour, label, and whether the status dot should pulse.
({Color accent, String label, bool pulse}) marketSessionVisual(
  MarketSessionState state,
) {
  switch (state) {
    case MarketSessionState.loading:
      return (accent: AppColors.grey, label: '…', pulse: false);
    case MarketSessionState.preOpen:
      return (accent: kMarketPreOpenYellow, label: 'PRE-Open', pulse: false);
    case MarketSessionState.open:
      return (accent: AppColors.green, label: 'LIVE', pulse: true);
    case MarketSessionState.postMarket:
      return (accent: AppColors.orangeAccent, label: 'CLOSE', pulse: false);
    case MarketSessionState.closed:
      return (accent: AppColors.red, label: 'CLOSE', pulse: false);
  }
}

/// Market session pill rendered next to the "Market" label on the ticker.
///
/// Renders one of four states (plus a loading placeholder), each with a
/// distinct colour:
///
/// • `preOpen`    → **Yellow**  PRE-MARKET   (09:00 – 09:15 IST)
/// • `open`       → **Green**   LIVE MARKET  (09:15 – 15:30 IST, pulsing dot)
/// • `postMarket` → **Orange**  AFTER-MARKET (15:30 onwards IST)
/// • `closed`     → **Red**     MARKET CLOSED (outside trading hours / weekends)
/// • `loading`    → **Grey** with ellipsis until first snapshot lands
class LiveDotDesign extends StatefulWidget {
  const LiveDotDesign({super.key, required this.state});

  final MarketSessionState state;

  @override
  State<LiveDotDesign> createState() => _LiveDotDesignState();
}

class _LiveDotDesignState extends State<LiveDotDesign>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.35,
      upperBound: 1,
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(LiveDotDesign oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    // Only the live "OPEN" state pulses — every other state shows a static
    // dot so the pill doesn't fight for attention when nothing is changing.
    if (widget.state == MarketSessionState.open) {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.stop();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final compact = w < 360;
    final labelSize = compact ? 12.0 : 13.0;
    final statusSize = compact ? 10.0 : 11.0;
    final dotSize = compact ? 6.0 : 7.0;
    final hPad = compact ? 8.0 : 12.0;
    final vPad = compact ? 6.0 : 8.0;

    final visual = marketSessionVisual(widget.state);
    final accent = visual.accent;
    final statusText = visual.label;

    final solidDot = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
    );

    final Widget dot = widget.state == MarketSessionState.open
        ? FadeTransition(opacity: _pulse, child: solidDot)
        : solidDot;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Market',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: labelSize,
              color: AppColors.darkblue,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: widget.state == MarketSessionState.loading ? 0.06 : 0.10,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: accent.withValues(
                  alpha: widget.state == MarketSessionState.loading
                      ? 0.2
                      : 0.35,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 4 : 5,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dot,
                  SizedBox(width: compact ? 4 : 5),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: statusSize,
                      letterSpacing: 0.3,
                    ),
                    child: Text(statusText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact session pill (dot + OPEN / POST-MKT / …) for the markets table row.
class CompactMarketSessionChip extends StatefulWidget {
  const CompactMarketSessionChip({
    super.key,
    required this.state,
    this.isMobile = false,
  });

  final MarketSessionState state;
  final bool isMobile;

  @override
  State<CompactMarketSessionChip> createState() =>
      _CompactMarketSessionChipState();
}

class _CompactMarketSessionChipState extends State<CompactMarketSessionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.35,
      upperBound: 1,
    );
    _syncPulse(widget.state);
  }

  @override
  void didUpdateWidget(covariant CompactMarketSessionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncPulse(widget.state);
    }
  }

  void _syncPulse(MarketSessionState state) {
    final visual = marketSessionVisual(state);
    if (visual.pulse) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final visual = marketSessionVisual(state);
    final accent = visual.accent;
    final fontSize = widget.isMobile ? 10.5 : 11.0;
    final dotSize = widget.isMobile ? 6.0 : 7.0;

    final solidDot = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
    );

    final Widget dot = visual.pulse
        ? FadeTransition(opacity: _pulse, child: solidDot)
        : solidDot;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 5),
        Text(
          visual.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: accent,
            letterSpacing: 0.25,
          ),
        ),
      ],
    );
  }
}

/// Table-row market status — same session source as the ticker [LiveDotDesign].
class DashboardMarketSessionIndicator extends StatelessWidget {
  const DashboardMarketSessionIndicator({super.key, this.isMobile = false});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MarketStatusController>()) {
      return CompactMarketSessionChip(
        state: MarketSessionState.fromIstClock(),
        isMobile: isMobile,
      );
    }

    final mc = Get.find<MarketStatusController>();
    return Obx(
      () => CompactMarketSessionChip(
        state: mc.sessionState.value,
        isMobile: isMobile,
      ),
    );
  }
}
