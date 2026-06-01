import 'package:flutter/foundation.dart';

/// Target price analysis data from the backend.
///
/// Contains fundamentals, multiple valuation methods, consensus, and analyst target.
@immutable
class TargetPriceAnalysis {
  const TargetPriceAnalysis({
    required this.companyName,
    required this.ticker,
    required this.currentPrice,
    required this.peMethod,
    required this.pbMethod,
    required this.evEbitdaMethod,
    required this.consensus,
    required this.analystTarget,
  });

  final String companyName;
  final String ticker;
  final double currentPrice;
  final ValuationMethod peMethod;
  final ValuationMethod pbMethod;
  final ValuationMethod evEbitdaMethod;
  final ConsensusData consensus;
  final ConsensusData analystTarget;

  factory TargetPriceAnalysis.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final fundamentals = data['fundamentals'] as Map<String, dynamic>? ?? {};
    final methods = data['methods'] as Map<String, dynamic>? ?? {};
    final consensus = data['consensus'] as Map<String, dynamic>? ?? {};
    final analystTarget = data['analyst_target'] as Map<String, dynamic>? ?? {};

    return TargetPriceAnalysis(
      companyName: fundamentals['company_name'] as String? ?? 'Unknown',
      ticker: fundamentals['ticker'] as String? ?? '',
      currentPrice: _toDouble(fundamentals['current_price']),
      peMethod: ValuationMethod.fromJson(
        (methods['pe_method'] as Map<String, dynamic>?) ?? {},
        'P/E Valuation',
      ),
      pbMethod: ValuationMethod.fromJson(
        (methods['pb_method'] as Map<String, dynamic>?) ?? {},
        'P/B Valuation',
      ),
      evEbitdaMethod: ValuationMethod.fromJson(
        (methods['ev_ebitda_method'] as Map<String, dynamic>?) ?? {},
        'EV/EBITDA',
      ),
      consensus: ConsensusData.fromJson(consensus, 'Consensus'),
      analystTarget: ConsensusData.fromJson(analystTarget, 'Analyst Target'),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Single valuation method result.
@immutable
class ValuationMethod {
  const ValuationMethod({
    required this.name,
    required this.targetPrice,
    required this.upsidePercent,
    required this.recommendation,
    required this.formula,
  });

  final String name;
  final double targetPrice;
  final double upsidePercent;
  final String recommendation;
  final String formula;

  factory ValuationMethod.fromJson(
    Map<String, dynamic> json,
    String methodName,
  ) {
    return ValuationMethod(
      name: methodName,
      targetPrice: _toDouble(json['target_price']),
      upsidePercent: _toDouble(json['upside_pct']),
      recommendation: json['recommendation'] as String? ?? 'HOLD',
      formula: json['formula'] as String? ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Consensus or analyst target data.
@immutable
class ConsensusData {
  const ConsensusData({
    required this.name,
    required this.targetPrice,
    required this.upsidePercent,
    required this.recommendation,
  });

  final String name;
  final double targetPrice;
  final double upsidePercent;
  final String recommendation;

  factory ConsensusData.fromJson(Map<String, dynamic> json, String dataName) {
    return ConsensusData(
      name: dataName,
      targetPrice: _toDouble(
        json['target_price'] ?? json['average_target_price'],
      ),
      upsidePercent: _toDouble(json['upside_pct']),
      recommendation: json['recommendation'] as String? ?? 'HOLD',
    );
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
