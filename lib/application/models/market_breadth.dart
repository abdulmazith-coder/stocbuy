/// Market breadth data structure
class MarketBreadth {
  const MarketBreadth({
    required this.timestamp,
    required this.indexName,
    required this.totalStocks,
    required this.advancers,
    required this.decliners,
    required this.unchanged,
    required this.breadthScore,
    required this.breadthRatio,
    required this.sentiment,
    required this.marketStatus,
    required this.stocks,
    required this.fetchedAt,
  });

  final DateTime timestamp;
  final String indexName;
  final int totalStocks;
  final int advancers;
  final int decliners;
  final int unchanged;
  final double breadthScore;
  final double breadthRatio;
  final String sentiment; // POSITIVE, NEGATIVE, NEUTRAL
  final String marketStatus;
  final List<BreadthStock> stocks;
  final DateTime fetchedAt;

  /// Calculate advance percentage (advancers / total)
  double get advancePercent => totalStocks > 0 ? advancers / totalStocks : 0;

  /// Calculate decline percentage (decliners / total)
  double get declinePercent => totalStocks > 0 ? decliners / totalStocks : 0;

  /// Get sentiment color indicator
  bool get isPositive => sentiment == 'POSITIVE' || advancers > decliners;
  bool get isNegative => sentiment == 'NEGATIVE' || decliners > advancers;

  /// Formatted breadth ratio string
  String get formattedBreadthRatio => breadthRatio.toStringAsFixed(2);

  /// Formatted advance percentage string
  String get formattedAdvancePercent =>
      (advancePercent * 100).toStringAsFixed(2);

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'indexName': indexName,
      'totalStocks': totalStocks,
      'advancers': advancers,
      'decliners': decliners,
      'unchanged': unchanged,
      'breadthScore': breadthScore,
      'breadthRatio': breadthRatio,
      'sentiment': sentiment,
      'marketStatus': marketStatus,
      'stocks': stocks.map((s) => s.toJson()).toList(),
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    };
  }

  static MarketBreadth? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    try {
      final timestamp = DateTime.tryParse(json['timestamp'] ?? '')?.toLocal();
      final fetchedAt =
          DateTime.tryParse(json['fetchedAt'] ?? '')?.toLocal() ??
          DateTime.now();

      if (timestamp == null) return null;

      final stocks = <BreadthStock>[];
      if (json['stocks'] is List) {
        for (final item in json['stocks']) {
          if (item is Map<String, dynamic>) {
            final stock = BreadthStock.fromJson(item);
            if (stock != null) stocks.add(stock);
          }
        }
      }

      // Handle both snake_case (from API) and camelCase (from local storage)
      return MarketBreadth(
        timestamp: timestamp,
        indexName: json['indexName'] ?? json['index_name'] ?? 'NIFTY 50',
        totalStocks: json['totalStocks'] ?? json['total_stocks'] ?? 0,
        advancers: json['advancers'] ?? 0,
        decliners: json['decliners'] ?? 0,
        unchanged: json['unchanged'] ?? 0,
        breadthScore:
            parseDouble(json['breadthScore'] ?? json['breadth_score']) ?? 0,
        breadthRatio:
            parseDouble(json['breadthRatio'] ?? json['breadth_ratio']) ?? 0,
        sentiment: json['sentiment'] ?? 'NEUTRAL',
        marketStatus:
            json['marketStatus'] ?? json['market_status'] ?? 'NEUTRAL',
        stocks: stocks,
        fetchedAt: fetchedAt,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Individual stock in market breadth data
class BreadthStock {
  const BreadthStock({
    required this.symbol,
    required this.prevClose,
    required this.currentClose,
    required this.change,
    required this.changePct,
    required this.status,
  });

  final String symbol;
  final double prevClose;
  final double currentClose;
  final double change;
  final double changePct;
  final String status; // UP, DOWN, UNCHANGED

  bool get isUp => status == 'UP';
  bool get isDown => status == 'DOWN';

  String get formattedChange => change.toStringAsFixed(2);
  String get formattedChangePct => changePct.toStringAsFixed(2);

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'prevClose': prevClose,
      'currentClose': currentClose,
      'change': change,
      'changePct': changePct,
      'status': status,
    };
  }

  static BreadthStock? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final prevClose = parseDouble(json['prev_close'] ?? json['prevClose']);
    final currentClose = parseDouble(
      json['current_close'] ?? json['currentClose'],
    );
    final change = parseDouble(json['change']);
    final changePct = parseDouble(json['change_pct'] ?? json['changePct']);

    if (prevClose == null || currentClose == null) return null;

    return BreadthStock(
      symbol: json['symbol'] ?? '',
      prevClose: prevClose,
      currentClose: currentClose,
      change: change ?? 0,
      changePct: changePct ?? 0,
      status: json['status'] ?? 'UNCHANGED',
    );
  }
}

/// Helper function to parse double values
double? parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
