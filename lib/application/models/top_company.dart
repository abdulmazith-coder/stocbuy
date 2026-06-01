import 'package:flutter/foundation.dart';

/// One row from `GET …/top-gain-stocks/` (or `top-loss-stocks/`).
///
/// The backend payload is the full yfinance-style record per stock, so
/// in addition to the basics (`symbol`, `companyName`, `currentPrice`,
/// `changePercent`) every row also carries the **already-fetched**
/// fundamentals the dashboard table needs:
///
///   • marketCap
///   • trailingPE / forwardPE
///   • trailingEps / forwardEps
///   • previousClose / dayHigh / dayLow / open
///   • volume / averageVolume
///   • 52-week low / high
///   • exchange (`NSE`, `NSI`, `BSE`)
///
/// Earlier versions of this model only kept `currentPrice + changePercent`
/// and the dashboard table had to fan out per-row `stock-info` calls to
/// hydrate Mcap / EPS / P/E. That fan-out is now redundant — read these
/// fields straight off the row.
///
/// All extra fields are nullable so older / partial payloads still parse.
@immutable
class TopCompany {
  const TopCompany({
    required this.symbol,
    this.companyName,
    required this.currentPrice,
    required this.changePercent,
    this.marketCap,
    this.trailingPE,
    this.forwardPE,
    this.trailingEps,
    this.forwardEps,
    this.previousClose,
    this.open,
    this.dayHigh,
    this.dayLow,
    this.volume,
    this.averageVolume,
    this.fiftyTwoWeekLow,
    this.fiftyTwoWeekHigh,
    this.exchange,
    this.sector,
    this.industry,
  });

  /// Short ticker (e.g. RELIANCE, TCS). Exchange suffix (`.NS`, `.BO`)
  /// is stripped during parsing.
  final String symbol;

  /// Full company name when provided by the API; optional for compact fallbacks.
  final String? companyName;

  final double currentPrice;

  /// Intraday or session change in **percent** (e.g. `-0.07` means −0.07%).
  final double changePercent;

  /// Trailing market capitalization in raw rupees (not crores).
  final num? marketCap;

  /// Trailing twelve-month P/E ratio.
  final double? trailingPE;

  /// Analyst-forecast forward P/E ratio.
  final double? forwardPE;

  /// Trailing twelve-month earnings per share.
  final double? trailingEps;

  /// Analyst-forecast forward earnings per share.
  final double? forwardEps;

  /// Yesterday's close — the baseline most exchanges use to compute
  /// "today's change". Useful for cross-checking the percent.
  final double? previousClose;

  /// Today's open / high / low.
  final double? open;
  final double? dayHigh;
  final double? dayLow;

  /// Today's traded volume + the trailing-3-month average for context.
  final num? volume;
  final num? averageVolume;

  /// 52-week range (used by sidebar / hover tooltips on the table).
  final double? fiftyTwoWeekLow;
  final double? fiftyTwoWeekHigh;

  /// `NSE`, `NSI` (NSE India), or `BSE`. Stamped from the `exchange`
  /// field in the payload, or `fullExchangeName` as a fallback.
  final String? exchange;

  /// Sector / industry tags — surfaced on the row tooltip and on the
  /// stock-details "About" card.
  final String? sector;
  final String? industry;

  bool get isUp => changePercent > 0;
  bool get isDown => changePercent < 0;
  bool get isFlat => changePercent == 0;

  String get displayName => (companyName != null && companyName!.trim().isNotEmpty)
      ? companyName!.trim()
      : symbol;

  factory TopCompany.fromJson(Map<String, dynamic> json) {
    // Accepts both our backend's snake_case keys and the Yahoo-Finance style
    // camelCase keys (`longName`, `regularMarketPrice`, …) used by the new
    // top-gain / top-loss endpoints.
    final rawCompany = json['company'] ??
        json['longName'] ??
        json['longname'] ??
        json['name'] ??
        json['shortName'];
    final rawTicker = json['symbol'] ??
        json['ticker'] ??
        json['stock_symbol'];

    final company = rawCompany != null ? '$rawCompany'.trim() : '';
    var ticker = rawTicker != null ? '$rawTicker'.trim() : '';
    ticker = ticker.isNotEmpty ? _stripExchangeSuffix(ticker) : '';

    final sym = ticker.isNotEmpty
        ? ticker
        : (company.isNotEmpty ? _tickerFromCompanyName(company) : '');

    final priceRaw = json['current_price'] ??
        json['currentPrice'] ??
        json['regularMarketPrice'];
    final changeRaw = json['change_percent'] ??
        json['regularMarketChangePercent'];

    final exchangeRaw = json['exchange'] ??
        json['fullExchangeName'] ??
        json['exchangeName'];
    String? exchange;
    if (exchangeRaw != null) {
      final e = '$exchangeRaw'.trim().toUpperCase();
      // Normalise yfinance's "NSI" → "NSE" for display.
      if (e == 'NSI') {
        exchange = 'NSE';
      } else if (e.isNotEmpty) {
        exchange = e;
      }
    }

    String? trim(dynamic v) {
      if (v == null) return null;
      final s = '$v'.trim();
      return s.isEmpty ? null : s;
    }

    return TopCompany(
      symbol: sym,
      companyName: company.isNotEmpty ? company : null,
      currentPrice: _parseDouble(priceRaw),
      changePercent: _parseDouble(changeRaw),
      marketCap: _parseNum(json['marketCap'] ?? json['market_cap']),
      trailingPE: _parseDoubleOrNull(json['trailingPE'] ?? json['trailing_pe']),
      forwardPE: _parseDoubleOrNull(json['forwardPE'] ?? json['forward_pe']),
      trailingEps: _parseDoubleOrNull(
        json['trailingEps'] ??
            json['epsTrailingTwelveMonths'] ??
            json['trailing_eps'],
      ),
      forwardEps: _parseDoubleOrNull(
        json['forwardEps'] ?? json['epsForward'] ?? json['forward_eps'],
      ),
      previousClose: _parseDoubleOrNull(
        json['previousClose'] ?? json['regularMarketPreviousClose'],
      ),
      open: _parseDoubleOrNull(json['open'] ?? json['regularMarketOpen']),
      dayHigh: _parseDoubleOrNull(
        json['dayHigh'] ?? json['regularMarketDayHigh'],
      ),
      dayLow: _parseDoubleOrNull(
        json['dayLow'] ?? json['regularMarketDayLow'],
      ),
      volume: _parseNum(json['volume'] ?? json['regularMarketVolume']),
      averageVolume: _parseNum(
        json['averageVolume'] ?? json['averageDailyVolume3Month'],
      ),
      fiftyTwoWeekLow: _parseDoubleOrNull(json['fiftyTwoWeekLow']),
      fiftyTwoWeekHigh: _parseDoubleOrNull(json['fiftyTwoWeekHigh']),
      exchange: exchange,
      sector: trim(json['sectorDisp'] ?? json['sector']),
      industry: trim(json['industryDisp'] ?? json['industry']),
    );
  }

  static String _stripExchangeSuffix(String s) {
    final u = s.toUpperCase();
    final dot = u.lastIndexOf('.');
    if (dot <= 0) return s;
    final suf = u.substring(dot + 1);
    const suffixes = {'NS', 'NSE', 'BO', 'BSE', 'NSI'};
    if (suffixes.contains(suf)) {
      return s.substring(0, dot);
    }
    return s;
  }

  static String _tickerFromCompanyName(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final abbr = parts.take(3).map((w) => w[0].toUpperCase()).join();
      if (abbr.length >= 2) return abbr;
    }
    return name.length <= 12 ? name.toUpperCase() : name.substring(0, 12).toUpperCase();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0;
    return 0;
  }

  /// Like [_parseDouble] but returns `null` instead of `0` when the value
  /// is missing — so "missing" and "explicitly zero" can be distinguished
  /// in the UI (a zero P/E is meaningful, a missing one is "—").
  static double? _parseDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final d = value.toDouble();
      return d.isNaN || d.isInfinite ? null : d;
    }
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty) return null;
      final d = double.tryParse(s);
      if (d == null || d.isNaN || d.isInfinite) return null;
      return d;
    }
    return null;
  }

  static num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty) return null;
      return num.tryParse(s);
    }
    return null;
  }

  static String formatChangeLabel(double changePercent) {
    if (changePercent == 0) return '0.00%';
    final sign = changePercent > 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }
}
