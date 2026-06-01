import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/models/stock_detail.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/stock_formatters.dart';

/// Identity + price block shown at the top of [StockDetailsPage].
///
/// Layout (mirrors the reference design):
///   • Row 1: full company name (big, can wrap up to 3 lines)  +  star /
///     share icon-buttons aligned to the top-right.
///   • Row 2: symbol pill (e.g. `TCS`) — small grey chip below the name.
///   • Row 3: big rupee price + change pill (sit side-by-side, wrap if the
///     column gets narrow).
///
/// This widget renders directly on the page background — no card border /
/// shadow — so it visually leads the column with the metric cards below it.
class StockDetailsHeader extends StatelessWidget {
  const StockDetailsHeader({
    super.key,
    required this.detail,
    required this.watchlisted,
    required this.onToggleWatchlist,
    this.changeAbs,
    this.changePct,
    this.displayPrice,
    this.onShare,
  });

  final StockDetail detail;
  final bool watchlisted;
  final VoidCallback onToggleWatchlist;

  /// When set (e.g. from the active chart bar), overrides [StockDetail.change].
  final double? changeAbs;
  final double? changePct;

  /// Live chart close while intraday; falls back to [StockDetail.currentPrice].
  final double? displayPrice;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final bool mobile = Responsive.isMobile(context);

    // Big primary title is the full name. When the backend hasn't returned
    // a longer name yet, [displayName] falls back to the symbol itself —
    // which is fine because the symbol pill on the next line would just be
    // redundant; we hide it in that case.
    final fullName = detail.displayName.trim();
    final symbol = detail.symbol.trim();
    final showSymbolPill =
        symbol.isNotEmpty && symbol.toUpperCase() != fullName.toUpperCase();

    final titleStyle = TextStyle(
      fontSize: mobile ? 22 : 26,
      fontWeight: FontWeight.w900,
      color: AppColors.darkblue,
      height: 1.18,
      letterSpacing: -0.4,
    );
    final priceStyle = TextStyle(
      fontSize: mobile ? 30 : 36,
      fontWeight: FontWeight.w900,
      color: AppColors.darkblue,
      height: 1.0,
      letterSpacing: -1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // —— Name + actions ——
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                fullName.isEmpty ? symbol : fullName,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            const SizedBox(width: 12),
            _IconAction(
              icon: watchlisted
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              activeColor:
                  watchlisted ? AppColors.lightblue : AppColors.grey,
              tooltip: watchlisted ? 'Remove from watchlist' : 'Watchlist',
              onTap: onToggleWatchlist,
            ),
            const SizedBox(width: 8),
            _IconAction(
              icon: Icons.ios_share_outlined,
              activeColor: AppColors.grey,
              tooltip: 'Share',
              onTap: onShare ?? () {},
            ),
          ],
        ),
        if (showSymbolPill) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _SymbolPill(symbol: symbol),
              if (detail.exchange != null) ...[
                const SizedBox(width: 6),
                _SymbolPill(
                  symbol: detail.exchange!.toUpperCase(),
                  emphasised: true,
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 14),
        // —— Price + change ——
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              StockFormatters.price(displayPrice ?? detail.currentPrice),
              style: priceStyle,
            ),
            _ChangeBadge(
              changeAbs: changeAbs ?? detail.change,
              changePct: changePct ?? detail.changePercent,
            ),
          ],
        ),
      ],
    );
  }
}

// —— Icon button (star / share) ——————————————————————————————————————————

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.activeColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color activeColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.surfaceMuted.withValues(alpha: 0.6),
        splashColor: AppColors.lightblue.withValues(alpha: 0.08),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: activeColor),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// —— Small grey chip used for symbol / exchange ——————————————————————————

class _SymbolPill extends StatelessWidget {
  const _SymbolPill({required this.symbol, this.emphasised = false});

  final String symbol;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasised
            ? AppColors.lightblue.withValues(alpha: 0.08)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: emphasised
              ? AppColors.lightblue.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: emphasised ? AppColors.lightblue : AppColors.grey,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

// —— Change badge (up arrow + percent + abs) ——————————————————————————————

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.changeAbs, required this.changePct});

  final double? changeAbs;
  final double? changePct;

  @override
  Widget build(BuildContext context) {
    final pct = changePct ?? 0;
    final isUp = pct > 0;
    final isDown = pct < 0;
    final color = !isUp && !isDown
        ? AppColors.grey
        : (isUp ? AppColors.green : AppColors.red);

    final arrow = !isUp && !isDown ? '' : (isUp ? '▲' : '▼');
    final absLabel = changeAbs == null || changeAbs == 0
        ? ''
        : ' (${StockFormatters.price(changeAbs!.abs(), currency: '₹')})';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$arrow ${StockFormatters.percent(pct)}$absLabel'.trim(),
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
          height: 1.2,
        ),
      ),
    );
  }
}
