/// Public entry-point for the TradingView "Advanced Chart" embed.
///
/// On Flutter web this conditionally re-exports the real implementation
/// (which mounts a `<iframe>` containing the TradingView widget script via
/// [HtmlElementView]). On every other platform we fall back to a tiny
/// placeholder so the rest of the app still compiles, since the widget is
/// JS-only.
///
/// Usage:
///   TradingViewChartView(symbol: 'TCS')           // → NSE:TCS
///   TradingViewChartView(symbol: 'TCS', exchange: 'BSE')
library;

export 'tradingview_chart_view_stub.dart'
    if (dart.library.html) 'tradingview_chart_view_web.dart';
