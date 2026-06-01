import 'dart:async';

import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/models/peer_company.dart';
import 'package:stocbuy_application/application/models/stock_detail.dart';
import 'package:stocbuy_application/application/models/stock_fundamentals.dart';
import 'package:stocbuy_application/application/models/stock_ohlc.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/get_deatils_stocks.dart';
import 'package:stocbuy_application/application/utils/market_hours.dart';
import 'package:stocbuy_application/application/models/target_price_analysis.dart';

/// One-off controller backing a single [StockDetailsPage].
///
/// Instantiate per route with `Get.put(tag: symbol)` / `Get.find(tag: symbol)`
/// so multiple detail pages stacked on the navigator don't trample each
/// other.
///
/// Data flow:
///
///   • `stock-info` populates [detail]; shareholding on fundamentals prefers
///     `share_holders` from `stock-financial-data`, then this payload as
///     fallback.
///   • `stock-financial-data` + `company-news` (parallel) populate
///     [fundamentals] (statements, shareholding pie, news list).
///   • `history-price` / `1m-price-history` populates [candles] for the
///     active `(selectedInterval, selectedRange?)` selection, resolved via
///     [ChartSelection].
///
/// Caching & polling — mirrors the real-world fintech pattern already used
/// for Top Gainers / Top Losers:
///
///   • Price (history): 1-minute TTL keyed by [ChartSelection.cacheKey] so
///     swapping interval / range and coming back is instant. The background
///     poller fires every minute while the Indian market is open (09:15–
///     15:35 IST) and refreshes only the *current* selection — and only if
///     its interval is intraday (1m … 1h). Daily+ candles don't move within
///     a minute, so we save the round-trip.
///   • Info (`stock-info`): 1-minute TTL. Polled every minute during market
///     hours so the live "current price" / "today's change" text in the
///     header ticks once per minute regardless of the chart's selection.
///   • In addition, whenever the candle list refreshes (initial fetch or a
///     background 1-min poll) the controller derives a live last-traded
///     price from the most recent intraday candle and patches it into
///     `detail` — so the header text often updates *before* the 1-minute
///     info poll lands.
///   • Financials: fetched once. They only change at quarterly cadence so
///     no polling is needed.
///
/// Auth — these endpoints require login. A 401 / 403 flips
/// [requiresLogin] to `true` so the page can show a single inline
/// "Login to view this stock" panel instead of broken cards.
class StockDetailsController extends GetxController {
  StockDetailsController({
    required this.symbol,
    String? initialCompanyName,
    double initialPrice = 0,
    double initialChangePercent = 0,
    StockDetailsDio? service,
  }) : _service = service ?? StockDetailsDio(),
       detail = StockDetail(
         symbol: symbol,
         shortName: initialCompanyName,
         longName: initialCompanyName,
         currentPrice: initialPrice,
         changePercent: initialChangePercent,
       ).obs;

  /// Cache TTLs.
  static const Duration cacheChartTtl = Duration(minutes: 1);

  /// Info TTL is 1 minute so the live price text on the page header ticks
  /// once a minute during market hours — same cadence as the chart poller.
  /// The ratios in the same payload are repeated work but the payload is
  /// small (~few KB) and the user expects "live" feel on the price.
  static const Duration cacheInfoTtl = Duration(minutes: 1);

  /// Background poll cadences during market hours.
  /// Intraday charts poll faster so the forming candle tracks LTP; daily+
  /// bars stay on a 1-minute cadence.
  static const Duration _chartPollIntervalDaily = Duration(minutes: 1);
  static const Duration _chartPollIntervalIntraday = Duration(seconds: 10);
  static const Duration _chartPollIntervalLive1m = Duration(seconds: 5);
  static const Duration _infoPollIntervalDaily = Duration(minutes: 1);
  static const Duration _infoPollIntervalIntraday = Duration(seconds: 5);
  static const Duration _chartCacheTtlIntraday = Duration(seconds: 8);

  final String symbol;
  final StockDetailsDio _service;

  /// Reactive snapshot — starts as a thin skeleton built from the row that
  /// triggered the navigation, then upgrades to the full API payload.
  final Rx<StockDetail> detail;

  final Rxn<StockFundamentals> fundamentals = Rxn<StockFundamentals>();
  final candles = <StockOhlc>[].obs;
  final peers = <PeerCompany>[].obs;
  final Rxn<TargetPriceAnalysis> targetPrice = Rxn<TargetPriceAnalysis>();

  /// Active candle size. Default = `1m` so the chart opens on the dedicated
  /// `/features/1m-price-history/` live endpoint (same UX as Zerodha Kite's
  /// 1-minute intraday view).
  final selectedInterval = ChartInterval.m1.obs;

  /// Active lookback range. `null` means "let the backend pick" — that
  /// resolves to Mode A (`istread=true`) for non-1m intervals or Mode C
  /// (the dedicated 1m endpoint) when the interval is 1m. Setting a range
  /// switches the toolbar into Mode B.
  final Rxn<ChartRange> selectedRange = Rxn<ChartRange>();

  /// The selection actually being fetched, resolved from
  /// `(selectedInterval, selectedRange)` on every change.
  ChartSelection get currentSelection => ChartSelection.resolve(
    interval: selectedInterval.value,
    range: selectedRange.value,
  );

  // —— Loading flags (spinner shown only when nothing is rendered yet) ——
  final isLoadingDetail = false.obs;
  final isLoadingChart = false.obs;
  final isLoadingFundamentals = false.obs;
  final isLoadingPeers = false.obs;
  final isLoadingTargetPrice = false.obs;

  // —— "Has fetched once" flags (drives first-load vs background refresh) ——
  final hasFetchedDetail = false.obs;
  final hasFetchedChart = false.obs;
  final hasFetchedFundamentals = false.obs;
  final hasFetchedPeers = false.obs;
  final hasFetchedTargetPrice = false.obs;

  // —— "Last fetch failed / backend has no data for this symbol" flags ——
  // Used by the cards to swap the optimistic "Data will appear here"
  // placeholder for a definitive "Not available for this stock" message
  // once we know the backend can't serve the field. Cleared on every
  // successful refresh.
  final fundamentalsUnavailable = false.obs;
  final peersUnavailable = false.obs;
  final targetPriceUnavailable = false.obs;

  /// `true` when the user must log in to view this stock (logged out or
  /// any of the three endpoints returned 401 after a refresh attempt).
  final requiresLogin = false.obs;

  /// Last successful fetch timestamps — for the "Live · Last updated"
  /// indicator the markets toolbar shows.
  final Rxn<DateTime> chartUpdatedAt = Rxn<DateTime>();
  final Rxn<DateTime> detailUpdatedAt = Rxn<DateTime>();

  // —— Internal state ——————————————————————————————————————————————————
  DateTime? _detailFetchedAt;
  // Per-selection cache map keyed by [ChartSelection.cacheKey] so users
  // flipping between (1D · 5m) ↔ (1Y · 1D) ↔ (1m live) hit warm cache on
  // re-selection within the TTL window.
  final Map<String, DateTime> _chartFetchedAtBySelection = {};
  String? _lastFetchedSelectionKey;

  /// Shareholding from `stock-info`, used only when financial-data has no
  /// `share_holders` row yet. Cleared on logout.
  ShareholdingBreakdown? _lastShareholding;

  bool _detailInFlight = false;
  bool _chartInFlight = false;
  bool _fundamentalsInFlight = false;
  bool _peersInFlight = false;
  bool _targetPriceInFlight = false;

  Timer? _chartPollTimer;
  Timer? _infoPollTimer;
  Timer? _formingCandleTimer;
  Worker? _authListener;
  Worker? _candlesListener;

  @override
  void onInit() {
    super.onInit();

    // Stamp the initial logged-in state and listen for changes.
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      requiresLogin.value = !auth.isLoggedIn.value;
      _authListener = ever<bool>(auth.isLoggedIn, _onAuthChanged);
    } else {
      requiresLogin.value = true;
    }

    // Whenever the candle list refreshes (initial fetch OR background 1-min
    // poll) we derive the live "last traded price" from the most recent
    // candle's close and patch it into [detail]. The header / sidebar
    // price text rebuilds in place — no extra API call needed.
    _candlesListener = ever(candles, (_) => _applyLivePriceFromCandles());

    // Kick off the initial fetch and start the pollers after the first
    // frame so the UI paints the hydrated skeleton immediately.
    scheduleMicrotask(_bootstrap);
  }

  @override
  void onClose() {
    _authListener?.dispose();
    _authListener = null;
    _candlesListener?.dispose();
    _candlesListener = null;
    _chartPollTimer?.cancel();
    _infoPollTimer?.cancel();
    _formingCandleTimer?.cancel();
    _chartPollTimer = null;
    _infoPollTimer = null;
    _formingCandleTimer = null;
    super.onClose();
  }

  // —— Public API ————————————————————————————————————————————————————

  /// Candles shown on the chart — last intraday bar merged with live LTP so
  /// OHLC strip, axis marker, and sidebar always agree.
  List<StockOhlc> get chartCandles {
    if (candles.isEmpty) return const [];
    if (!currentSelection.isIntraday) {
      return List<StockOhlc>.unmodifiable(candles);
    }
    final live = detail.value.currentPrice;
    if (live == null || live <= 0) {
      return List<StockOhlc>.unmodifiable(candles);
    }
    final last = candles.last;
    if (last.close == live && last.high >= live && last.low <= live) {
      return List<StockOhlc>.unmodifiable(candles);
    }
    final merged = List<StockOhlc>.from(candles);
    merged[merged.length - 1] = last.copyWith(
      close: live,
      high: live > last.high ? live : last.high,
      low: live < last.low ? live : last.low,
    );
    return List<StockOhlc>.unmodifiable(merged);
  }

  /// Price shown in the page header while intraday — matches chart close.
  double? get headerDisplayPrice {
    final series = chartCandles;
    if (currentSelection.isIntraday && series.isNotEmpty) {
      return series.last.close;
    }
    return detail.value.currentPrice;
  }

  /// Header change pill — matches the chart OHLC strip for the latest bar
  /// (close vs previous close) while an intraday interval is active.
  /// Falls back to the stock-info day change on daily+ views.
  ({double changeAbs, double changePct}) get headerQuoteChange {
    final series = chartCandles;
    if (!currentSelection.isIntraday || series.isEmpty) {
      final d = detail.value;
      return (changeAbs: d.change ?? 0, changePct: d.changePercent ?? 0);
    }

    final last = series.last;
    final referenceClose = series.length > 1
        ? series[series.length - 2].close
        : last.open;
    if (referenceClose <= 0) {
      final d = detail.value;
      return (changeAbs: d.change ?? 0, changePct: d.changePercent ?? 0);
    }

    final change = last.close - referenceClose;
    final pct = (change / referenceClose) * 100;
    return (changeAbs: change, changePct: pct);
  }

  /// Swap the active candle size. If the new interval is incompatible with
  /// the current range (e.g. picking `1m` while range = `5Y` would produce
  /// hundreds of thousands of candles), the range is auto-shrunk to a
  /// compatible default — matching TradingView's behaviour.
  ///
  /// User-initiated changes clear the old candle list and flip
  /// [hasFetchedChart] back to `false` so the chart shows its loading
  /// state for the new selection; background polls keep candles visible.
  Future<void> setInterval(ChartInterval interval) async {
    if (selectedInterval.value == interval) return;
    selectedInterval.value = interval;
    _enforceCompatibility(intervalChanged: true);
    await _onSelectionChanged();
  }

  /// Switch the active lookback range. Pass `null` to clear and fall back
  /// to Mode A (quick-read) for non-1m intervals or Mode C (1m live) for
  /// the 1m interval.
  ///
  /// If the picked range is too long for the current interval (e.g. 5Y at
  /// 1m granularity), the interval is bumped up to a compatible coarser
  /// one instead of the range being clobbered — preserves the user's
  /// chosen range.
  Future<void> setRange(ChartRange? range) async {
    if (selectedRange.value == range) return;
    selectedRange.value = range;
    if (range != null) {
      _enforceCompatibility(intervalChanged: false);
    }
    await _onSelectionChanged();
  }

  /// Manual pull-to-refresh — bypasses every cache.
  Future<void> refreshAll() async {
    _detailFetchedAt = null;
    _chartFetchedAtBySelection.clear();
    hasFetchedFundamentals.value = false;
    hasFetchedPeers.value = false;
    fundamentalsUnavailable.value = false;
    peersUnavailable.value = false;
    await Future.wait([_loadDetail(force: true), _loadChart(force: true)]);
    await Future.wait([
      _loadFundamentals(force: true),
      _loadPeers(force: true),
    ]);
  }

  /// Shared post-selection-change refetch path used by both [setInterval]
  /// and [setRange]. Clears the visible candles, resets the
  /// `hasFetchedChart` flag for the new selection (so the first-load
  /// spinner appears), then refetches.
  Future<void> _onSelectionChanged() async {
    candles.clear();
    final key = currentSelection.cacheKey;
    if (_lastFetchedSelectionKey != key) {
      hasFetchedChart.value = false;
    }
    await _loadChart(force: true);
    _startPollers();
  }

  /// Ensure the active `(interval, range)` pair is sane. Too many candles
  /// produces backend timeouts and unreadable charts.
  ///
  /// Compatibility caps:
  ///   • 1m, 2m              ⇒ range ≤ 5D
  ///   • 5m, 15m             ⇒ range ≤ 1M
  ///   • 30m, 60m, 90m, 1h   ⇒ range ≤ 6M
  ///   • 1D                  ⇒ range ≤ 10Y
  ///   • 5D, 1W, 1M, 3M      ⇒ range ≤ MAX
  void _enforceCompatibility({required bool intervalChanged}) {
    final interval = selectedInterval.value;
    final range = selectedRange.value;
    if (range == null) return;

    final maxRange = _maxRangeFor(interval);
    final isCompatible = range.index <= maxRange.index;
    if (isCompatible) return;

    if (intervalChanged) {
      // User just picked an interval — keep their interval and shrink the
      // range to the maximum that's compatible.
      selectedRange.value = maxRange;
    } else {
      // User just picked a range — keep their range and bump the interval
      // up to the finest one that allows it.
      selectedInterval.value = _minIntervalFor(range);
    }
  }

  static ChartRange _maxRangeFor(ChartInterval interval) {
    return switch (interval) {
      ChartInterval.m1 || ChartInterval.m2 => ChartRange.d5,
      ChartInterval.m5 || ChartInterval.m15 => ChartRange.mo1,
      ChartInterval.m30 ||
      ChartInterval.m60 ||
      ChartInterval.m90 ||
      ChartInterval.h1 => ChartRange.mo6,
      ChartInterval.d1 => ChartRange.y10,
      ChartInterval.d5 ||
      ChartInterval.wk1 ||
      ChartInterval.mo1 ||
      ChartInterval.mo3 => ChartRange.max,
    };
  }

  /// Inverse of [_maxRangeFor] — finest interval that can serve [range].
  static ChartInterval _minIntervalFor(ChartRange range) {
    return switch (range) {
      ChartRange.d1 || ChartRange.d5 => ChartInterval.m1,
      ChartRange.mo1 => ChartInterval.m5,
      ChartRange.mo3 || ChartRange.mo6 || ChartRange.ytd => ChartInterval.m30,
      ChartRange.y1 || ChartRange.y2 || ChartRange.y5 => ChartInterval.d1,
      ChartRange.y10 => ChartInterval.d1,
      ChartRange.max => ChartInterval.wk1,
    };
  }

  // —— Bootstrap & lifecycle ————————————————————————————————————————

  Future<void> _bootstrap() async {
    if (requiresLogin.value) return;
    // Detail + chart in parallel — financials follow once detail lands so
    // the shareholding pie can be spliced in. Peers are fetched in
    // parallel with financials because they don't depend on each other.
    await Future.wait([_loadDetail(), _loadChart()]);
    if (isClosed) return;
    await Future.wait([_loadFundamentals(), _loadPeers(), _loadTargetPrice()]);
    if (isClosed) return;
    _startPollers();
  }

  void _startPollers() {
    _chartPollTimer?.cancel();
    _infoPollTimer?.cancel();
    _formingCandleTimer?.cancel();

    final intraday = currentSelection.isIntraday;
    final chartInterval = !intraday
        ? _chartPollIntervalDaily
        : (currentSelection is ChartSelectionOneMinuteLive
              ? _chartPollIntervalLive1m
              : _chartPollIntervalIntraday);
    final infoInterval = intraday
        ? _infoPollIntervalIntraday
        : _infoPollIntervalDaily;

    _chartPollTimer = Timer.periodic(chartInterval, (_) => _onChartTick());
    _infoPollTimer = Timer.periodic(infoInterval, (_) => _onInfoTick());

    // Between API ticks, keep the open bar aligned with the latest LTP so
    // colour (green/red) flips immediately when price crosses the bar open.
    if (intraday) {
      _formingCandleTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _syncFormingCandle(),
      );
    }
  }

  void _onChartTick() {
    if (isClosed) return;
    if (requiresLogin.value) return;
    if (!isWithinIndianMarketHours()) return;
    if (!hasFetchedChart.value) return;
    // Daily / weekly / monthly candles don't move within a minute — skip
    // the round-trip. Intraday intervals (1m … 1h) keep polling.
    if (!currentSelection.isIntraday) return;
    unawaited(_loadChart(force: true));
  }

  void _onInfoTick() {
    if (isClosed) return;
    if (requiresLogin.value) return;
    if (!isWithinIndianMarketHours()) return;
    if (!hasFetchedDetail.value) return;
    unawaited(_loadDetail(force: true));
  }

  void _onAuthChanged(bool loggedIn) {
    if (isClosed) return;
    if (loggedIn) {
      requiresLogin.value = false;
      // Re-bootstrap after a successful login so the page hydrates.
      _detailFetchedAt = null;
      _chartFetchedAtBySelection.clear();
      _lastFetchedSelectionKey = null;
      hasFetchedDetail.value = false;
      hasFetchedChart.value = false;
      hasFetchedFundamentals.value = false;
      hasFetchedPeers.value = false;
      hasFetchedTargetPrice.value = false;
      fundamentalsUnavailable.value = false;
      peersUnavailable.value = false;
      targetPriceUnavailable.value = false;
      targetPrice.value = null;
      unawaited(_bootstrap());
    } else {
      _markLoginRequired();
    }
  }

  void _markLoginRequired() {
    requiresLogin.value = true;
    candles.clear();
    peers.clear();
    fundamentals.value = null;
    _detailFetchedAt = null;
    _chartFetchedAtBySelection.clear();
    _lastFetchedSelectionKey = null;
    _lastShareholding = null;
    hasFetchedDetail.value = false;
    hasFetchedChart.value = false;
    hasFetchedFundamentals.value = false;
    hasFetchedPeers.value = false;
    hasFetchedTargetPrice.value = false;
    fundamentalsUnavailable.value = false;
    peersUnavailable.value = false;
    targetPriceUnavailable.value = false;
    targetPrice.value = null;
    detailUpdatedAt.value = null;
    chartUpdatedAt.value = null;
    _chartPollTimer?.cancel();
    _infoPollTimer?.cancel();
    _formingCandleTimer?.cancel();
  }

  // —— Fetches ————————————————————————————————————————————————————————

  Duration get _infoCacheTtl =>
      currentSelection.isIntraday ? const Duration(seconds: 4) : cacheInfoTtl;

  Future<void> _loadDetail({bool force = false}) async {
    if (_detailInFlight || isClosed) return;
    if (!force && _isFresh(_detailFetchedAt, _infoCacheTtl)) return;
    _detailInFlight = true;
    isLoadingDetail.value = true;
    try {
      final outcome = await _service.fetchStockInfo(symbol: symbol);
      if (isClosed) return;
      if (outcome.unauthorized) {
        _markLoginRequired();
        return;
      }
      final bundle = outcome.data;
      if (outcome.ok && bundle != null) {
        // Merge live values onto the skeleton so partial backend fields
        // don't clobber the price/name we already showed.
        detail.value = _mergeDetails(detail.value, bundle.detail);
        _lastShareholding = bundle.shareholding ?? _lastShareholding;
        // If financials already arrived, splice the fresh shareholding in.
        final f = fundamentals.value;
        if (f != null) {
          final merged = f.shareholding ?? _lastShareholding;
          if (merged != f.shareholding) {
            fundamentals.value = StockFundamentals(
              balanceSheet: f.balanceSheet,
              incomeStatement: f.incomeStatement,
              cashFlow: f.cashFlow,
              shareholding: merged,
              news: f.news,
            );
          }
        }
        final now = DateTime.now();
        _detailFetchedAt = now;
        detailUpdatedAt.value = now;
        _syncFormingCandle();
      }
    } finally {
      if (!isClosed) {
        isLoadingDetail.value = false;
        hasFetchedDetail.value = true;
      }
      _detailInFlight = false;
    }
  }

  Future<void> _loadChart({bool force = false}) async {
    if (_chartInFlight || isClosed) return;
    final selection = currentSelection;
    final key = selection.cacheKey;
    final selectionChanged = _lastFetchedSelectionKey != key;
    final chartTtl = selection.isIntraday
        ? _chartCacheTtlIntraday
        : cacheChartTtl;
    if (!force &&
        !selectionChanged &&
        _isFresh(_chartFetchedAtBySelection[key], chartTtl)) {
      return;
    }
    _chartInFlight = true;
    isLoadingChart.value = true;
    try {
      final outcome = await _service.fetchHistoryPrice(
        symbol: symbol,
        selection: selection,
      );
      if (isClosed) return;
      // Bail if the user changed selection mid-flight — a newer fetch is
      // about to overwrite us anyway, and the candles we'd write don't
      // belong to the new selection.
      if (currentSelection.cacheKey != key) return;
      if (outcome.unauthorized) {
        _markLoginRequired();
        return;
      }
      if (outcome.ok && outcome.data != null) {
        candles.assignAll(outcome.data!);
        _syncFormingCandle();
        final now = DateTime.now();
        _chartFetchedAtBySelection[key] = now;
        _lastFetchedSelectionKey = key;
        chartUpdatedAt.value = now;
      }
    } finally {
      if (!isClosed) {
        isLoadingChart.value = false;
        hasFetchedChart.value = true;
      }
      _chartInFlight = false;
    }
  }

  /// Mirror the latest candle's close into [detail] so the big price text on
  /// the page header / left sidebar ticks every time the chart refreshes.
  ///
  /// Only applied while the active selection is **intraday** — for 1Y / 5Y
  /// / MAX views the "latest candle" is a stale daily / weekly / monthly
  /// bar that mustn't clobber the live price the info endpoint reported.
  ///
  /// Day-change baseline picking order (most accurate → fallback):
  ///   1. `previousClose` from the stock-info payload (true vs-yesterday)
  ///   2. First candle's open in the current intraday session (intraday
  ///      open as a session baseline)
  ///   3. The existing `currentPrice` (no movement)
  /// Push the latest LTP from [detail] into the open (last) intraday candle so
  /// the chart colour and OHLC strip match trading apps between API refreshes.
  void _syncFormingCandle() {
    if (isClosed) return;
    if (!currentSelection.isIntraday) return;
    if (candles.isEmpty) return;

    final live = detail.value.currentPrice;
    if (live == null || live <= 0) return;

    final last = candles.last;
    if (last.close == live && last.high >= live && last.low <= live) return;

    candles[candles.length - 1] = last.copyWith(
      close: live,
      high: live > last.high ? live : last.high,
      low: live < last.low ? live : last.low,
    );
    // Notify chart + header (they read [chartCandles] / [headerDisplayPrice]).
    candles.refresh();
    detail.refresh();
  }

  /// When candles refresh without a fresher stock-info price, mirror the last
  /// bar into the header. Otherwise stock-info LTP wins and we patch the bar
  /// via [_syncFormingCandle] instead of dragging the header backwards.
  void _applyLivePriceFromCandles() {
    if (isClosed) return;
    if (candles.isEmpty) return;
    if (!currentSelection.isIntraday) return;

    final liveFromDetail = detail.value.currentPrice;
    if (liveFromDetail != null && liveFromDetail > 0) {
      _syncFormingCandle();
      return;
    }

    final last = candles.last.close;
    final current = detail.value;
    if (current.currentPrice == last && current.change != null) return;

    final baseline =
        (current.previousClose != null && current.previousClose! > 0)
        ? current.previousClose!
        : (candles.first.open > 0
              ? candles.first.open
              : (current.currentPrice ?? 0));

    final change = baseline > 0 ? last - baseline : 0.0;
    final pct = baseline > 0 ? (change / baseline) * 100 : 0.0;

    detail.value = current.copyWithLivePrice(
      currentPrice: last,
      change: change.toDouble(),
      changePercent: pct.toDouble(),
    );
  }

  Future<void> _loadFundamentals({bool force = false}) async {
    if (_fundamentalsInFlight || isClosed) return;
    // No TTL — financials change at quarterly cadence. Re-fetch only when
    // explicitly forced (manual refresh / re-login).
    if (!force && hasFetchedFundamentals.value) return;
    _fundamentalsInFlight = true;
    isLoadingFundamentals.value = true;
    try {
      final results = await Future.wait([
        _service.fetchFinancials(
          symbol: symbol,
          shareholding: _lastShareholding,
        ),
        _service.fetchCompanyNews(symbol: symbol, days: 7),
      ]);
      final outcome = results[0] as StockDetailsOutcome<StockFundamentals>;
      final newsOutcome =
          results[1] as StockDetailsOutcome<List<StockNewsItem>>;
      if (isClosed) return;
      if (outcome.unauthorized || newsOutcome.unauthorized) {
        _markLoginRequired();
        return;
      }
      final newsItems = newsOutcome.ok && newsOutcome.data != null
          ? newsOutcome.data!
          : const <StockNewsItem>[];

      if (outcome.ok && outcome.data != null) {
        final base = outcome.data!;
        fundamentals.value = StockFundamentals(
          balanceSheet: base.balanceSheet,
          incomeStatement: base.incomeStatement,
          cashFlow: base.cashFlow,
          shareholding: base.shareholding,
          news: newsItems,
        );
        fundamentalsUnavailable.value = fundamentals.value!.isEmpty;
      } else {
        // Financial-data may fail while company-news still returns headlines.
        // Keep any partial payload (shareholding from stock-info + news) and
        // only mark unavailable when every section is empty.
        if (fundamentals.value == null && _lastShareholding != null) {
          fundamentals.value = StockFundamentals(
            balanceSheet: const [],
            incomeStatement: const [],
            cashFlow: const [],
            shareholding: _lastShareholding,
            news: newsItems,
          );
        } else if (fundamentals.value != null && newsItems.isNotEmpty) {
          final current = fundamentals.value!;
          fundamentals.value = StockFundamentals(
            balanceSheet: current.balanceSheet,
            incomeStatement: current.incomeStatement,
            cashFlow: current.cashFlow,
            shareholding: current.shareholding,
            news: newsItems,
          );
        }
        fundamentalsUnavailable.value = fundamentals.value?.isEmpty ?? true;
      }
    } finally {
      if (!isClosed) {
        isLoadingFundamentals.value = false;
        hasFetchedFundamentals.value = true;
      }
      _fundamentalsInFlight = false;
    }
  }

  /// Fetch the peer-companies list. Same one-shot pattern as
  /// [_loadFundamentals] — peer membership is stable over the trading day
  /// (it's defined by sector/industry classification), so there's no
  /// auto-poll. The numeric snapshot on each peer (price / today %) will
  /// drift during the session but cheaply: a manual refresh re-fetches.
  Future<void> _loadPeers({bool force = false}) async {
    if (_peersInFlight || isClosed) return;
    if (!force && hasFetchedPeers.value) return;
    _peersInFlight = true;
    isLoadingPeers.value = true;
    try {
      final outcome = await _service.fetchPeers(symbol: symbol);
      if (isClosed) return;
      if (outcome.unauthorized) {
        _markLoginRequired();
        return;
      }
      if (outcome.ok && outcome.data != null) {
        peers.assignAll(outcome.data!);
        peersUnavailable.value = outcome.data!.isEmpty;
      } else {
        peers.clear();
        peersUnavailable.value = true;
      }
    } finally {
      if (!isClosed) {
        isLoadingPeers.value = false;
        hasFetchedPeers.value = true;
      }
      _peersInFlight = false;
    }
  }

  Future<void> _loadTargetPrice({bool force = false}) async {
    if (_targetPriceInFlight || isClosed) return;
    if (!force && hasFetchedTargetPrice.value) return;
    _targetPriceInFlight = true;
    isLoadingTargetPrice.value = true;
    try {
      final outcome = await _service.fetchTargetPrice(symbol: symbol);
      if (isClosed) return;
      if (outcome.unauthorized) {
        _markLoginRequired();
        return;
      }
      if (outcome.ok && outcome.data != null) {
        targetPrice.value = outcome.data!;
        targetPriceUnavailable.value = false;
      } else {
        targetPrice.value = null;
        targetPriceUnavailable.value = true;
      }
    } finally {
      if (!isClosed) {
        isLoadingTargetPrice.value = false;
        hasFetchedTargetPrice.value = true;
      }
      _targetPriceInFlight = false;
    }
  }

  bool _isFresh(DateTime? at, Duration ttl) =>
      at != null && DateTime.now().difference(at) < ttl;

  StockDetail _mergeDetails(StockDetail base, StockDetail next) {
    return StockDetail(
      symbol: prefer(next.symbol, base.symbol) ?? base.symbol,
      shortName: prefer(next.shortName, base.shortName),
      longName: prefer(next.longName, base.longName),
      exchange: prefer(next.exchange, base.exchange),
      currency: next.currency.isNotEmpty ? next.currency : base.currency,
      currentPrice: next.currentPrice ?? base.currentPrice,
      previousClose: next.previousClose ?? base.previousClose,
      open: next.open ?? base.open,
      dayHigh: next.dayHigh ?? base.dayHigh,
      dayLow: next.dayLow ?? base.dayLow,
      changePercent: next.changePercent ?? base.changePercent,
      change: next.change ?? base.change,
      fiftyTwoWeekHigh: next.fiftyTwoWeekHigh ?? base.fiftyTwoWeekHigh,
      fiftyTwoWeekLow: next.fiftyTwoWeekLow ?? base.fiftyTwoWeekLow,
      fiftyDayAverage: next.fiftyDayAverage ?? base.fiftyDayAverage,
      twoHundredDayAverage:
          next.twoHundredDayAverage ?? base.twoHundredDayAverage,
      volume: next.volume ?? base.volume,
      regularMarketVolume: next.regularMarketVolume ?? base.regularMarketVolume,
      averageVolume: next.averageVolume ?? base.averageVolume,
      marketCap: next.marketCap ?? base.marketCap,
      trailingPE: next.trailingPE ?? base.trailingPE,
      forwardPE: next.forwardPE ?? base.forwardPE,
      priceToBook: next.priceToBook ?? base.priceToBook,
      priceToSalesTrailing12Months:
          next.priceToSalesTrailing12Months ??
          base.priceToSalesTrailing12Months,
      enterpriseToRevenue: next.enterpriseToRevenue ?? base.enterpriseToRevenue,
      bookValue: next.bookValue ?? base.bookValue,
      trailingEps: next.trailingEps ?? base.trailingEps,
      forwardEps: next.forwardEps ?? base.forwardEps,
      pegRatio: next.pegRatio ?? base.pegRatio,
      trailingPegRatio: next.trailingPegRatio ?? base.trailingPegRatio,
      beta: next.beta ?? base.beta,
      dividendRate: next.dividendRate ?? base.dividendRate,
      dividendYield: next.dividendYield ?? base.dividendYield,
      trailingAnnualDividendYield:
          next.trailingAnnualDividendYield ?? base.trailingAnnualDividendYield,
      fiveYearAvgDividendYield:
          next.fiveYearAvgDividendYield ?? base.fiveYearAvgDividendYield,
      payoutRatio: next.payoutRatio ?? base.payoutRatio,
      industryPE: next.industryPE ?? base.industryPE,
      evToEbitda: next.evToEbitda ?? base.evToEbitda,
      returnOnCapitalEmployed:
          next.returnOnCapitalEmployed ?? base.returnOnCapitalEmployed,
      faceValue: next.faceValue ?? base.faceValue,
      pledgedPercent: next.pledgedPercent ?? base.pledgedPercent,
      unpledgedPromoterHolding:
          next.unpledgedPromoterHolding ?? base.unpledgedPromoterHolding,
      heldPercentInsiders: next.heldPercentInsiders ?? base.heldPercentInsiders,
      heldPercentInstitutions:
          next.heldPercentInstitutions ?? base.heldPercentInstitutions,
      returnOnEquity: next.returnOnEquity ?? base.returnOnEquity,
      returnOnAssets: next.returnOnAssets ?? base.returnOnAssets,
      debtToEquity: next.debtToEquity ?? base.debtToEquity,
      quickRatio: next.quickRatio ?? base.quickRatio,
      currentRatio: next.currentRatio ?? base.currentRatio,
      profitMargins: next.profitMargins ?? base.profitMargins,
      grossMargins: next.grossMargins ?? base.grossMargins,
      operatingMargins: next.operatingMargins ?? base.operatingMargins,
      ebitdaMargins: next.ebitdaMargins ?? base.ebitdaMargins,
      earningsGrowth: next.earningsGrowth ?? base.earningsGrowth,
      revenueGrowth: next.revenueGrowth ?? base.revenueGrowth,
      earningsQuarterlyGrowth:
          next.earningsQuarterlyGrowth ?? base.earningsQuarterlyGrowth,
      revenuePerShare: next.revenuePerShare ?? base.revenuePerShare,
      totalCashPerShare: next.totalCashPerShare ?? base.totalCashPerShare,
      totalRevenue: next.totalRevenue ?? base.totalRevenue,
      totalDebt: next.totalDebt ?? base.totalDebt,
      totalCash: next.totalCash ?? base.totalCash,
      numberOfAnalystOpinions:
          next.numberOfAnalystOpinions ?? base.numberOfAnalystOpinions,
      recommendationKey: prefer(next.recommendationKey, base.recommendationKey),
      targetMeanPrice: next.targetMeanPrice ?? base.targetMeanPrice,
      targetHighPrice: next.targetHighPrice ?? base.targetHighPrice,
      targetLowPrice: next.targetLowPrice ?? base.targetLowPrice,
      longBusinessSummary: prefer(
        next.longBusinessSummary,
        base.longBusinessSummary,
      ),
      sector: prefer(next.sector, base.sector),
      industry: prefer(next.industry, base.industry),
      website: prefer(next.website, base.website),
      phone: prefer(next.phone, base.phone),
      address1: prefer(next.address1, base.address1),
      address2: prefer(next.address2, base.address2),
      city: prefer(next.city, base.city),
      state: prefer(next.state, base.state),
      zip: prefer(next.zip, base.zip),
      country: prefer(next.country, base.country),
      fullTimeEmployees: next.fullTimeEmployees ?? base.fullTimeEmployees,
      officers: next.officers.isNotEmpty ? next.officers : base.officers,
    );
  }

  static T? prefer<T>(T? next, T? base) => next ?? base;
}
