// ❌ இந்த import remove பண்ணு
// import 'package:flutter_dotenv/flutter_dotenv.dart';

class APISConfigs {
  static const String baseURL = "https://stocbuy.onrender.com/api/";

  // AUTH
  static const String signup        = "${baseURL}auth/signup/";
  static const String verifySignup  = "${baseURL}auth/verify-signup/";
  static const String resendOtp     = "${baseURL}auth/resend-otp/";
  static const String login         = "${baseURL}auth/login/";
  static const String logout        = "${baseURL}auth/logout/";
  static const String refreshToken  = "${baseURL}auth/refresh/";

  // AI
  static const String aiAnalysis    = "${baseURL}features/ai-analysis/";
  static const String aiUsage       = "${baseURL}features/ai-analysis-usage/";
  static const String noramlChat    = "${baseURL}features/normal-chat/";

  // STOCK
  static const String stockInfo     = "${baseURL}features/stock-info/";
  static const String financials    = "${baseURL}features/stock-financial-data/";
  static const String historicalData= "${baseURL}features/history-price/";
  static const String one_minuteData= "${baseURL}features/1m-price-history/";
  static const String peers_companys= "${baseURL}features/peers-companies/";
  static const String news          = "${baseURL}features/company-news/";
  static const String targetPrice   = "${baseURL}features/future-target/";
  static const String ipos          = "${baseURL}features/ipos/";
  static const String index         = "${baseURL}features/index-data/";
  static const String indiaVIX      = "${baseURL}features/indiavix-data/";
  static const String marketStatus  = "${baseURL}features/exchange-isactive/";
  static const String marketBreadth = "${baseURL}features/market-breadth/";
  static const String marketRsi     = "${baseURL}features/market-rsi/";
  static const String stockFilter   = "${baseURL}features/penny-stock-filter/";
  static const String searchStock   = "${baseURL}features/search-stock/";
  static const String topCompanies  = "${baseURL}features/top-companies/";
  static const String topGainStocks = "${baseURL}features/top-gain-stocks/";
  static const String topLossStocks = "${baseURL}features/top-loss-stocks/";
}