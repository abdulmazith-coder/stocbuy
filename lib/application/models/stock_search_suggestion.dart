import 'package:stocbuy_application/application/models/stock_search_result.dart';

/// One row in the search UI: merges duplicate API rows (e.g. NSE + BSE) into a
/// single suggestion with combined exchange labels.
class StockSearchSuggestion {
  const StockSearchSuggestion({
    required this.headlineSymbol,
    required this.companyLine,
    required this.typeLabel,
    required this.exchangesLine,
    required this.primaryResult,
  });

  /// Short ticker without `.NS` / `.BO` (e.g. `TCS`, `RELIANCE`).
  final String headlineSymbol;

  final String companyLine;
  final String typeLabel;

  /// e.g. `NSE & BSE` when the same stock is listed twice.
  final String exchangesLine;

  /// Prefer NSE listing for navigation when both exist.
  final StockSearchResult primaryResult;
}

/// Combines rows that share the same underlying ticker (e.g. `RELIANCE.NS` + `RELIANCE.BO`).
List<StockSearchSuggestion> mergeStockSearchResults(List<StockSearchResult> raw) {
  final keyOrder = <String>[];
  final groups = <String, List<StockSearchResult>>{};

  for (final r in raw) {
    if (r.symbol.trim().isEmpty) continue;
    final key = _mergeKey(r);
    if (!groups.containsKey(key)) {
      keyOrder.add(key);
      groups[key] = <StockSearchResult>[];
    }
    groups[key]!.add(r);
  }

  return keyOrder.map((k) => _fromGroup(groups[k]!)).toList(growable: false);
}

/// Same underlying ticker (e.g. `RELIANCE` for `.NS` and `.BO`) → one row.
String _mergeKey(StockSearchResult r) => _baseTicker(r.symbol);

String _baseTicker(String symbol) {
  final s = symbol.trim().toUpperCase();
  if (s.isEmpty) return s;
  final dot = s.lastIndexOf('.');
  if (dot <= 0 || dot >= s.length - 1) return s;
  final suf = s.substring(dot + 1);
  const suffixes = {'NS', 'NSE', 'BO', 'BSE', 'NSI', 'NE'};
  if (suffixes.contains(suf)) {
    return s.substring(0, dot);
  }
  return s;
}

StockSearchSuggestion _fromGroup(List<StockSearchResult> group) {
  if (group.length == 1) {
    final r = group.first;
    return StockSearchSuggestion(
      headlineSymbol: _baseTicker(r.symbol),
      companyLine: r.displaySubtitle,
      typeLabel: r.typeDisp?.toLowerCase() ?? '—',
      exchangesLine: _shortExchangeLabel(r),
      primaryResult: r,
    );
  }

  group.sort((a, b) => _exchangeRank(_canonicalExchange(a)).compareTo(_exchangeRank(_canonicalExchange(b))));

  StockSearchResult primary = group.first;
  for (final r in group) {
    if (_canonicalExchange(r) == 'NSE') {
      primary = r;
      break;
    }
  }

  final base = _baseTicker(group.first.symbol);
  var company = primary.displaySubtitle;
  for (final r in group) {
    if (r.displaySubtitle.trim().isNotEmpty) {
      company = r.displaySubtitle;
      break;
    }
  }

  var typeLower = primary.typeDisp?.toLowerCase() ?? '—';
  for (final r in group) {
    final t = r.typeDisp?.trim();
    if (t != null && t.isNotEmpty) {
      typeLower = t.toLowerCase();
      break;
    }
  }

  final labels = <String>{};
  for (final r in group) {
    final c = _canonicalExchange(r);
    if (c.isNotEmpty) labels.add(c);
  }
  final exchangesLine = labels.isEmpty
      ? '—'
      : (labels.toList()..sort((a, b) => _exchangeRank(a).compareTo(_exchangeRank(b)))).join(' & ');

  return StockSearchSuggestion(
    headlineSymbol: base,
    companyLine: company,
    typeLabel: typeLower,
    exchangesLine: exchangesLine,
    primaryResult: primary,
  );
}

String _shortExchangeLabel(StockSearchResult r) {
  final c = _canonicalExchange(r);
  return c.isEmpty ? '—' : c;
}

/// Maps API labels to short `NSE` / `BSE` style names.
String _canonicalExchange(StockSearchResult r) {
  final disp = (r.exchDisp ?? '').trim();
  final ex = (r.exchange ?? '').trim();
  final combined = '$disp $ex'.toUpperCase();

  if (combined.contains('NSE') || combined == 'NS' || combined.contains('NSI')) {
    return 'NSE';
  }
  if (combined.contains('BSE') || combined == 'BO' || combined.contains('BOMBAY')) {
    return 'BSE';
  }

  final sym = r.symbol.toUpperCase();
  if (sym.endsWith('.NS') || sym.endsWith('.NSE')) return 'NSE';
  if (sym.endsWith('.BO') || sym.endsWith('.BSE')) return 'BSE';

  if (disp.isNotEmpty) return disp.toUpperCase();
  if (ex.isNotEmpty) return ex.toUpperCase();
  return '';
}

int _exchangeRank(String label) {
  switch (label) {
    case 'NSE':
      return 0;
    case 'BSE':
      return 1;
    default:
      return 10;
  }
}
