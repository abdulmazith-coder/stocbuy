import 'package:flutter/material.dart';

import '../landing_navigation.dart';

const _kBlue = Color(0xFF3B82F6);

class _PricingTier {
  const _PricingTier({
    required this.name,
    required this.price,
    required this.period,
    required this.description,
    required this.features,
    required this.cta,
    required this.isHighlight,
    this.badge,
  });

  final String name;
  final String price;
  final String period;
  final String description;
  final List<String> features;
  final String cta;
  final bool isHighlight;
  final String? badge;
}

const _tiers = [
  _PricingTier(
    name: 'Starter',
    price: 'Free',
    period: 'forever',
    description: 'Get started with basic stock analysis and AI insights.',
    features: [
      'Search any NSE & BSE stock',
      'Basic AI stock summary',
      'Live price tracking (5 stocks)',
      'News feed',
      'Beginner-friendly explanations',
    ],
    cta: 'Start for Free',
    isHighlight: false,
  ),
  _PricingTier(
    name: 'Pro',
    price: '₹499',
    period: '/month',
    description: 'Full AI-powered analysis for serious Indian investors.',
    badge: 'Most Popular',
    features: [
      'Everything in Starter',
      'Full AI fundamental & technical analysis',
      'Target price prediction',
      'News & sentiment impact analysis',
      'AI-picked penny & growth stocks',
      'Unlimited watchlist & portfolio tracking',
      'Quarterly result analysis',
      'Government policy impact tracking',
      'Buy / Hold / Avoid recommendations',
      'AI alerts for market movements',
      'Multi-language AI assistant',
    ],
    cta: 'Start Pro Trial',
    isHighlight: true,
  ),
  _PricingTier(
    name: 'Expert',
    price: '₹999',
    period: '/month',
    description: 'Advanced tools with advisor guidance for power investors.',
    features: [
      'Everything in Pro',
      'SEBI-registered advisor integration',
      'Voice/chat-based AI assistant',
      'Risk management system',
      'Advanced momentum & trend detection',
      'Priority AI analysis queue',
      'Personalized investment strategy',
      'Company financial deep reports',
      'Sector & industry tracking',
      'API access (coming soon)',
    ],
    cta: 'Get Expert Access',
    isHighlight: false,
  ),
];

// ─── Section ──────────────────────────────────────────────────────────────────

class PricingSection extends StatelessWidget {
  const PricingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hp = w < 640 ? 20.0 : (w < 1024 ? 40.0 : 64.0);
        final isDesktop = w >= 900;

        return Container(
          width: double.infinity,
          color: const Color(0xFF0A0A0A),
          padding: EdgeInsets.fromLTRB(hp, 96, hp, 96),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  const _SectionHeader(),
                  const SizedBox(height: 64),
                  isDesktop
                      ? _DesktopPricingRow(tiers: _tiers)
                      : _MobilePricingList(tiers: _tiers),
                  const SizedBox(height: 48),
                  const _PricingNote(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final headSize = w < 640 ? 34.0 : 46.0;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _kBlue.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kBlue.withValues(alpha: .35)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.payments_rounded, size: 15, color: _kBlue),
                SizedBox(width: 7),
                Text(
                  'Simple Pricing',
                  style: TextStyle(
                    color: _kBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: headSize,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
            children: const [
              TextSpan(text: 'Invest smarter,\n'),
              TextSpan(
                text: 'start free',
                style: TextStyle(color: _kBlue, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No hidden fees. Cancel anytime.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF888888),
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Desktop Row ──────────────────────────────────────────────────────────────

class _DesktopPricingRow extends StatelessWidget {
  const _DesktopPricingRow({required this.tiers});
  final List<_PricingTier> tiers;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _PricingCard(tier: tiers[0])),
        const SizedBox(width: 20),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -16),
            child: _PricingCard(tier: tiers[1]),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: _PricingCard(tier: tiers[2])),
      ],
    );
  }
}

class _MobilePricingList extends StatelessWidget {
  const _MobilePricingList({required this.tiers});
  final List<_PricingTier> tiers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < tiers.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _PricingCard(tier: tiers[i]),
        ],
      ],
    );
  }
}

// ─── Pricing Card ─────────────────────────────────────────────────────────────

class _PricingCard extends StatefulWidget {
  const _PricingCard({required this.tier});
  final _PricingTier tier;

  @override
  State<_PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends State<_PricingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tier;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: t.isHighlight ? _kBlue : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: t.isHighlight
                ? Colors.transparent
                : (_hovered
                    ? const Color(0xFF444444)
                    : const Color(0xFF222222)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: t.isHighlight
                  ? _kBlue.withValues(alpha: _hovered ? .40 : .25)
                  : Colors.black.withValues(alpha: _hovered ? .30 : .15),
              blurRadius: _hovered ? 40 : 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (t.badge != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(
                      t.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                t.name,
                style: TextStyle(
                  color: t.isHighlight
                      ? Colors.white.withValues(alpha: .70)
                      : const Color(0xFF888888),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    t.price,
                    style: TextStyle(
                      color: t.isHighlight ? Colors.white : Colors.white,
                      fontSize: t.price == 'Free' ? 40 : 36,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                  if (t.period.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        t.period,
                        style: TextStyle(
                          color: t.isHighlight
                              ? Colors.white.withValues(alpha: .55)
                              : const Color(0xFF666666),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                t.description,
                style: TextStyle(
                  color: t.isHighlight
                      ? Colors.white.withValues(alpha: .70)
                      : const Color(0xFF777777),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _CtaButton(tier: t),
              const SizedBox(height: 28),
              // Divider
              Divider(
                color: t.isHighlight
                    ? Colors.white.withValues(alpha: .20)
                    : const Color(0xFF2A2A2A),
                height: 1,
              ),
              const SizedBox(height: 24),
              for (final feature in t.features)
                _PricingFeatureRow(
                  label: feature,
                  isHighlight: t.isHighlight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.tier});
  final _PricingTier tier;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tier.isHighlight ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: tier.isHighlight
              ? null
              : Border.all(color: const Color(0xFF333333)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: openApplicationDashboard,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                tier.cta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tier.isHighlight ? _kBlue : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PricingFeatureRow extends StatelessWidget {
  const _PricingFeatureRow({required this.label, required this.isHighlight});
  final String label;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: isHighlight ? Colors.white : _kBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isHighlight
                    ? Colors.white.withValues(alpha: .85)
                    : const Color(0xFFAAAAAA),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Note ─────────────────────────────────────────────────────────────────────

class _PricingNote extends StatelessWidget {
  const _PricingNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'All plans include a 7-day free trial. No credit card required for Starter.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: .35),
        fontSize: 13,
        height: 1.5,
      ),
    );
  }
}
