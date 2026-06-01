import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/navigation/app_routes.dart';
import 'package:stocbuy_application/application/navigation/shell_menu_navigation.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/external_url.dart';
import 'package:stocbuy_application/application/widgets/navbar.dart';

/// Pricing — Free plan and Contact us.
class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  static const String route = '/plan';
  static const _contactEmail = 'support@stocbuy.com';

  @override
  Widget build(BuildContext context) {
    final pad = Responsive.value(
      context,
      mobile: 20.0,
      tablet: 32.0,
      desktop: 48.0,
    );
    final isMobile = Responsive.isMobile(context);
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppNavBar(
        currentIndex: AppMenuIndex.pricing,
        onMenuTap: navigateAppMenu,
        onSearchTap: () => navigateAppMenu(AppMenuIndex.dashboard),
        onLogoTap: () => navigateAppMenu(AppMenuIndex.dashboard),
      ),
      body: Stack(
        children: [
          const _PricingBackground(),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, isMobile ? 28 : 48, pad, 56),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  children: [
                    const _PricingHero(),
                    SizedBox(height: isMobile ? 32 : 48),
                    if (isMobile) ...[
                      const _FreePlanCard(),
                      const SizedBox(height: 24),
                      _ContactPlanCard(
                        onContact: () => _openContact(context),
                      ),
                    ] else
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(child: _FreePlanCard()),
                            SizedBox(width: isDesktop ? 28 : 20),
                            Expanded(
                              child: _ContactPlanCard(
                                onContact: () => _openContact(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                    const _PricingTrustRow(),
                    const SizedBox(height: 16),
                    Text(
                      'Stocbuy AI is for educational purposes only. '
                      'Consult a SEBI-registered advisor before investing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openContact(BuildContext context) {
    return openExternalUrl(
      'mailto:$_contactEmail?subject=Stocbuy%20pricing%20inquiry',
      context: context,
      failureMessage:
          'Could not open your email app. Email us at $_contactEmail',
    );
  }
}

// ── Background ─────────────────────────────────────────────────────────────

class _PricingBackground extends StatelessWidget {
  const _PricingBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.lightblue.withValues(alpha: 0.06),
                AppColors.white,
                AppColors.white,
              ],
              stops: const [0, 0.35, 1],
            ),
          ),
          child: CustomPaint(
            painter: _GridPainter(
              color: AppColors.lightblue.withValues(alpha: 0.04),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.45), paint);
    }
    for (var y = 0.0; y < size.height * 0.45; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Hero ───────────────────────────────────────────────────────────────────

class _PricingHero extends StatelessWidget {
  const _PricingHero();

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final titleSize = isMobile ? 32.0 : 40.0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.lightblue.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.lightblue.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.lightblue.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Text(
                'Simple, transparent pricing',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightblue.withValues(alpha: 0.95),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 20 : 28),
        Text(
          'Start free.\nScale when you\'re ready.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            height: 1.12,
            fontWeight: FontWeight.w800,
            color: AppColors.darkblue,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'Everything you need to research Indian markets — no credit card required.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 15 : 16,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: AppColors.grey.withValues(alpha: 0.95),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Free plan card ─────────────────────────────────────────────────────────

class _FreePlanCard extends StatelessWidget {
  const _FreePlanCard();

  static const _features = [
    'Unlimited stock search (NSE & BSE)',
    'Live dashboard & top gainers',
    'AI stock analysis on any ticker',
    'Charts, financials & news',
    'Stocbuy GPT assistant',
  ];

  @override
  Widget build(BuildContext context) {
    return _PlanCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _PlanIconBadge(
                icon: Icons.rocket_launch_rounded,
                gradient: [
                  Color(0xFF3861FB),
                  Color(0xFF5B8DEF),
                ],
              ),
              const Spacer(),
              _StatusPill(
                label: 'Your plan',
                background: AppColors.lightblue.withValues(alpha: 0.1),
                foreground: AppColors.lightblue,
                border: AppColors.lightblue.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Free',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹0',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkblue,
                  height: 1,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/ forever',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Full access to research tools while you learn the markets.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: AppColors.grey.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 24),
          const _FeatureDivider(label: 'Included'),
          const SizedBox(height: 16),
          for (final f in _features) ...[
            _FeatureLine(text: f),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 28),
          _PlanCta(
            label: 'Continue with Free',
            icon: Icons.arrow_forward_rounded,
            filled: false,
            onPressed: () => Get.offAllNamed(AppRoutes.dashboard),
          ),
        ],
      ),
    );
  }
}

// ── Contact plan card ────────────────────────────────────────────────────────

class _ContactPlanCard extends StatefulWidget {
  const _ContactPlanCard({required this.onContact});

  final VoidCallback onContact;

  static const _features = [
    'Higher AI analysis limits',
    'Team & advisor workspaces',
    'Priority email support',
    'Custom integrations & API',
    'Dedicated onboarding',
  ];

  @override
  State<_ContactPlanCard> createState() => _ContactPlanCardState();
}

class _ContactPlanCardState extends State<_ContactPlanCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(
                alpha: _hovered ? 0.22 : 0.14,
              ),
              blurRadius: _hovered ? 36 : 28,
              offset: Offset(0, _hovered ? 16 : 12),
            ),
            BoxShadow(
              color: AppColors.lightblue.withValues(
                alpha: _hovered ? 0.18 : 0.1,
              ),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _PlanIconBadge(
                      icon: Icons.headset_mic_rounded,
                      gradient: [
                        Color(0xFF6366F1),
                        Color(0xFF8B5CF6),
                      ],
                      iconColor: Colors.white,
                    ),
                    const Spacer(),
                    _StatusPill(
                      label: 'Enterprise',
                      background: Colors.white.withValues(alpha: 0.12),
                      foreground: Colors.white.withValues(alpha: 0.95),
                      border: Colors.white.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Custom',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Contact us',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Tell us what you need — we\'ll tailor a plan for you or your team.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 24),
                _FeatureDivider(
                  label: 'Available on request',
                  lineColor: Colors.white.withValues(alpha: 0.15),
                  labelColor: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                for (final f in _ContactPlanCard._features) ...[
                  _FeatureLine(
                    text: f,
                    textColor: Colors.white.withValues(alpha: 0.92),
                    checkColor: const Color(0xFF34D399),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 28),
                _PlanCta(
                  label: 'Get in touch',
                  icon: Icons.mail_outline_rounded,
                  filled: true,
                  onPressed: widget.onContact,
                  lightOnDark: true,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    PlanPage._contactEmail,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.45),
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

// ── Shared pieces ──────────────────────────────────────────────────────────

class _PlanCardShell extends StatelessWidget {
  const _PlanCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PlanIconBadge extends StatelessWidget {
  const _PlanIconBadge({
    required this.icon,
    required this.gradient,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final List<Color> gradient;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: 24),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: foreground,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FeatureDivider extends StatelessWidget {
  const _FeatureDivider({
    required this.label,
    this.lineColor,
    this.labelColor,
  });

  final String label;
  final Color? lineColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final line = lineColor ?? AppColors.border.withValues(alpha: 0.85);
    final labelC = labelColor ?? AppColors.grey.withValues(alpha: 0.85);

    return Row(
      children: [
        Expanded(child: Divider(color: line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: labelC,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(child: Divider(color: line, height: 1)),
      ],
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.text,
    this.textColor,
    this.checkColor,
  });

  final String text;
  final Color? textColor;
  final Color? checkColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_rounded,
          size: 20,
          color: checkColor ?? AppColors.green,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: textColor ?? AppColors.darkblue.withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCta extends StatelessWidget {
  const _PlanCta({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.filled,
    this.lightOnDark = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final bool lightOnDark;

  @override
  Widget build(BuildContext context) {
    if (lightOnDark) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: Color(0xFF0F172A),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightblue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: AppColors.lightblue),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.lightblue,
        side: BorderSide(
          color: AppColors.lightblue.withValues(alpha: 0.45),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _PricingTrustRow extends StatelessWidget {
  const _PricingTrustRow();

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final items = [
      (Icons.verified_user_outlined, 'No credit card'),
      (Icons.bolt_outlined, 'Instant access'),
      (Icons.flag_outlined, 'Built for India'),
    ];

    if (isMobile) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: items.map(_TrustChip.new).toList(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 32),
          _TrustChip(items[i]),
        ],
      ],
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip(this.item);

  final (IconData, String) item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          item.$1,
          size: 18,
          color: AppColors.grey.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 8),
        Text(
          item.$2,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.grey.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
