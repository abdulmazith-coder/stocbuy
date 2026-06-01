import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBlue = Color(0xFF3B82F6);
const _kBlueLight = Color(0xFFEFF6FF);
const _kBlueBorder = Color(0xFFBFDBFE);
const _kBlack = Color(0xFF0A0A0A);
const _kGray = Color(0xFF555555);
const _kBg = Color(0xFFFFFFFF);
const _kCardBg = Color(0xFFF9F9F9);

// ─── Feature Categories ───────────────────────────────────────────────────────

class _FeatureGroup {
  const _FeatureGroup({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.isHighlight,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> features;
  final bool isHighlight;
}

const _groups = [
  _FeatureGroup(
    icon: Icons.psychology_rounded,
    title: 'AI-Powered Analysis',
    subtitle: 'Deep stock intelligence, explained in plain language.',
    features: [
  'AI analysis on every NSE & BSE listed stock',
'Fundamental analysis explained simply — no jargon',
'Technical analysis — RSI, MACD, EMA, SMA & chart patterns',
'AI target price prediction with confidence score',
'Clear buy, hold, or avoid recommendation with reason',
'Short-term & long-term investment outlook',
    ],
    isHighlight: true,
  ),
  _FeatureGroup(
    icon: Icons.newspaper_rounded,
    title: 'Market Intelligence',
    subtitle: "Know what's moving the market before you miss it.",
    features: [
      'Real-time NSE & BSE stock tracking',
'AI-powered news impact & sentiment analysis',
'Instant AI alerts for major market movements',
'Quarterly results impact — explained simply',
'Government policy & sector impact tracking',
'Company news summarized in your language',
'Bullish & bearish trend detection with reasoning',
'Market momentum & trend strength analysis',
    ],
    isHighlight: false,
  ),
  _FeatureGroup(
    icon: Icons.diamond_rounded,
    title: 'Stock Discovery',
    subtitle: 'Find the right stock before everyone else does.',
    features: [
'AI-picked penny stocks with real growth potential',
'Mid-cap & large-cap opportunity finder',
'Hidden high-growth stock discovery across NSE & BSE',
'Personalised picks based on your risk level & goals',
'Risk score, safety rating & investment suitability check',
'Company financial report analysis in simple language',
    ],
    isHighlight: false,
  ),
  _FeatureGroup(
    icon: Icons.dashboard_rounded,
    title: 'Dashboard & Portfolio',
    subtitle: 'Your entire investment life, in one clean view.',
    features: [
'Live NSE & BSE dashboard with real-time price updates',
'Portfolio tracking & watchlist management',
'Smart stock search with intelligent filters',
'Clean, beginner-friendly dashboard — no clutter',
'Personalised risk management & investment tracker',
    ],
    isHighlight: false,
  ),
  _FeatureGroup(
    icon: Icons.forum_rounded,
    title: 'AI Financial Assistant',
    subtitle: 'Ask anything. Get answers in your language, instantly.',
    features: [
'AI assistant in English, Hindi, Tamil, Telugu & more Indian languages',
'Voice & chat-based stock queries — anytime, anywhere',
'Complex market data explained in simple, plain language',
'SEBI-registered advisor guidance built into every answer',
'Personalised investment insights based on your portfolio',
    ],
    isHighlight: true,
  ),
];

// ─── Section Root ──────────────────────────────────────────────────────────────

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hp = w < 640 ? 20.0 : (w < 1024 ? 40.0 : 64.0);
        final isDesktop = w >= 1024;
        final isTablet = w >= 640 && w < 1024;

        return Container(
          width: double.infinity,
          color: _kBg,
          padding: EdgeInsets.fromLTRB(hp, 96, hp, 96),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  const _SectionHeader(),
                  const SizedBox(height: 64),
                  _FeatureGrid(
                    groups: _groups,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                  ),
                  const SizedBox(height: 56),
                  const _AllFeaturesStrip(),
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
    final headSize = w < 640 ? 34.0 : 48.0;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _kBlueLight,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kBlueBorder),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 15, color: _kBlue),
                SizedBox(width: 7),
                Text(
                  'Platform Features',
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
              color: _kBlack,
              fontSize: headSize,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
            children: const [
              TextSpan(text: 'Everything you need\nto invest '),
              TextSpan(
                text: 'smarter',
                style: TextStyle(
                  color: _kBlue,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: const Text(
           '30+ AI-powered features built exclusively for Indian investors — NSE, BSE, and beyond.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kGray,
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Feature Grid ─────────────────────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.groups,
    required this.isDesktop,
    required this.isTablet,
  });

  final List<_FeatureGroup> groups;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Column(
        children: [
          // Top row: 3 cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupCard(group: groups[0], flex: 5),
              const SizedBox(width: 20),
              _GroupCard(group: groups[1], flex: 5),
              const SizedBox(width: 20),
              _GroupCard(group: groups[2], flex: 4),
            ],
          ),
          const SizedBox(height: 20),
          // Bottom row: 2 cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupCard(group: groups[3], flex: 1),
              const SizedBox(width: 20),
              _GroupCard(group: groups[4], flex: 1),
            ],
          ),
        ],
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupCard(group: groups[0], flex: 1),
              const SizedBox(width: 16),
              _GroupCard(group: groups[1], flex: 1),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupCard(group: groups[2], flex: 1),
              const SizedBox(width: 16),
              _GroupCard(group: groups[3], flex: 1),
            ],
          ),
          const SizedBox(height: 16),
          _GroupCard(group: groups[4]),
        ],
      );
    }

    return Column(
      children: [
        for (final g in groups) ...[
          _GroupCard(group: g),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ─── Group Card ───────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  const _GroupCard({required this.group, this.flex});

  final _FeatureGroup group;
  final int? flex;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final card = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: g.isHighlight ? _kBlack : _kCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: g.isHighlight
                ? Colors.transparent
                : (_hovered
                    ? const Color(0xFF999999)
                    : const Color(0xFFE5E5E5)),
          ),
          boxShadow: [
            BoxShadow(
              color: g.isHighlight
                  ? _kBlack.withValues(alpha: _hovered ? .22 : .12)
                  : Colors.black.withValues(alpha: _hovered ? .10 : .04),
              blurRadius: _hovered ? 28 : 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(group: g),
              const SizedBox(height: 22),
              ...g.features.map(
                (f) => _FeatureRow(
                  label: f,
                  isDark: g.isHighlight,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.flex != null) {
      return Expanded(flex: widget.flex!, child: card);
    }
    return card;
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.group});
  final _FeatureGroup group;

  @override
  Widget build(BuildContext context) {
    final isDark = group.isHighlight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: .12)
                : _kBlueLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              group.icon,
              color: isDark ? Colors.white : _kBlue,
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          group.title,
          style: TextStyle(
            color: isDark ? Colors.white : _kBlack,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          group.subtitle,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: .55)
                : _kGray,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? _kBlue.withValues(alpha: .20)
                    : _kBlueLight,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 18,
                height: 18,
                child: Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 11,
                    color: isDark ? _kBlue : _kBlue,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: .85)
                    : const Color(0xFF333333),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── All Features Strip ───────────────────────────────────────────────────────

const _allFeatures = [
'AI-powered stock analysis',
'NSE & BSE live tracking',
'AI target price prediction',
'News impact analysis',
'Market sentiment detection',
'Portfolio tracking',
'Risk scoring & safety rating',
'Penny stock AI picks',
'Mid-cap opportunity finder',
'Large-cap recommendations',
'Watchlist management',
'Quarterly results analysis',
'Government policy impact',
'Trend & momentum detection',
'Bullish & bearish signals',
'Buy / Hold / Avoid signal',
'Voice & chat assistance',
'10+ Indian languages',
'Beginner-friendly explanations',
'SEBI-backed guidance',
'Smart AI alerts',
'Fast intelligent search',
'Company financials & reports',
'AI-powered dashboard',
'Short-term & long-term outlook',
'Hidden growth stock finder',
'Personalised risk management',
'Investment goal matching',
'Stock comparison tool',
'Financial health score',
'ect...'
];

class _AllFeaturesStrip extends StatelessWidget {
  const _AllFeaturesStrip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 16, color: _kBlue),
                const SizedBox(width: 8),
                const Text(
                  '30+ Platform Features',
                  style: TextStyle(
                    color: _kBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in _allFeatures) _FeatureChip(label: f),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatefulWidget {
  const _FeatureChip({required this.label});
  final String label;

  @override
  State<_FeatureChip> createState() => _FeatureChipState();
}

class _FeatureChipState extends State<_FeatureChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hovered ? _kBlueLight : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _hovered ? _kBlueBorder : const Color(0xFFDDDDDD),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? _kBlue : const Color(0xFF333333),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
