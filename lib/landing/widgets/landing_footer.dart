import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';

import '../work_in_progress_page.dart';

const _kBlue = Color(0xFF3B82F6);

class LandingFooter extends StatelessWidget {
  const LandingFooter({this.onSectionTap, super.key});

  /// Called with section index (0–3) when a Product link is tapped.
  final ValueChanged<int>? onSectionTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hp = w < 640 ? 24.0 : (w < 1024 ? 48.0 : 72.0);
        final isDesktop = w >= 900;

        return Container(
          width: double.infinity,
          color: const Color(0xFF0A0A0A),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(hp, 64, hp, 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: isDesktop
                        ? _DesktopFooterContent(onSectionTap: onSectionTap)
                        : _MobileFooterContent(onSectionTap: onSectionTap),
                  ),
                ),
              ),
              const _FooterDivider(),
              Padding(
                padding: EdgeInsets.fromLTRB(hp, 20, hp, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: const _FooterBottom(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Desktop Layout ───────────────────────────────────────────────────────────

class _DesktopFooterContent extends StatelessWidget {
  const _DesktopFooterContent({this.onSectionTap});
  final ValueChanged<int>? onSectionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 280, child: _BrandColumn()),
        const SizedBox(width: 64),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LinkGroup(
                  title: 'Product',
                  links: _productLinks,
                  isWip: false,
                  onSectionTap: onSectionTap,
                ),
              ),
              Expanded(
                child: _LinkGroup(
                  title: 'Company',
                  links: _companyLinks,
                  isWip: true,
                ),
              ),
              Expanded(
                child: _LinkGroup(
                  title: 'Legal',
                  links: _legalLinks,
                  isWip: true,
                ),
              ),
              const Expanded(child: _SocialColumn()),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileFooterContent extends StatelessWidget {
  const _MobileFooterContent({this.onSectionTap});
  final ValueChanged<int>? onSectionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BrandColumn(),
        const SizedBox(height: 48),
        _LinkGroup(
          title: 'Product',
          links: _productLinks,
          isWip: false,
          onSectionTap: onSectionTap,
        ),
        const SizedBox(height: 36),
        const _LinkGroup(
          title: 'Company',
          links: _companyLinks,
          isWip: true,
        ),
        const SizedBox(height: 36),
        const _LinkGroup(title: 'Legal', links: _legalLinks, isWip: true),
        const SizedBox(height: 36),
        const _SocialColumn(),
      ],
    );
  }
}

// ─── Link data ────────────────────────────────────────────────────────────────

const _productLinks = [
  'How it Works',
  'Features',
  'Pricing',
  'FAQ',
];

const _companyLinks = [
  'About Us',
  'Contact',
  'Blog',
  'Careers',
  'Press Kit',
];

const _legalLinks = [
  'Privacy Policy',
  'Terms of Service',
  'Cookie Policy',
  'Disclaimer',
];

// ─── Brand Column ─────────────────────────────────────────────────────────────

class _BrandColumn extends StatelessWidget {
  const _BrandColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StocbuyBrandMark(
          labelColor: Colors.white,
        ),
        const SizedBox(height: 18),
        Text(
          'An AI-powered financial assistant built exclusively '
          'for Indian investors on NSE and BSE markets.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .45),
            fontSize: 13.5,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _FooterBadge(label: 'NSE & BSE'),
            _FooterBadge(label: 'AI Powered'),
            _FooterBadge(label: 'SEBI Guided'),
          ],
        ),
      ],
    );
  }
}

class _FooterBadge extends StatelessWidget {
  const _FooterBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .55),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Link Group ───────────────────────────────────────────────────────────────

class _LinkGroup extends StatelessWidget {
  const _LinkGroup({
    required this.title,
    required this.links,
    required this.isWip,
    this.onSectionTap,
  });

  final String title;
  final List<String> links;

  /// If true, tapping any link navigates to WorkInProgressPage.
  final bool isWip;

  /// For Product links: called with 0-based section index to scroll to it.
  final ValueChanged<int>? onSectionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < links.length; i++) ...[
          _FooterLink(
            label: links[i],
            onTap: isWip
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkInProgressPage(title: links[i]),
                      ),
                    )
                : (onSectionTap != null ? () => onSectionTap!(i) : null),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  const _FooterLink({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: TextStyle(
            color: _hovered ? Colors.white : Colors.white.withValues(alpha: .40),
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

// ─── Social Column (no email input) ──────────────────────────────────────────

class _SocialColumn extends StatelessWidget {
  const _SocialColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Follow Us',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SocialBtn(icon: Icons.send_rounded, label: 'Twitter / X'),
            _SocialBtn(icon: Icons.camera_alt_outlined, label: 'Instagram'),
            _SocialBtn(icon: Icons.play_circle_outline, label: 'YouTube'),
            _SocialBtn(
              icon: Icons.business_center_outlined,
              label: 'LinkedIn',
            ),
          ],
        ),
        SizedBox(height: 28),
        Text(
          'Built for India 🇮🇳',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: .3,
          ),
        ),
        SizedBox(height: 10),
        _BuiltForIndiaText(),
      ],
    );
  }
}

class _BuiltForIndiaText extends StatelessWidget {
  const _BuiltForIndiaText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'NSE & BSE powered AI analysis for every\nIndian investor — from beginner to expert.',
      style: TextStyle(
        color: Colors.white.withValues(alpha: .38),
        fontSize: 13,
        height: 1.6,
      ),
    );
  }
}

class _SocialBtn extends StatefulWidget {
  const _SocialBtn({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  State<_SocialBtn> createState() => _SocialBtnState();
}

class _SocialBtnState extends State<_SocialBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _hovered
                ? _kBlue.withValues(alpha: .15)
                : Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? _kBlue.withValues(alpha: .35)
                  : Colors.white.withValues(alpha: .10),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              widget.icon,
              size: 17,
              color: _hovered ? _kBlue : Colors.white.withValues(alpha: .55),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Divider ──────────────────────────────────────────────────────────────────

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withValues(alpha: .08),
      height: 1,
    );
  }
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class _FooterBottom extends StatelessWidget {
  const _FooterBottom();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 640;

    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CopyrightText(),
              const SizedBox(height: 8),
              _DisclaimerText(),
            ],
          )
        : Row(
            children: [
              _CopyrightText(),
              const Spacer(),
              _DisclaimerText(),
            ],
          );
  }
}

class _CopyrightText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      '© 2026 StocBuy. All rights reserved.',
      style: TextStyle(
        color: Colors.white.withValues(alpha: .30),
        fontSize: 12.5,
      ),
    );
  }
}

class _DisclaimerText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Not SEBI registered. For informational purposes only.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: .22),
        fontSize: 12,
      ),
    );
  }
}
