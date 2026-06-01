import 'package:stocbuy_application/application/models/stock_detail.dart';
import 'package:stocbuy_application/application/utils/stock_formatters.dart';

/// Bare NSE/BSE ticker for feature APIs (`ITC`, not `itc` or `ITC.NS`).
String apiStockSymbol(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;

  final dot = s.lastIndexOf('.');
  if (dot > 0) {
    const suffixes = {'NS', 'NSE', 'BO', 'BSE', 'NSI'};
    if (suffixes.contains(s.substring(dot + 1).toUpperCase())) {
      s = s.substring(0, dot);
    }
  }

  return s.toUpperCase();
}

/// Builds a prompt the AI analysis endpoint can use to fetch statements.
String buildStockAnalysisPrompt({
  required String symbol,
  String? displayName,
  required String userPrompt,
}) {
  final ticker = apiStockSymbol(symbol);
  final name = displayName?.trim();
  final subject =
      name != null && name.isNotEmpty ? '$name ($ticker)' : ticker;
  final user = userPrompt.trim();

  if (user.isEmpty || _shouldUseDefaultAnalysisPrompt(user)) {
    return 'Run a full fundamental analysis for $subject. '
        'Include balance sheet, income statement, cash flow, shareholding, '
        'financial ratios, and recent news using live market data for this '
        'Indian stock on NSE.';
  }

  return 'For $subject: $user. '
      'Use live balance sheet, income statement, and cash flow data for '
      'this Indian stock where available.';
}

bool _shouldUseDefaultAnalysisPrompt(String user) {
  final lower = user.toLowerCase();
  if (lower.length < 12) return true;

  const keywords = [
    'balance sheet',
    'income statement',
    'cash flow',
    'profit',
    'loss',
    'revenue',
    'debt',
    'ratio',
    'shareholder',
    'shareholding',
    'news',
    'fundamental',
    'technical',
    'valuation',
    'full analysis',
    'analyse',
    'analyze',
    'analysis',
  ];
  return !keywords.any(lower.contains);
}

/// Optional snapshot from [StockDetail] (already on the details page).
String stockDetailContextBlock(StockDetail detail) {
  final lines = <String>[
    'Stock symbol: ${apiStockSymbol(detail.symbol)}',
    if (detail.displayName.isNotEmpty) 'Company: ${detail.displayName}',
    if (detail.sector != null && detail.sector!.trim().isNotEmpty)
      'Sector: ${detail.sector}',
    if (detail.currentPrice != null)
      'Current price: ${StockFormatters.price(detail.currentPrice)}',
    if (detail.changePercent != null)
      'Today change: ${StockFormatters.percent(detail.changePercent)}',
    if (detail.marketCap != null)
      'Market cap: ${StockFormatters.compactRupees(detail.marketCap)}',
    if (detail.trailingPE != null) 'Trailing P/E: ${detail.trailingPE}',
    if (detail.forwardPE != null) 'Forward P/E: ${detail.forwardPE}',
    if (detail.priceToBook != null) 'Price to book: ${detail.priceToBook}',
    if (detail.trailingEps != null) 'Trailing EPS: ${detail.trailingEps}',
    if (detail.debtToEquity != null) 'Debt to equity: ${detail.debtToEquity}',
    if (detail.returnOnEquity != null) 'ROE: ${detail.returnOnEquity}',
    if (detail.profitMargins != null)
      'Profit margin: ${_formatMargin(detail.profitMargins)}',
  ];

  if (lines.length <= 1) return '';

  return '\n\nPage snapshot (from stock-info):\n${lines.join('\n')}';
}

String _formatMargin(num? value) {
  if (value == null) return '—';
  final v = value.toDouble();
  final pct = v.abs() <= 1 ? v * 100 : v;
  return StockFormatters.percent(pct);
}

String composeStockAnalysisRequest({
  required String symbol,
  String? displayName,
  required String userPrompt,
  StockDetail? detailSnapshot,
}) {
  final prompt = buildStockAnalysisPrompt(
    symbol: symbol,
    displayName: displayName,
    userPrompt: userPrompt,
  );
  if (detailSnapshot == null) return prompt;
  return '$prompt${stockDetailContextBlock(detailSnapshot)}';
}
