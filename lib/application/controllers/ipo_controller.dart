import 'dart:async';

import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/models/ipo_listings.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/get_ipos.dart';

/// App-wide controller backing the Dashboard's IPO surface.
///
/// One singleton (registered as `permanent: true` in `main.dart`) because
/// IPO listings are the same across the app and refresh slowly (daily
/// cadence at most). Polling would be wasteful.
///
/// Lifecycle:
///   • Lazy first fetch the first time the UI subscribes to [listings]
///     via [ensureLoaded].
///   • Re-fetches when the auth state flips to logged-in (the endpoint
///     requires a Bearer token).
///   • Manual [refresh] bypasses the [cacheTtl] gate.
///   • A 401 / 403 flips [requiresLogin] so the UI can swap in a
///     "Login to see IPOs" pill instead of broken rows.
class IpoController extends GetxController {
  IpoController({IposDio? service}) : _service = service ?? IposDio();

  static const Duration cacheTtl = Duration(minutes: 30);

  final IposDio _service;

  /// Reactive snapshot — empty listings until the first fetch lands.
  final Rx<IpoListings> listings = const IpoListings.empty().obs;

  // —— Status flags ————————————————————————————————————————————————————
  final isLoading = false.obs;
  final hasFetched = false.obs;

  /// `true` once the controller has tried and confirmed the backend has
  /// no IPO payload — UI swaps the optimistic "Loading IPOs…" placeholder
  /// for the definitive "No IPOs available right now." message.
  final unavailable = false.obs;

  /// `true` if the IPO endpoint returned 401/403 (or the user is logged
  /// out at controller-init time). UI shows a login pill.
  final requiresLogin = false.obs;

  /// Stamp of the most recent successful fetch — exposed so the UI can
  /// show a "Updated 4 min ago" footer or similar if desired.
  final Rxn<DateTime> updatedAt = Rxn<DateTime>();

  DateTime? _fetchedAt;
  bool _inFlight = false;
  Worker? _authListener;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      requiresLogin.value = !auth.isLoggedIn.value;
      _authListener = ever<bool>(auth.isLoggedIn, _onAuthChanged);
    } else {
      requiresLogin.value = true;
    }
  }

  @override
  void onClose() {
    _authListener?.dispose();
    _authListener = null;
    super.onClose();
  }

  /// Lazy-fetch entry point — the UI calls this on mount. Safe to call
  /// from a `build` method indirectly (we defer to a microtask).
  void ensureLoaded() {
    if (requiresLogin.value) return;
    if (_isFresh(_fetchedAt, cacheTtl) && hasFetched.value) return;
    scheduleMicrotask(_load);
  }

  /// Manual refresh — bypasses TTL, used by the pull-to-refresh button
  /// in the IPO section header.
  @override
  Future<void> refresh() async {
    _fetchedAt = null;
    await _load(force: true);
  }

  void _onAuthChanged(bool loggedIn) {
    if (isClosed) return;
    if (loggedIn) {
      requiresLogin.value = false;
      _fetchedAt = null;
      hasFetched.value = false;
      unavailable.value = false;
      unawaited(_load());
    } else {
      requiresLogin.value = true;
      listings.value = const IpoListings.empty();
      hasFetched.value = false;
      unavailable.value = false;
      updatedAt.value = null;
      _fetchedAt = null;
    }
  }

  Future<void> _load({bool force = false}) async {
    if (_inFlight || isClosed) return;
    if (requiresLogin.value) return;
    if (!force && _isFresh(_fetchedAt, cacheTtl) && hasFetched.value) return;
    _inFlight = true;
    isLoading.value = true;
    try {
      final outcome = await _service.fetchIpos();
      if (isClosed) return;
      if (outcome.unauthorized) {
        requiresLogin.value = true;
        listings.value = const IpoListings.empty();
        return;
      }
      if (outcome.ok && outcome.data != null) {
        listings.value = outcome.data!;
        unavailable.value = outcome.data!.isEmpty;
        final now = DateTime.now();
        _fetchedAt = now;
        updatedAt.value = now;
      } else {
        unavailable.value = true;
      }
    } finally {
      if (!isClosed) {
        isLoading.value = false;
        hasFetched.value = true;
      }
      _inFlight = false;
    }
  }

  bool _isFresh(DateTime? at, Duration ttl) =>
      at != null && DateTime.now().difference(at) < ttl;
}
