import 'dart:async';

import 'package:get/get.dart';
import 'package:stocbuy_application/application/models/market_session_status.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/market_active.dart';
import 'package:timezone/timezone.dart' as tz;

/// Exchange open/closed for the ticker (public API, no auth).
///
/// Polling (IST / `Asia/Kolkata`):
/// - **[09:15 – 09:30]**: every **5 minutes**.
/// - **[09:31 – 15:30]**: every **1 hour**, and `min(1h, time until 15:30)` so a
///   fetch lands at **market close (3:30 PM)** without extra hourly polls after that.
/// - **After 15:30 until before 09:15** (evening / night): **no** hourly polling —
///   only **one** wait until the **next 09:15**, then the cycle repeats.
class MarketStatusController extends GetxController {
  MarketStatusController({MarketActiveDio? dio})
      : _dio = dio ?? MarketActiveDio();

  final MarketActiveDio _dio;

  final Rxn<IndiaMarketStatus> snapshot = Rxn<IndiaMarketStatus>();
  final isLoading = false.obs;

  /// Resolved session for the ticker pill — `yahoo_state` from the API,
  /// with Saturday/Sunday (IST) forced to CLOSED. Refreshes on snapshot
  /// changes and every 30s for wall-clock boundaries on weekdays.
  final Rx<MarketSessionState> sessionState =
      MarketSessionState.loading.obs;

  static final tz.Location _ist = tz.getLocation('Asia/Kolkata');

  Timer? _pollTimer;
  Timer? _clockTicker;
  bool _refreshInFlight = false;

  /// Conservative when we have never loaded: treat as closed (red) until data arrives.
  bool get isOpenForTrading => snapshot.value?.isOpenForTrading ?? false;

  bool get hasData => snapshot.value != null;

  @override
  void onInit() {
    super.onInit();
    // Recompute session state whenever the snapshot changes.
    ever(snapshot, (_) => _refreshSessionState());
    // …and every 30s so wall-clock transitions reflect promptly.
    _clockTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshSessionState(),
    );
    _refreshSessionState();
    unawaited(_bootstrap());
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _clockTicker?.cancel();
    _clockTicker = null;
    super.onClose();
  }

  void _refreshSessionState() {
    if (isClosed) return;
    if (isLoading.value && snapshot.value == null) {
      sessionState.value = MarketSessionState.loading;
      return;
    }
    sessionState.value = MarketSessionState.resolve(snapshot.value);
  }

  Future<void> _bootstrap() async {
    await fetchMarketStatus();
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (isClosed) return;

    final delay = _clampDelay(_nextPollDelay());
    _pollTimer = Timer(delay, () async {
      if (isClosed) return;
      await fetchMarketStatus();
      _scheduleNextPoll();
    });
  }

  static Duration _clampDelay(Duration d) {
    if (d.inMilliseconds <= 0) return const Duration(seconds: 1);
    return d;
  }

  /// Next delay after a fetch (or startup), based on **current** IST wall clock.
  Duration _nextPollDelay() {
    final now = tz.TZDateTime.now(_ist);

    if (_inPreOpenWindowIst(now)) {
      return const Duration(minutes: 5);
    }

    if (_isPostCloseOrPreOpenIdleIst(now)) {
      final next915 = _next915OccurrenceIst(now);
      return _clampDelay(next915.difference(now));
    }

    if (_inIntradayHourlyWindowIst(now)) {
      final close = tz.TZDateTime(
        _ist,
        now.year,
        now.month,
        now.day,
        15,
        30,
        0,
      );
      if (!now.isBefore(close)) {
        final next915 = _next915OccurrenceIst(now);
        return _clampDelay(next915.difference(now));
      }
      final untilClose = close.difference(now);
      const hourly = Duration(hours: 1);
      final step = untilClose < hourly ? untilClose : hourly;
      return _clampDelay(step);
    }

    final next915 = _next915OccurrenceIst(now);
    return _clampDelay(next915.difference(now));
  }

  /// After **15:30** or before **09:15** (same IST calendar day, minute resolution).
  static bool _isPostCloseOrPreOpenIdleIst(tz.TZDateTime t) {
    final m = t.hour * 60 + t.minute;
    return m > 15 * 60 + 30 || m < 9 * 60 + 15;
  }

  /// **09:31 – 15:30** IST inclusive (minutes after pre-open through close).
  static bool _inIntradayHourlyWindowIst(tz.TZDateTime t) {
    final m = t.hour * 60 + t.minute;
    return m >= 9 * 60 + 31 && m <= 15 * 60 + 30;
  }

  /// Next calendar occurrence of 09:15:00 IST (today if still ahead, else +1 day).
  static tz.TZDateTime _next915OccurrenceIst(tz.TZDateTime now) {
    var candidate = tz.TZDateTime(
      _ist,
      now.year,
      now.month,
      now.day,
      9,
      15,
      0,
    );
    if (!now.isBefore(candidate)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// Inclusive 09:15–09:30 IST (minute resolution).
  static bool _inPreOpenWindowIst(tz.TZDateTime t) {
    final minutes = t.hour * 60 + t.minute;
    const start = 9 * 60 + 15;
    const end = 9 * 60 + 30;
    return minutes >= start && minutes <= end;
  }

  /// Pull latest session state (used by the IST-aware poll and for manual refresh).
  Future<void> fetchMarketStatus() async {
    if (_refreshInFlight || isClosed) return;
    _refreshInFlight = true;
    final firstLoad = snapshot.value == null;
    if (firstLoad) isLoading.value = true;
    try {
      final result = await _dio.fetchMarketStatus();
      if (isClosed) return;
      if (result.ok && result.status != null) {
        snapshot.value = result.status;
      }
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
      _refreshInFlight = false;
    }
  }
}
