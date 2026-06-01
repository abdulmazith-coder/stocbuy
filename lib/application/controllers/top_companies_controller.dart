import 'dart:async';

import 'package:get/get.dart';
import 'package:stocbuy_application/application/models/top_company.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/top_companies.dart';
import 'package:stocbuy_application/application/utils/market_hours.dart';

/// Holds top-company quotes for the ticker and other dashboard surfaces.
class TopCompaniesController extends GetxController {
  TopCompaniesController({TopCompaniesDio? dio}) : _dio = dio ?? TopCompaniesDio();

  final TopCompaniesDio _dio;

  final quotes = <TopCompany>[].obs;
  final isLoading = false.obs;
  final lastFetchFailed = false.obs;

  /// Only re-fetches `top-companies/` — no other endpoints.
  ///
  /// Polling fires every minute but the network call is gated by Indian
  /// market hours (09:15 – 15:30 IST) to avoid wasted requests overnight.
  static const Duration pollInterval = Duration(minutes: 1);

  /// Re-entries / external triggers within this TTL return cached quotes
  /// without touching the network. The auto-poller bypasses it (force).
  static const Duration cacheTtl = Duration(minutes: 1);

  Timer? _pollTimer;
  bool _refreshInFlight = false;
  DateTime? _lastFetchedAt;

  /// Shown when the API returns nothing or fails (offline / dev).
  static const List<TopCompany> fallbackQuotes = [
    TopCompany(symbol: 'ITC', companyName: 'ITC Limited', currentPrice: 412.30, changePercent: 0.45),
    TopCompany(symbol: 'HINDUNILVR', companyName: 'Hindustan Unilever Limited', currentPrice: 2456.80, changePercent: -0.38),
    TopCompany(symbol: 'RELIANCE', companyName: 'Reliance Industries Limited', currentPrice: 2892.15, changePercent: 0.72),
    TopCompany(symbol: 'TCS', companyName: 'Tata Consultancy Services Limited', currentPrice: 3588.40, changePercent: -0.21),
    TopCompany(symbol: 'HDFCBANK', companyName: 'HDFC Bank Limited', currentPrice: 1687.25, changePercent: 0.55),
    TopCompany(symbol: 'INFY', companyName: 'Infosys Limited', currentPrice: 1524.60, changePercent: 0.18),
    TopCompany(symbol: 'ICICIBANK', companyName: 'ICICI Bank Limited', currentPrice: 1123.90, changePercent: -0.62),
    TopCompany(symbol: 'SBIN', companyName: 'State Bank of India', currentPrice: 758.45, changePercent: 0.91),
  ];

  List<TopCompany> get displayQuotes =>
      quotes.isNotEmpty ? quotes : fallbackQuotes;

  @override
  void onInit() {
    super.onInit();
    // Let the first frame paint (fallback quotes) before hitting the network.
    scheduleMicrotask(() {
      if (!isClosed) refresh();
    });
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (isClosed) return;
      if (!isWithinIndianMarketHours()) return;
      _doRefresh(force: true);
    });
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.onClose();
  }

  /// External / re-entry refresh. Honors the 1-minute cache TTL — repeated
  /// calls inside the window are no-ops and return the previously fetched
  /// `quotes` unchanged. Pass `force: true` (via [forceRefresh]) to bypass.
  @override
  Future<void> refresh() => _doRefresh(force: false);

  /// Bypass the TTL — primarily for explicit pull-to-refresh / dev controls.
  Future<void> forceRefresh() => _doRefresh(force: true);

  Future<void> _doRefresh({required bool force}) async {
    if (_refreshInFlight || isClosed) return;
    if (!force && _isFresh()) return;
    _refreshInFlight = true;
    isLoading.value = true;
    try {
      final result = await _dio.fetchTopCompanies();
      if (isClosed) return;

      if (result.ok) {
        lastFetchFailed.value = false;
        if (result.companies.isEmpty) {
          quotes.clear();
        } else {
          quotes.assignAll(_dedupeBySymbol(result.companies));
        }
        _lastFetchedAt = DateTime.now();
      } else {
        lastFetchFailed.value = true;
      }
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
      _refreshInFlight = false;
    }
  }

  bool _isFresh() =>
      _lastFetchedAt != null &&
      DateTime.now().difference(_lastFetchedAt!) < cacheTtl;
}

List<TopCompany> _dedupeBySymbol(List<TopCompany> list) {
  final seen = <String>{};
  final out = <TopCompany>[];
  for (final c in list) {
    final key = c.symbol.toUpperCase();
    if (seen.add(key)) out.add(c);
  }
  return out;
}
