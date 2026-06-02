import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/navigation/app_routes.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/tradingview/tradingview_chart_view.dart';

/// Route prefix for the full-screen TradingView chart page. The full path
/// is `/tradingview/<symbol>` (e.g. `/tradingview/TCS`).
const String stockTradingViewRouteBase = '/tradingview';
String stockTradingViewRouteFor(String symbol) =>
    '$stockTradingViewRouteBase/${_stripExchangeSuffix(symbol)}';

/// Args passed via [Get.toNamed] so the page can render the right symbol
/// title in the top bar without waiting for an API roundtrip.
///
/// The constructor normalises [symbol] by dropping the yfinance-style
/// exchange suffix (`.NS`, `.NSE`, `.BO`, `.BSE`, `.NSI`) — TradingView's
/// embed wants the bare ticker (`BSE:TCS`, not `BSE:TCS.NS`).
class StockTradingViewArgs {
  StockTradingViewArgs({
    required String symbol,
    this.displayName,
    this.exchange = 'BSE',
  }) : symbol = _stripExchangeSuffix(symbol.trim());

  final String symbol;
  final String? displayName;

  /// India-only — defaults to `BSE` because TradingView's free embed serves
  /// Indian listings reliably on the Bombay Stock Exchange feed.
  final String exchange;
}

/// Navigation helper used from the chart card.
Future<void> openStockTradingView(
  BuildContext context, {
  required String symbol,
  String? displayName,
  String exchange = 'BSE',
}) {
  final args = StockTradingViewArgs(
    symbol: symbol,
    displayName: displayName,
    exchange: exchange,
  );
  if (Get.key.currentState != null) {
    return Get.toNamed(
          stockTradingViewRouteFor(args.symbol),
          arguments: args,
        ) ??
        Future<void>.value();
  }
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => StockTradingViewPage(args: args)),
  );
}

String _resolveRouteSymbolFromPath(String routeBase, String? symbolFromParam) {
  final candidate = symbolFromParam?.trim();
  if (candidate != null && candidate.isNotEmpty) return candidate;

  final uri = Uri.base;
  final rawRoute = uri.fragment.isNotEmpty ? uri.fragment : uri.path;
  final normalized = rawRoute.startsWith('/')
      ? rawRoute.substring(1)
      : rawRoute;
  final path = normalized.split('?').first.trim();
  if (path.isEmpty) return '';

  final segments = path.split('/').where((segment) => segment.isNotEmpty);
  final list = segments.toList();
  if (list.length >= 2 && list[0] == routeBase.replaceFirst('/', '')) {
    return list[1].trim();
  }
  return '';
}

/// Builder used by [GetMaterialApp.getPages].
Widget stockTradingViewPageFromRoute() {
  final symbolFromParam = Get.parameters['symbol']?.trim() ?? '';
  final args = Get.arguments;
  StockTradingViewArgs effective;
  if (args is StockTradingViewArgs && args.symbol.isNotEmpty) {
    effective = args;
  } else {
    effective = StockTradingViewArgs(
      symbol: _resolveRouteSymbolFromPath(
        stockTradingViewRouteBase,
        symbolFromParam,
      ),
    );
  }
  return StockTradingViewPage(args: effective);
}

/// Drop the yfinance-style exchange suffix (`.NS`, `.NSE`, `.BO`, `.BSE`,
/// `.NSI`). Any value with no recognised suffix is returned unchanged.
String _stripExchangeSuffix(String s) {
  final dot = s.lastIndexOf('.');
  if (dot <= 0) return s;
  const suffixes = {'NS', 'NSE', 'BO', 'BSE', 'NSI'};
  if (suffixes.contains(s.substring(dot + 1).toUpperCase())) {
    return s.substring(0, dot);
  }
  return s;
}

/// Full-screen page that hosts the TradingView Advanced Chart for a given
/// Indian stock. The top bar only carries a back arrow + the stock title;
/// everything else is the live TradingView widget.
class StockTradingViewPage extends StatelessWidget {
  const StockTradingViewPage({super.key, required this.args});

  final StockTradingViewArgs args;

  @override
  Widget build(BuildContext context) {
    final symbol = args.symbol.toUpperCase();
    final exchange = args.exchange.toUpperCase();
    final name = args.displayName?.trim();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: AppColors.white,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).maybePop();
            } else {
              Get.offAllNamed(AppRoutes.dashboard);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.darkblue),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lightblue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.lightblue.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                symbol,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.lightblue,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                exchange,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkblue,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (name != null && name.isNotEmpty) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkblue,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.8),
          ),
        ),
      ),
      body: TradingViewChartView(symbol: symbol, exchange: exchange),
    );
  }
}
