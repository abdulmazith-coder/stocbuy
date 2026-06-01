class StockSearchResult {
  const StockSearchResult({
    required this.symbol,
    this.longname,
    this.shortname,
    this.typeDisp,
    this.exchDisp,
    this.exchange,
  });

  final String symbol;
  final String? longname;
  final String? shortname;
  final String? typeDisp;
  final String? exchDisp;
  final String? exchange;

  String get displaySubtitle {
    final n = longname?.trim();
    if (n != null && n.isNotEmpty) return n;
    final s = shortname?.trim();
    if (s != null && s.isNotEmpty) return s;
    return symbol;
  }

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      symbol: json['symbol'] as String? ?? '',
      longname: json['longname'] as String?,
      shortname: json['shortname'] as String?,
      typeDisp: json['typeDisp'] as String?,
      exchDisp: json['exchDisp'] as String?,
      exchange: json['exchange'] as String?,
    );
  }
}
