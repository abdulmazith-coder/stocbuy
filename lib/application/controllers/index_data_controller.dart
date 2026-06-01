import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stocbuy_application/application/models/index_quote.dart';
import 'package:stocbuy_application/application/models/index_rsi.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/index_data.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/market_rsi_dio.dart';
import 'package:timezone/timezone.dart' as tz;

enum RsiIndex { nifty, sensex }

class IndexDataController extends GetxController {
  IndexDataController({IndexDataDio? dio, MarketRsiDio? marketRsiDio})
    : _dio = dio ?? IndexDataDio(),
      _marketRsiDio = marketRsiDio ?? MarketRsiDio();

  static const Duration _pollInterval = Duration(seconds: 60);
  static const String _prefsKey = 'index_data_snapshot';
  static final tz.Location _ist = tz.getLocation('Asia/Kolkata');

  final IndexDataDio _dio;
  final MarketRsiDio _marketRsiDio;

  final Rxn<IndexQuote> nifty = Rxn<IndexQuote>();
  final Rxn<IndexQuote> sensex = Rxn<IndexQuote>();
  final Rxn<IndexRsi> niftyRsi = Rxn<IndexRsi>();
  final Rxn<IndexRsi> sensexRsi = Rxn<IndexRsi>();
  final selectedRsiIndex = RsiIndex.nifty.obs;
  final isLoading = false.obs;
  final isRsiLoading = false.obs;

  Timer? _pollTimer;
  bool _inFlight = false;
  bool _rsiInFlight = false;

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

  // ── Startup ──────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    await _loadSavedSnapshot();
    await Future.wait([fetchIndexData(), fetchIndexRsiData()]);
    _scheduleTimer();
  }

  // ── Scheduling ───────────────────────────────────────────────────────────

  /// Sets up either:
  ///   • a periodic 1-min timer  — when the market is currently open, OR
  ///   • a one-shot wake-up timer — set to fire at the next 09:15 IST weekday
  void _scheduleTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;

    final now = tz.TZDateTime.now(_ist);

    if (_isMarketOpen(now)) {
      // Market is open → poll every minute; each tick re-checks closing time.
      _pollTimer = Timer.periodic(_pollInterval, (_) => _onTick());
    } else {
      // Market is closed → sleep until the next 09:15 weekday open.
      final delay = _clamp(_nextOpenTime(now).difference(now));
      _pollTimer = Timer(delay, () async {
        await fetchIndexData();
        _scheduleTimer(); // re-enter: will now start the periodic timer
      });
    }
  }

  /// Called every minute while the market is open.
  void _onTick() {
    final now = tz.TZDateTime.now(_ist);
    if (!_isMarketOpen(now)) {
      // Market just closed mid-session → switch to the wake-up timer.
      _scheduleTimer();
      return;
    }
    unawaited(fetchIndexData());
    unawaited(fetchIndexRsiData());
  }

  // ── Network ───────────────────────────────────────────────────────────────

  Future<void> fetchIndexData() async {
    if (_inFlight) return;
    _inFlight = true;
    isLoading.value = true;
    try {
      final outcome = await _dio.fetchIndexData();
      if (outcome.ok) {
        if (outcome.nifty != null) nifty.value = outcome.nifty!;
        if (outcome.sensex != null) sensex.value = outcome.sensex!;
        await _saveSnapshot();
      }
    } finally {
      if (!isClosed) isLoading.value = false;
      _inFlight = false;
    }
  }

  Future<void> fetchIndexRsiData() async {
    if (_rsiInFlight) return;
    _rsiInFlight = true;
    isRsiLoading.value = true;
    try {
      final outcome = await _marketRsiDio.fetchMarketRsi();
      if (outcome.ok) {
        if (outcome.nifty != null) niftyRsi.value = outcome.nifty!;
        if (outcome.sensex != null) sensexRsi.value = outcome.sensex!;
        await _saveSnapshot();
      }
    } finally {
      if (!isClosed) isRsiLoading.value = false;
      _rsiInFlight = false;
    }
  }

  IndexRsi? get selectedRsi {
    return selectedRsiIndex.value == RsiIndex.sensex
        ? sensexRsi.value
        : niftyRsi.value;
  }

  String get selectedRsiTitle {
    return selectedRsiIndex.value == RsiIndex.sensex
        ? 'Sensex RSI'
        : 'Nifty RSI';
  }

  void setSelectedRsiIndex(RsiIndex index) {
    selectedRsiIndex.value = index;
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadSavedSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return;
      nifty.value = IndexQuote.fromJson(
        Map<String, dynamic>.from(json['nifty'] ?? {}),
      );
      sensex.value = IndexQuote.fromJson(
        Map<String, dynamic>.from(json['sensex'] ?? {}),
      );
      final rsiJson = json['rsi'];
      if (rsiJson is Map<String, dynamic>) {
        niftyRsi.value = IndexRsi.fromJson(
          Map<String, dynamic>.from(rsiJson['nifty'] ?? rsiJson['NIFTY'] ?? {}),
        );
        sensexRsi.value = IndexRsi.fromJson(
          Map<String, dynamic>.from(
            rsiJson['sensex'] ?? rsiJson['SENSEX'] ?? {},
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(<String, dynamic>{
          if (nifty.value != null) 'nifty': nifty.value!.toJson(),
          if (sensex.value != null) 'sensex': sensex.value!.toJson(),
          if (niftyRsi.value != null || sensexRsi.value != null)
            'rsi': <String, dynamic>{
              if (niftyRsi.value != null) 'nifty': niftyRsi.value!.toJson(),
              if (sensexRsi.value != null) 'sensex': sensexRsi.value!.toJson(),
            },
        }),
      );
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns true only on weekdays between 09:15 and 15:30 IST (inclusive).
  static bool _isMarketOpen(tz.TZDateTime t) {
    if (t.weekday == DateTime.saturday || t.weekday == DateTime.sunday) {
      return false;
    }
    final minutes = t.hour * 60 + t.minute;
    return minutes >= 9 * 60 + 15 && minutes <= 15 * 60 + 30;
  }

  /// Returns the next 09:15 IST on a weekday (Mon–Fri).
  static tz.TZDateTime _nextOpenTime(tz.TZDateTime now) {
    var candidate = tz.TZDateTime(
      tz.getLocation('Asia/Kolkata'),
      now.year,
      now.month,
      now.day,
      9,
      15,
    );
    // If today's 09:15 has already passed, move to tomorrow.
    if (!now.isBefore(candidate)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    // Skip weekends.
    while (candidate.weekday == DateTime.saturday ||
        candidate.weekday == DateTime.sunday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static Duration _clamp(Duration d) =>
      d.inMilliseconds <= 0 ? const Duration(seconds: 1) : d;
}
