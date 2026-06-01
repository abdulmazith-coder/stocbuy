import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DashboardAnalysisAnimation extends StatefulWidget {
  const DashboardAnalysisAnimation({super.key});

  @override
  State<DashboardAnalysisAnimation> createState() =>
      _DashboardAnalysisAnimationState();
}

class _DashboardAnalysisAnimationState extends State<DashboardAnalysisAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 640;
        final isTablet = width >= 640 && width < 1024;
        final visualHeight = isMobile
            ? width * .86
            : isTablet
            ? width * .56
            : width * .50;

        return SizedBox(
          height: visualHeight.clamp(310.0, 560.0).toDouble(),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  _AmbientGlow(progress: progress),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DataFlowPainter(progress: progress),
                    ),
                  ),
                  _DashboardFrame(isMobile: isMobile),
                  _ScanningBeam(progress: progress),
                  Positioned(
                    left: isMobile ? 8 : 20,
                    top: isMobile ? 24 : 42,
                    child: _FloatingAnalysisCard(
                      progress: progress,
                      phase: .1,
                      title: 'AI Risk Scan',
                      value: 'LOW',
                      accent: const Color(0xFF22C55E),
                      icon: Icons.shield_rounded,
                    ),
                  ),
                  Positioned(
                    right: isMobile ? 6 : 28,
                    top: isMobile ? 42 : 18,
                    child: _FloatingAnalysisCard(
                      progress: progress,
                      phase: 1.7,
                      title: 'News Impact',
                      value: '+2.8%',
                      accent: const Color(0xFF2563EB),
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                  Positioned(
                    right: isMobile ? 18 : 70,
                    bottom: isMobile ? 20 : 44,
                    child: _MarketSignalPill(
                      progress: progress,
                      label: 'NIFTY AI Trend',
                      value: 'Bullish',
                    ),
                  ),
                  Positioned(
                    left: isMobile ? 18 : 54,
                    bottom: isMobile ? 36 : 58,
                    child: _MiniGraphCard(progress: progress),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _DashboardFrame extends StatelessWidget {
  const _DashboardFrame({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: isMobile ? .96 : .84,
      child: AspectRatio(
        aspectRatio: isMobile ? 1.16 : 1.78,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 24 : 30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .96),
                const Color(0xFFEFF6FF).withValues(alpha: .92),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .86)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: .16),
                blurRadius: 42,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: .13),
                blurRadius: 42,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 22 : 28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _DashboardImage(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: .10),
                        const Color(0xFFDBEAFE).withValues(alpha: .20),
                      ],
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

class _DashboardImage extends StatefulWidget {
  const _DashboardImage();

  @override
  State<_DashboardImage> createState() => _DashboardImageState();
}

class _DashboardImageState extends State<_DashboardImage> {
  late final Future<bool> _hasAsset = _hasDashboardAsset();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasAsset,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const _DashboardFallback();

        return Image.asset(
          'assets/animation_image.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const _DashboardFallback();
          },
        );
      },
    );
  }
}

Future<bool> _hasDashboardAsset() async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().contains('assets/animation_image.png');
  } catch (_) {
    return false;
  }
}

class _DashboardFallback extends StatelessWidget {
  const _DashboardFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFE0F2FE)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _DashboardDot(color: const Color(0xFF22C55E)),
                _DashboardDot(color: const Color(0xFFF59E0B)),
                _DashboardDot(color: const Color(0xFFEF4444)),
                const Spacer(),
                const Text(
                  'StocBuy AI Dashboard',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: CustomPaint(
                      painter: _FallbackChartPainter(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: const [
                        _MetricTile(label: 'TATASTEEL', value: '+3.42%'),
                        SizedBox(height: 10),
                        _MetricTile(label: 'HDFCBANK', value: '+1.18%'),
                        SizedBox(height: 10),
                        _MetricTile(label: 'RELIANCE', value: '-0.44%'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingAnalysisCard extends StatelessWidget {
  const _FloatingAnalysisCard({
    required this.progress,
    required this.phase,
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final double progress;
  final double phase;
  final String title;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final lift = math.sin((progress * math.pi * 2) + phase) * 8;

    return Transform.translate(
      offset: Offset(0, lift),
      child: _GlassPanel(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: accent, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniGraphCard extends StatelessWidget {
  const _MiniGraphCard({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: SizedBox(
        width: 146,
        height: 72,
        child: CustomPaint(painter: _MiniGraphPainter(progress: progress)),
      ),
    );
  }
}

class _MarketSignalPill extends StatelessWidget {
  const _MarketSignalPill({
    required this.progress,
    required this.label,
    required this.value,
  });

  final double progress;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final pulse = .55 + (math.sin(progress * math.pi * 2) * .18);

    return _GlassPanel(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: pulse),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: .36),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            '$label  ',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .92)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: .10),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: .10),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _ScanningBeam extends StatelessWidget {
  const _ScanningBeam({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: .84,
      heightFactor: .70,
      child: Align(
        alignment: Alignment(-1 + (progress * 2), 0),
        child: Container(
          width: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                const Color(0xFF38BDF8).withValues(alpha: .68),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: .32),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final pulse = .18 + (math.sin(progress * math.pi * 2) * .04);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: pulse),
            blurRadius: 120,
            spreadRadius: 50,
          ),
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: .10),
            blurRadius: 110,
            spreadRadius: 42,
          ),
        ],
      ),
      child: const SizedBox(width: 120, height: 120),
    );
  }
}

class _DataFlowPainter extends CustomPainter {
  const _DataFlowPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF2563EB).withValues(alpha: .12);

    for (var i = 0; i < 7; i++) {
      final y = size.height * (.18 + (i * .10));
      final phase = (progress + (i * .11)) % 1;
      final path = Path()..moveTo(size.width * .08, y);
      path.cubicTo(
        size.width * .30,
        y - 36,
        size.width * .68,
        y + 36,
        size.width * .92,
        y,
      );
      canvas.drawPath(path, paint);

      final dotOffset = _pointOnCurve(size, y, phase);
      canvas.drawCircle(
        dotOffset,
        3.2,
        Paint()
          ..color = const Color(0xFF2563EB).withValues(alpha: .34)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  Offset _pointOnCurve(Size size, double y, double t) {
    final x = size.width * (.08 + (.84 * t));
    final wave = math.sin(t * math.pi * 2) * 28;
    return Offset(x, y + wave);
  }

  @override
  bool shouldRepaint(covariant _DataFlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MiniGraphPainter extends CustomPainter {
  const _MiniGraphPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < 18; i++) {
      final t = i / 17;
      final x = t * size.width;
      final y =
          size.height * (.56 - (t * .22)) +
          math.sin((t * math.pi * 4) + (progress * math.pi * 2)) * 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF2563EB)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniGraphPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _FallbackChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: .18)
      ..strokeWidth = 1;

    for (var i = 1; i < 5; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 5),
        Offset(size.width, size.height * i / 5),
        gridPaint,
      );
    }

    final path = Path();
    for (var i = 0; i < 16; i++) {
      final t = i / 15;
      final x = t * size.width;
      final y = size.height * (.70 - (t * .34)) + math.sin(t * 10) * 18;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF22C55E)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardDot extends StatelessWidget {
  const _DashboardDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 42;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .70),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white),
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 6 : 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: compact ? 9 : 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        color: value.startsWith('-')
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF16A34A),
                        fontSize: compact ? 11 : 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
