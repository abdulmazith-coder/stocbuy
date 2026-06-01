



import 'package:flutter_dotenv/flutter_dotenv.dart';

class APISConfigs{
  static String baseURL = dotenv.env['BASE_URL'] ?? "";

// REGISTER
  static String signup = dotenv.env['SIGNUP'] ?? "";
  static String verifySignup = dotenv.env['VERIFY_SIGNUP'] ?? "";
  static String resendOtp = dotenv.env['RESEND_OTP'] ?? "";
  static String login = dotenv.env['LOGIN'] ?? "";
  static String logout = dotenv.env['LOGOUT'] ?? "";
  static String refreshToken = dotenv.env['REFRESH_TOKEN'] ?? "";

// APP FEATURES 

  static String aiAnalysis = dotenv.env['AI_ANALYSIS_URL'] ?? "";
  static String aiUsage = dotenv.env['AI_USAGE_URL'] ?? "";
  
// STOCK DATAS 
  static String stockInfo = dotenv.env['STOCK_INFO_URL'] ?? "";
  static String financials = dotenv.env['STOCK_FINANCIALS_URL'] ?? "";
  static String historicalData = dotenv.env['HISTORY_PRICE_URL'] ?? "";
  static String one_minuteData = dotenv.env['ONE_MINUTE_PRICE_URL'] ?? "";
  static String peers_companys = dotenv.env['PEERS_COMPANYS_URL'] ?? "";
  static String news = dotenv.env['COMPANY_NEWS_URL'] ?? "";
  static String targetPrice = dotenv.env['TRAGET_PRICE_URL'] ?? "";
  static String ipos = dotenv.env['IPOS_URL'] ?? "";
  static String index = dotenv.env['INDEX_URL'] ?? "";
  static String indiaVIX = dotenv.env['INDIA_VIX'] ?? "";
  static String marketStatus = dotenv.env['MARKET_STATUS'] ?? "";
  static String marketBreadth = dotenv.env['MARKET_BREADTH'] ?? "";
  static String marketRsi = dotenv.env['MARKET_RSI'] ?? "";
  static String noramlChat  = dotenv.env['NORMAL_CHAT_URL'] ?? "";
  static String stockFilter = dotenv.env['STOCK_FILTER'] ?? "";
  static String searchStock = dotenv.env['STOCK_SEARCH'] ?? "";
  static String topCompanies = dotenv.env['TOP_COMAPNIES'] ?? "";
  static String topGainStocks = dotenv.env['TOP_GAIN_STOCKS'] ?? "";
  static String topLossStocks = dotenv.env['TOP_LOSS_STOCKS'] ?? "";

}