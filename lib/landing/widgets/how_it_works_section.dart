import 'dart:math' as math;

import 'package:flutter/material.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

const _kBlue = Color(0xFF3B82F6);
const _kBlueBorder = Color(0xFFBFDBFE);
const _kBlueLight = Color(0xFFEFF6FF);
const _kBg = Color(0xFFF7F7F7);
const _kCardBg = Colors.white;
const _kHeading = Color(0xFF0A0A0A);
const _kBody = Color(0xFF555555);
const _kChipBg = Color(0xFFF2F2F2);
const _kChipBorder = Color(0xFFE0E0E0);
const _kChipText = Color(0xFF222222);

class _FlowStep {
  const _FlowStep({
    required this.number,
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.description,
    required this.chips,
    required this.previewLabel,
    required this.previewValue,
    required this.previewPositive,
  });

  final String number;
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String description;
  final List<String> chips;
  final String previewLabel;
  final String previewValue;
  final bool previewPositive;
}

const _steps = [
  _FlowStep(
    number: '01',
    icon: Icons.search_rounded,
    gradientColors: [Color(0xFF111111), Color(0xFF333333)],
    title: 'Search Any\nIndian Stock',
    description:
        'Type any stock name or ticker — NSE or BSE, penny to large-cap.'
        'Get live price, financials, and recent news instantly.\n',
    chips:  ['NSE & BSE', 'Live Data', 'Financials', 'Price History', 'News Feed'],
    previewLabel: 'TATASTEEL',
    previewValue: '+3.42%',
    previewPositive: true,
  ),
  _FlowStep(
    number: '02',
    icon: Icons.psychology_alt_rounded,
    gradientColors: [Color(0xFF1A1A1A), Color(0xFF3D3D3D)],
    title: 'Deep AI\nStock Analysis',
    description:
        'Get full fundamental and technical analysis — financial strength,'
        'growth potential, risk level, and market trends, explained in simple language.',
    chips: ['Fundamental', 'Technical', 'Risk Level', 'Growth Score', 'Simple Language'],
    previewLabel: 'AI Score',
    previewValue: '8.4 / 10',
    previewPositive: true,
  ),
  _FlowStep(
    number: '03',
    icon: Icons.newspaper_rounded,
    gradientColors: [Color(0xFF222222), Color(0xFF444444)],
    title: 'News &\nSentiment Analysis',
    description:
        'AI scans latest company news, government policies, and market sentiment — '
        'and explains exactly how each one impacts your stock in simple terms.',
    chips: ['News Impact', 'Policy Effect', 'Market Sentiment', 'Short & Long Term'],
    previewLabel: 'Sentiment',
    previewValue: 'Bullish',
    previewPositive: true,
  ),
  _FlowStep(
    number: '04',
    icon: Icons.auto_graph_rounded,
    gradientColors: [Color(0xFF111111), Color(0xFF2E2E2E)],
    title: 'AI Predictions\n& Target Price',
    description:
        'AI calculates target price based on real data — identifies bullish and bearish signals '
        'and tells you if the stock is best for short-term or long-term investment.',
    chips: ['Target Price', 'Bull & Bear', 'Short Term', 'Long Term', 'Probability'],
    previewLabel: 'Target (1Y)',
    previewValue: '₹1,820',
    previewPositive: true,
  ),
  _FlowStep(
    number: '05',
    icon: Icons.diamond_outlined,
    gradientColors: [Color(0xFF1A1A1A), Color(0xFF3A3A3A)],
    title: 'Discover\nHidden Gems',
    description:
        'AI filters the entire Indian market — penny stocks, mid-caps, large-caps,'
        'and high-growth picks, matched to your risk level and investment goal.',
    chips: ['Penny Stocks', 'Mid-Cap', 'Large-Cap', 'Growth Picks', 'Risk Matched'],
    previewLabel: 'Opportunity',
    previewValue: 'HIGH',
    previewPositive: true,
  ),
  _FlowStep(
    number: '06',
    icon: Icons.forum_rounded,
    gradientColors: [Color(0xFF222222), Color(0xFF404040)],
    title: 'Your AI\nFinancial Assistant',
    description:
        'Ask anything in Hindi, Tamil, Telugu or any language — get SEBI-backed answers'
        ' to "Is this stock safe?", "Why is it falling?", "Should I invest now?" instantly.',
    chips: ['Any Language', 'SEBI Backed', 'Voice Query', 'Instant Answers'],
    previewLabel: 'Response',
    previewValue: 'Instant',
    previewPositive: true,
  ),
];

// ─── Section Root ─────────────────────────────────────────────────────────────

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hp = w < 640 ? 20.0 : (w < 1024 ? 36.0 : 56.0);
        final isDesktop = w >= 1024;
        final isTablet = w >= 640 && w < 1024;

        return Container(
          width: double.infinity,
          color: _kBg,
          child: Column(
            children: [
              _TopCurve(color: _kBg),
              Padding(
                padding: EdgeInsets.fromLTRB(hp, 20, hp, 96),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      children: [
                        const _SectionHeader(),
                        const SizedBox(height: 64),
                        if (isDesktop)
                          _DesktopGrid(steps: _steps)
                        else if (isTablet)
                          _TabletGrid(steps: _steps)
                        else
                          _MobileList(steps: _steps),
                        const SizedBox(height: 72),
                        const _TrustBanner(),
                      ],
                    ),
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

// ─── Top clip that merges with hero ──────────────────────────────────────────

class _TopCurve extends StatelessWidget {
  const _TopCurve({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: CustomPaint(painter: _TopCurvePainter(color: color)),
    );
  }
}

class _TopCurvePainter extends CustomPainter {
  const _TopCurvePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..cubicTo(
        size.width * .25,
        0,
        size.width * .75,
        0,
        size.width,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TopCurvePainter old) => old.color != color;
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final headSize = w < 640 ? 34.0 : 48.0;

    return Column(
      children: [
        // pill label
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
                Icon(Icons.auto_awesome_rounded, size: 15, color: _kBlue),
                SizedBox(width: 7),
                Text(
                  'How StocBuy Works',
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
              color: _kHeading,
              fontSize: headSize,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
            children: const [
              TextSpan(text: 'Your Smart\n'),
              TextSpan(
                text: 'AI Stock Analyst',
                style: TextStyle(
                  color: Color(0xFF333333),
                  fontStyle: FontStyle.italic,
                ),
              ),
              TextSpan(text: ' — \nfor Every Indian Investor'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: const Text(
            'Search any NSE or BSE stock — get instant AI risk analysis,'
            'news impact, target price, and smart buy/sell insights in your language.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kBody,
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

// ─── Layouts ─────────────────────────────────────────────────────────────────

class _DesktopGrid extends StatelessWidget {
  const _DesktopGrid({required this.steps});
  final List<_FlowStep> steps;

  @override
  Widget build(BuildContext context) {
    // 3-col alternating: row 1 is [big, small, small], row 2 is [small, small, big]
    // Actually: use uniform 3-col grid but with connector dots between columns
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row == 1) const SizedBox(height: 24),
          _DesktopRow(
            steps: [steps[row * 3], steps[row * 3 + 1], steps[row * 3 + 2]],
            rowIndex: row,
          ),
        ],
      ],
    );
  }
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({required this.steps, required this.rowIndex});
  final List<_FlowStep> steps;
  final int rowIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _StepCard(step: steps[0])),
        _StepConnector(fromStep: steps[0], toStep: steps[1]),
        Expanded(child: _StepCard(step: steps[1])),
        _StepConnector(fromStep: steps[1], toStep: steps[2]),
        Expanded(child: _StepCard(step: steps[2])),
      ],
    );
  }
}

class _TabletGrid extends StatelessWidget {
  const _TabletGrid({required this.steps});
  final List<_FlowStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StepCard(step: steps[row * 2])),
              _StepConnector(
                fromStep: steps[row * 2],
                toStep: steps[row * 2 + 1],
              ),
              Expanded(child: _StepCard(step: steps[row * 2 + 1])),
            ],
          ),
        ],
      ],
    );
  }
}

class _MobileList extends StatelessWidget {
  const _MobileList({required this.steps});
  final List<_FlowStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) _VerticalConnector(fromStep: steps[i - 1]),
          _StepCard(step: steps[i]),
        ],
      ],
    );
  }
}

// ─── Connector arrows ────────────────────────────────────────────────────────

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.fromStep, required this.toStep});
  final _FlowStep fromStep;
  final _FlowStep toStep;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(40, 28),
            painter: _ConnectorPainter(color: fromStep.gradientColors.last),
          ),
        ],
      ),
    );
  }
}

class _VerticalConnector extends StatelessWidget {
  const _VerticalConnector({required this.fromStep});
  final _FlowStep fromStep;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 44,
        width: 28,
        child: CustomPaint(
          painter: _VerticalConnectorPainter(color: fromStep.gradientColors[0]),
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const blue = Color(0xFF3B82F6);
    final paint = Paint()
      ..color = blue.withValues(alpha: .40)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // dashed line
    const dashW = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width - 10) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + dashW, size.height / 2), paint);
      x += dashW + gap;
    }
    // arrow head
    final tip = Offset(size.width, size.height / 2);
    final arrowPaint = Paint()
      ..color = blue.withValues(alpha: .65)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width - 9, size.height / 2 - 5), tip, arrowPaint);
    canvas.drawLine(Offset(size.width - 9, size.height / 2 + 5), tip, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) => old.color != color;
}

class _VerticalConnectorPainter extends CustomPainter {
  const _VerticalConnectorPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const blue = Color(0xFF3B82F6);
    final paint = Paint()
      ..color = blue.withValues(alpha: .40)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dashH = 5.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height - 10) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashH),
        paint,
      );
      y += dashH + gap;
    }
    // down arrow
    final tip = Offset(size.width / 2, size.height);
    canvas.drawLine(Offset(size.width / 2 - 5, size.height - 9), tip, paint);
    canvas.drawLine(Offset(size.width / 2 + 5, size.height - 9), tip, paint);
  }

  @override
  bool shouldRepaint(covariant _VerticalConnectorPainter old) =>
      old.color != color;
}

// ─── Step Card ────────────────────────────────────────────────────────────────

class _StepCard extends StatefulWidget {
  const _StepCard({required this.step});
  final _FlowStep step;

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _hovered
                ? const Color(0xFF999999)
                : const Color(0xFFE5E5E5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? .12 : .05),
              blurRadius: _hovered ? 36 : 18,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTop(step: step, hovered: _hovered),
              const SizedBox(height: 22),
              Text(
                step.title,
                style: const TextStyle(
                  color: _kHeading,
                  fontSize: 21,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                step.description,
                style: const TextStyle(
                  color: _kBody,
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final chip in step.chips) _Chip(label: chip),
                ],
              ),
              const SizedBox(height: 20),
              _MiniChart(step: step, hovered: _hovered),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTop extends StatelessWidget {
  const _CardTop({required this.step, required this.hovered});
  final _FlowStep step;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon with gradient
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: step.gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: step.gradientColors[0].withValues(alpha: hovered ? .38 : .22),
                blurRadius: hovered ? 18 : 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(step.icon, color: Colors.white, size: 24),
          ),
        ),
        const Spacer(),
        // Step number badge — blue accent
        DecoratedBox(
          decoration: BoxDecoration(
            color: _kBlueLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBlueBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Text(
              step.number,
              style: const TextStyle(
                color: _kBlue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Mini chart preview ───────────────────────────────────────────────────────

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.step, required this.hovered});
  final _FlowStep step;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hovered ? const Color(0xFFBBBBBB) : const Color(0xFFE8E8E8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: CustomPaint(
                painter: _SparklinePainter(
                  seed: int.tryParse(step.number) ?? 1,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      step.previewPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: const Color(0xFF111111),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      step.previewValue,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.previewLabel,
                  style: const TextStyle(
                    color: _kBody,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    // grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        gridPaint,
      );
    }

    // sparkline points
    final pts = <Offset>[];
    for (var i = 0; i < 20; i++) {
      final t = i / 19;
      final x = t * size.width;
      final y = size.height * (.55 - t * .22) +
          math.sin(t * math.pi * 3.4 + seed) * 6;
      pts.add(Offset(x, y.clamp(2, size.height - 2)));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    // filled area under sparkline
    final fillPath = Path()..addPath(path, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF111111).withValues(alpha: .10),
            const Color(0xFF111111).withValues(alpha: .00),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF111111),
    );

    // end dot
    canvas.drawCircle(
      pts.last,
      4,
      Paint()..color = const Color(0xFF111111),
    );
    canvas.drawCircle(
      pts.last,
      7,
      Paint()..color = const Color(0xFF111111).withValues(alpha: .15),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.seed != seed;
}

// ─── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kChipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kChipBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: _kChipText,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Trust Banner ─────────────────────────────────────────────────────────────

class _TrustBanner extends StatelessWidget {
  const _TrustBanner();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .22),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: w < 640 ? 24 : 48,
          vertical: w < 640 ? 32 : 40,
        ),
        child: w < 640
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TrustText(),
                  SizedBox(height: 24),
                  _TrustCTA(),
                ],
              )
            : const Row(
                children: [
                  Expanded(child: _TrustText()),
                  SizedBox(width: 32),
                  _TrustCTA(),
                ],
              ),
      ),
    );
  }
}

class _TrustText extends StatelessWidget {
  const _TrustText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'SEBI-Guided AI Insights',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Text(
          'Smarter decisions backed\nby AI and expert guidance.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Every AI recommendation is aligned with SEBI-registered advisor guidelines — \nso you invest with full confidence, not guesswork.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _TrustCTA extends StatelessWidget {
  const _TrustCTA();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Try StocBuy AI',
                  style: TextStyle(
                    color: Color(0xFF0A0A0A),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF0A0A0A),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
