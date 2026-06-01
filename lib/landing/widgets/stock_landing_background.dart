import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class StockLandingBackground extends StatefulWidget {
  const StockLandingBackground({super.key});

  @override
  State<StockLandingBackground> createState() => _StockLandingBackgroundState();
}

class _StockLandingBackgroundState extends State<StockLandingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<_ShareOrbData> _orbs = [
    _ShareOrbData(
      symbol: 'TCS',
      shortName: 'TCS',
      color: Color(0xFF9FC0FF),
      secondaryColor: Color(0xFF3157C8),
      desktopPosition: Offset(.04, .47),
      tabletPosition: Offset(.08, .42),
      mobilePosition: Offset(.13, .35),
      size: 90,
      phase: .1,
      drift: 28,
      labelAlignment: Alignment.bottomRight,
      blobSeed: .2,
      price: '₹4,012.30',
      tokenShape: _TokenShape.diamond,
    ),
    _ShareOrbData(
      symbol: 'INFY',
      shortName: 'INFY',
      color: Color(0xFF23CFAD),
      secondaryColor: Color(0xFF06736D),
      desktopPosition: Offset(.22, .50),
      tabletPosition: Offset(.24, .48),
      mobilePosition: Offset(.74, .34),
      size: 116,
      phase: 1.0,
      drift: 34,
      labelAlignment: Alignment.bottomRight,
      blobSeed: 1.1,
      price: '₹1,539.45',
      tokenShape: _TokenShape.squircle,
    ),
    _ShareOrbData(
      symbol: 'HDFCBANK',
      shortName: 'HDFC',
      color: Color(0xFFFFC842),
      secondaryColor: Color(0xFFB46304),
      desktopPosition: Offset(.30, .87),
      tabletPosition: Offset(.30, .78),
      mobilePosition: Offset(.27, .64),
      size: 126,
      phase: 2.0,
      drift: 32,
      labelAlignment: Alignment.topLeft,
      blobSeed: 2.2,
      price: '₹1,987.20',
      tokenShape: _TokenShape.hexagon,
    ),
    _ShareOrbData(
      symbol: 'RELIANCE',
      shortName: 'REL',
      color: Color(0xFF1EC68D),
      secondaryColor: Color(0xFF026E59),
      desktopPosition: Offset(.07, .91),
      tabletPosition: Offset(.10, .88),
      mobilePosition: Offset(.17, .84),
      size: 100,
      phase: 2.9,
      drift: 26,
      labelAlignment: Alignment.topRight,
      blobSeed: 3.2,
      price: '₹2,839.10',
      tokenShape: _TokenShape.roundedSquare,
    ),
    _ShareOrbData(
      symbol: 'ICICIBANK',
      shortName: 'ICICI',
      color: Color(0xFFFF6576),
      secondaryColor: Color(0xFF73313A),
      desktopPosition: Offset(.69, .43),
      tabletPosition: Offset(.75, .48),
      mobilePosition: Offset(.82, .57),
      size: 112,
      phase: 3.7,
      drift: 28,
      labelAlignment: Alignment.bottomLeft,
      blobSeed: 4.1,
      price: '₹1,424.75',
      tokenShape: _TokenShape.softBlob,
    ),
    _ShareOrbData(
      symbol: 'SBIN',
      shortName: 'SBI',
      color: Color(0xFF7EA4FF),
      secondaryColor: Color(0xFF263FA3),
      desktopPosition: Offset(.85, .43),
      tabletPosition: Offset(.84, .34),
      mobilePosition: Offset(.72, .76),
      size: 104,
      phase: 4.6,
      drift: 30,
      labelAlignment: Alignment.bottomLeft,
      blobSeed: 4.9,
      price: '₹806.40',
      tokenShape: _TokenShape.diamond,
    ),
    _ShareOrbData(
      symbol: 'ITC',
      shortName: 'ITC',
      color: Color(0xFF69EABB),
      secondaryColor: Color(0xFF087249),
      desktopPosition: Offset(.79, .79),
      tabletPosition: Offset(.76, .73),
      mobilePosition: Offset(.51, .86),
      size: 104,
      phase: 5.4,
      drift: 29,
      labelAlignment: Alignment.topLeft,
      blobSeed: 5.5,
      price: '₹421.80',
      tokenShape: _TokenShape.hexagon,
    ),
    _ShareOrbData(
      symbol: 'LT',
      shortName: 'L&T',
      color: Color(0xFF9A78FF),
      secondaryColor: Color(0xFF322075),
      desktopPosition: Offset(.76, .04),
      tabletPosition: Offset(.72, .11),
      mobilePosition: Offset(.53, .16),
      size: 128,
      phase: 2.6,
      drift: 28,
      labelAlignment: Alignment.bottomLeft,
      blobSeed: 2.8,
      price: '₹3,612.65',
      tokenShape: _TokenShape.squircle,
    ),
    _ShareOrbData(
      symbol: 'MARUTI',
      shortName: 'M',
      color: Color(0xFFFFA45A),
      secondaryColor: Color(0xFF74411F),
      desktopPosition: Offset(.32, .05),
      tabletPosition: Offset(.32, .12),
      mobilePosition: Offset(.87, .15),
      size: 110,
      phase: 5.9,
      drift: 27,
      labelAlignment: Alignment.bottomRight,
      blobSeed: 6.1,
      price: '₹12,408.50',
      tokenShape: _TokenShape.roundedSquare,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 52),
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
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final breakpoint = _LandingBreakpoint.fromWidth(size.width);

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            const _BaseGradient(),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: breakpoint == _LandingBreakpoint.mobile ? .95 : .72,
                    colors: const [
                      Color(0xF2FFFFFF),
                      Color(0xBFF8FAFC),
                      Color(0x00F8FAFC),
                    ],
                    stops: [0, .56, 1],
                  ),
                ),
              ),
            ),
            for (final orb in _orbs)
              _FloatingShareOrb(
                data: orb,
                animation: _controller,
                canvasSize: size,
                breakpoint: breakpoint,
              ),
          ],
        );
      },
    );
  }
}

enum _LandingBreakpoint {
  desktop,
  tablet,
  mobile;

  static _LandingBreakpoint fromWidth(double width) {
    if (width < 700) return _LandingBreakpoint.mobile;
    if (width < 1050) return _LandingBreakpoint.tablet;
    return _LandingBreakpoint.desktop;
  }
}

class _FloatingShareOrb extends StatefulWidget {
  const _FloatingShareOrb({
    required this.data,
    required this.animation,
    required this.canvasSize,
    required this.breakpoint,
  });

  final _ShareOrbData data;
  final Animation<double> animation;
  final Size canvasSize;
  final _LandingBreakpoint breakpoint;

  @override
  State<_FloatingShareOrb> createState() => _FloatingShareOrbState();
}

class _FloatingShareOrbState extends State<_FloatingShareOrb> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    final scale = switch (widget.breakpoint) {
      _LandingBreakpoint.desktop => 1.0,
      _LandingBreakpoint.tablet => .88,
      _LandingBreakpoint.mobile => .68,
    };
    final orbSize = widget.data.size * scale;
    final position = widget.data.positionFor(widget.breakpoint);
    final drift =
        widget.data.drift *
        switch (widget.breakpoint) {
          _LandingBreakpoint.desktop => 1.0,
          _LandingBreakpoint.tablet => .72,
          _LandingBreakpoint.mobile => .38,
        };

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final time = widget.animation.value * math.pi * 2;
        final phase = widget.data.phase;
        final travelX =
            (math.sin(time + phase) * drift) +
            (math.sin((time * 2) + phase * .7) * drift * .18);
        final travelY =
            (math.cos(time + phase * .9) * drift * .72) +
            (math.sin((time * 3) + phase) * drift * .14);

        return Positioned(
          left:
              (position.dx * widget.canvasSize.width) - (orbSize / 2) + travelX,
          top:
              (position.dy * widget.canvasSize.height) -
              (orbSize / 2) +
              travelY,
          width: orbSize,
          height: orbSize,
          child: child!,
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isRevealed = true),
        onExit: (_) => setState(() => _isRevealed = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) => setState(() => _isRevealed = true),
          onTapCancel: () => setState(() => _isRevealed = false),
          onTapUp: (_) {
            Future<void>.delayed(const Duration(milliseconds: 950), () {
              if (mounted) setState(() => _isRevealed = false);
            });
          },
          child: _ShareOrb(data: widget.data, isRevealed: _isRevealed),
        ),
      ),
    );
  }
}

class _ShareOrb extends StatelessWidget {
  const _ShareOrb({required this.data, required this.isRevealed});

  final _ShareOrbData data;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isRevealed ? 1.14 : 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelOffset = _labelOffset(
            data.labelAlignment,
            constraints.biggest.shortestSide,
          );

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: isRevealed ? .86 : .92,
                duration: const Duration(milliseconds: 260),
                child: _SoftBackgroundBlob(data: data),
              ),
              AnimatedOpacity(
                opacity: isRevealed ? 1 : 0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: _GlassHoverGlow(data: data),
              ),
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: isRevealed ? 0 : 1.2,
                  sigmaY: isRevealed ? 0 : 1.2,
                ),
                child: AnimatedOpacity(
                  opacity: isRevealed ? 1 : .76,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: _HoverShareToken(data: data, isRevealed: isRevealed),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: labelOffset.dx,
                top: labelOffset.dy,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: isRevealed ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: _ShareHoverLabel(data: data),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Offset _labelOffset(Alignment alignment, double size) {
    final horizontal = alignment.x < 0 ? -size * .58 : size * .82;
    final vertical = alignment.y < 0 ? size * .20 : size * .42;
    return Offset(horizontal, vertical);
  }
}

class _GlassHoverGlow extends StatelessWidget {
  const _GlassHoverGlow({required this.data});

  final _ShareOrbData data;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 1.46,
      heightFactor: 1.46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .24),
          border: Border.all(
            color: Colors.white.withValues(alpha: .78),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: .44),
              blurRadius: 38,
              spreadRadius: 8,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: .70),
              blurRadius: 20,
              spreadRadius: -3,
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftBackgroundBlob extends StatelessWidget {
  const _SoftBackgroundBlob({required this.data});

  final _ShareOrbData data;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: CustomPaint(
        painter: _SoftBlobPainter(data: data),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SoftBlobPainter extends CustomPainter {
  const _SoftBlobPainter({required this.data});

  final _ShareOrbData data;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .5;
    final path = Path();

    for (var i = 0; i < 10; i++) {
      final angle = (math.pi * 2 / 10) * i;
      final wobble = .76 + (math.sin(data.blobSeed + i * 1.73) * .2);
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * wobble;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        final prevAngle = (math.pi * 2 / 10) * (i - .5);
        final control =
            center +
            Offset(math.cos(prevAngle), math.sin(prevAngle)) * radius * 1.12;
        path.quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);
      }
    }
    path.close();

    final rect = Rect.fromCircle(center: center, radius: radius * 1.35);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.28, -.25),
        colors: [
          Color.lerp(data.color, Colors.white, .12)!.withValues(alpha: .84),
          data.color.withValues(alpha: .50),
          data.secondaryColor.withValues(alpha: .22),
          data.secondaryColor.withValues(alpha: 0),
        ],
        stops: const [0, .33, .72, 1],
      ).createShader(rect);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SoftBlobPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _HoverShareToken extends StatelessWidget {
  const _HoverShareToken({required this.data, required this.isRevealed});

  final _ShareOrbData data;
  final bool isRevealed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _HoverRing(
          data: data,
          scale: 1.72,
          opacity: isRevealed ? .18 : .07,
          width: 1,
        ),
        _HoverRing(
          data: data,
          scale: 1.48,
          opacity: isRevealed ? .24 : .10,
          width: 1,
        ),
        _HoverRing(
          data: data,
          scale: 1.24,
          opacity: isRevealed ? .30 : .14,
          width: 1.2,
        ),
        FractionallySizedBox(
          widthFactor: .9,
          heightFactor: .9,
          child: CustomPaint(
            painter: _TokenShapePainter(data: data),
            child: Center(child: _StockName(data: data)),
          ),
        ),
      ],
    );
  }
}

class _TokenShapePainter extends CustomPainter {
  const _TokenShapePainter({required this.data});

  final _ShareOrbData data;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shapePath(size, data.tokenShape, data.blobSeed);
    final rect = Offset.zero & size;

    canvas.drawShadow(path, data.color.withValues(alpha: .26), 12, false);

    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.22, -.3),
        colors: [
          Color.lerp(data.color, Colors.white, .22)!,
          data.color,
          data.secondaryColor,
        ],
        stops: const [0, .52, 1],
      ).createShader(rect);

    canvas.drawPath(path, paint);
  }

  Path _shapePath(Size size, _TokenShape shape, double seed) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) * .48;

    switch (shape) {
      case _TokenShape.roundedSquare:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            rect.deflate(w * .07),
            Radius.circular(w * .22),
          ),
        );
      case _TokenShape.squircle:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            rect.deflate(w * .05),
            Radius.circular(w * .32),
          ),
        );
      case _TokenShape.diamond:
        return Path()
          ..moveTo(center.dx, h * .05)
          ..lineTo(w * .95, center.dy)
          ..lineTo(center.dx, h * .95)
          ..lineTo(w * .05, center.dy)
          ..close();
      case _TokenShape.hexagon:
        final path = Path();
        for (var i = 0; i < 6; i++) {
          final angle = (-math.pi / 2) + (math.pi * 2 / 6) * i;
          final point =
              center + Offset(math.cos(angle), math.sin(angle)) * radius;
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        return path..close();
      case _TokenShape.softBlob:
        final path = Path();
        for (var i = 0; i < 9; i++) {
          final angle = (math.pi * 2 / 9) * i;
          final wobble = .86 + math.sin(seed + i * 1.47) * .12;
          final point =
              center +
              Offset(math.cos(angle), math.sin(angle)) * radius * wobble;
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            final controlAngle = (math.pi * 2 / 9) * (i - .5);
            final control =
                center +
                Offset(math.cos(controlAngle), math.sin(controlAngle)) *
                    radius *
                    1.05;
            path.quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);
          }
        }
        return path..close();
    }
  }

  @override
  bool shouldRepaint(covariant _TokenShapePainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _StockName extends StatelessWidget {
  const _StockName({required this.data});

  final _ShareOrbData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          data.shortName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .95),
            fontWeight: FontWeight.w900,
            fontSize: data.shortName.length > 3 ? 12 : 15,
            letterSpacing: -.35,
            shadows: const [
              Shadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareHoverLabel extends StatelessWidget {
  const _ShareHoverLabel({required this.data});

  final _ShareOrbData data;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: .14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.symbol,
            style: TextStyle(
              color: data.color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '▲',
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                data.price,
                style: TextStyle(
                  color: const Color(0xFF111827).withValues(alpha: .92),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoverRing extends StatelessWidget {
  const _HoverRing({
    required this.data,
    required this.scale,
    required this.opacity,
    required this.width,
  });

  final _ShareOrbData data;
  final double scale;
  final double opacity;
  final double width;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: scale,
      heightFactor: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: data.color.withValues(alpha: opacity),
            width: width,
          ),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: opacity * .55),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

enum _TokenShape { roundedSquare, squircle, diamond, hexagon, softBlob }

class _BaseGradient extends StatelessWidget {
  const _BaseGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F8FC),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.12,
          colors: [Color(0xFFFFFFFF), Color(0xFFF4F8FF), Color(0xFFEAF1F8)],
          stops: [0, .52, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ShareOrbData {
  const _ShareOrbData({
    required this.symbol,
    required this.shortName,
    required this.color,
    required this.secondaryColor,
    required this.desktopPosition,
    required this.tabletPosition,
    required this.mobilePosition,
    required this.size,
    required this.phase,
    required this.drift,
    required this.labelAlignment,
    required this.blobSeed,
    required this.price,
    required this.tokenShape,
  });

  final String symbol;
  final String shortName;
  final Color color;
  final Color secondaryColor;
  final Offset desktopPosition;
  final Offset tabletPosition;
  final Offset mobilePosition;
  final double size;
  final double phase;
  final double drift;
  final Alignment labelAlignment;
  final double blobSeed;
  final String price;
  final _TokenShape tokenShape;

  Offset positionFor(_LandingBreakpoint breakpoint) {
    return switch (breakpoint) {
      _LandingBreakpoint.desktop => desktopPosition,
      _LandingBreakpoint.tablet => tabletPosition,
      _LandingBreakpoint.mobile => mobilePosition,
    };
  }
}
