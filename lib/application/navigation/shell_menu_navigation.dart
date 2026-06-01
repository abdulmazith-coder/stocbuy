import 'package:get/get.dart';
import 'package:stocbuy_application/application/navigation/app_routes.dart';
import 'package:stocbuy_application/application/pages/plan/plan_page.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/stocbuy_gpt_chat_page.dart';

/// Indices for [AppNavBar] / [ApplicationDrawer] items (order must match).
abstract final class AppMenuIndex {
  static const dashboard = 0;
  static const stocbuyAi = 1;
  static const ipos = 2;
  static const pricing = 3;
  static const watchlist = 4;

  /// Use on sub-routes (stock details, etc.) so no top tab looks selected.
  static const none = -1;
}

bool _isOnHome() {
  final route = Get.currentRoute;
  return route == AppRoutes.dashboard || route == '/HomePage';
}

/// One-step navigation from any page to the selected shell destination.
///
/// From [HomePage], Stocbuy AI and Pricing are pushed so Back returns to the
/// dashboard. From everywhere else (stock details, plan, etc.) the stack is
/// replaced so the user lands only on the target screen.
void navigateAppMenu(int index) {
  final route = Get.currentRoute;
  final onHome = _isOnHome();

  switch (index) {
    case AppMenuIndex.dashboard:
      if (onHome) return;
      Get.offAllNamed(AppRoutes.dashboard);
    case AppMenuIndex.stocbuyAi:
      if (route == StocbuyGptChatPage.route) return;
      if (onHome) {
        Get.toNamed(StocbuyGptChatPage.route);
      } else {
        Get.offAllNamed(StocbuyGptChatPage.route);
      }
    case AppMenuIndex.ipos:
      Get.offAllNamed(AppRoutes.dashboard, arguments: {'openIpos': true});
    case AppMenuIndex.pricing:
      if (route == PlanPage.route) return;
      if (onHome) {
        Get.toNamed(PlanPage.route);
      } else {
        Get.offAllNamed(PlanPage.route);
      }
    case AppMenuIndex.watchlist:
      if (onHome) return;
      Get.offAllNamed(AppRoutes.dashboard);
    default:
      if (!onHome) Get.offAllNamed(AppRoutes.dashboard);
  }
}
