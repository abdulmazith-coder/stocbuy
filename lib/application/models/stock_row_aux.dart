import 'package:flutter/foundation.dart';

/// Per-row supplementary data for the dashboard markets table.
///
/// The Top Gainers / Top Losers payload already carries everything
/// numeric we need (symbol, price, change %, market cap, EPS, P/E,
/// previousClose, …) — the **only** thing not in the payload is a
/// short price-history series for the "Last 7 Days" sparkline. So
/// [StockRowAux] now holds just that: a list of recent closes plus
/// the request lifecycle flags the cell uses to pick between shimmer,
/// curve, and dash.
@immutable
class StockRowAux {
  const StockRowAux({
    this.sparkline,
    this.sparkFetchedAt,
    this.sparkLoading = false,
    this.sparkFailed = false,
  });

  const StockRowAux.initial() : this();

  /// Closing prices for the last ~7 trading days (most-recent last).
  final List<double>? sparkline;

  /// When `history-price` last succeeded for this symbol.
  final DateTime? sparkFetchedAt;

  /// A `history-price` request is currently in flight.
  final bool sparkLoading;

  /// The last `history-price` attempt failed.
  final bool sparkFailed;

  /// True while the sparkline series is missing AND no attempt has
  /// resolved yet — the UI shows a shimmer in that state.
  bool get sparkIsLoading =>
      sparkLoading ||
      ((sparkline == null || sparkline!.isEmpty) && !sparkFailed);

  StockRowAux copyWith({
    List<double>? sparkline,
    DateTime? sparkFetchedAt,
    bool? sparkLoading,
    bool? sparkFailed,
  }) {
    return StockRowAux(
      sparkline: sparkline ?? this.sparkline,
      sparkFetchedAt: sparkFetchedAt ?? this.sparkFetchedAt,
      sparkLoading: sparkLoading ?? this.sparkLoading,
      sparkFailed: sparkFailed ?? this.sparkFailed,
    );
  }
}
