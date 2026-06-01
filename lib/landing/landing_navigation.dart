import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/navigation/app_routes.dart';
import 'package:stocbuy_application/application/pages/auth/auth_page.dart';
import 'package:stocbuy_application/application/pages/plan/plan_page.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/stocbuy_gpt_chat_page.dart';

/// Opens the main application dashboard.
void openApplicationDashboard() {
  Get.offAllNamed(AppRoutes.dashboard);
}

/// Opens Stocbuy AI inside the application shell.
void openApplicationAi() {
  Get.offAllNamed(AppRoutes.dashboard);
  Get.toNamed(StocbuyGptChatPage.route);
}

/// Opens in-app pricing (from landing "View Pricing" when already in app).
void openApplicationPricing() {
  Get.offAllNamed(AppRoutes.dashboard);
  Get.toNamed(PlanPage.route);
}

/// Login / sign-up on the landing page (uses the same auth flow as the app).
Future<void> openApplicationLogin(BuildContext context) async {
  await showAuthDialog(context, initialTab: AuthTab.login);
}
