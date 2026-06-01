import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/models/stock_ohlc.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/stock_formatters.dart';

/// Production-grade candlestick chart, painted on a CustomPainter so it has
/// zero external dependencies and inherits the rest of the app's typography
/// and colours.
///
/// Layout (rendered inside [height]):
///   ┌──────────────────────────────────────────────────────────────────────┐
///   │  ●  TCS · 1D · NSE   O 3790  H 3945  L 3760  C 3824   +44.15 (+1.17%)│
///   │                       Vol: 2.9M                                       │
///   ├──────────────────────────────────────────────────────────────────────┤
///   │                                                                       │
///   │      Candles area (with grid, last-price marker, crosshair)           │
///   │                                                                       │
///   ├──────────────────────────────────────────────────────────────────────┤
///   │      Volume bars (~22% of plot height)                                │
///   ├──────────────────────────────────────────────────────────────────────┤
///   │  Feb           Mar           Apr           May                        │
///   └──────────────────────────────────────────────────────────────────────┘
///
/// Features:
///   • Right-aligned price axis with 5 evenly-spaced gridlines.
///   • Volume bar band underneath the candles, coloured by candle direction.
///   • Persistent "last close" marker — dashed horizontal line + dark pill on
///     the right axis at the latest closing price.
///   • Hover (mouse) or drag (touch) anywhere to drop a dashed crosshair, a
///     teal price pill on the right axis, and a dark date pill in the bottom
///     time axis. Lifting / leaving clears it.
///   • The top OHLC strip ("● TCS · 1D · NSE   O ... C ... +x (+y%)  Vol: …")
///     follows the hovered candle, falling back to the latest candle when no
///     crosshair is active.
class StockCandleChart extends StatefulWidget {
  const StockCandleChart({
    super.key,
    required this.candles,
    this.symbolLabel = '',
    this.height = 380,
  });

  final List<StockOhlc> candles;
  final String symbolLabel;
  final double height;

  @override
  State<StockCandleChart> createState() => _StockCandleChartState();
}

class _StockCandleChartState extends State<StockCandleChart> {
  int? _hoverIndex;
  Offset? _hoverPos;
  Size? _chartSize;

  static const double _axisRightWidth = 66;
  static const double _axisBottomHeight = 26;
  static const double _stripHeight = 36;

  @override
  void didUpdateWidget(StockCandleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.candles, widget.candles)) {
      _hoverIndex = null;
      _hoverPos = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final candles = widget.candles;

    if (candles.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'No chart data',
            style: TextStyle(
              color: AppColors.grey,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final displayedIndex = _hoverIndex ?? candles.length - 1;
    final displayedCandle = candles[displayedIndex];
    final prevClose = displayedIndex > 0
        ? candles[displayedIndex - 1].close
        : displayedCandle.open;

    return SizedBox(
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OhlcStrip(
            symbolLabel: widget.symbolLabel,
            candles: candles,
            candleIndex: displayedIndex,
            candle: displayedCandle,
            referenceClose: prevClose,
          ),
          Container(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.55),
          ),
          Expanded(
            child: MouseRegion(
              onExit: (_) => _clearHover(),
              onHover: (e) => _updateHover(e.localPosition),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _updateHover(d.localPosition),
                onPanUpdate: (d) => _updateHover(d.localPosition),
                onPanEnd: (_) => _clearHover(),
                onTapUp: (_) => _clearHover(),
                child: LayoutBuilder(
                  builder: (context, c) {
                    _chartSize = Size(c.maxWidth, c.maxHeight);
                    return CustomPaint(
                      painter: _CandlePainter(
                        candles: candles,
                        hoverIndex: _hoverIndex,
                        axisRightWidth: _axisRightWidth,
                        axisBottomHeight: _axisBottomHeight,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateHover(Offset pos) {
    final size = _chartSize;
    if (size == null) return;
    final plotWidth = size.width - _axisRightWidth;
    if (plotWidth <= 0) return;
    final n = widget.candles.length;
    if (n == 0) return;
    if (pos.dx < 0 ||
        pos.dx > plotWidth ||
        pos.dy < 0 ||
        pos.dy > size.height - _axisBottomHeight) {
      _clearHover();
      return;
    }
    final perCandle = plotWidth / n;
    final idx = (pos.dx / perCandle).floor().clamp(0, n - 1);
    if (idx != _hoverIndex || _hoverPos != pos) {
      setState(() {
        _hoverIndex = idx;
        _hoverPos = pos;
      });
    }
  }

  void _clearHover() {
    if (_hoverIndex == null && _hoverPos == null) return;
    setState(() {
      _hoverIndex = null;
      _hoverPos = null;
    });
  }

  // Used to size the column above.
  // (Stored as a class-level const so the painter can reference it too.)
  // ignore: unused_element
  double get stripHeight => _stripHeight;
}

// —— Top OHLC info strip ————————————————————————————————————————————————

class _OhlcStrip extends StatelessWidget {
  const _OhlcStrip({
    required this.symbolLabel,
    required this.candles,
    required this.candleIndex,
    required this.candle,
    required this.referenceClose,
  });

  final String symbolLabel;
  final List<StockOhlc> candles;
  final int candleIndex;
  final StockOhlc candle;
  final double referenceClose;

  @override
  Widget build(BuildContext context) {
    final change = candle.close - referenceClose;
    final pct = referenceClose == 0
        ? 0.0
        : (change / referenceClose) * 100;
    final isUp = StockOhlc.isUpBar(candles, candleIndex);
    final changeColor = isUp ? AppColors.green : AppColors.red;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: changeColor,
              ),
            ),
            const SizedBox(width: 8),
            if (symbolLabel.isNotEmpty) ...[
              Text(
                symbolLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkblue,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 12),
            ],
            _OhlcKv(label: 'O', value: candle.open),
            const SizedBox(width: 10),
            _OhlcKv(label: 'H', value: candle.high),
            const SizedBox(width: 10),
            _OhlcKv(label: 'L', value: candle.low),
            const SizedBox(width: 10),
            _OhlcKv(label: 'C', value: candle.close, color: changeColor),
            const SizedBox(width: 14),
            Text(
              '${isUp ? '+' : ''}${change.toStringAsFixed(2)} '
              '(${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: changeColor,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(width: 18),
            Text(
              'Vol: ${StockFormatters.compactNumber(candle.volume)}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.grey,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OhlcKv extends StatelessWidget {
  const _OhlcKv({required this.label, required this.value, this.color});
  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.grey,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _CandlePainter._formatAxisPrice(value),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: color ?? AppColors.darkblue,
            letterSpacing: -0.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// —— Painter ——————————————————————————————————————————————————————————————

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.candles,
    required this.hoverIndex,
    required this.axisRightWidth,
    required this.axisBottomHeight,
  });

  final List<StockOhlc> candles;
  final int? hoverIndex;
  final double axisRightWidth;
  final double axisBottomHeight;

  static const _upColor = AppColors.green;
  static const _downColor = AppColors.red;
  static const _gridColor = AppColors.border;
  static const _axisLabelColor = AppColors.grey;

  bool _isUp(int index) => StockOhlc.isUpBar(candles, index);

  Color _barColor(int index) => _isUp(index) ? _upColor : _downColor;

  /// Volume band takes this fraction of the plot's vertical space at the
  /// bottom. The remainder is the candles area.
  static const double _volumeBandFraction = 0.22;
  static const double _bandGap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    // Overall drawable plot (everything except the right axis & bottom axis).
    final plot = Rect.fromLTWH(
      0,
      0,
      size.width - axisRightWidth,
      size.height - axisBottomHeight,
    );

    // Carve plot vertically: candles on top, volume on bottom.
    final volumeHeight = plot.height * _volumeBandFraction;
    final candlesRect = Rect.fromLTWH(
      plot.left,
      plot.top,
      plot.width,
      plot.height - volumeHeight - _bandGap,
    );
    final volumeRect = Rect.fromLTWH(
      plot.left,
      candlesRect.bottom + _bandGap,
      plot.width,
      volumeHeight,
    );

    // Compute price range across candles.
    var high = candles.first.high;
    var low = candles.first.low;
    num maxVol = 0;
    for (final c in candles) {
      if (c.high > high) high = c.high;
      if (c.low < low) low = c.low;
      if (c.volume > maxVol) maxVol = c.volume;
    }
    final span = (high - low).abs();
    if (span == 0) {
      high += 1;
      low -= 1;
    } else {
      final pad = span * 0.06;
      high += pad;
      low -= pad;
    }

    _drawAxisGutter(canvas, plot, size);
    _drawGridAndPriceAxis(canvas, candlesRect, size, high, low);
    _drawTimeAxis(canvas, plot, size);
    _drawVolumeBars(canvas, volumeRect, maxVol);
    _drawCandles(canvas, candlesRect, high, low);
    _drawLastPriceMarker(canvas, candlesRect, high, low);
    _drawCrosshair(canvas, candlesRect, plot, high, low);
  }

  /// Subtle background tint behind the right-side price axis — same trick
  /// TradingView uses to visually separate the price scale from the plot.
  void _drawAxisGutter(Canvas canvas, Rect plot, Size size) {
    final gutter = Rect.fromLTWH(
      plot.right,
      0,
      axisRightWidth,
      size.height,
    );
    canvas.drawRect(
      gutter,
      Paint()..color = AppColors.surfaceMuted.withValues(alpha: 0.35),
    );
    // Hairline separator between plot and axis gutter.
    canvas.drawLine(
      Offset(plot.right, 0),
      Offset(plot.right, size.height - axisBottomHeight),
      Paint()
        ..color = _gridColor.withValues(alpha: 0.7)
        ..strokeWidth = 1,
    );
  }

  // —— Grid + right price axis ————————————————————————————————————————————

  void _drawGridAndPriceAxis(
    Canvas canvas,
    Rect plot,
    Size size,
    double high,
    double low,
  ) {
    final gridPaint = Paint()
      ..color = _gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // "Nice number" ticks — pick a step that rounds to 1/2/2.5/5 × 10^k so
    // axis labels read like real prices (3,700 / 3,750 / 3,800) instead of
    // arbitrary fractions (3787.43 / 3825.67 / …).
    const targetTicks = 6;
    final niceStep = _niceStep((high - low) / targetTicks);
    final firstTick = (low / niceStep).floor() * niceStep;
    final lastTick = (high / niceStep).ceil() * niceStep;

    for (var price = firstTick; price <= lastTick + 1e-9; price += niceStep) {
      if (price < low || price > high) continue;
      final t = (high - price) / (high - low);
      final y = plot.top + plot.height * t;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _paintLabel(
        canvas,
        _formatAxisPrice(price),
        Offset(plot.right + 8, y - 7),
        align: TextAlign.left,
        color: _axisLabelColor,
        weight: FontWeight.w700,
      );
    }
  }

  /// Round a raw tick spacing up to the nearest "nice" fraction of a
  /// power-of-ten:
  ///   • 1, 2, 2.5, 5, 10  × 10^n
  /// e.g. raw step 17.3 → 25; raw step 312 → 500; raw step 0.041 → 0.05.
  static double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final exp = (math.log(raw) / math.ln10).floor();
    final pow10 = math.pow(10, exp).toDouble();
    final fraction = raw / pow10;
    double nice;
    if (fraction <= 1) {
      nice = 1;
    } else if (fraction <= 2) {
      nice = 2;
    } else if (fraction <= 2.5) {
      nice = 2.5;
    } else if (fraction <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * pow10;
  }

  /// Indian comma grouping for axis prices: 3824.5 → "3,824.50".
  static String _formatAxisPrice(double v) {
    final fixed = v.toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    final intPart = fixed.substring(0, dot);
    final dec = fixed.substring(dot + 1);
    final neg = intPart.startsWith('-');
    final body = neg ? intPart.substring(1) : intPart;
    if (body.length <= 3) {
      return '${neg ? '-' : ''}$body.$dec';
    }
    final last3 = body.substring(body.length - 3);
    final rest = body.substring(0, body.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '${neg ? '-' : ''}$buf,$last3.$dec';
  }

  // —— Bottom time axis ————————————————————————————————————————————————————

  void _drawTimeAxis(Canvas canvas, Rect plot, Size size) {
    final n = candles.length;
    final maxTicks = (plot.width / 110).floor().clamp(2, 6);
    final step = math.max(1, (n / maxTicks).floor());
    for (var i = 0; i < n; i += step) {
      final x = plot.left + (plot.width / n) * (i + 0.5);
      final dt = candles[i].time;
      _paintLabel(
        canvas,
        _formatAxisDate(dt),
        Offset(x - 30, plot.bottom + 6),
        align: TextAlign.center,
        color: _axisLabelColor,
        weight: FontWeight.w600,
      );
    }
  }

  // —— Volume bars ————————————————————————————————————————————————————————

  void _drawVolumeBars(Canvas canvas, Rect band, num maxVol) {
    if (band.height <= 0 || maxVol <= 0) return;
    final n = candles.length;
    final perCandle = band.width / n;
    final barWidth = (perCandle * 0.7).clamp(2.0, 14.0);

    for (var i = 0; i < n; i++) {
      final c = candles[i];
      final h = (c.volume / maxVol) * band.height;
      final x = band.left + perCandle * (i + 0.5);
      final rect = Rect.fromLTWH(
        x - barWidth / 2,
        band.bottom - h,
        barWidth,
        math.max(1.0, h.toDouble()),
      );
      final color = _barColor(i).withValues(alpha: 0.55);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.2)),
        Paint()..color = color,
      );
    }
  }

  // —— Candles ————————————————————————————————————————————————————————————

  void _drawCandles(Canvas canvas, Rect plot, double high, double low) {
    final n = candles.length;
    final perCandle = plot.width / n;
    final bodyWidth = (perCandle * 0.7).clamp(2.0, 14.0);
    final wickWidth = (bodyWidth * 0.18).clamp(1.0, 2.0);

    double yOf(double price) {
      final t = (high - price) / (high - low);
      return plot.top + plot.height * t;
    }

    for (var i = 0; i < n; i++) {
      final c = candles[i];
      final x = plot.left + perCandle * (i + 0.5);
      final color = _barColor(i);

      // Wick.
      final wick = Paint()
        ..color = color
        ..strokeWidth = wickWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, yOf(c.high)), Offset(x, yOf(c.low)), wick);

      // Body.
      final openY = yOf(c.open);
      final closeY = yOf(c.close);
      final top = math.min(openY, closeY);
      final bottom = math.max(openY, closeY);
      final body = Rect.fromLTWH(
        x - bodyWidth / 2,
        top,
        bodyWidth,
        math.max(1.0, bottom - top),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(1.4)),
        Paint()..color = color,
      );
    }
  }

  // —— Persistent "last close" marker ——————————————————————————————————————

  void _drawLastPriceMarker(Canvas canvas, Rect plot, double high, double low) {
    if (candles.isEmpty) return;
    final lastIndex = candles.length - 1;
    final last = candles[lastIndex];
    final price = last.close;
    final y = plot.top + plot.height * (high - price) / (high - low);
    final barColor = _barColor(lastIndex);

    // Dashed horizontal line across the candles area — slightly heavier
    // than the grid so the "you are here" feel reads at a glance.
    final dashPaint = Paint()
      ..color = barColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    _dashedLine(canvas, Offset(plot.left, y), Offset(plot.right, y), dashPaint);

    // Single live-price pill on the axis (green up / red down vs prev bar).
    _drawAxisPricePill(
      canvas,
      y,
      plot.right,
      _formatAxisPrice(price),
      bg: barColor,
      fg: AppColors.white,
    );
  }

  // —— Crosshair (dashed + teal price pill + dark date pill) ——————————————

  void _drawCrosshair(
    Canvas canvas,
    Rect candlesPlot,
    Rect fullPlot,
    double high,
    double low,
  ) {
    final idx = hoverIndex;
    if (idx == null || idx < 0 || idx >= candles.length) return;

    final perCandle = candlesPlot.width / candles.length;
    final x = candlesPlot.left + perCandle * (idx + 0.5);
    final candle = candles[idx];
    final y = candlesPlot.top +
        (candlesPlot.height * (high - candle.close) / (high - low));

    final paint = Paint()
      ..color = AppColors.darkblue.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    // Vertical dashed line (full plot height — spans candles + volume bands).
    _dashedLine(
      canvas,
      Offset(x, candlesPlot.top),
      Offset(x, fullPlot.bottom),
      paint,
    );
    // Horizontal dashed line inside candles band.
    _dashedLine(
      canvas,
      Offset(candlesPlot.left, y),
      Offset(candlesPlot.right, y),
      paint,
    );

    // Historical bars only — skip the axis pill on the live bar so we don't
    // stack a blue/teal tag on top of the green/red last-price marker.
    if (idx < candles.length - 1) {
      _drawAxisPricePill(
        canvas,
        y,
        candlesPlot.right,
        _formatAxisPrice(candle.close),
        bg: _barColor(idx),
        fg: AppColors.white,
      );
    }

    // Dark date pill below the chart at the crosshair x position.
    _drawDateChip(
      canvas,
      x,
      fullPlot.bottom + 4,
      _formatTooltipDate(candle.time),
    );
  }

  // —— Right-axis price pill helper ———————————————————————————————————————

  void _drawAxisPricePill(
    Canvas canvas,
    double y,
    double rightEdge,
    String text, {
    required Color bg,
    required Color fg,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pillRect = Rect.fromLTWH(
      rightEdge + 2,
      y - tp.height / 2 - 3,
      tp.width + 12,
      tp.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(4)),
      Paint()..color = bg,
    );
    tp.paint(canvas, Offset(pillRect.left + 6, pillRect.top + 3));
  }

  // —— Bottom-axis date chip helper —————————————————————————————————————

  void _drawDateChip(Canvas canvas, double cx, double top, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 14;
    final h = tp.height + 6;
    final left = cx - w / 2;
    final rect = Rect.fromLTWH(left, top, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = AppColors.darkblue,
    );
    tp.paint(canvas, Offset(rect.left + 7, rect.top + 3));
  }

  // —— Dashed line helper ————————————————————————————————————————————————

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dash = 4, double gap = 4}) {
    final delta = b - a;
    final dist = delta.distance;
    if (dist == 0) return;
    final dir = delta / dist;
    var travelled = 0.0;
    while (travelled < dist) {
      final end = math.min(travelled + dash, dist);
      canvas.drawLine(a + dir * travelled, a + dir * end, paint);
      travelled = end + gap;
    }
  }

  // —— Text helper ————————————————————————————————————————————————————————

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset position, {
    TextAlign align = TextAlign.left,
    Color color = const Color(0xFF58667E),
    FontWeight weight = FontWeight.w600,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: 60);
    tp.paint(canvas, position);
  }

  String _formatAxisDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final isIntraday = candles.isNotEmpty &&
        candles.last.time.difference(candles.first.time).inHours < 36;
    if (isIntraday) {
      return StockFormatters.hhmm(dt);
    }
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
  }

  String _formatTooltipDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final isIntraday = candles.isNotEmpty &&
        candles.last.time.difference(candles.first.time).inHours < 36;
    if (isIntraday) {
      return '${StockFormatters.hhmm(dt)}  ·  '
          '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
    }
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) {
    return old.candles != candles || old.hoverIndex != hoverIndex;
  }
}
