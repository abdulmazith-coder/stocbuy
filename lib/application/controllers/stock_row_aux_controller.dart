import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/models/stock_ohlc.dart';
import 'package:stocbuy_application/application/models/stock_row_aux.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/get_deatils_stocks.dart';
import 'package:stocbuy_application/application/utils/market_hours.dart';

/// Per-symbol cache that powers the dashboard markets table's "Last 7
/// Days" sparkline column.
///
/// Market cap, EPS, P/E, previousClose, etc. are read straight off the
/// [TopCompany] row that the gainers / losers endpoint already returns,
/// so no fan-out is needed for those. The only piece of per-row data
/// not in the top-gain payload is a short price-history series — that's
/// what this controller fetches.
///
/// • [Rx<StockRowAux>] per symbol — the table watches only its own row,
///   so a single sparkline landing doesn't repaint the whole list.
/// • `history-price` (5-day daily candles) is cached for [cacheSparkTtl]
///   (10 min) — sparkline barely moves intraday, no point spending
///   bandwidth every minute.
/// • Inside Indian market hours, [refreshAll] is called once every
///   [_pollInterval] (1 min) so the latest day's bar stays fresh.
///   Outside market hours, the cache is kept indefinitely.
/// • In-flight de-duplication: a second [ensureFor] for the same symbol
///   while a request is already pending is a no-op.
class StockRowAuxController extends GetxController {
  StockRowAuxController({StockDetailsDio? dio})
      : _dio = dio ?? StockDetailsDio();

  static const Duration cacheSparkTtl = Duration(minutes: 10);
  static const Duration _pollInterval = Duration(minutes: 1);

  /// 5 trading days ~ 1 calendar week. The dashboard labels the column
  /// "Last 7 Days" but Indian markets only trade 5 days/week — fetching
  /// 5d is the right call (Coinmarketcap does the same on stock-ish
  /// instruments).
  static const ChartSelection _sparkSelection = ChartSelectionRangeInterval(
    range: ChartRange.d5,
    interval: ChartInterval.d1,
  );

  final StockDetailsDio _dio;

  final RxMap<String, Rx<StockRowAux>> _entries =
      <String, Rx<StockRowAux>>{}.obs;

  final Set<String> _sparkInFlight = <String>{};

  Timer? _pollTimer;

  @override
  void onInit() {
    super.onInit();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _onPollTick());
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.onClose();
  }

  /// Read (or lazily create) the reactive aux for [symbol]. The widget
  /// can `Obx(() => …)` on `aux.value` to react to data landing.
  ///
  /// Side effect: also schedules a fetch when the cache is stale.
  Rx<StockRowAux> auxFor(String symbol) {
    final key = _normaliseSymbol(symbol);
    final existing = _entries[key];
    final rx = existing ?? Rx<StockRowAux>(const StockRowAux.initial());
    if (existing == null) {
      _entries[key] = rx;
    }
    scheduleMicrotask(() => ensureFor(symbol));
    return rx;
  }

  /// Trigger a sparkline fetch when stale or never loaded. Safe to call
  /// repeatedly — in-flight calls are de-duped and fresh cache entries
  /// are skipped.
  void ensureFor(String symbol) {
    final key = _normaliseSymbol(symbol);
    if (key.isEmpty) return;
    final rx = _entries.putIfAbsent(
      key,
      () => Rx<StockRowAux>(const StockRowAux.initial()),
    );
    _maybeRefreshSpark(key, rx);
  }

  /// Imperative refresh — bypasses TTL. Used by the periodic poller.
  Future<void> refreshAll() async {
    final keys = _entries.keys.toList(growable: false);
    if (keys.isEmpty) return;
    for (final k in keys) {
      final rx = _entries[k];
      if (rx == null) continue;
      _maybeRefreshSpark(k, rx, force: true);
    }
  }

  void _onPollTick() {
    if (isClosed) return;
    if (!isWithinIndianMarketHours()) return;
    unawaited(refreshAll());
  }

  void _maybeRefreshSpark(
    String symbol,
    Rx<StockRowAux> rx, {
    bool force = false,
  }) {
    if (_sparkInFlight.contains(symbol)) return;
    final current = rx.value;
    if (!force &&
        current.sparkFetchedAt != null &&
        DateTime.now().difference(current.sparkFetchedAt!) < cacheSparkTtl) {
      return;
    }
    unawaited(_fetchSpark(symbol, rx));
  }

  Future<void> _fetchSpark(String symbol, Rx<StockRowAux> rx) async {
    _sparkInFlight.add(symbol);
    rx.value = rx.value.copyWith(sparkLoading: true, sparkFailed: false);
    try {
      final outcome = await _dio.fetchHistoryPrice(
        symbol: symbol,
        selection: _sparkSelection,
      );
      if (isClosed) return;
      if (outcome.ok && outcome.data != null && outcome.data!.isNotEmpty) {
        final closes = outcome.data!
            .map((c) => c.close)
            .where((v) => v.isFinite && v > 0)
            .toList(growable: false);
        rx.value = rx.value.copyWith(
          sparkline: closes,
          sparkFetchedAt: DateTime.now(),
          sparkLoading: false,
          sparkFailed: false,
        );
      } else {
        rx.value = rx.value.copyWith(
          sparkLoading: false,
          sparkFailed: true,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StockRowAuxController._fetchSpark($symbol): $e');
      }
      if (!isClosed) {
        rx.value = rx.value.copyWith(sparkLoading: false, sparkFailed: true);
      }
    } finally {
      _sparkInFlight.remove(symbol);
    }
  }

  /// Cheap normalisation so `tcs` / `TCS` / `TCS.NS` all share one cache
  /// entry. The Dio service strips the suffix again on the wire — this
  /// is just for the in-memory key.
  static String _normaliseSymbol(String s) {
    final trimmed = s.trim().toUpperCase();
    final dot = trimmed.lastIndexOf('.');
    if (dot > 0) {
      final suf = trimmed.substring(dot + 1);
      const knownSuffixes = {'NS', 'NSE', 'BO', 'BSE', 'NSI'};
      if (knownSuffixes.contains(suf)) {
        return trimmed.substring(0, dot);
      }
    }
    return trimmed;
  }
}
