/// Shared number / currency formatters used across the Stock Details page.
class StockFormatters {
  const StockFormatters._();

  /// Format an INR price as `₹ 1,234.56` with comma grouping (Indian style).
  static String price(double? value, {String currency = '₹'}) {
    if (value == null) return '—';
    final fixed = value.toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    final intPart = fixed.substring(0, dot);
    final dec = fixed.substring(dot + 1);
    return '$currency${_groupIndian(intPart)}.$dec';
  }

  /// Format a percent value (already in percent units, e.g. 5.95 → "+5.95%").
  static String percent(double? value, {int fractionDigits = 2}) {
    if (value == null) return '—';
    if (value == 0) return '0.00%';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(fractionDigits)}%';
  }

  /// Indian-style large-money compaction:
  /// 1_25_00_00_000 → "₹125.00 Cr"
  static String compactRupees(num? value) {
    if (value == null || value == 0) return '—';
    final v = value.toDouble();
    final abs = v.abs();
    if (abs >= 1e7) {
      return '₹${(v / 1e7).toStringAsFixed(2)} Cr';
    }
    if (abs >= 1e5) {
      return '₹${(v / 1e5).toStringAsFixed(2)} L';
    }
    if (abs >= 1e3) {
      return '₹${(v / 1e3).toStringAsFixed(1)}K';
    }
    return '₹${v.toStringAsFixed(0)}';
  }

  /// Compact volume label, e.g. 12_409_803 → "12.4M".
  static String compactNumber(num? value) {
    if (value == null) return '—';
    final v = value.toDouble();
    final abs = v.abs();
    if (abs >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (abs >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (abs >= 1e3) return '${(v / 1e3).toStringAsFixed(2)}K';
    return v.toStringAsFixed(0);
  }

  /// A multiplier (e.g. P/E) — `null` → "—", else two decimals.
  static String multiplier(double? value, {String suffix = ''}) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(2)}$suffix';
  }

  /// Ratio expressed as 0..1 (e.g. ROE = 0.18) → "18.00%".
  static String ratioAsPercent(double? value, {int fractionDigits = 2}) {
    if (value == null) return '—';
    return '${(value * 100).toStringAsFixed(fractionDigits)}%';
  }

  /// Plain INR Crores label for fundamentals tables: 14_523 → "₹14,523 Cr".
  static String crores(double? value) {
    if (value == null) return '—';
    final whole = value.round().toString();
    return '₹${_groupIndian(whole)} Cr';
  }

  /// Short timestamp like "11 May 2026" → for news / shareholding date.
  static String shortDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  /// 24-hour clock: "10:32".
  static String hhmm(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// "5 hours ago" / "Just now" / "Yesterday" — small fuzzy formatter for news.
  static String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate(dt);
  }

  /// Indian grouping (lakh / crore): 1234567 → 12,34,567.
  static String _groupIndian(String intStr) {
    final neg = intStr.startsWith('-');
    final s = neg ? intStr.substring(1) : intStr;
    if (s.length <= 3) return neg ? '-$s' : s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    // Group `rest` in 2-digit chunks from the right.
    for (var i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '${neg ? '-' : ''}$buf,$last3';
  }
}
