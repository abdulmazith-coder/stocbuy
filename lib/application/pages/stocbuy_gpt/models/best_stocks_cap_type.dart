/// `cap_type` query param for `features/penny-stock-filter/`.
enum BestStocksCapType {
  growth('growth', 'Growth'),
  penny('penny', 'Penny'),
  mid('mid', 'Mid cap'),
  large('large', 'Large cap');

  const BestStocksCapType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static BestStocksCapType? fromApiValue(String raw) {
    final v = raw.trim().toLowerCase();
    for (final t in BestStocksCapType.values) {
      if (t.apiValue == v) return t;
    }
    return null;
  }
}
