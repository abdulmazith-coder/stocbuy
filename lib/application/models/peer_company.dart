import 'package:flutter/foundation.dart';

/// One row from `GET features/peers-companies/?stock_symbol=…`.
///
/// The payload uses Indian-broker-style keys (`ltp`, `pChange`, `pat`,
/// `totalIncome`) and includes the queried stock itself as the first row
/// — the UI can either render it as the "self" pivot or filter it out.
@immutable
class PeerCompany {
  const PeerCompany({
    required this.symbol,
    this.series,
    this.marketType,
    this.ltp,
    this.pChange,
    this.pe,
    this.eps,
    this.marketCap,
    this.value,
    this.volume,
    this.pat,
    this.totalIncome,
    this.promoterHolding,
    this.debtEqRatio,
  });

  /// Short ticker — e.g. `TCS`, `INFY`, `WIPRO`.
  final String symbol;

  /// `EQ` for equity series on NSE. Kept for completeness but not rendered.
  final String? series;

  /// `N` for normal market. Same — kept for completeness only.
  final String? marketType;

  /// Last traded price (₹ per share).
  final double? ltp;

  /// Today's percent change (`-3.96` means −3.96%).
  final double? pChange;

  /// Trailing P/E ratio.
  final double? pe;

  /// Trailing earnings per share (₹).
  final double? eps;

  /// Market cap in raw rupees (not crores).
  final num? marketCap;

  /// Total trading value today — `price × volume` summed.
  final num? value;

  /// Shares traded today.
  final num? volume;

  /// Profit-after-tax for the most recent reporting period. The endpoint
  /// reports this in **₹ Lakh** (verified: TCS PAT = 13,78,400 in the
  /// payload ≈ ₹13,784 Cr, matching the published TCS FY24 PAT).
  final num? pat;

  /// Total income for the most recent reporting period — also in ₹ Lakh.
  final num? totalIncome;

  /// Promoter holding percentage (`71.77` means 71.77 %).
  final double? promoterHolding;

  /// Debt-to-equity ratio. Often `null` for IT / services companies.
  final double? debtEqRatio;

  bool get isUp => (pChange ?? 0) > 0;
  bool get isDown => (pChange ?? 0) < 0;

  factory PeerCompany.fromJson(Map<String, dynamic> json) {
    return PeerCompany(
      symbol: _string(json['symbol']) ?? '',
      series: _string(json['series']),
      marketType: _string(json['marketType']),
      ltp: _double(json['ltp']),
      pChange: _double(json['pChange'] ?? json['PChange']),
      pe: _double(json['pe']),
      eps: _double(json['eps']),
      marketCap: _num(json['marketCap']),
      value: _num(json['value']),
      volume: _num(json['volume']),
      pat: _num(json['pat']),
      totalIncome: _num(json['totalIncome']),
      promoterHolding: _double(json['promoterHolding']),
      debtEqRatio: _double(json['debtEqRatio']),
    );
  }

  static String? _string(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  static double? _double(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      final d = v.toDouble();
      return d.isFinite ? d : null;
    }
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      final d = double.tryParse(t);
      return (d != null && d.isFinite) ? d : null;
    }
    return null;
  }

  static num? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      return num.tryParse(t);
    }
    return null;
  }
}
