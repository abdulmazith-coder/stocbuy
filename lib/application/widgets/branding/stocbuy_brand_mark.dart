import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stocbuy icon — black rounded square + white market trend line (landing style).
class StocbuyLogoMark extends StatelessWidget {
  const StocbuyLogoMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StocbuyLogoPainter()),
    );
  }
}

/// @deprecated Use [StocbuyLogoMark].
typedef StocbuyBarChartLogo = StocbuyLogoMark;

/// Logo + wordmark row for compact (mobile/tablet) and expanded (desktop) headers.
class StocbuyBrandMark extends StatelessWidget {
  const StocbuyBrandMark({
    super.key,
    this.compact = false,
    this.labelOverride,
    this.labelColor = const Color(0xFF111827),
    this.logoSize,
  });

  final bool compact;
  final String? labelOverride;
  final Color labelColor;
  final double? logoSize;

  @override
  Widget build(BuildContext context) {
    final logo = logoSize ?? (compact ? 22.0 : 24.0);
    final fontSize = compact ? 18.0 : 20.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StocbuyLogoMark(size: logo),
        SizedBox(width: compact ? 8 : 10),
        Text(
          labelOverride ?? 'Stocbuy',
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: labelColor,
            letterSpacing: -0.35,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _StocbuyLogoPainter extends CustomPainter {
  /// Solid black tile — matches landing page mockup.
  static const Color _tile = Color(0xFF0A0A0A);
  static const Color _ink = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final corner = w * 0.22;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        Radius.circular(corner),
      ),
      Paint()..color = _tile,
    );

    final stroke = w * 0.095;
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final start = Offset(w * 0.18, h * 0.74);
    final peak = Offset(w * 0.40, h * 0.36);
    final trough = Offset(w * 0.52, h * 0.48);
    final end = Offset(w * 0.78, h * 0.26);

    final trend = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(peak.dx, peak.dy)
      ..lineTo(trough.dx, trough.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(trend, line);

    final dotR = w * 0.055;
    final dot = Paint()..color = _ink;
    canvas.drawCircle(start, dotR, dot);
    canvas.drawCircle(end, dotR, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
