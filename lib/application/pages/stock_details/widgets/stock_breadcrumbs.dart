import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/navigation/app_routes.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// "Stocks  ›  IT Sector  ›  TCS" — the lightweight breadcrumb row that
/// sits above the price card on the Stock Details page.
///
/// • "Stocks" is always tappable → returns to the dashboard.
/// • The middle segment is the sector (or "All sectors" when unknown), trimmed
///   to its core word ("Information Technology" → "IT Sector").
/// • The last segment is the current symbol and is rendered as the active
///   crumb (non-tappable, ink-dark).
class StockBreadcrumbs extends StatelessWidget {
  const StockBreadcrumbs({
    super.key,
    required this.symbol,
    this.sector,
  });

  final String symbol;
  final String? sector;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.grey,
        letterSpacing: 0.1,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          _Crumb(
            label: 'Stocks',
            onTap: () => Get.offAllNamed(AppRoutes.dashboard),
          ),
          const _Separator(),
          _Crumb(label: _sectorLabel(sector)),
          const _Separator(),
          Text(
            symbol,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: AppColors.darkblue,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  static String _sectorLabel(String? sector) {
    final s = sector?.trim();
    if (s == null || s.isEmpty) return 'All sectors';
    // Compact common Yahoo-style sector names into shorter breadcrumbs.
    const map = <String, String>{
      'Technology': 'IT Sector',
      'Information Technology': 'IT Sector',
      'Information Technology Services': 'IT Sector',
      'Financial Services': 'Financials',
      'Consumer Defensive': 'FMCG',
      'Consumer Cyclical': 'Consumer',
      'Communication Services': 'Communications',
      'Basic Materials': 'Materials',
      'Healthcare': 'Pharma',
      'Energy': 'Energy',
      'Industrials': 'Industrials',
      'Utilities': 'Utilities',
    };
    return map[s] ?? s;
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(label);
    if (onTap == null) return text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: text,
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: 16,
      color: AppColors.grey.withValues(alpha: 0.7),
    );
  }
}
