class IndexRsi {
  const IndexRsi({
    required this.symbol,
    required this.close,
    required this.rsi,
    required this.previousRsi,
    required this.rsiChange,
    required this.signal,
    required this.marketTrend,
    required this.fetchedAt,
  });

  final String symbol;
  final double close;
  final double rsi;
  final double previousRsi;
  final double rsiChange;
  final String signal;
  final String marketTrend;
  final DateTime fetchedAt;

  String get formattedRsi => rsi.toStringAsFixed(2);

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'close': close,
      'rsi': rsi,
      'previous_rsi': previousRsi,
      'rsi_change': rsiChange,
      'signal': signal,
      'market_trend': marketTrend,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    };
  }

  static IndexRsi? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final symbol = json['symbol']?.toString() ?? '';
    final close = parseDouble(json['close']);
    final rsi = parseDouble(json['rsi']);
    final previousRsi = parseDouble(
      json['previous_rsi'] ?? json['previousRsi'],
    );
    final rsiChange = parseDouble(json['rsi_change'] ?? json['rsiChange']);
    final signal = json['signal']?.toString() ?? '';
    final marketTrend =
        json['market_trend']?.toString() ??
        json['marketTrend']?.toString() ??
        '';
    final fetchedAt =
        DateTime.tryParse('${json['fetchedAt']}')?.toUtc() ??
        DateTime.now().toUtc();

    if (close == null ||
        rsi == null ||
        previousRsi == null ||
        rsiChange == null) {
      return null;
    }

    return IndexRsi(
      symbol: symbol,
      close: close,
      rsi: rsi,
      previousRsi: previousRsi,
      rsiChange: rsiChange,
      signal: signal,
      marketTrend: marketTrend,
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
