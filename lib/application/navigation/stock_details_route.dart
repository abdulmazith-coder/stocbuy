import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/models/top_company.dart';
import 'package:stocbuy_application/application/pages/stock_details/stock_details_page.dart';

/// Route prefix used in [GetMaterialApp.getPages].
///
/// The full route path is `/stocks/<symbol>`. Web URLs are shareable, e.g.
/// `https://app/#/stocks/TATACONSUM`.
const String stockDetailsRouteBase = '/stocks';
String stockDetailsRouteFor(String symbol) => '$stockDetailsRouteBase/$symbol';

/// Arguments passed via [Get.toNamed] / [Navigator.pushNamed] so the page can
/// hydrate immediately (symbol + last-known price + change %) while the full
/// detail loads in the background.
class StockDetailsArgs {
  const StockDetailsArgs({
    required this.symbol,
    this.companyName,
    this.initialPrice = 0,
    this.initialChangePercent = 0,
  });

  final String symbol;
  final String? companyName;
  final double initialPrice;
  final double initialChangePercent;

  factory StockDetailsArgs.fromTopCompany(TopCompany c) {
    return StockDetailsArgs(
      symbol: c.symbol,
      companyName: c.companyName,
      initialPrice: c.currentPrice,
      initialChangePercent: c.changePercent,
    );
  }
}

/// Open the [StockDetailsPage] for a given stock. Use this from anywhere
/// (dashboard rows, search overlay, watchlist, etc.) — it handles the
/// arg-passing and route-name plumbing in one place.
Future<void> openStockDetails(
  BuildContext context, {
  required String symbol,
  String? companyName,
  double initialPrice = 0,
  double initialChangePercent = 0,
}) {
  final args = StockDetailsArgs(
    symbol: symbol,
    companyName: companyName,
    initialPrice: initialPrice,
    initialChangePercent: initialChangePercent,
  );

  // Prefer Get routing when available so web URLs stay shareable, but fall
  // back to the local navigator (e.g. when the caller pops a dialog first).
  if (Get.key.currentState != null) {
    return Get.toNamed(stockDetailsRouteFor(symbol), arguments: args) ??
        Future<void>.value();
  }
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StockDetailsPage(args: args),
    ),
  );
}

/// Same as above but takes a [TopCompany] directly — saves the caller from
/// unpacking the fields by hand at every call site.
Future<void> openStockDetailsForCompany(BuildContext context, TopCompany c) {
  return openStockDetails(
    context,
    symbol: c.symbol,
    companyName: c.companyName,
    initialPrice: c.currentPrice,
    initialChangePercent: c.changePercent,
  );
}

/// Builder used by [GetMaterialApp.getPages] so the route can read both the
/// path parameter (`:symbol`) AND the typed [StockDetailsArgs] if passed.
Widget stockDetailsPageFromRoute() {
  final symbolFromParam = Get.parameters['symbol']?.trim() ?? '';
  final args = Get.arguments;
  StockDetailsArgs effective;
  if (args is StockDetailsArgs && args.symbol.isNotEmpty) {
    effective = args;
  } else {
    effective = StockDetailsArgs(symbol: symbolFromParam);
  }
  return StockDetailsPage(args: effective);
}
