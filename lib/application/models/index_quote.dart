/// A lightweight snapshot of an index quote.
class IndexQuote {
  const IndexQuote({
    required this.price,
    this.change,
    this.changePercent,
    this.changeLabel,
    required this.fetchedAt,
  });

  final double price;
  final double? change;
  final double? changePercent;
  final String? changeLabel;
  final DateTime fetchedAt;

  bool get isUp => (change ?? changePercent ?? 0) >= 0;

  String get formattedPrice => price.toStringAsFixed(2);

  String get formattedChangeLabel {
    if (changeLabel != null && changeLabel!.isNotEmpty) {
      return changeLabel!;
    }
    if (changePercent != null) {
      final sign = changePercent! >= 0 ? '+' : '';
      return '$sign${changePercent!.toStringAsFixed(2)}%';
    }
    if (change != null) {
      final sign = change! >= 0 ? '+' : '';
      return '$sign${change!.toStringAsFixed(2)}';
    }
    return '-';
  }

  Map<String, dynamic> toJson() {
    return {
      'price': price,
      if (change != null) 'change': change,
      if (changePercent != null) 'changePercent': changePercent,
      if (changeLabel != null) 'changeLabel': changeLabel,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    };
  }

  static IndexQuote? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final price = parseDouble(json['price']);
    if (price == null) return null;
    final fetchedAt =
        DateTime.tryParse('${json['fetchedAt']}')?.toUtc() ??
        DateTime.now().toUtc();
    return IndexQuote(
      price: price,
      change: parseDouble(json['change']),
      changePercent: parseDouble(json['changePercent']),
      changeLabel: json['changeLabel']?.toString(),
      fetchedAt: fetchedAt,
    );
  }

  IndexQuote copyWith({
    double? price,
    double? change,
    double? changePercent,
    String? changeLabel,
    DateTime? fetchedAt,
  }) {
    return IndexQuote(
      price: price ?? this.price,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      changeLabel: changeLabel ?? this.changeLabel,
      fetchedAt: fetchedAt ?? this.fetchedAt,
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
