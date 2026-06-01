import 'package:flutter/material.dart';

const _kBlue = Color(0xFF3B82F6);
const _kBlueLight = Color(0xFFEFF6FF);
const _kBlueBorder = Color(0xFFBFDBFE);
const _kBlack = Color(0xFF0A0A0A);
const _kGray = Color(0xFF555555);

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;
}

const _faqs = [
_FaqItem(
  question: 'What is StocBuy and who is it for?',
  answer:
      'StocBuy is an AI-powered stock analysis app built exclusively for Indian investors. '
      'Whether you\'re a first-time investor or an experienced trader, StocBuy turns complex '
      'NSE & BSE market data into simple, actionable insights — in your own language.',
),
_FaqItem(
  question: 'How does StocBuy analyze stocks?',
  answer:
      'Search any NSE or BSE stock and StocBuy\'s AI instantly analyzes live price data, '
      'company financials, technical indicators (RSI, MACD, EMA, SMA), news sentiment, '
      'and fundamentals like P/E ratio, revenue growth, and debt levels — then explains '
      'everything in plain, simple language.',
),
_FaqItem(
  question: 'Can StocBuy predict future stock prices?',
  answer:
      'Yes — StocBuy\'s AI calculates estimated target prices based on historical data, '
      'technical patterns, and fundamental strength. These are AI-generated estimates to '
      'guide your research, not guaranteed returns. Always invest based on your own judgment.',
),
_FaqItem(
  question: 'Which Indian languages does StocBuy support?',
  answer:
      'StocBuy supports Hindi, Tamil, Telugu, Kannada, Malayalam, Bengali, Marathi, '
      'Gujarati, and more. Ask your question in any language — "यह स्टॉक सुरक्षित है क्या?" '
      'or "இந்த பங்கு நல்லதா?" — and get a clear AI answer instantly.',
),
_FaqItem(
  question: 'Is StocBuy SEBI compliant?',
  answer:
      'StocBuy provides AI-generated insights for educational and informational purposes only. '
      'Our Expert plan includes guidance aligned with SEBI-registered financial advisor '
      'standards to help you make more informed decisions. StocBuy itself is not a '
      'SEBI-registered investment advisor.',
),
_FaqItem(
  question: 'Which stocks does StocBuy cover?',
  answer:
      'StocBuy covers every stock listed on NSE and BSE — large-cap, mid-cap, small-cap, '
      'and penny stocks. Search any company by name or ticker symbol and get full '
      'AI analysis in seconds.',
),
_FaqItem(
  question: 'How is StocBuy different from Zerodha, Groww, or other platforms?',
  answer:
      'Other platforms show you data. StocBuy explains it. Instead of raw charts and '
      'confusing numbers, you get AI risk scores, news impact analysis, target prices, '
      'and buy/hold/avoid recommendations — all in plain language. It\'s like having '
      'a personal financial analyst available 24/7, for free.',
),
_FaqItem(
  question: 'Can I use StocBuy for free?',
  answer:
      'Yes! StocBuy\'s free Starter plan lets you search stocks, get basic AI summaries, '
      'and track up to 5 stocks — no credit card needed. Upgrade anytime to unlock '
      'full AI analysis, target price predictions, multilingual assistant, and 30+ features.',
),
];

// ─── Section ──────────────────────────────────────────────────────────────────

class FaqSection extends StatelessWidget {
  const FaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final hp = w < 640 ? 20.0 : (w < 1024 ? 40.0 : 64.0);

        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(hp, 96, hp, 96),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  const _SectionHeader(),
                  const SizedBox(height: 56),
                  for (var i = 0; i < _faqs.length; i++) ...[
                    if (i > 0)
                      const Divider(color: Color(0xFFEEEEEE), height: 1),
                    _FaqAccordion(item: _faqs[i]),
                  ],
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
    final headSize = w < 640 ? 32.0 : 44.0;

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
                Icon(Icons.help_outline_rounded, size: 15, color: _kBlue),
                SizedBox(width: 7),
                Text(
                  'Frequently Asked Questions',
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
        Text(
          'Got questions?\nWe\'ve got answers.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kBlack,
            fontSize: headSize,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Can\'t find what you\'re looking for? Reach out to our support team.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _kGray, fontSize: 15, height: 1.5),
        ),
      ],
    );
  }
}

// ─── Accordion ────────────────────────────────────────────────────────────────

class _FaqAccordion extends StatefulWidget {
  const _FaqAccordion({required this.item});
  final _FaqItem item;

  @override
  State<_FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<_FaqAccordion>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _heightFactor;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _heightFactor = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _rotation = Tween(begin: 0.0, end: .5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: TextStyle(
                      color: _expanded ? _kBlue : _kBlack,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedBuilder(
                  animation: _rotation,
                  builder: (context, child) => Transform.rotate(
                    angle: _rotation.value * 3.14159,
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _expanded ? _kBlueLight : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _expanded ? _kBlueBorder : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: _expanded ? _kBlue : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizeTransition(
              sizeFactor: _heightFactor,
              child: Padding(
                padding: const EdgeInsets.only(top: 14, right: 48),
                child: Text(
                  widget.item.answer,
                  style: const TextStyle(
                    color: _kGray,
                    fontSize: 14.5,
                    height: 1.65,
                    fontWeight: FontWeight.w400,
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
