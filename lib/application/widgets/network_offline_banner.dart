import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/network_controller.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// Slim full-width banner shown above the page chrome whenever
/// [NetworkController.isOnline] is `false`. Designed to feel like
/// Gmail's "You're offline" strip — unobtrusive but unmissable, never
/// blocks interaction, and animates in/out so the layout doesn't snap.
///
/// Mounted once in [HomePage] (and any other top-level scaffold that
/// wants it). The widget reads [NetworkController] from GetX, so make
/// sure it has been registered before the first frame.
class NetworkOfflineBanner extends StatelessWidget {
  const NetworkOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final net = Get.isRegistered<NetworkController>()
        ? Get.find<NetworkController>()
        : null;
    if (net == null) return const SizedBox.shrink();

    return Obx(() {
      final offline = !net.isOnline.value;
      return AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: offline
              ? const _OfflineStrip(key: ValueKey('offline'))
              : const SizedBox.shrink(key: ValueKey('online')),
        ),
      );
    });
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.red,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.wifi_off_rounded,
                size: 16,
                color: AppColors.white,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Network is not working. You're offline — "
                  "live prices and account features are paused.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
