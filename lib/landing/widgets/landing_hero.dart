import 'package:flutter/material.dart';

import 'landing_product_showcase.dart';
import 'stock_landing_background.dart';

class LandingHero extends StatelessWidget {
  const LandingHero({
    super.key,
    this.onGetStarted,
    this.onTryAi,
    this.onExploreFeatures,
  });

  final VoidCallback? onGetStarted;
  final VoidCallback? onTryAi;

  /// Scrolls to the Features section on the landing page.
  final VoidCallback? onExploreFeatures;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = screenSize.width;
    final isMobile = width < 640;
    final horizontalPadding = isMobile ? 20.0 : 40.0;
    final topPadding = isMobile ? 104.0 : 116.0;
    final headlineSize = (width * (isMobile ? .105 : .058))
        .clamp(32.0, 72.0)
        .toDouble();
    final subheadingSize = (width * (isMobile ? .040 : .016))
        .clamp(14.0, 19.0)
        .toDouble();
    final minHeroHeight = (screenSize.height - topPadding - 52)
        .clamp(0.0, double.infinity);

    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            const Positioned.fill(child: StockLandingBackground()),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                52,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeroHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: _HeroContent(
                            headlineSize: headlineSize,
                            subheadingSize: subheadingSize,
                            isMobile: isMobile,
                            onGetStarted: onGetStarted,
                            onExploreFeatures: onExploreFeatures,
                          ),
                        ),
                        SizedBox(height: isMobile ? 30 : 42),
                        const LandingProductShowcase(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({
    required this.headlineSize,
    required this.subheadingSize,
    required this.isMobile,
    this.onGetStarted,
    this.onExploreFeatures,
  });

  final double headlineSize;
  final double subheadingSize;
  final bool isMobile;
  final VoidCallback? onGetStarted;
  final VoidCallback? onExploreFeatures;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: isMobile ? 18 : 22),
        Text(
          'AI Stock Analysis for Indian Investors — NSE & BSE Insights in Your Language',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontSize: headlineSize,
            height: 1.02,
            fontWeight: FontWeight.w800,
            letterSpacing: isMobile ? -1.3 : -2.4,
          ),
        ),
        SizedBox(height: isMobile ? 18 : 22),
        Text(
          'Search any Indian stock and instantly get AI-powered risk analysis, target price, news impact, and smart recommendations — from penny stocks to large caps, in English, Hindi, Tamil, Telugu & more.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF475569),
            fontSize: subheadingSize,
            height: 1.55,
            fontWeight: FontWeight.w500,
            letterSpacing: -.1,
          ),
        ),
        SizedBox(height: isMobile ? 26 : 32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _PrimaryHeroButton(onPressed: onGetStarted),
            _SecondaryHeroButton(onPressed: onExploreFeatures),
          ],
        ),
      ],
    );
  }
}

class _PrimaryHeroButton extends StatefulWidget {
  const _PrimaryHeroButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_PrimaryHeroButton> createState() => _PrimaryHeroButtonState();
}

class _PrimaryHeroButtonState extends State<_PrimaryHeroButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.04 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111827), Color(0xFF020617)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF0F172A,
                ).withValues(alpha: _isHovered ? .32 : .18),
                blurRadius: _isHovered ? 28 : 16,
                offset: Offset(0, _isHovered ? 12 : 7),
              ),
              if (_isHovered)
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: .22),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFE0F2FE),
                        size: 17,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'Get Started',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryHeroButton extends StatelessWidget {
  const _SecondaryHeroButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: const Text(
        'Explore Features',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
