import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/market_status_controller.dart';
import 'package:stocbuy_application/application/controllers/top_companies_controller.dart';
import 'package:stocbuy_application/application/models/top_company.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/livedot.dart';

/// Indian NSE-style ticker row: market status (left) + auto-scrolling quotes.
class IndianStockTickerStrip extends StatefulWidget {
  const IndianStockTickerStrip({super.key});

  /// Fixed layout height for placing under the app bar (padding + row + border).
  static const double layoutHeight = 54;

  @override
  State<IndianStockTickerStrip> createState() => _IndianStockTickerStripState();
}

class _IndianStockTickerStripState extends State<IndianStockTickerStrip>
    with SingleTickerProviderStateMixin {
  /// Identical quote blocks in a row; loop length = one block. Must match marquee math.
  static const int _marqueeCopies = 8;

  final ScrollController _scrollController = ScrollController();
  Ticker? _marqueeTicker;
  bool _marqueeScrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _marqueeTicker = createTicker(_onMarqueeTick)..start();
  }

  /// Never call [ScrollController.jumpTo] during layout; defer to post-frame.
  void _onMarqueeTick(Duration elapsed) {
    if (!mounted || _marqueeScrollScheduled) return;
    if (!_scrollController.hasClients) return;
    _marqueeScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _marqueeScrollScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      try {
        final pos = _scrollController.position;
        if (!pos.hasPixels) return;
        final max = pos.maxScrollExtent;
        if (!max.isFinite || max <= 0) return;
        final cycle = (max + pos.viewportDimension) / _marqueeCopies;
        var next = pos.pixels + 0.65;
        if (next >= cycle) {
          next -= cycle;
        }
        _scrollController.jumpTo(next);
      } catch (_) {
        // Scroll view torn down mid-frame / hot restart.
      }
    });
  }

  @override
  void dispose() {
    _marqueeTicker?.dispose();
    _marqueeTicker = null;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = Get.find<TopCompaniesController>();

    return Obx(() {
      final quotes = tc.displayQuotes;

      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xffEFF2F5), width: 1),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.isMobile(context) ? 20 : 8,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _MarketStatusBlock(),
              ),
              SizedBox(width: MediaQuery.sizeOf(context).width < 360 ? 8 : 12),
              Expanded(
                child: ClipRect(
                  child: SizedBox(
                    height: 32,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (var c = 0; c < _marqueeCopies; c++)
                            for (final q in quotes) _TickerQuoteItem(company: q),
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
    });
  }
}

class _MarketStatusBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mc = Get.find<MarketStatusController>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Obx(() => LiveDotDesign(state: mc.sessionState.value)),
    );
  }
}

class _TickerQuoteItem extends StatelessWidget {
  const _TickerQuoteItem({required this.company});

  final TopCompany company;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    late final Color changeColor;
    late final IconData trendIcon;

    if (company.isUp) {
      changeColor = AppColors.green;
      trendIcon = Icons.arrow_drop_up_rounded;
    } else if (company.isDown) {
      changeColor = AppColors.red;
      trendIcon = Icons.arrow_drop_down_rounded;
    } else {
      changeColor = AppColors.grey;
      trendIcon = Icons.trending_flat_rounded;
    }

    final pctLabel = TopCompany.formatChangeLabel(company.changePercent);

    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            company.symbol,
            style: textTheme.titleSmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.darkblue,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${company.currentPrice.toStringAsFixed(2)}',
            style: textTheme.titleSmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkblue,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            trendIcon,
            size: 24,
            color: changeColor,
          ),
          Text(
            pctLabel,
            style: textTheme.titleSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: changeColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
