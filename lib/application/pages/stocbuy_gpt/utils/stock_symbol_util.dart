/// Parses `RELIANCE: analyze this stock` → symbol + prompt.
({String symbol, String prompt})? parseSymbolPrefixPrompt(String text) {
  final trimmed = text.trim();
  final colon = trimmed.indexOf(':');
  if (colon <= 0 || colon >= trimmed.length - 1) return null;

  final symbolPart = trimmed.substring(0, colon).trim();
  final promptPart = trimmed.substring(colon + 1).trim();
  if (symbolPart.isEmpty || promptPart.isEmpty) return null;
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.\-]*$').hasMatch(symbolPart)) {
    return null;
  }

  return (
    symbol: normalizeStockSymbol(symbolPart),
    prompt: promptPart,
  );
}

/// Normalizes symbols for `features/ai-analysis/` (plain ticker, no suffix).
String normalizeStockSymbol(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;

  final dot = s.indexOf('.');
  if (dot > 0) {
    s = s.substring(0, dot);
  }

  return s.toLowerCase();
}

/// Display label (uppercase ticker).
String displayStockSymbol(String raw) =>
    normalizeStockSymbol(raw).toUpperCase();
