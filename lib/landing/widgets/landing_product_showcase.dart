import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';
import 'package:stocbuy_application/application/widgets/dashboard_market_summary_row.dart';
import 'package:stocbuy_application/application/models/market_session_status.dart';
import 'package:stocbuy_application/application/widgets/livedot.dart';

/// Landing hero preview — matches the real `/app` dashboard (2nd screenshot).
class LandingProductShowcase extends StatefulWidget {
  const LandingProductShowcase({super.key});

  @override
  State<LandingProductShowcase> createState() => _LandingProductShowcaseState();
}

class _LandingProductShowcaseState extends State<LandingProductShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final radius = w < 400 ? 18.0 : 22.0;
        final previewHeight = (w * 0.72).clamp(380.0, 560.0);

        return AnimatedBuilder(
          animation: _float,
          builder: (context, child) {
            final dy = math.sin(_float.value * math.pi * 2) * 5;
            return Transform.translate(offset: Offset(0, dy), child: child);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkblue.withValues(alpha: .12),
                  blurRadius: 40,
                  offset: const Offset(0, 22),
                ),
                BoxShadow(
                  color: AppColors.lightblue.withValues(alpha: .10),
                  blurRadius: 48,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: SizedBox(
                height: previewHeight,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(w < 500 ? 0.88 : 0.92),
                  ),
                  child: _AppDashboardPreview(compactNav: w < 720),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppDashboardPreview extends StatelessWidget {
  const _AppDashboardPreview({required this.compactNav});

  final bool compactNav;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreviewAppBar(compact: compactNav),
          const _PreviewTickerStrip(),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DashboardMarketSummaryRow(),
                  const SizedBox(height: 14),
                  const _PreviewMarketsPanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewAppBar extends StatelessWidget {
  const _PreviewAppBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: .9),
          ),
        ),
      ),
      child: Row(
        children: [
          const StocbuyBrandMark(compact: true, logoSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.grey.withValues(alpha: .85),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search Stocks, IPOs, etc...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey.withValues(alpha: .9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 10),
            const _NavTab(label: 'Dashboard', active: true),
            const SizedBox(width: 6),
            const _NavTab(
              label: 'Stocbuy AI',
              active: false,
              showSparkle: true,
            ),
            const SizedBox(width: 6),
            const _NavTab(label: 'IPOs', active: false),
          ],
          const Spacer(),
          if (!compact)
            Text(
              'Log In',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.darkblue,
              ),
            ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.lightblue,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Sign Up',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.active,
    this.showSparkle = false,
  });

  final String label;
  final bool active;
  final bool showSparkle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSparkle) ...[
              Icon(
                Icons.auto_awesome_rounded,
                size: 12,
                color: active ? AppColors.lightblue : AppColors.grey,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppColors.darkblue : AppColors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 2,
          width: active ? 28 : 0,
          decoration: BoxDecoration(
            color: AppColors.lightblue,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _PreviewTickerStrip extends StatelessWidget {
  const _PreviewTickerStrip();

  static const _quotes = [
    ('LT', '₹3,842.50', '+0.62%', true),
    ('KOTAKBANK', '₹2,108.30', '+0.41%', true),
    ('HINDUNILVR', '₹2,456.80', '-0.18%', false),
    ('AXISBANK', '₹1,178.20', '+0.55%', true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: .55)),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: LiveDotDesign(state: MarketSessionState.postMarket),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _quotes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) {
                final q = _quotes[i];
                final up = q.$4;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      q.$1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkblue,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      q.$2,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      q.$3,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: up ? AppColors.green : AppColors.red,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMarketsPanel extends StatelessWidget {
  const _PreviewMarketsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: .9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: .04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                _TabChip(label: 'Top Gainers', selected: true),
                const SizedBox(width: 8),
                _TabChip(label: 'Top Losers', selected: false),
                const SizedBox(width: 8),
                _TabChip(label: 'Upcoming IPOs', selected: false),
                const Spacer(),
                Icon(Icons.tune_rounded, size: 16, color: AppColors.grey),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                _ExchangePill(label: 'NSE top gain stock', selected: true),
                const SizedBox(width: 8),
                _ExchangePill(label: 'BSE top gain stock', selected: false),
                const Spacer(),
                const DashboardMarketSessionIndicator(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const _PreviewTableHeader(),
          const _PreviewStockRow(
            rank: 1,
            name: 'TECH MAHINDRA LIMITED',
            symbol: 'TECHM',
            price: '₹1,623.40',
            change: '+2.14%',
            up: true,
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const _PreviewStockRow(
            rank: 2,
            name: 'INFOSYS LIMITED',
            symbol: 'INFY',
            price: '₹1,539.45',
            change: '+1.86%',
            up: true,
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const _PreviewStockRow(
            rank: 3,
            name: 'BHARTI AIRTEL LIMITED',
            symbol: 'BHARTIARTL',
            price: '₹1,678.20',
            change: '+1.52%',
            up: true,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? AppColors.lightblue : AppColors.grey,
        decoration: selected
            ? TextDecoration.underline
            : TextDecoration.none,
        decorationColor: AppColors.lightblue,
      ),
    );
  }
}

class _ExchangePill extends StatelessWidget {
  const _ExchangePill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.lightblue : AppColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? AppColors.lightblue : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.white : AppColors.darkblue,
        ),
      ),
    );
  }
}

class _PreviewTableHeader extends StatelessWidget {
  const _PreviewTableHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(
            flex: 4,
            child: Text(
              'Name',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Price',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Today %',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.grey,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _PreviewStockRow extends StatelessWidget {
  const _PreviewStockRow({
    required this.rank,
    required this.name,
    required this.symbol,
    required this.price,
    required this.change,
    required this.up,
  });

  final int rank;
  final String name;
  final String symbol;
  final String price;
  final String change;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkblue,
                  ),
                ),
                Text(
                  symbol,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              price,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.darkblue,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              change,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: up ? AppColors.green : AppColors.red,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            height: 22,
            child: CustomPaint(
              painter: _SparklinePainter(up: up),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.up});

  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = up ? AppColors.green : AppColors.red
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final pts = up
        ? [0.9, 0.75, 0.82, 0.65, 0.7, 0.45, 0.5, 0.25]
        : [0.3, 0.45, 0.4, 0.55, 0.5, 0.65, 0.6, 0.8];
    for (var i = 0; i < pts.length; i++) {
      final x = size.width * (i / (pts.length - 1));
      final y = size.height * pts[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.up != up;
}
