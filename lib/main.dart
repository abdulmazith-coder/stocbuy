import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/controllers/ipo_controller.dart';
import 'package:stocbuy_application/application/controllers/index_data_controller.dart';
import 'package:stocbuy_application/application/controllers/market_status_controller.dart';
import 'package:stocbuy_application/application/controllers/network_controller.dart';
import 'package:stocbuy_application/application/controllers/top_companies_controller.dart';
import 'package:stocbuy_application/application/controllers/india_vix_controller.dart';
import 'package:stocbuy_application/application/controllers/market_breadth_controller.dart';
import 'package:stocbuy_application/application/controllers/ai_usage_controller.dart';
import 'package:stocbuy_application/application/controllers/stock_row_aux_controller.dart';
import 'package:stocbuy_application/application/controllers/top_gain_loss_controller.dart';
import 'package:stocbuy_application/application/navigation/app_navigator.dart';
import 'package:stocbuy_application/application/navigation/stock_details_route.dart';
import 'package:stocbuy_application/application/navigation/app_routes.dart';
import 'package:stocbuy_application/application/pages/plan/plan_page.dart';
import 'package:stocbuy_application/application/pages/homepage.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/stocbuy_gpt_chat_page.dart';
import 'package:stocbuy_application/landing/landing_page.dart';
import 'package:stocbuy_application/application/pages/stock_details/stock_tradingview_page.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';
import 'package:stocbuy_application/application/themes/application_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  tzdata.initializeTimeZones();
  // NetworkController must exist BEFORE DioClient.init() so the
  // interceptor's first request can already report online/offline.
  Get.put(NetworkController(), permanent: true);
  DioClient.init();
  await Get.putAsync<AuthController>(() async {
    final c = AuthController();
    await c.hydrate(); // hydrate before UI to avoid showing login again
    return c;
  }, permanent: true);
  Get.put(TopCompaniesController(), permanent: true);
  Get.put(MarketStatusController(), permanent: true);
  Get.put(IndexDataController(), permanent: true);
  Get.put(IndiaVixController(), permanent: true);
  Get.put(AiUsageController(), permanent: true);
  Get.put(MarketBreadthController(), permanent: true);
  Get.put(TopGainLossController(), permanent: true);
  Get.put(StockRowAuxController(), permanent: true);
  Get.put(IpoController(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: AppNavigator.rootKey,
      title: 'Stocbuy',
      debugShowCheckedModeBanner: false,
      theme: ApplicationTheme.lightTheme,
      initialRoute: AppRoutes.landing,
      getPages: [
        GetPage(name: AppRoutes.landing, page: () => const LandingPage()),
        GetPage(name: AppRoutes.dashboard, page: () => const HomePage()),
        GetPage(
          name: StocbuyGptChatPage.route,
          page: () => const StocbuyGptChatPage(),
          transition: Transition.rightToLeft,
          transitionDuration: const Duration(milliseconds: 260),
        ),
        GetPage(
          name: PlanPage.route,
          page: () => const PlanPage(),
          transition: Transition.rightToLeft,
          transitionDuration: const Duration(milliseconds: 260),
        ),
        // If the browser URL contains /AuthPage from a previous session,
        // avoid the "Could not navigate to initial route" warning.
        GetPage(name: '/AuthPage', page: () => const HomePage()),
        // Legacy bookmark: old builds used `/` for the dashboard.
        GetPage(name: '/HomePage', page: () => const HomePage()),
        GetPage(
          name: '$stockDetailsRouteBase/:symbol',
          page: stockDetailsPageFromRoute,
          transition: Transition.rightToLeft,
          transitionDuration: const Duration(milliseconds: 260),
        ),
        GetPage(
          name: '$stockTradingViewRouteBase/:symbol',
          page: stockTradingViewPageFromRoute,
          transition: Transition.rightToLeft,
          transitionDuration: const Duration(milliseconds: 260),
        ),
      ],
    );
  }
}
