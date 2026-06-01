import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/stock_details_controller.dart';
import 'package:stocbuy_application/application/models/stock_fundamentals.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/external_url.dart';
import 'package:stocbuy_application/application/utils/stock_formatters.dart';

/// Each financial statement is rendered as its own card so the section tabs
/// at the top of the chart can scroll directly to the matching card. All
/// five cards share the same chrome (white card, light border, soft shadow,
/// header row with icon + title, then the body / table).
///
/// The fundamentals data and loading state live on
/// [StockDetailsController.fundamentals] — every card listens via [Obx], so
/// the very first card to mount triggers the API fetch and all five fill in
/// together when the data lands.

// —— Public section cards ————————————————————————————————————————————————

class StockBalanceSheetCard extends StatelessWidget {
  const StockBalanceSheetCard({super.key, required this.controller});
  final StockDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return _FinancialsSectionCard(
      title: 'Balance Sheet',
      icon: Icons.account_balance_outlined,
      trailing: '5Y',
      controller: controller,
      builder: (_, f) => _BalanceSheetTable(rows: f.balanceSheet),
    );
  }
}

class StockIncomeStatementCard extends StatelessWidget {
  const StockIncomeStatementCard({super.key, required this.controller});
  final StockDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return _FinancialsSectionCard(
      title: 'Income Statement',
      icon: Icons.trending_up_rounded,
      trailing: '5Y',
      controller: controller,
      builder: (_, f) => _IncomeStatementTable(rows: f.incomeStatement),
    );
  }
}

class StockCashFlowCard extends StatelessWidget {
  const StockCashFlowCard({super.key, required this.controller});
  final StockDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return _FinancialsSectionCard(
      title: 'Cash Flow',
      icon: Icons.swap_vert_rounded,
      trailing: '5Y',
      controller: controller,
      builder: (_, f) => _CashFlowTable(rows: f.cashFlow),
    );
  }
}

class StockShareholdingCard extends StatelessWidget {
  const StockShareholdingCard({super.key, required this.controller});
  final StockDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return _FinancialsSectionCard(
      title: 'Shareholding Pattern',
      icon: Icons.pie_chart_outline_rounded,
      trailing: 'Latest',
      controller: controller,
      builder: (_, f) => _ShareholdingPie(breakdown: f.shareholding),
    );
  }
}

class StockNewsCard extends StatelessWidget {
  const StockNewsCard({super.key, required this.controller});
  final StockDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return _FinancialsSectionCard(
      title: 'News',
      icon: Icons.newspaper_outlined,
      trailing: null,
      controller: controller,
      builder: (_, f) => _NewsList(news: f.news),
    );
  }
}

// —— Shared section-card chrome ————————————————————————————————————————————

class _FinancialsSectionCard extends StatelessWidget {
  const _FinancialsSectionCard({
    required this.title,
    required this.icon,
    required this.trailing,
    required this.controller,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final String? trailing;
  final StockDetailsController controller;
  final Widget Function(BuildContext context, StockFundamentals f) builder;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 20,
              mobile ? 16 : 20,
              mobile ? 16 : 20,
              mobile ? 14 : 16,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.darkblue.withValues(alpha: 0.85),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mobile ? 15 : 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkblue,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    trailing!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.55),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 12 : 18,
              mobile ? 14 : 18,
              mobile ? 12 : 18,
              mobile ? 16 : 22,
            ),
            child: Obx(() {
              final f = controller.fundamentals.value;
              if (controller.isLoadingFundamentals.value && f == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.lightblue),
                      ),
                    ),
                  ),
                );
              }
              if (f == null) {
                return _EmptyFinancials(
                  unavailable: controller.fundamentalsUnavailable.value,
                );
              }
              return builder(context, f);
            }),
          ),
        ],
      ),
    );
  }
}

class _EmptyFinancials extends StatelessWidget {
  const _EmptyFinancials({this.unavailable = false});

  /// `true` once the controller has tried and confirmed the backend has
  /// no fundamentals payload for this symbol (5xx / success=false /
  /// unparseable). Used to swap the optimistic "Data will appear here"
  /// placeholder for a definitive "Not available" message so users on
  /// obscure tickers (ETFs / illiquid scrips) aren't left waiting.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final text = unavailable
        ? "This stock doesn't have data available right now."
        : 'Data will appear here.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// —— Tables ————————————————————————————————————————————————————————————————
//
// Every financial statement is rendered through the same [_FinancialsTable].
// Each line is either a [_FinSection] (sub-header with a quiet background)
// or a [_FinRow] (label + N year columns). [_FinRow.kind] decides the
// unit suffix applied to the rendered value:
//
//   • [_RowKind.crores]     — raw rupees → "₹ X Cr" (auto-switches to L/K
//                              for tiny numbers via the formatter).
//   • [_RowKind.perShare]   — plain rupee value with no Cr suffix
//                              (EPS, Book value per share).
//   • [_RowKind.percent]    — 0..1 fraction → "24.48%".
//   • [_RowKind.shareCount] — large integer → "3.62 B" / "1.45 Cr".
//   • [_RowKind.raw]        — pass-through, two-decimal plain number.
//
// "Don't mention the Cr / Lakh for ratios" → every ratio-shaped row uses
// `percent`, `perShare`, `shareCount`, or `raw` — never `crores`.

enum _RowKind { crores, perShare, percent, shareCount, raw }

class _FinRow {
  const _FinRow(
    this.label,
    this.values, {
    this.kind = _RowKind.crores,
    this.bold = false,
    this.indent = 0,
  });

  final String label;
  final List<double?> values;
  final _RowKind kind;
  final bool bold;

  /// Indent level (0 = top-level row, 1 = sub-item). Visual only.
  final int indent;
}

class _FinSection {
  const _FinSection(this.title);
  final String title;
}

class _FinancialsTable extends StatelessWidget {
  const _FinancialsTable({
    required this.years,
    required this.lines,
  });

  final List<int> years;

  /// Mix of [_FinSection] (sub-header) and [_FinRow] (data row).
  final List<Object> lines;

  @override
  Widget build(BuildContext context) {
    final tableRows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted.withValues(alpha: 0.4),
          border: Border(
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
          ),
        ),
        children: [
          _hdrCell('Metric'),
          for (final y in years)
            _hdrCell(_fiscalLabel(y), right: true),
        ],
      ),
    ];
    for (final line in lines) {
      if (line is _FinSection) {
        tableRows.add(
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.lightblue.withValues(alpha: 0.05),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
            ),
            children: [
              _sectionCell(line.title),
              for (final _ in years) const SizedBox.shrink(),
            ],
          ),
        );
      } else if (line is _FinRow) {
        tableRows.add(
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.45),
                ),
              ),
            ),
            children: [
              _bodyLabel(line.label, bold: line.bold, indent: line.indent),
              for (final v in line.values)
                _bodyValue(v, kind: line.kind, bold: line.bold),
            ],
          ),
        );
      }
    }
    // Column widths shrink on narrower viewports so financial tables stay
    // readable on phones / tablets without the user having to scroll every
    // single row to the right. The first column (metric label) keeps a
    // healthy chunk so labels like "Common Stock Equity" don't ellipsise.
    final viewportW = MediaQuery.sizeOf(context).width;
    final double labelW;
    final double yearW;
    if (viewportW < 480) {
      // Phones — tight columns. 5-year table now needs ~140 + 5*88 = 580 px,
      // ~30 % less than the desktop sizing, which means significantly less
      // horizontal scrolling on a 360-px viewport.
      labelW = 140;
      yearW = 88;
    } else if (viewportW < 900) {
      labelW = 180;
      yearW = 108;
    } else {
      labelW = 220;
      yearW = 130;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: viewportW - 80,
        ),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          columnWidths: {
            0: FixedColumnWidth(labelW),
            for (var i = 1; i <= years.length; i++)
              i: FixedColumnWidth(yearW),
          },
          children: tableRows,
        ),
      ),
    );
  }

  /// Indian fiscal year label: yfinance reports the year ending. The Indian
  /// fiscal year is named after the year in which it ENDS — so a row with
  /// date `2026-03-31` is "FY26". We render the full 4-digit year so it
  /// reads cleanly: "FY 2026".
  static String _fiscalLabel(int year) =>
      year > 0 ? 'FY ${year.toString()}' : '—';

  Widget _hdrCell(String text, {bool right = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.grey,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _sectionCell(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: AppColors.lightblue,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _bodyLabel(String text, {bool bold = false, int indent = 0}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12 + indent * 14.0, 10, 10, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          color: AppColors.darkblue.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _bodyValue(double? v, {required _RowKind kind, bool bold = false}) {
    final text = _formatCell(v, kind);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: v == null || v == 0
                ? AppColors.grey.withValues(alpha: 0.65)
                : AppColors.darkblue,
            letterSpacing: -0.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  static String _formatCell(double? v, _RowKind kind) {
    if (v == null) return '—';
    if (v == 0) return '—';
    switch (kind) {
      case _RowKind.crores:
        return _compactRupees(v);
      case _RowKind.perShare:
        return StockFormatters.price(v);
      case _RowKind.percent:
        return StockFormatters.ratioAsPercent(v);
      case _RowKind.shareCount:
        return StockFormatters.compactNumber(v);
      case _RowKind.raw:
        return v.toStringAsFixed(2);
    }
  }

  /// Compact rupee formatter purpose-built for financial tables — keeps the
  /// sign in front of the ₹, uses Indian comma grouping, and auto-switches
  /// between Cr / L / K so the column stays readable across orders of
  /// magnitude.
  ///
  ///   2_67_02_10_00_000  → "₹2,67,021 Cr"
  ///   -170000000000      → "-₹17,000 Cr"
  ///   -2440000000        → "-₹244 Cr"
  static String _compactRupees(double v) {
    if (v == 0) return '—';
    final neg = v < 0;
    final abs = v.abs();
    String body;
    if (abs >= 1e7) {
      body = '₹${_groupIndianInt((abs / 1e7).round())} Cr';
    } else if (abs >= 1e5) {
      body = '₹${(abs / 1e5).toStringAsFixed(2)} L';
    } else if (abs >= 1e3) {
      body = '₹${(abs / 1e3).toStringAsFixed(1)} K';
    } else {
      body = '₹${abs.toStringAsFixed(0)}';
    }
    return neg ? '-$body' : body;
  }

  static String _groupIndianInt(int v) {
    final s = v.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '$buf,$last3';
  }
}

// ── Balance sheet ──────────────────────────────────────────────────────────

class _BalanceSheetTable extends StatelessWidget {
  const _BalanceSheetTable({required this.rows});
  final List<BalanceSheetRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _EmptyFinancials();
    final years = rows.map((r) => r.fiscalYear).toList();

    List<double?> pick(double? Function(BalanceSheetRow) f) =>
        rows.map(f).toList();

    return _FinancialsTable(
      years: years,
      lines: [
        const _FinSection('Assets'),
        _FinRow('Total Assets', pick((r) => r.totalAssets), bold: true),
        _FinRow('Current Assets', pick((r) => r.currentAssets), indent: 1),
        _FinRow('Cash & Cash Equivalents',
            pick((r) => r.cashAndCashEquivalents),
            indent: 2),
        _FinRow('Cash + Short-term Investments',
            pick((r) => r.cashAndShortTermInvestments),
            indent: 2),
        _FinRow('Other Short-term Investments',
            pick((r) => r.otherShortTermInvestments),
            indent: 2),
        _FinRow('Accounts Receivable', pick((r) => r.accountsReceivable),
            indent: 2),
        _FinRow('Other Receivables', pick((r) => r.otherReceivables),
            indent: 2),
        _FinRow('Inventory', pick((r) => r.inventory), indent: 2),
        _FinRow('Prepaid Assets', pick((r) => r.prepaidAssets), indent: 2),
        _FinRow('Total Non-current Assets', pick((r) => r.totalNonCurrentAssets),
            indent: 1),
        _FinRow('Net PPE', pick((r) => r.netPpe), indent: 2),
        _FinRow('Gross PPE', pick((r) => r.grossPpe), indent: 2),
        _FinRow('Accumulated Depreciation',
            pick((r) => r.accumulatedDepreciation),
            indent: 2),
        _FinRow('Goodwill', pick((r) => r.goodwill), indent: 2),
        _FinRow('Other Intangible Assets', pick((r) => r.otherIntangibleAssets),
            indent: 2),
        _FinRow('Goodwill + Intangibles',
            pick((r) => r.goodwillAndIntangibles),
            indent: 2),
        _FinRow('Investments in Financial Assets',
            pick((r) => r.investmentsInFinancialAssets),
            indent: 2),
        const _FinSection('Liabilities'),
        _FinRow('Total Liabilities', pick((r) => r.totalLiabilities),
            bold: true),
        _FinRow('Current Liabilities', pick((r) => r.currentLiabilities),
            indent: 1),
        _FinRow('Accounts Payable', pick((r) => r.accountsPayable), indent: 2),
        _FinRow('Total Tax Payable', pick((r) => r.totalTaxPayable),
            indent: 2),
        _FinRow('Payables', pick((r) => r.payables), indent: 2),
        _FinRow('Current Debt', pick((r) => r.currentDebt), indent: 2),
        _FinRow('Total Non-current Liabilities',
            pick((r) => r.totalNonCurrentLiabilities),
            indent: 1),
        _FinRow('Long-term Debt', pick((r) => r.longTermDebt), indent: 2),
        _FinRow('Total Debt', pick((r) => r.totalDebt), bold: true),
        const _FinSection('Equity & Capital'),
        _FinRow('Stockholders Equity', pick((r) => r.stockholdersEquity),
            bold: true),
        _FinRow('Total Equity (Gross Minority)',
            pick((r) => r.totalEquityGrossMinority),
            indent: 1),
        _FinRow('Minority Interest', pick((r) => r.minorityInterest),
            indent: 1),
        _FinRow('Retained Earnings', pick((r) => r.retainedEarnings),
            indent: 1),
        _FinRow('Additional Paid-in Capital',
            pick((r) => r.additionalPaidInCapital),
            indent: 1),
        _FinRow('Common Stock', pick((r) => r.commonStock), indent: 1),
        const _FinSection('Key Metrics'),
        _FinRow('Working Capital', pick((r) => r.workingCapital)),
        _FinRow('Tangible Book Value', pick((r) => r.tangibleBookValue)),
        _FinRow('Invested Capital', pick((r) => r.investedCapital)),
        _FinRow('Net Tangible Assets', pick((r) => r.netTangibleAssets)),
        _FinRow('Shares Issued', pick((r) => r.shareIssued),
            kind: _RowKind.shareCount),
        _FinRow('Ordinary Shares', pick((r) => r.ordinaryShares),
            kind: _RowKind.shareCount),
      ],
    );
  }
}

// ── Income statement ──────────────────────────────────────────────────────

class _IncomeStatementTable extends StatelessWidget {
  const _IncomeStatementTable({required this.rows});
  final List<IncomeStatementRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _EmptyFinancials();
    final years = rows.map((r) => r.fiscalYear).toList();

    List<double?> pick(double? Function(IncomeStatementRow) f) =>
        rows.map(f).toList();

    return _FinancialsTable(
      years: years,
      lines: [
        const _FinSection('Revenue'),
        _FinRow('Total Revenue', pick((r) => r.totalRevenue), bold: true),
        _FinRow('Operating Revenue', pick((r) => r.operatingRevenue),
            indent: 1),
        _FinRow('Cost of Revenue', pick((r) => r.costOfRevenue), indent: 1),
        _FinRow('Gross Profit', pick((r) => r.grossProfit), bold: true),
        const _FinSection('Operating Costs'),
        _FinRow('Operating Expense', pick((r) => r.operatingExpense),
            bold: true),
        _FinRow('Other Operating Expenses',
            pick((r) => r.otherOperatingExpenses),
            indent: 1),
        _FinRow('Selling, General & Admin',
            pick((r) => r.sellingGeneralAdmin),
            indent: 1),
        _FinRow('Depreciation & Amortization', pick((r) => r.depreciation),
            indent: 1),
        _FinRow('Operating Income', pick((r) => r.operatingIncome), bold: true),
        const _FinSection('Profitability'),
        _FinRow('EBITDA', pick((r) => r.ebitda), bold: true),
        _FinRow('Normalized EBITDA', pick((r) => r.normalizedEbitda),
            indent: 1),
        _FinRow('EBIT', pick((r) => r.ebit), bold: true),
        const _FinSection('Non-operating'),
        _FinRow('Interest Expense', pick((r) => r.interestExpense)),
        _FinRow('Interest Income', pick((r) => r.interestIncome)),
        _FinRow('Net Interest Income', pick((r) => r.netInterestIncome)),
        _FinRow('Other Non-operating Income/Expenses',
            pick((r) => r.otherNonOperatingIncomeExpenses)),
        _FinRow('Special Income Charges', pick((r) => r.specialIncomeCharges)),
        _FinRow('Total Unusual Items', pick((r) => r.totalUnusualItems)),
        const _FinSection('Tax & Net Income'),
        _FinRow('Pretax Income', pick((r) => r.pretaxIncome), bold: true),
        _FinRow('Tax Provision', pick((r) => r.taxProvision), indent: 1),
        _FinRow('Effective Tax Rate', pick((r) => r.taxRate),
            kind: _RowKind.percent, indent: 1),
        _FinRow('Net Income', pick((r) => r.netIncome), bold: true),
        _FinRow('Net Income (Common Stockholders)',
            pick((r) => r.netIncomeCommonStockholders),
            indent: 1),
        _FinRow('Net Income (Continuous Operations)',
            pick((r) => r.netIncomeContinuousOperations),
            indent: 1),
        _FinRow('Normalized Income', pick((r) => r.normalizedIncome),
            indent: 1),
        _FinRow('Minority Interests', pick((r) => r.minorityInterests),
            indent: 1),
        const _FinSection('Per Share'),
        _FinRow('Diluted EPS', pick((r) => r.dilutedEps),
            kind: _RowKind.perShare, bold: true),
        _FinRow('Basic EPS', pick((r) => r.basicEps), kind: _RowKind.perShare),
        _FinRow('Diluted Avg Shares', pick((r) => r.dilutedAverageShares),
            kind: _RowKind.shareCount),
        _FinRow('Basic Avg Shares', pick((r) => r.basicAverageShares),
            kind: _RowKind.shareCount),
        const _FinSection('Totals'),
        _FinRow('Total Expenses', pick((r) => r.totalExpenses)),
      ],
    );
  }
}

// ── Cash flow ─────────────────────────────────────────────────────────────

class _CashFlowTable extends StatelessWidget {
  const _CashFlowTable({required this.rows});
  final List<CashFlowRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _EmptyFinancials();
    final years = rows.map((r) => r.fiscalYear).toList();

    List<double?> pick(double? Function(CashFlowRow) f) => rows.map(f).toList();

    return _FinancialsTable(
      years: years,
      lines: [
        const _FinSection('Operating Activities'),
        _FinRow('Operating Cash Flow', pick((r) => r.operatingCashFlow),
            bold: true),
        _FinRow('Net Income (Continuing Ops)',
            pick((r) => r.netIncomeFromContinuingOps),
            indent: 1),
        _FinRow('Depreciation & Amortization',
            pick((r) => r.depreciationAndAmortization),
            indent: 1),
        _FinRow('Deferred Tax', pick((r) => r.deferredTax), indent: 1),
        _FinRow('Change in Working Capital',
            pick((r) => r.changeInWorkingCapital),
            indent: 1),
        _FinRow('Change in Receivables', pick((r) => r.changeInReceivables),
            indent: 2),
        _FinRow('Change in Payable', pick((r) => r.changeInPayable), indent: 2),
        _FinRow('Change in Inventory', pick((r) => r.changeInInventory),
            indent: 2),
        _FinRow('Taxes Refund / Paid', pick((r) => r.taxesRefundPaid),
            indent: 1),
        const _FinSection('Investing Activities'),
        _FinRow('Investing Cash Flow', pick((r) => r.investingCashFlow),
            bold: true),
        _FinRow('Net Investment Purchase & Sale',
            pick((r) => r.netInvestmentPurchaseAndSale),
            indent: 1),
        _FinRow('Purchase of Investment', pick((r) => r.purchaseOfInvestment),
            indent: 2),
        _FinRow('Sale of Investment', pick((r) => r.saleOfInvestment),
            indent: 2),
        _FinRow('Capital Expenditure', pick((r) => r.capitalExpenditure),
            indent: 1),
        _FinRow('Purchase of PPE', pick((r) => r.purchaseOfPpe), indent: 2),
        _FinRow('Net PPE Purchase & Sale', pick((r) => r.netPpePurchaseAndSale),
            indent: 2),
        _FinRow('Net Business Purchase & Sale',
            pick((r) => r.netBusinessPurchaseAndSale),
            indent: 1),
        _FinRow('Net Intangibles Purchase & Sale',
            pick((r) => r.netIntangiblesPurchaseAndSale),
            indent: 1),
        _FinRow('Interest Received (CFI)', pick((r) => r.interestReceivedCfi),
            indent: 1),
        _FinRow('Dividends Received (CFI)', pick((r) => r.dividendsReceivedCfi),
            indent: 1),
        const _FinSection('Financing Activities'),
        _FinRow('Financing Cash Flow', pick((r) => r.financingCashFlow),
            bold: true),
        _FinRow('Cash Dividends Paid', pick((r) => r.cashDividendsPaid),
            indent: 1),
        _FinRow('Repurchase of Capital Stock',
            pick((r) => r.repurchaseOfCapitalStock),
            indent: 1),
        _FinRow('Issuance of Capital Stock',
            pick((r) => r.issuanceOfCapitalStock),
            indent: 1),
        _FinRow('Net Common Stock Issuance',
            pick((r) => r.netCommonStockIssuance),
            indent: 1),
        _FinRow('Interest Paid (CFF)', pick((r) => r.interestPaidCff),
            indent: 1),
        const _FinSection('Net Cash Position'),
        _FinRow('Free Cash Flow', pick((r) => r.freeCashFlow), bold: true),
        _FinRow('Net Change in Cash', pick((r) => r.netChangeInCash)),
        _FinRow('Effect of Exchange Rate Changes',
            pick((r) => r.effectOfExchangeRateChanges)),
        _FinRow('Beginning Cash Position',
            pick((r) => r.beginningCashPosition)),
        _FinRow('End Cash Position', pick((r) => r.endCashPosition), bold: true),
      ],
    );
  }
}

// —— Shareholding ————————————————————————————————————————————————————————

class _ShareholdingPie extends StatelessWidget {
  const _ShareholdingPie({required this.breakdown});
  final ShareholdingBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    if (b == null) return const _EmptyFinancials();
    // Drop zero-valued slices so the pie + legend only show the buckets
    // the backend actually reported. Until the API splits institutions
    // into FII vs DII we display them under a single "Institutions"
    // label rather than splitting 50/50 with fake numbers.
    final hasFiiDiiSplit =
        b.foreignInstitutions > 0 && b.domesticInstitutions > 0;
    final slices = <_PieSlice>[
      _PieSlice('Promoters', b.promoters, const Color(0xFF3861FB)),
      if (hasFiiDiiSplit) ...[
        _PieSlice('Foreign Inst.', b.foreignInstitutions,
            const Color(0xFF16C784)),
        _PieSlice('Domestic Inst.', b.domesticInstitutions,
            const Color(0xFFF18221)),
      ] else
        _PieSlice(
          'Institutions',
          b.foreignInstitutions + b.domesticInstitutions,
          const Color(0xFF16C784),
        ),
      _PieSlice('Public / Retail', b.publicRetail, const Color(0xFF6D28D9)),
      _PieSlice('Others', b.others, const Color(0xFF58667E)),
    ].where((s) => s.value > 0).toList();
    if (slices.isEmpty) return const _EmptyFinancials();

    return LayoutBuilder(
      builder: (context, c) {
        final stacked = c.maxWidth < 520;
        final chart = SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(painter: _PiePainter(slices: slices)),
        );
        final legend = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in slices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkblue,
                        ),
                      ),
                    ),
                    Text(
                      '${s.value.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkblue,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'As of ${StockFormatters.shortDate(b.asOf)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.grey,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(child: chart),
              const SizedBox(height: 14),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: 24),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _PieSlice {
  const _PieSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.slices});
  final List<_PieSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (acc, s) => acc + s.value);
    if (total <= 0) return;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - 6,
    );
    final innerRect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - 36,
    );
    double start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.value / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = s.color,
      );
      start += sweep;
    }
    canvas.drawArc(
      innerRect,
      0,
      math.pi * 2,
      true,
      Paint()..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.slices != slices;
}

// —— News ————————————————————————————————————————————————————————————————

class _NewsList extends StatefulWidget {
  const _NewsList({required this.news});

  final List<StockNewsItem> news;

  @override
  State<_NewsList> createState() => _NewsListState();
}

class _NewsListState extends State<_NewsList> {
  static const int _previewCount = 10;

  bool _showAll = false;

  @override
  void didUpdateWidget(covariant _NewsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final o = oldWidget.news;
    final n = widget.news;
    if (o.length != n.length ||
        (o.isNotEmpty &&
            n.isNotEmpty &&
            (o.first.headline != n.first.headline || o.first.url != n.first.url))) {
      _showAll = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final news = widget.news;
    if (news.isEmpty) return const _EmptyFinancials();

    final hasOverflow = news.length > _previewCount;
    final visibleCount =
        hasOverflow && !_showAll ? _previewCount : news.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visibleCount; i++) ...[
          _NewsTile(item: news[i]),
          if (i < visibleCount - 1)
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.45),
            ),
        ],
        if (hasOverflow) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.45),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.lightblue,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? 'Show less' : 'More'),
            ),
          ),
        ],
      ],
    );
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({required this.item});

  final StockNewsItem item;

  @override
  Widget build(BuildContext context) {
    final hasLink = item.url != null && item.url!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !hasLink
            ? null
            : () {
                unawaited(openExternalUrl(item.url, context: context));
              },
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.darkblue.withValues(alpha: 0.04),
        splashColor: AppColors.lightblue.withValues(alpha: 0.12),
        mouseCursor:
            hasLink ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 8, right: 12),
                decoration: const BoxDecoration(
                  color: AppColors.lightblue,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.headline,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkblue,
                        height: 1.35,
                      ),
                    ),
                    if (item.summary != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          item.source,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.lightblue.withValues(alpha: 0.9),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.grey,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          StockFormatters.relativeTime(item.publishedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
