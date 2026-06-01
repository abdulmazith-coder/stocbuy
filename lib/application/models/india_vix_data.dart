class IndiaVixData {
  const IndiaVixData({
    required this.vix,
    this.vixChangePercent,
    this.niftyChangePercent,
    this.sentiment,
    this.marketCondition,
    this.riskLevel,
    this.sentimentScore,
    this.panicSelling,
    required this.fetchedAt,
  });

  final double vix;
  final double? vixChangePercent;
  final double? niftyChangePercent;
  final String? sentiment;
  final String? marketCondition;
  final String? riskLevel;
  final double? sentimentScore;
  final bool? panicSelling;
  final DateTime fetchedAt;

  String get formattedVix => vix.toStringAsFixed(2);

  String get formattedVixChange {
    if (vixChangePercent == null) return '-';
    final sign = vixChangePercent! >= 0 ? '+' : '';
    return '$sign${vixChangePercent!.toStringAsFixed(2)}%';
  }

  String get formattedNiftyChange {
    if (niftyChangePercent == null) return '-';
    final sign = niftyChangePercent! >= 0 ? '+' : '';
    return '$sign${niftyChangePercent!.toStringAsFixed(2)}%';
  }

  Map<String, dynamic> toJson() {
    return {
      'India_VIX': vix,
      if (vixChangePercent != null) 'VIX_Change_%': vixChangePercent,
      if (niftyChangePercent != null) 'NIFTY_Change_%': niftyChangePercent,
      if (sentiment != null) 'Sentiment': sentiment,
      if (marketCondition != null) 'Market_Condition': marketCondition,
      if (riskLevel != null) 'Risk_Level': riskLevel,
      if (sentimentScore != null) 'Sentiment_Score': sentimentScore,
      if (panicSelling != null) 'Panic_Selling': panicSelling,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    };
  }

  static IndiaVixData? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final vix = parseDouble(
      json['India_VIX'] ??
          json['India VIX'] ??
          json['india_vix'] ??
          json['india_vix'],
    );
    if (vix == null) return null;

    final fetchedAt =
        DateTime.tryParse('${json['fetchedAt']}')?.toUtc() ??
        DateTime.now().toUtc();

    return IndiaVixData(
      vix: vix,
      vixChangePercent: parseDouble(
        json['VIX_Change_%'] ?? json['VIX Change %'],
      ),
      niftyChangePercent: parseDouble(
        json['NIFTY_Change_%'] ?? json['NIFTY Change %'],
      ),
      sentiment: json['Sentiment']?.toString(),
      marketCondition: json['Market_Condition']?.toString(),
      riskLevel: json['Risk_Level']?.toString(),
      sentimentScore: parseDouble(json['Sentiment_Score']),
      panicSelling: json['Panic_Selling'] is bool
          ? json['Panic_Selling'] as bool
          : (json['Panic_Selling']?.toString().toLowerCase() == 'true'),
      fetchedAt: fetchedAt,
    );
  }

  static double? parseDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final cleaned = raw.replaceAll(',', '').trim();
      return double.tryParse(cleaned);
    }
    return null;
  }
}
