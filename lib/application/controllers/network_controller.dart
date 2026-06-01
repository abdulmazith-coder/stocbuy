import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/utils/network_status.dart'
    as ns;
import 'package:stocbuy_application/application/widgets/stocbuy_result_toast.dart';

/// Global connectivity state for the app.
///
/// Two signal sources feed [isOnline]:
///
/// 1.  **Proactive (web only).** [ns.listenToConnectivity] hooks the
///     browser's `online` / `offline` events. The moment the OS drops
///     wifi or the modem is unplugged, Chrome fires `offline` and the
///     banner appears within a frame — no request needed.
///
/// 2.  **Reactive (all platforms).** [DioClient]'s interceptor calls
///     [markOffline] on connection errors and [markOnline] on any
///     successful 2xx response. This is what catches "wifi looks fine
///     but the backend is dead" or "captive portal eating our packets",
///     and it's the only signal we have on mobile / desktop without an
///     extra connectivity plugin.
///
/// Both sources converge on a single [isOnline] flag so callers can
/// just `Obx((){ ... })` and not worry about the source.
class NetworkController extends GetxController {
  static NetworkController get to => Get.find<NetworkController>();

  /// `true` when the app believes it can reach the network.
  final isOnline = true.obs;

  Timer? _toastDebounce;

  @override
  void onInit() {
    super.onInit();
    isOnline.value = ns.isInitiallyOnline();
    ns.listenToConnectivity(
      onOnline: markOnline,
      onOffline: markOffline,
    );
  }

  @override
  void onClose() {
    _toastDebounce?.cancel();
    super.onClose();
  }

  /// Flag connectivity as broken. Safe to call repeatedly — only the
  /// first call in a streak fires the toast.
  void markOffline() {
    if (!isOnline.value) return;
    isOnline.value = false;
    _fireToast(
      kind: StocbuyToastKind.error,
      title: 'You are offline',
      message: "Network is not working. Reconnect to keep prices live.",
    );
    if (kDebugMode) debugPrint('NetworkController: offline');
  }

  /// Flag connectivity as restored.
  void markOnline() {
    if (isOnline.value) return;
    isOnline.value = true;
    _fireToast(
      kind: StocbuyToastKind.success,
      title: 'Back online',
      message: 'Connection restored.',
    );
    if (kDebugMode) debugPrint('NetworkController: online');
  }

  /// Debounce so a burst of failures (or a quick flap on/off) doesn't
  /// stack toasts.
  void _fireToast({
    required StocbuyToastKind kind,
    required String title,
    required String message,
  }) {
    _toastDebounce?.cancel();
    _toastDebounce = Timer(const Duration(milliseconds: 150), () {
      showStocbuyResultToast(
        null,
        kind: kind,
        title: title,
        message: message,
      );
    });
  }
}
