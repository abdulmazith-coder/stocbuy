import 'dart:async';

import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/models/top_company.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/top_gain_stocks.dart';
import 'package:stocbuy_application/application/utils/market_hours.dart';

/// Which Indian exchange to surface in the markets section.
enum StockExchange { nse, bse }

/// Drives the **Top Gainers** and **Top Losers** tabs in the markets section.
///
/// Each call to the endpoint returns NSE *and* BSE rows in a single payload,
/// so one network round trip populates both buckets for the same kind.
///
/// Caching: each kind is cached for [cacheTtl] (1 minute). User-triggered
/// re-entry inside the TTL window returns the cached lists without hitting
/// the network. The auto-poller force-refreshes every minute *only* while the
/// Indian market is open (09:15 – 15:30 IST). Outside trading hours the cache
/// is kept indefinitely (cleared naturally when the app/web tab is closed).
///
/// Auth: top-gainers is a public route. Top-losers requires authentication —
/// when the user is logged out (or a 401 surfaces after a refresh attempt)
/// [losersRequiresLogin] flips to `true` so the UI can show a login prompt.
class TopGainLossController extends GetxController {
  TopGainLossController({TopGainAndLossStocksDio? dio})
      : _dio = dio ?? TopGainAndLossStocksDio();

  /// Time-to-live for a fetched payload. Re-entries within this window reuse
  /// the cached lists; refreshes outside it (or `force: true`) hit the API.
  static const Duration cacheTtl = Duration(minutes: 1);

  /// Auto-poll cadence — 1 minute. Gated by [isWithinIndianMarketHours].
  static const Duration _pollInterval = Duration(minutes: 1);

  final TopGainAndLossStocksDio _dio;

  // Per-exchange lists. Updated atomically when a fetch completes.
  final gainersNse = <TopCompany>[].obs;
  final gainersBse = <TopCompany>[].obs;
  final losersNse = <TopCompany>[].obs;
  final losersBse = <TopCompany>[].obs;

  final isLoadingGainers = false.obs;
  final isLoadingLosers = false.obs;

  /// True once a fetch (or the no-auth short-circuit) has completed. The UI
  /// uses it to tell "still spinning up" apart from "loaded with zero rows".
  final hasFetchedGainers = false.obs;
  final hasFetchedLosers = false.obs;

  /// `true` when the user must log in to see Top Losers (logged out or 401).
  final losersRequiresLogin = false.obs;

  /// Timestamps of the last successful fetch — used by the UI's "Live /
  /// Last updated" indicator. `null` until the first successful fetch.
  final Rxn<DateTime> gainersUpdatedAt = Rxn<DateTime>();
  final Rxn<DateTime> losersUpdatedAt = Rxn<DateTime>();

  bool _gainersInFlight = false;
  bool _losersInFlight = false;
  DateTime? _gainersFetchedAt;
  DateTime? _losersFetchedAt;
  Timer? _pollTimer;
  Worker? _authListener;

  @override
  void onInit() {
    super.onInit();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _onPollTick());

    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      losersRequiresLogin.value = !auth.isLoggedIn.value;
      _authListener = ever<bool>(auth.isLoggedIn, _onAuthChanged);
    } else {
      // No auth controller registered → assume logged out for safety.
      losersRequiresLogin.value = true;
    }
  }

  @override
  void onClose() {
    _authListener?.dispose();
    _authListener = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    super.onClose();
  }

  /// Reactive accessor — pick the gainers list for [exchange].
  RxList<TopCompany> gainersFor(StockExchange exchange) =>
      exchange == StockExchange.nse ? gainersNse : gainersBse;

  /// Reactive accessor — pick the losers list for [exchange].
  RxList<TopCompany> losersFor(StockExchange exchange) =>
      exchange == StockExchange.nse ? losersNse : losersBse;

  /// Fetches gainers when the cache is stale. Pass `force: true` to bypass.
  Future<void> ensureGainersLoaded({bool force = false}) async {
    if (_gainersInFlight) return;
    if (!force && _isFresh(_gainersFetchedAt)) return;
    _gainersInFlight = true;
    isLoadingGainers.value = true;
    try {
      final outcome = await _dio.getTopGainStocks();
      if (isClosed) return;
      if (outcome.ok) {
        gainersNse.assignAll(outcome.nse);
        gainersBse.assignAll(outcome.bse);
        final now = DateTime.now();
        _gainersFetchedAt = now;
        gainersUpdatedAt.value = now;
      }
    } finally {
      if (!isClosed) {
        isLoadingGainers.value = false;
        hasFetchedGainers.value = true;
      }
      _gainersInFlight = false;
    }
  }

  /// Fetches losers when the cache is stale and the user is logged in.
  /// When logged out, no network call is made and [losersRequiresLogin] is
  /// set so the UI can prompt for login.
  Future<void> ensureLosersLoaded({bool force = false}) async {
    if (_losersInFlight) return;

    final auth = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final loggedIn = auth?.isLoggedIn.value ?? false;
    if (!loggedIn) {
      _markLosersLoginRequired();
      return;
    }

    if (!force && _isFresh(_losersFetchedAt)) return;

    _losersInFlight = true;
    isLoadingLosers.value = true;
    try {
      final outcome = await _dio.getTopLossStocks();
      if (isClosed) return;
      if (outcome.unauthorized) {
        _markLosersLoginRequired();
      } else if (outcome.ok) {
        losersRequiresLogin.value = false;
        losersNse.assignAll(outcome.nse);
        losersBse.assignAll(outcome.bse);
        final now = DateTime.now();
        _losersFetchedAt = now;
        losersUpdatedAt.value = now;
      }
    } finally {
      if (!isClosed) {
        isLoadingLosers.value = false;
        hasFetchedLosers.value = true;
      }
      _losersInFlight = false;
    }
  }

  Future<void> refreshGainers() => ensureGainersLoaded(force: true);

  Future<void> refreshLosers() => ensureLosersLoaded(force: true);

  Future<void> refreshAll() async {
    await Future.wait([refreshGainers(), refreshLosers()]);
  }

  /// React to login / logout so Top Losers warms (or clears) automatically.
  void _onAuthChanged(bool loggedIn) {
    if (isClosed) return;
    if (loggedIn) {
      losersRequiresLogin.value = false;
      _losersFetchedAt = null;
      losersUpdatedAt.value = null;
      // Treat the post-login state as a first load so the dashboard shows the
      // spinner once (not the empty placeholder) until losers arrive.
      hasFetchedLosers.value = false;
      unawaited(ensureLosersLoaded(force: true));
    } else {
      _markLosersLoginRequired();
    }
  }

  void _markLosersLoginRequired() {
    losersRequiresLogin.value = true;
    losersNse.clear();
    losersBse.clear();
    _losersFetchedAt = null;
    losersUpdatedAt.value = null;
    hasFetchedLosers.value = true;
  }

  void _onPollTick() {
    if (isClosed) return;
    if (!isWithinIndianMarketHours()) return;
    if (hasFetchedGainers.value) {
      unawaited(refreshGainers());
    }
    if (hasFetchedLosers.value && !losersRequiresLogin.value) {
      unawaited(refreshLosers());
    }
  }

  bool _isFresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < cacheTtl;
}
