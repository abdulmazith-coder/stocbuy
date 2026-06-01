import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/stock_details_controller.dart';
import 'package:stocbuy_application/application/models/target_price_analysis.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// Card displaying target price analysis with multiple valuation methods.
///
/// Fully responsive across mobile, tablet, and desktop.
/// All text is visible without truncation on any screen size.
class StockTargetPriceCard extends StatelessWidget {
  const StockTargetPriceCard({super.key, required this.controller});

  final StockDetailsController controller;

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
          // ── Header ──────────────────────────────────────────────────────
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
                  Icons.trending_up_rounded,
                  color: AppColors.darkblue.withValues(alpha: 0.85),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Target Price Analysis',
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
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.55),
          ),
          // ── Content ─────────────────────────────────────────────────────
          Obx(() {
            final tpa = controller.targetPrice.value;
            if (controller.isLoadingTargetPrice.value && tpa == null) {
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
            if (tpa == null) {
              return _EmptyTargetPrice(
                unavailable: controller.targetPriceUnavailable.value,
              );
            }
            return _TargetPriceTable(analysis: tpa, mobile: mobile);
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTargetPrice extends StatelessWidget {
  const _EmptyTargetPrice({this.unavailable = false});

  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          unavailable
              ? "Target price analysis isn't available right now."
              : 'Data will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.grey.withValues(alpha: 0.9),
            letterSpacing: -0.15,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Signal helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _signalFg(String rec) {
  switch (rec.toUpperCase()) {
    case 'BUY':
      return const Color(0xFF0F6E56);
    case 'SELL':
      return const Color(0xFFA32D2D);
    default:
      return const Color(0xFF854F0B);
  }
}

Color _signalBg(String rec) {
  switch (rec.toUpperCase()) {
    case 'BUY':
      return const Color(0xFFE1F5EE);
    case 'SELL':
      return const Color(0xFFFCEBEB);
    default:
      return const Color(0xFFFAEEDA);
  }
}

String _signalLabel(String rec) {
  switch (rec.toUpperCase()) {
    case 'BUY':
      return 'BUY';
    case 'SELL':
      return 'SELL';
    default:
      return 'HOLD';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TargetPriceTable
//
// Strategy: fixed minimum column widths + horizontal scroll.
//  • On wide screens (tablet/desktop) the table fills the card naturally.
//  • On narrow screens (mobile) the user can scroll horizontally — all text
//    stays on one line and is fully readable, nothing ever wraps or truncates.
//  • Column min-widths are sized to fit the longest realistic content.
// ─────────────────────────────────────────────────────────────────────────────

class _TargetPriceTable extends StatelessWidget {
  const _TargetPriceTable({
    required this.analysis,
    required this.mobile,
  });

  final TargetPriceAnalysis analysis;
  final bool mobile;

  String _formatUpside(double v) {
    final sign = v >= 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(2)}%';
  }

  Color _upsideColor(double v) => v >= 0 ? AppColors.green : AppColors.red;

  @override
  Widget build(BuildContext context) {
    const dotColors = [
      Color(0xFF378ADD), // P/E  – blue
      Color(0xFF1D9E75), // P/B  – teal
      Color(0xFFBA7517), // EV   – amber
    ];

    final methods = [
      (
        dot: dotColors[0],
        name: analysis.peMethod.name,
        target: analysis.peMethod.targetPrice,
        upside: analysis.peMethod.upsidePercent,
        rec: analysis.peMethod.recommendation,
      ),
      (
        dot: dotColors[1],
        name: analysis.pbMethod.name,
        target: analysis.pbMethod.targetPrice,
        upside: analysis.pbMethod.upsidePercent,
        rec: analysis.pbMethod.recommendation,
      ),
      (
        dot: dotColors[2],
        name: analysis.evEbitdaMethod.name,
        target: analysis.evEbitdaMethod.targetPrice,
        upside: analysis.evEbitdaMethod.upsidePercent,
        rec: analysis.evEbitdaMethod.recommendation,
      ),
    ];

    // ── Column widths ────────────────────────────────────────────────────
    // Fixed widths sized for worst-case content so nothing ever wraps:
    //   Method : "Consensus (Avg)"  → 150px
    //   Target : "₹99999.99"        → 105px
    //   Upside : "+99.99%"          → 85px
    //   Signal : "SIGNAL" header    → 72px  (header text + letterSpacing)
    // Total = 412px.  Card on a 360px phone ≈ 328px usable → scrolls ~84px.
    // On ≥ 412px screens Method expands to fill all extra space.
    const double minMethodW = 150;
    const double minTargetW = 105;
    const double minUpsideW = 85;
    const double minSignalW = 72;
    const double minTotalW = minMethodW + minTargetW + minUpsideW + minSignalW;

    return LayoutBuilder(
      builder: (context, constraints) {
        // constraints.maxWidth == full card inner width (no extra padding here)
        final availableW = constraints.maxWidth;

        final double methodW = availableW > minTotalW
            ? availableW - minTargetW - minUpsideW - minSignalW
            : minMethodW;
        const double targetW = minTargetW;
        const double upsideW = minUpsideW;
        const double signalW = minSignalW;


        final colWidths = <int, TableColumnWidth>{
          0: FixedColumnWidth(methodW),
          1: FixedColumnWidth(targetW),
          2: FixedColumnWidth(upsideW),
          3: FixedColumnWidth(signalW),
        };

        final rows = <TableRow>[
          // ── Column header ──────────────────────────────────────────────
          _buildHeaderRow(mobile),

          // ── Disclaimer ─────────────────────────────────────────────────
          _buildDisclaimerRow(mobile),

          // ── Valuation method rows ───────────────────────────────────────
          for (final m in methods)
            _buildDataRow(
              dot: m.dot,
              methodName: m.name,
              target: '₹${m.target.toStringAsFixed(2)}',
              upside: _formatUpside(m.upside),
              upsideColor: _upsideColor(m.upside),
              rec: m.rec,
              mobile: mobile,
              isLast: false,
              isEmphasis: false,
            ),

          // ── Consensus row ───────────────────────────────────────────────
          _buildSummaryRow(
            methodName: 'Consensus (Avg)',
            target:
                '₹${analysis.consensus.targetPrice.toStringAsFixed(2)}',
            upside: _formatUpside(analysis.consensus.upsidePercent),
            upsideColor: _upsideColor(analysis.consensus.upsidePercent),
            rec: analysis.consensus.recommendation,
            mobile: mobile,
            isEmphasis: true,
          ),

          // ── Analyst Target row ──────────────────────────────────────────
          _buildSummaryRow(
            methodName: 'Analyst Target',
            target:
                '₹${analysis.analystTarget.targetPrice.toStringAsFixed(2)}',
            upside: _formatUpside(analysis.analystTarget.upsidePercent),
            upsideColor: _upsideColor(analysis.analystTarget.upsidePercent),
            rec: analysis.analystTarget.recommendation,
            mobile: mobile,
            isEmphasis: true,
            isLast: true,
          ),
        ];

        // Horizontal scroll: on narrow screens table scrolls smoothly;
        // on wide screens it fills naturally with no scrollbar shown.
        final tableWidth = methodW + targetW + upsideW + signalW;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          // Ensure scrollable content is at least as wide as the card so
          // background decorations (row colours) always fill edge-to-edge.
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: availableW),
            child: SizedBox(
              width: tableWidth < availableW ? availableW : tableWidth,
              child: Table(
                columnWidths: colWidths,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: rows,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header row ────────────────────────────────────────────────────────────

  TableRow _buildHeaderRow(bool mobile) {
    return TableRow(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.7),
          ),
        ),
      ),
      children: [
        _headerCell('METHOD', align: TextAlign.left),
        _headerCell('TARGET', align: TextAlign.right),
        _headerCell('UPSIDE', align: TextAlign.right),
        _headerCell('SIGNAL', align: TextAlign.center),
      ],
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      child: Text(
        text,
        textAlign: align,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.grey,
          // No letterSpacing — keeps header text compact so SIGNAL fits in 72px
        ),
      ),
    );
  }

  // ── Disclaimer row ────────────────────────────────────────────────────────

  TableRow _buildDisclaimerRow(bool mobile) {
    return TableRow(
      decoration: BoxDecoration(
        color: AppColors.lightblue.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: Color(0xFF888780),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Estimates only — not financial advice',
                  style: TextStyle(
                    fontSize: mobile ? 10 : 10.5,
                    color: const Color(0xFF888780),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Empty cells spanning the other 3 columns (merged visually)
        const SizedBox.shrink(),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
      ],
    );
  }

  // ── Valuation method data row ─────────────────────────────────────────────

  TableRow _buildDataRow({
    required Color dot,
    required String methodName,
    required String target,
    required String upside,
    required Color upsideColor,
    required String rec,
    required bool mobile,
    bool isLast = false,
    bool isEmphasis = false,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: isLast ? 0.0 : 0.45),
          ),
        ),
      ),
      children: [
        // Method name + coloured dot
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 7, top: 1),
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                ),
              ),
              Flexible(
                child: Text(
                  methodName,
                  // Allow 2 lines on very narrow screens so nothing truncates
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mobile ? 12 : 13,
                    fontWeight: isEmphasis
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: AppColors.darkblue,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Target price
        _numericCell(
          text: target,
          mobile: mobile,
          bold: isEmphasis,
        ),
        // Upside %
        _numericCell(
          text: upside,
          mobile: mobile,
          color: upsideColor,
          bold: isEmphasis,
        ),
        // Signal badge
        _signalCell(rec, mobile, emphasis: isEmphasis),
      ],
    );
  }

  // ── Summary rows (Consensus / Analyst Target) ─────────────────────────────

  TableRow _buildSummaryRow({
    required String methodName,
    required String target,
    required String upside,
    required Color upsideColor,
    required String rec,
    required bool mobile,
    bool isEmphasis = true,
    bool isLast = false,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        color: AppColors.lightWhite,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: isLast ? 0.0 : 0.45),
          ),
        ),
      ),
      children: [
        // Method name with snowflake icon (matching original design)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.hub_outlined,
                size: 14,
                color: AppColors.grey.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  methodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mobile ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkblue,
                  ),
                ),
              ),
            ],
          ),
        ),
        _numericCell(text: target, mobile: mobile, bold: true),
        _numericCell(
          text: upside,
          mobile: mobile,
          color: upsideColor,
          bold: true,
        ),
        _signalCell(rec, mobile, emphasis: true),
      ],
    );
  }

  // ── Shared cell builders ──────────────────────────────────────────────────

  Widget _numericCell({
    required String text,
    required bool mobile,
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      child: Text(
        text,
        textAlign: TextAlign.right,
        // Numbers are short — 1 line is always fine, but allow 2 as fallback
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: mobile ? 12 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: color ?? AppColors.darkblue,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _signalCell(
    String recommendation,
    bool mobile, {
    bool emphasis = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            color: _signalBg(recommendation),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _signalLabel(recommendation),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: mobile ? 10 : 10.5,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
              color: _signalFg(recommendation),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}