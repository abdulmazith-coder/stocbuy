import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stocbuy_application/application/models/market_breadth.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/market_breadth_dio.dart';
import 'package:timezone/timezone.dart' as tz;

class MarketBreadthController extends GetxController {
  MarketBreadthController({
    MarketBreadthDio? dio,
    String indexName = 'NIFTY 50',
  }) : _dio = dio ?? MarketBreadthDio(),
       _indexName = indexName;

  /// 1-minute polling interval
  static const Duration _pollInterval = Duration(seconds: 60);

  /// Storage key for market breadth cache
  static const String _prefsKey = 'market_breadth_snapshot';

  /// IST timezone for market hours check
  static final tz.Location _ist = tz.getLocation('Asia/Kolkata');

  final MarketBreadthDio _dio;
  final String _indexName;

  /// Current market breadth data
  final Rxn<MarketBreadth> marketBreadth = Rxn<MarketBreadth>();

  /// Loading state
  final isLoading = false.obs;

  /// Last update timestamp
  final Rxn<DateTime> lastUpdateTime = Rxn<DateTime>();

  /// Error message if any
  final Rxn<String> errorMessage = Rxn<String>();

  Timer? _pollTimer;
  bool _inFlight = false;

  @override
  void onInit() {
    super.onInit();
    unawaited(_bootstrap());
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.onClose();
  }

  /// Initialize by loading cached data and fetching fresh data
  Future<void> _bootstrap() async {
    await _loadSavedSnapshot();
    // Try to populate UI immediately from backend
    unawaited(fetchMarketBreadth(force: true));
    _scheduleNextPoll(immediate: true);
  }

  /// Load market breadth data from local cache
  Future<void> _loadSavedSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;

      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return;

      marketBreadth.value = MarketBreadth.fromJson(json);
    } catch (_) {
      // Ignore malformed local data
    }
  }

  /// Save market breadth data to local cache
  Future<void> _saveSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (marketBreadth.value != null) {
        await prefs.setString(
          _prefsKey,
          jsonEncode(marketBreadth.value!.toJson()),
        );
      }
    } catch (_) {
      // Ignore local storage failures
    }
  }

  /// Schedule next polling based on market hours
  void _scheduleNextPoll({bool immediate = false}) {
    _pollTimer?.cancel();
    _pollTimer = null;

    final now = tz.TZDateTime.now(_ist);
    if (_isMarketOpenIst(now)) {
      if (immediate) {
        unawaited(fetchMarketBreadth(force: true));
      }
      // Set up 1-minute periodic polling during market hours
      _pollTimer = Timer.periodic(_pollInterval, (_) => _onPollTick());
      return;
    }

    // Schedule to restart polling at next market open (9:15 AM IST)
    final next = _next915OccurrenceIst(now);
    final delay = next.difference(now);
    _pollTimer = Timer(_clampDelay(delay), () async {
      await fetchMarketBreadth(force: true);
      _scheduleNextPoll(immediate: true);
    });
  }

  /// Called on each poll tick during market hours
  void _onPollTick() {
    final now = tz.TZDateTime.now(_ist);
    if (!_isMarketOpenIst(now)) {
      _scheduleNextPoll(immediate: false);
      return;
    }
    unawaited(fetchMarketBreadth(force: true));
  }

  /// Fetch market breadth data from API
  /// [force] - Force fetch even if request is in flight
  Future<void> fetchMarketBreadth({bool force = false}) async {
    if (_inFlight && !force) return;
    _inFlight = true;
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final outcome = await _dio.fetchMarketBreadth(indexName: _indexName);
      if (outcome.ok && outcome.data != null) {
        marketBreadth.value = outcome.data!;
        lastUpdateTime.value = DateTime.now();
        errorMessage.value = null;
        await _saveSnapshot();
      } else {
        errorMessage.value =
            outcome.error ?? 'Failed to fetch market breadth data';
      }
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
      _inFlight = false;
    }
  }

  /// Manually refresh market breadth data
  Future<void> refreshMarketBreadth() async {
    await fetchMarketBreadth(force: true);
  }

  /// Get formatted last update time
  String get formattedLastUpdate {
    final time = lastUpdateTime.value;
    if (time == null) return 'Never';

    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  /// Get breadth ratio display
  String get breadthRatioDisplay {
    final breadth = marketBreadth.value;
    if (breadth == null) return '--';
    return breadth.formattedBreadthRatio;
  }

  /// Get advance percentage display
  String get advancePercentDisplay {
    final breadth = marketBreadth.value;
    if (breadth == null) return '--';
    return '${breadth.formattedAdvancePercent}%';
  }

  /// Get advancers count
  int get advancersCount => marketBreadth.value?.advancers ?? 0;

  /// Get decliners count
  int get declinersCount => marketBreadth.value?.decliners ?? 0;

  /// Get unchanged count
  int get unchangedCount => marketBreadth.value?.unchanged ?? 0;

  /// Check if market is positive
  bool get isMarketPositive => marketBreadth.value?.isPositive ?? false;

  /// Check if market is negative
  bool get isMarketNegative => marketBreadth.value?.isNegative ?? false;

  // ==================== Helper Methods ====================

  /// Clamp delay to minimum 1 second
  static Duration _clampDelay(Duration d) {
    if (d.inMilliseconds <= 0) return const Duration(seconds: 1);
    return d;
  }

  /// Check if market is open in IST (9:15 AM to 3:30 PM, Mon-Fri)
  static bool _isMarketOpenIst(tz.TZDateTime now) {
    // Market closed on weekends
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return false;
    }
    // Market hours: 9:15 AM (555 minutes) to 3:30 PM (930 minutes)
    final minutes = now.hour * 60 + now.minute;
    return minutes >= 9 * 60 + 15 && minutes <= 15 * 60 + 30;
  }

  /// Get next market open time (9:15 AM IST)
  static tz.TZDateTime _next915OccurrenceIst(tz.TZDateTime now) {
    var candidate = tz.TZDateTime(_ist, now.year, now.month, now.day, 9, 15, 0);
    // If 9:15 AM has already passed today, move to next day
    if (!now.isBefore(candidate)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    // Skip weekends
    while (candidate.weekday == DateTime.saturday ||
        candidate.weekday == DateTime.sunday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
