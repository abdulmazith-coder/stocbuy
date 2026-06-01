// Flutter web implementation of the TradingView Advanced Chart embed.
//
// The widget mounts an off-DOM `<iframe srcdoc="…">` via
// [HtmlElementView]. The iframe boots a self-contained HTML document that
// loads TradingView's `embed-widget-advanced-chart.js` script with the
// configuration JSON inlined as the script element's text content (this
// is the exact pattern that TradingView's own copy-paste snippet uses).
//
// Each instance gets a unique `viewType` so multiple charts can co-exist
// on the same page without their iframes colliding.

// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class TradingViewChartView extends StatefulWidget {
  const TradingViewChartView({
    super.key,
    required this.symbol,
    this.exchange = 'BSE',
  });

  final String symbol;

  /// India-only by design — defaults to `BSE` (NSE feed isn't currently
  /// served by TradingView's free embed for most Indian listings, so we
  /// pin to the Bombay Stock Exchange ticker).
  final String exchange;

  @override
  State<TradingViewChartView> createState() => _TradingViewChartViewState();
}

class _TradingViewChartViewState extends State<TradingViewChartView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    final symbol = widget.symbol.toUpperCase();
    final exchange = widget.exchange.toUpperCase();

    // Unique view type so multiple chart embeds don't clobber each other.
    _viewType = 'tradingview-$exchange-$symbol-'
        '${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'fullscreen';
        // `srcdoc` runs the embedded document in its own browsing context,
        // so the TradingView script can boot normally.
        iframe.srcdoc = _buildHtml(symbol: symbol, exchange: exchange);
        return iframe;
      },
    );
  }

  String _buildHtml({required String symbol, required String exchange}) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100vh;
      width: 100vw;
      overflow: hidden;
      background: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
        Helvetica, Arial, sans-serif;
    }
  </style>
</head>
<body>
  <div class="tradingview-widget-container" style="height:100%;width:100%;">
    <div class="tradingview-widget-container__widget"
         style="height:calc(100% - 32px);width:100%;"></div>
    <div class="tradingview-widget-copyright"
         style="font-size:12px;line-height:32px;text-align:center;color:#9DB2BD;">
      <a href="https://in.tradingview.com/symbols/$exchange-$symbol/"
         rel="noopener nofollow" target="_blank"
         style="color:#3861FB;text-decoration:none;">
        Track all markets on TradingView
      </a>
    </div>
    <script type="text/javascript"
            src="https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js"
            async>
    {
      "allow_symbol_change": false,
      "calendar": false,
      "details": false,
      "hide_side_toolbar": false,
      "hide_top_toolbar": false,
      "hide_legend": false,
      "hide_volume": false,
      "hotlist": false,
      "interval": "3",
      "locale": "in",
      "save_image": true,
      "style": "1",
      "symbol": "$exchange:$symbol",
      "theme": "light",
      "timezone": "Asia/Kolkata",
      "backgroundColor": "#ffffff",
      "gridColor": "rgba(46, 46, 46, 0.06)",
      "watchlist": [],
      "withdateranges": false,
      "compareSymbols": [],
      "studies": [],
      "autosize": true
    }
    </script>
  </div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
