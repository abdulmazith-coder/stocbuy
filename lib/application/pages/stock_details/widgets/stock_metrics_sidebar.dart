import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/models/stock_detail.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/external_url.dart';
import 'package:stocbuy_application/application/utils/stock_formatters.dart';

/// "Ratios + Company" rail on the Stock Details page.
///
/// Lives on the left on desktop and stacks beneath the chart on mobile /
/// tablet. Visually it's a column of compact white cards, each grouping a
/// related set of label/value pairs — mirroring the Screener / Moneycontrol
/// "Quick stats" panel.
class StockMetricsSidebar extends StatelessWidget {
  const StockMetricsSidebar({super.key, required this.detail});

  final StockDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Market snapshot ────────────────────────────────────────────────
        _PairsCard(
          rows: [
            _MetricRow(
              'Market Cap',
              StockFormatters.compactRupees(detail.marketCap),
            ),
            _MetricRow(
              '52W High / Low',
              _highLowLabel(detail),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Valuation ─────────────────────────────────────────────────────
        _TitledPairsCard(
          icon: Icons.show_chart_rounded,
          title: 'Valuation',
          rows: [
            _MetricRow('P/E', StockFormatters.multiplier(detail.trailingPE)),
            _MetricRow(
              'Forward P/E',
              StockFormatters.multiplier(detail.forwardPE),
            ),
            _MetricRow(
              'Industry P/E',
              StockFormatters.multiplier(detail.industryPE),
            ),
            _MetricRow(
              'PEG Ratio',
              StockFormatters.multiplier(detail.pegRatio),
            ),
            _MetricRow(
              'Trailing PEG',
              StockFormatters.multiplier(detail.trailingPegRatio),
            ),
            _MetricRow(
              'Price to Book',
              StockFormatters.multiplier(detail.priceToBook),
            ),
            _MetricRow(
              'Price to Sales',
              StockFormatters.multiplier(detail.priceToSalesTrailing12Months),
            ),
            _MetricRow(
              'EV / Revenue',
              StockFormatters.multiplier(detail.enterpriseToRevenue),
            ),
            _MetricRow(
              'EV / EBITDA',
              StockFormatters.multiplier(detail.evToEbitda),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Profitability & Returns ───────────────────────────────────────
        _TitledPairsCard(
          icon: Icons.trending_up_rounded,
          title: 'Profitability & Returns',
          rows: [
            _MetricRow(
              'Profit Margin',
              StockFormatters.ratioAsPercent(detail.profitMargins),
              valueColor: _signed(detail.profitMargins),
            ),
            _MetricRow(
              'Gross Margin',
              StockFormatters.ratioAsPercent(detail.grossMargins),
              valueColor: _signed(detail.grossMargins),
            ),
            _MetricRow(
              'Operating Margin',
              StockFormatters.ratioAsPercent(detail.operatingMargins),
              valueColor: _signed(detail.operatingMargins),
            ),
            _MetricRow(
              'EBITDA Margin',
              StockFormatters.ratioAsPercent(detail.ebitdaMargins),
              valueColor: _signed(detail.ebitdaMargins),
            ),
            _MetricRow(
              'Return on Assets (ROA)',
              StockFormatters.ratioAsPercent(detail.returnOnAssets),
              valueColor: _signed(detail.returnOnAssets),
            ),
            _MetricRow(
              'Return on Equity (ROE)',
              StockFormatters.ratioAsPercent(detail.returnOnEquity),
              valueColor: _signed(detail.returnOnEquity),
            ),
            _MetricRow(
              'ROCE',
              StockFormatters.ratioAsPercent(
                detail.returnOnCapitalEmployed,
                fractionDigits: 1,
              ),
              valueColor: _signed(detail.returnOnCapitalEmployed),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Liquidity & Leverage ──────────────────────────────────────────
        _TitledPairsCard(
          icon: Icons.balance_rounded,
          title: 'Liquidity & Leverage',
          rows: [
            _MetricRow(
              'Current Ratio',
              StockFormatters.multiplier(detail.currentRatio),
            ),
            _MetricRow(
              'Quick Ratio',
              StockFormatters.multiplier(detail.quickRatio),
            ),
            _MetricRow(
              'Debt to Equity',
              _debtToEquityLabel(detail.debtToEquity),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Growth ────────────────────────────────────────────────────────
        _TitledPairsCard(
          icon: Icons.rocket_launch_rounded,
          title: 'Growth',
          rows: [
            _MetricRow(
              'Earnings Growth',
              StockFormatters.ratioAsPercent(detail.earningsGrowth),
              valueColor: _signed(detail.earningsGrowth),
            ),
            _MetricRow(
              'Revenue Growth',
              StockFormatters.ratioAsPercent(detail.revenueGrowth),
              valueColor: _signed(detail.revenueGrowth),
            ),
            _MetricRow(
              'Quarterly Earnings Growth',
              StockFormatters.ratioAsPercent(detail.earningsQuarterlyGrowth),
              valueColor: _signed(detail.earningsQuarterlyGrowth),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Per Share ─────────────────────────────────────────────────────
        _TitledPairsCard(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Per Share',
          rows: [
            _MetricRow(
              'EPS (TTM)',
              StockFormatters.price(detail.trailingEps),
            ),
            _MetricRow(
              'Forward EPS',
              StockFormatters.price(detail.forwardEps),
            ),
            _MetricRow(
              'Revenue / Share',
              StockFormatters.price(detail.revenuePerShare),
            ),
            _MetricRow(
              'Cash / Share',
              StockFormatters.price(detail.totalCashPerShare),
            ),
            _MetricRow(
              'Book Value / Share',
              StockFormatters.price(detail.bookValue),
            ),
            _MetricRow(
              'Face Value',
              StockFormatters.price(detail.faceValue),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Dividends ─────────────────────────────────────────────────────
        _TitledPairsCard(
          icon: Icons.savings_outlined,
          title: 'Dividends',
          rows: [
            _MetricRow(
              'Dividend Yield',
              _rawPercent(detail.dividendYield),
            ),
            _MetricRow(
              'Trailing Dividend Yield',
              StockFormatters.ratioAsPercent(detail.trailingAnnualDividendYield),
            ),
            _MetricRow(
              '5Y Avg Dividend Yield',
              _rawPercent(detail.fiveYearAvgDividendYield),
            ),
            _MetricRow(
              'Payout Ratio',
              StockFormatters.ratioAsPercent(detail.payoutRatio),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Risk & Holdings ───────────────────────────────────────────────
        _TitledPairsCard(
          icon: Icons.account_balance_outlined,
          title: 'Risk & Holdings',
          rows: [
            _MetricRow(
              'Beta',
              StockFormatters.multiplier(detail.beta),
            ),
            _MetricRow(
              'Insider Holding %',
              StockFormatters.ratioAsPercent(detail.heldPercentInsiders),
              valueColor: AppColors.green,
            ),
            _MetricRow(
              'Institutional Holding %',
              StockFormatters.ratioAsPercent(detail.heldPercentInstitutions),
            ),
            _MetricRow(
              'Pledged %',
              _rawPercent(detail.pledgedPercent),
            ),
            _MetricRow(
              'Unpledged Promoter Hold',
              _rawPercent(detail.unpledgedPromoterHolding),
              valueColor: AppColors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),

        _ProfileScoreCard(detail: detail),
        const SizedBox(height: 12),
        _CompanyInfoCard(detail: detail),
      ],
    );
  }

  static String _highLowLabel(StockDetail detail) {
    final hi = detail.fiftyTwoWeekHigh;
    final lo = detail.fiftyTwoWeekLow;
    if (hi == null && lo == null) return '—';
    String fmt(double? v) =>
        v == null ? '—' : StockFormatters.price(v, currency: '');
    return '₹ ${fmt(hi)} / ${fmt(lo).trim()}';
  }

  /// Raw-percent formatter that does NOT prefix positives with `+`.
  /// Use for yields, payouts, holdings — anywhere a `+` looks weird.
  static String _rawPercent(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(2)}%';
  }

  /// D/E sometimes comes from the API as a percent-like value (e.g. `13.78`
  /// for 0.1378×). We pass it through as-is — backend is authoritative.
  static String _debtToEquityLabel(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(2);
  }

  /// Pick a foreground color based on whether a ratio is positive / negative.
  /// Null and zero stay neutral.
  static Color? _signed(double? value) {
    if (value == null || value == 0) return null;
    return value > 0 ? AppColors.green : AppColors.red;
  }
}

// —— Reusable label/value card ——————————————————————————————————————————————

class _MetricRow {
  const _MetricRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;
  String? get hint => null;
}

/// Variant of [_PairsCard] with a compact section header (icon + title).
/// Used to introduce a group of related ratios (Valuation, Profitability,
/// Growth, …) without cluttering each row.
class _TitledPairsCard extends StatelessWidget {
  const _TitledPairsCard({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<_MetricRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.lightblue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 13,
                    color: AppColors.lightblue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.grey,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.55),
          ),
          // The header sits above; the rows below reuse the same row
          // layout as [_PairsCard] to keep visual rhythm consistent.
          _PairsRows(rows: rows),
        ],
      ),
    );
  }
}

/// Bare list-of-rows used by both [_PairsCard] (no header) and
/// [_TitledPairsCard] (with header). Extracted so the divider + row
/// padding stays identical in both cases.
class _PairsRows extends StatelessWidget {
  const _PairsRows({required this.rows});

  final List<_MetricRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          rows[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (rows[i].hint != null) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: rows[i].hint!,
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.grey.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  rows[i].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: rows[i].valueColor ?? AppColors.darkblue,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          if (i < rows.length - 1)
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.55),
              indent: 16,
              endIndent: 16,
            ),
        ],
      ],
    );
  }
}

class _PairsCard extends StatelessWidget {
  const _PairsCard({required this.rows});

  final List<_MetricRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: _PairsRows(rows: rows),
    );
  }
}

// —— Profile score + Boost CTA ————————————————————————————————————————————

class _ProfileScoreCard extends StatelessWidget {
  const _ProfileScoreCard({required this.detail});

  final StockDetail detail;

  @override
  Widget build(BuildContext context) {
    // Composite profile-coverage score based on how many key fields the
    // detail payload carries — full-coverage payloads score 100%.
    final score = _computeScore(detail);

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Profile score',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message:
                    'Indicates how complete this stock\'s data profile is.',
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.grey.withValues(alpha: 0.65),
                ),
              ),
              const Spacer(),
              Text(
                '${(score * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 8,
              backgroundColor: AppColors.border.withValues(alpha: 0.7),
              valueColor: const AlwaysStoppedAnimation(AppColors.green),
            ),
          ),
          const SizedBox(height: 14),
          _BoostButton(),
        ],
      ),
    );
  }

  static double _computeScore(StockDetail d) {
    final checks = <bool>[
      d.marketCap != null,
      d.trailingPE != null,
      d.industryPE != null,
      d.pegRatio != null,
      d.evToEbitda != null,
      d.trailingEps != null,
      d.returnOnCapitalEmployed != null,
      d.returnOnEquity != null,
      d.dividendYield != null,
      d.bookValue != null,
      d.faceValue != null,
      d.pledgedPercent != null,
      d.unpledgedPromoterHolding != null,
      d.sector != null,
      d.industry != null,
      d.website != null,
      d.address1 != null,
      d.longBusinessSummary != null,
    ];
    final filled = checks.where((c) => c).length;
    return checks.isEmpty ? 0 : filled / checks.length;
  }
}

class _BoostButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.red.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.rocket_launch_rounded,
                size: 16,
                color: AppColors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'Boost',
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// —— Company info card (address, sector, website, etc.) —————————————————————

class _CompanyInfoCard extends StatelessWidget {
  const _CompanyInfoCard({required this.detail});

  final StockDetail detail;

  @override
  Widget build(BuildContext context) {
    final addressLine = [
      detail.address1,
      detail.address2,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    final cityLine = [
      detail.city,
      detail.state,
      detail.zip,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Company info',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.grey,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.donut_large_rounded,
            label: 'Sector',
            value: detail.sector,
          ),
          _InfoRow(
            icon: Icons.factory_outlined,
            label: 'Industry',
            value: detail.industry,
          ),
          _InfoRow(
            icon: Icons.people_alt_outlined,
            label: 'Employees',
            value: detail.fullTimeEmployees == null
                ? null
                : StockFormatters.compactNumber(detail.fullTimeEmployees),
          ),
          _InfoRow(
            icon: Icons.place_outlined,
            label: 'Head office',
            value: [
              if (addressLine.isNotEmpty) addressLine,
              if (cityLine.isNotEmpty) cityLine,
              if (detail.country != null) detail.country,
            ].whereType<String>().where((s) => s.isNotEmpty).join('\n'),
            multiline: true,
          ),
          _InfoRow(
            icon: Icons.call_outlined,
            label: 'Phone',
            value: detail.phone,
          ),
          if (detail.website != null && detail.website!.isNotEmpty)
            _WebsiteRow(url: detail.website!),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final v = (value == null || value!.trim().isEmpty) ? '—' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.grey.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  v,
                  softWrap: multiline,
                  maxLines: multiline ? 4 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkblue,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebsiteRow extends StatelessWidget {
  const _WebsiteRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openExternalUrl(
          url,
          context: context,
          failureMessage: "We couldn't open the company website.",
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 16, color: AppColors.lightblue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.lightblue,
                    decoration: TextDecoration.underline,
                    decorationColor:
                        AppColors.lightblue.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: AppColors.lightblue.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// —— Card chrome shared by every sub-card ————————————————————————————————

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
      boxShadow: [
        BoxShadow(
          color: AppColors.darkblue.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: -4,
        ),
      ],
    );
