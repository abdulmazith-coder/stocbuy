import 'package:flutter/material.dart';

import 'landing_navigation.dart';
import 'widgets/faq_section.dart';
import 'widgets/features_section.dart';
import 'widgets/final_cta_section.dart';
import 'widgets/how_it_works_section.dart';
import 'widgets/landing_footer.dart';
import 'widgets/landing_hero.dart';
import 'widgets/landing_navbar.dart';
import 'widgets/pricing_section.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  static const String route = '/';

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  int? _selectedMenuIndex;
  bool _showScrollTop = false;

  final _scrollController = ScrollController();

  // One key per menu item: 0=HowItWorks, 1=Features, 2=Pricing, 3=FAQ
  final _sectionKeys = List.generate(4, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // ── Scroll listener ─────────────────────────────────────────────────────────
  void _onScroll() {
    final offset = _scrollController.offset;

    // Show scroll-to-top button after 400px
    final shouldShow = offset > 400;
    if (shouldShow != _showScrollTop) {
      setState(() => _showScrollTop = shouldShow);
    }

    // Detect active section by screen Y of each anchor key
    // The anchor SizedBox(height:0) is placed right before each section.
    // Its globalY ≤ navbarThreshold means the section is at/above the navbar.
    const navbarThreshold = 120.0;
    int? activeIdx;
    for (var i = _sectionKeys.length - 1; i >= 0; i--) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final globalY = box.localToGlobal(Offset.zero).dy;
      if (globalY <= navbarThreshold) {
        activeIdx = i;
        break;
      }
    }

    if (activeIdx != _selectedMenuIndex) {
      setState(() => _selectedMenuIndex = activeIdx);
    }
  }

  // ── Menu tap ─────────────────────────────────────────────────────────────────
  void _handleMenuSelected(int index) {
    setState(() => _selectedMenuIndex = index);
    _scrollToSection(index);
  }

  void _scrollToSection(int index) {
    final key = _sectionKeys[index];
    if (key.currentContext == null) return;
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeInOutCubic,
      alignment: 0.0,
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      endDrawer: LandingDrawer(
        selectedIndex: _selectedMenuIndex,
        onMenuSelected: _handleMenuSelected,
      ),
      body: Stack(
        children: [
          // ── Scrollable page content ──────────────────────────────────────
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // Hero (full-viewport)
                LandingHero(
                  onGetStarted: openApplicationDashboard,
                  onTryAi: openApplicationAi,
                  onExploreFeatures: () => _scrollToSection(1),
                ),

                // 0 — How it works
                SizedBox(key: _sectionKeys[0], height: 0),
                const HowItWorksSection(),

                // 1 — Features
                SizedBox(key: _sectionKeys[1], height: 0),
                const FeaturesSection(),

                // 2 — Pricing
                SizedBox(key: _sectionKeys[2], height: 0),
                const PricingSection(),

                // 3 — FAQ
                SizedBox(key: _sectionKeys[3], height: 0),
                const FaqSection(),

                FinalCtaSection(
                  onGetStarted: openApplicationDashboard,
                  onViewPricing: () => _scrollToSection(2),
                ),
                LandingFooter(onSectionTap: _handleMenuSelected),
              ],
            ),
          ),

          // ── Fixed navbar ─────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: LandingNavbar(
                selectedIndex: _selectedMenuIndex,
                onMenuSelected: _handleMenuSelected,
              ),
            ),
          ),

          // ── Scroll-to-top FAB ─────────────────────────────────────────────
          Positioned(
            right: 24,
            bottom: 32,
            child: AnimatedOpacity(
              opacity: _showScrollTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 260),
              child: AnimatedScale(
                scale: _showScrollTop ? 1.0 : 0.6,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: IgnorePointer(
                  ignoring: !_showScrollTop,
                  child: _ScrollTopButton(onTap: _scrollToTop),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scroll-to-top Button ─────────────────────────────────────────────────────

class _ScrollTopButton extends StatefulWidget {
  const _ScrollTopButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ScrollTopButton> createState() => _ScrollTopButtonState();
}

class _ScrollTopButtonState extends State<_ScrollTopButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF3B82F6) : const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? .28 : .18),
                blurRadius: _hovered ? 20 : 12,
                offset: const Offset(0, 6),
              ),
              if (_hovered)
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: .30),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
