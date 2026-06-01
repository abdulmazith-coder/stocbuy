import 'package:flutter/foundation.dart';

/// Single OHLC candle.
@immutable
class StockOhlc {
  const StockOhlc({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final num volume;

  bool get isBullish => close >= open;

  /// Bar colour for charts — completed bars use open→close; the live (last)
  /// bar uses close vs the previous bar's close (TradingView / NSE style).
  static bool isUpBar(List<StockOhlc> series, int index) {
    if (index < 0 || index >= series.length) return true;
    final c = series[index];
    if (index == 0) return c.close >= c.open;
    if (index == series.length - 1) {
      return c.close >= series[index - 1].close;
    }
    return c.close >= c.open;
  }

  StockOhlc copyWith({
    double? open,
    double? high,
    double? low,
    double? close,
    num? volume,
  }) {
    return StockOhlc(
      time: time,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
    );
  }

  /// Parse a single row of the `history-price` / `1m-price-history`
  /// `data` array.
  ///
  /// The backend returns capitalised yfinance-style keys:
  /// ```json
  /// {
  ///   "Datetime": "2026-05-12 09:15:00",
  ///   "Open": 2368.30, "High": 2368.30, "Low": 2338.10, "Close": 2341.80,
  ///   "Volume": 0
  /// }
  /// ```
  /// Lowercase keys (`datetime`, `open`, …) are also tolerated for forward
  /// compatibility.
  static StockOhlc? tryFromJson(Map<String, dynamic> json) {
    final timeRaw =
        json['Datetime'] ?? json['datetime'] ?? json['Date'] ?? json['date'];
    final t = _parseDate(timeRaw);
    if (t == null) return null;
    return StockOhlc(
      time: t,
      open: _double(json['Open'] ?? json['open']) ?? 0,
      high: _double(json['High'] ?? json['high']) ?? 0,
      low: _double(json['Low'] ?? json['low']) ?? 0,
      close: _double(json['Close'] ?? json['close']) ?? 0,
      volume: _num(json['Volume'] ?? json['volume']) ?? 0,
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
//   Chart timeframe model
//
//   The backend supports three endpoint modes for OHLC candles:
//
//     A. GET features/history-price/?stock_symbol=…&timing=<interval>&istread=true
//        Quick-read mode. `timing` is the *candle size* (interval); the
//        backend chooses a sensible recent range. Allowed `timing` values:
//          2m, 5m, 15m, 30m, 60m, 90m, 1h, 1d, 5d, 1wk, 1mo, 3mo
//
//     B. GET features/history-price/?stock_symbol=…&timing=<range>
//                                    &interval=<interval>&istread=false
//        Custom-range mode. `timing` is the *lookback range* and `interval`
//        is the candle size — both required. Allowed:
//          timing   ∈ 1d, 5d, 1mo, 3mo, 6mo, 1y, 2y, 5y, 10y, ytd, max
//          interval ∈ 1m, 2m, 5m, 15m, 30m, 60m, 90m, 1h, 1d, 5d, 1wk, 1mo, 3mo
//
//     C. GET features/1m-price-history/?stock_symbol=…
//        Dedicated endpoint for 1-minute live intraday candles. The only
//        way to fetch 1m data — Mode A's allowed `timing` list excludes 1m.
//
//   A [ChartSelection] encodes the user's pick on the toolbar and resolves
//   to exactly one of these three modes. The controller threads it through
//   to the Dio service so the right URL is hit and the cache key is stable
//   across re-selections.
// ───────────────────────────────────────────────────────────────────────────

/// Candle size (granularity). Every value matches an `interval` token the
/// backend understands, *plus* one extra token (`m1` → `1m`) which is only
/// valid via the dedicated `/features/1m-price-history/` endpoint.
enum ChartInterval {
  m1('1m', '1m'),
  m2('2m', '2m'),
  m5('5m', '5m'),
  m15('15m', '15m'),
  m30('30m', '30m'),
  m60('60m', '60m'),
  m90('90m', '90m'),
  h1('1h', '1h'),
  d1('1d', '1D'),
  d5('5d', '5D'),
  wk1('1wk', '1W'),
  mo1('1mo', '1M'),
  mo3('3mo', '3M');

  const ChartInterval(this.code, this.label);

  /// Value sent to the backend on the wire.
  final String code;

  /// Short label rendered on the toolbar pill.
  final String label;

  /// Sub-day candle sizes refresh on the 1-minute poller; day+ sizes don't
  /// move within a minute so we save the round-trip.
  bool get isIntraday => switch (this) {
        m1 || m2 || m5 || m15 || m30 || m60 || m90 || h1 => true,
        _ => false,
      };

  /// True if this interval can be used in Mode A (quick-read). 1m is the
  /// only exception — it must go through Mode C.
  bool get supportsQuickRead => this != ChartInterval.m1;

  /// Approximate spacing between candles — used by the renderer to pick
  /// crosshair / axis-label granularity. Not the true count returned by
  /// the API (that comes from the response itself).
  Duration get step => switch (this) {
        m1 => const Duration(minutes: 1),
        m2 => const Duration(minutes: 2),
        m5 => const Duration(minutes: 5),
        m15 => const Duration(minutes: 15),
        m30 => const Duration(minutes: 30),
        m60 || h1 => const Duration(hours: 1),
        m90 => const Duration(minutes: 90),
        d1 => const Duration(days: 1),
        d5 => const Duration(days: 5),
        wk1 => const Duration(days: 7),
        mo1 => const Duration(days: 30),
        mo3 => const Duration(days: 90),
      };
}

/// Lookback range (Mode B only). Always paired with a [ChartInterval]
/// when sent on the wire.
enum ChartRange {
  d1('1d', '1D'),
  d5('5d', '5D'),
  mo1('1mo', '1M'),
  mo3('3mo', '3M'),
  mo6('6mo', '6M'),
  ytd('ytd', 'YTD'),
  y1('1y', '1Y'),
  y2('2y', '2Y'),
  y5('5y', '5Y'),
  y10('10y', '10Y'),
  max('max', 'MAX');

  const ChartRange(this.code, this.label);

  final String code;
  final String label;
}

/// One of three endpoint modes the user can be looking at. Built from
/// `(interval, range?)` by [ChartSelection.resolve].
@immutable
sealed class ChartSelection {
  const ChartSelection();

  /// Pick the right mode from an interval + optional range. The toolbar's
  /// reactive `(interval, range?)` pair feeds straight into this.
  factory ChartSelection.resolve({
    required ChartInterval interval,
    ChartRange? range,
  }) {
    if (range != null) {
      return ChartSelectionRangeInterval(range: range, interval: interval);
    }
    if (interval == ChartInterval.m1) {
      return const ChartSelectionOneMinuteLive();
    }
    return ChartSelectionQuickInterval(interval);
  }

  /// Stable identity used for cache lookup / chart key. Two selections that
  /// hit the same URL produce the same key.
  String get cacheKey;

  /// Short label rendered into the chart header (`TCS · 1D · NSE`).
  String get label;

  /// Which interval should the renderer use to pick its axis granularity?
  ChartInterval get effectiveInterval;

  /// `true` when this selection is fresh enough to be worth polling every
  /// minute during market hours.
  bool get isIntraday => effectiveInterval.isIntraday;
}

/// Mode A — `/features/history-price/?timing=<interval>&istread=true`.
class ChartSelectionQuickInterval extends ChartSelection {
  const ChartSelectionQuickInterval(this.interval);

  final ChartInterval interval;

  @override
  String get cacheKey => 'quick:${interval.code}';

  @override
  String get label => interval.label;

  @override
  ChartInterval get effectiveInterval => interval;
}

/// Mode B — `/features/history-price/?timing=<range>&interval=<interval>
/// &istread=false`.
class ChartSelectionRangeInterval extends ChartSelection {
  const ChartSelectionRangeInterval({
    required this.range,
    required this.interval,
  });

  final ChartRange range;
  final ChartInterval interval;

  @override
  String get cacheKey => 'range:${range.code}@${interval.code}';

  @override
  String get label => '${range.label} · ${interval.label}';

  @override
  ChartInterval get effectiveInterval => interval;
}

/// Mode C — `/features/1m-price-history/?stock_symbol=…`. Dedicated live
/// 1-minute endpoint.
class ChartSelectionOneMinuteLive extends ChartSelection {
  const ChartSelectionOneMinuteLive();

  @override
  String get cacheKey => 'live:1m';

  @override
  String get label => '1m · Live';

  @override
  ChartInterval get effectiveInterval => ChartInterval.m1;
}

// —— internal parsers ————————————————————————————————————————————————————————

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  // Backend returns naive "yyyy-MM-dd HH:mm:ss" sometimes; `DateTime.tryParse`
  // accepts both ISO-8601 and that form, so it's enough here.
  return DateTime.tryParse(s);
}

double? _double(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

num? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}
