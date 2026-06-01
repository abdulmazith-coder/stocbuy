import 'package:flutter/material.dart';

const _kBlue = Color(0xFF3B82F6);

class FinalCtaSection extends StatelessWidget {
  const FinalCtaSection({
    super.key,
    this.onGetStarted,
    this.onViewPricing,
  });

  final VoidCallback? onGetStarted;
  final VoidCallback? onViewPricing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hp = w < 640 ? 24.0 : (w < 1024 ? 40.0 : 64.0);
        final isMobile = w < 640;

        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(hp, 80, hp, 80),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: _CtaBanner(
                isMobile: isMobile,
                onGetStarted: onGetStarted,
                onViewPricing: onViewPricing,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CtaBanner extends StatelessWidget {
  const _CtaBanner({
    required this.isMobile,
    this.onGetStarted,
    this.onViewPricing,
  });

  final bool isMobile;
  final VoidCallback? onGetStarted;
  final VoidCallback? onViewPricing;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          // Background
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF0A0A0A)),
            ),
          ),
          // Decorative blobs
          Positioned(
            top: -60,
            right: -40,
            child: _GlowBlob(color: _kBlue.withValues(alpha: .18), size: 280),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _GlowBlob(
              color: _kBlue.withValues(alpha: .10),
              size: 240,
            ),
          ),
          // Grid dots
          const Positioned.fill(child: _DotGrid()),
          // Content
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 28 : 64,
              vertical: isMobile ? 56 : 80,
            ),
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kBlue.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: _kBlue.withValues(alpha: .35)),
                  ),
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rocket_launch_rounded,
                          size: 14,
                          color: _kBlue,
                        ),
                        SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'Start investing smarter today',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _kBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  isMobile
                      ? 'Your AI Stock\nAnalyst is Ready'
                      : 'Your Personal AI Stock\nAnalyst is Ready',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 38 : 56,
                    fontWeight: FontWeight.w900,
                    height: 1.06,
                    letterSpacing: isMobile ? -1.2 : -1.8,
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Text(
                    'Join thousands of Indian investors using StocBuy AI to search, analyze, and invest with confidence — powered by real-time data and intelligent AI.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .60),
                      fontSize: isMobile ? 14 : 16,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _PrimaryCtaBtn(onPressed: onGetStarted),
                    _SecondaryCtaBtn(onPressed: onViewPricing),
                  ],
                ),
                const SizedBox(height: 40),
                // Trust row
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 10,
                  children: [
                    _TrustItem(
                      icon: Icons.verified_rounded,
                      label: 'NSE & BSE Data',
                    ),
                    _TrustItem(
                      icon: Icons.security_rounded,
                      label: 'SEBI Guidance',
                    ),
                    _TrustItem(
                      icon: Icons.translate_rounded,
                      label: 'Multi-language',
                    ),
                    _TrustItem(
                      icon: Icons.star_rounded,
                      label: 'Free to Start',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DotGridPainter());
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .04);
    const spacing = 28.0;
    final cols = (size.width / spacing).ceil();
    final rows = (size.height / spacing).ceil();
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        canvas.drawCircle(
          Offset(c * spacing, r * spacing),
          1.5,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrimaryCtaBtn extends StatefulWidget {
  const _PrimaryCtaBtn({this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_PrimaryCtaBtn> createState() => _PrimaryCtaBtnState();
}

class _PrimaryCtaBtnState extends State<_PrimaryCtaBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.04 : 1,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: _kBlue,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: _kBlue.withValues(alpha: _hovered ? .45 : .25),
                blurRadius: _hovered ? 32 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Get Started Free',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryCtaBtn extends StatefulWidget {
  const _SecondaryCtaBtn({this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_SecondaryCtaBtn> createState() => _SecondaryCtaBtnState();
}

class _SecondaryCtaBtnState extends State<_SecondaryCtaBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _hovered
                ? Colors.white.withValues(alpha: .55)
                : Colors.white.withValues(alpha: .22),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Text(
                'View Pricing',
                style: TextStyle(
                  color: _hovered
                      ? Colors.white
                      : Colors.white.withValues(alpha: .75),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _kBlue),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .55),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

