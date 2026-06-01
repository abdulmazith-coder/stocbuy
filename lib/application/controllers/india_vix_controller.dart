import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stocbuy_application/application/models/india_vix_data.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/india_vix_data.dart';
import 'package:timezone/timezone.dart' as tz;

class IndiaVixController extends GetxController {
  IndiaVixController({IndiaVixDataDio? dio}) : _dio = dio ?? IndiaVixDataDio();

  static const Duration _pollInterval = Duration(seconds: 60);
  static const String _prefsKey = 'india_vix_snapshot';
  static final tz.Location _ist = tz.getLocation('Asia/Kolkata');

  final IndiaVixDataDio _dio;

  final Rxn<IndiaVixData> indiaVix = Rxn<IndiaVixData>();
  final isLoading = false.obs;

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

  // ── Startup ───────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    await _loadSavedSnapshot();
    await fetchIndiaVixData();   // single fetch on start; timer drives the rest
    _scheduleTimer();
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  /// Sets up either:
  ///   • a periodic 1-min timer  — when the market is currently open, OR
  ///   • a one-shot wake-up timer — fires at the next 09:15 IST weekday
  void _scheduleTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;

    final now = tz.TZDateTime.now(_ist);

    if (_isMarketOpen(now)) {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _onTick());
    } else {
      final delay = _clamp(_nextOpenTime(now).difference(now));
      _pollTimer = Timer(delay, () async {
        await fetchIndiaVixData();
        _scheduleTimer();   // re-enter: will now start the periodic timer
      });
    }
  }

  /// Called every minute while the market is open.
  void _onTick() {
    final now = tz.TZDateTime.now(_ist);
    if (!_isMarketOpen(now)) {
      // Market just closed mid-session → switch to the overnight wake-up timer.
      _scheduleTimer();
      return;
    }
    unawaited(fetchIndiaVixData());
  }

  // ── Network ───────────────────────────────────────────────────────────────

  Future<void> fetchIndiaVixData() async {
    if (_inFlight) return;
    _inFlight = true;
    isLoading.value = true;
    try {
      final outcome = await _dio.fetchIndiaVixData();
      if (outcome.ok && outcome.vix != null) {
        indiaVix.value = outcome.vix!;
        await _saveSnapshot();
      }
    } finally {
      if (!isClosed) isLoading.value = false;
      _inFlight = false;
    }
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadSavedSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return;
      indiaVix.value = IndiaVixData.fromJson(json);
    } catch (_) {}
  }

  Future<void> _saveSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = indiaVix.value?.toJson();
      if (payload == null) return;
      await prefs.setString(_prefsKey, jsonEncode(payload));
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
      now.year, now.month, now.day, 9, 15,
    );
    // If today's 09:15 has already passed, move to tomorrow.
    if (!now.isBefore(candidate)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    // Skip Saturday and Sunday.
    while (candidate.weekday == DateTime.saturday ||
           candidate.weekday == DateTime.sunday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static Duration _clamp(Duration d) =>
      d.inMilliseconds <= 0 ? const Duration(seconds: 1) : d;
}