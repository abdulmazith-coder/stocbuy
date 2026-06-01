import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/application/models/top_company.dart';

/// Snapshot of a single company officer (board member / executive).
@immutable
class StockOfficer {
  const StockOfficer({
    required this.name,
    this.title,
    this.age,
    this.totalPay,
  });

  final String name;
  final String? title;
  final int? age;
  final num? totalPay;

  factory StockOfficer.fromJson(Map<String, dynamic> json) {
    return StockOfficer(
      name: (json['name'] ?? '').toString().trim(),
      title: _str(json['title']),
      age: _int(json['age']),
      totalPay: _num(json['totalPay'] ?? json['total_pay']),
    );
  }
}

/// Full detail of a single stock — Yahoo-Finance-style fields, all optional
/// so partial backend responses still render cleanly.
@immutable
class StockDetail {
  const StockDetail({
    required this.symbol,
    this.shortName,
    this.longName,
    this.exchange,
    this.currency = 'INR',
    // Price
    this.currentPrice,
    this.previousClose,
    this.open,
    this.dayHigh,
    this.dayLow,
    this.changePercent,
    this.change,
    // Range
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekLow,
    this.fiftyDayAverage,
    this.twoHundredDayAverage,
    // Volume / cap
    this.volume,
    this.regularMarketVolume,
    this.averageVolume,
    this.marketCap,
    // Valuation
    this.trailingPE,
    this.forwardPE,
    this.priceToBook,
    this.priceToSalesTrailing12Months,
    this.enterpriseToRevenue,
    this.bookValue,
    this.trailingEps,
    this.forwardEps,
    this.pegRatio,
    this.trailingPegRatio,
    this.beta,
    // Dividend
    this.dividendRate,
    this.dividendYield,
    this.trailingAnnualDividendYield,
    this.fiveYearAvgDividendYield,
    this.payoutRatio,
    // India-specific extras (used on the details page sidebar)
    this.industryPE,
    this.evToEbitda,
    this.returnOnCapitalEmployed,
    this.faceValue,
    this.pledgedPercent,
    this.unpledgedPromoterHolding,
    // Holdings
    this.heldPercentInsiders,
    this.heldPercentInstitutions,
    // Financial health
    this.returnOnEquity,
    this.returnOnAssets,
    this.debtToEquity,
    this.quickRatio,
    this.currentRatio,
    this.profitMargins,
    this.grossMargins,
    this.operatingMargins,
    this.ebitdaMargins,
    // Growth
    this.earningsGrowth,
    this.revenueGrowth,
    this.earningsQuarterlyGrowth,
    // Per-share extras
    this.revenuePerShare,
    this.totalCashPerShare,
    this.totalRevenue,
    this.totalDebt,
    this.totalCash,
    // Analysts
    this.numberOfAnalystOpinions,
    this.recommendationKey,
    this.targetMeanPrice,
    this.targetHighPrice,
    this.targetLowPrice,
    // Company
    this.longBusinessSummary,
    this.sector,
    this.industry,
    this.website,
    this.phone,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.zip,
    this.country,
    this.fullTimeEmployees,
    this.officers = const <StockOfficer>[],
  });

  final String symbol;
  final String? shortName;
  final String? longName;
  final String? exchange;
  final String currency;

  final double? currentPrice;
  final double? previousClose;
  final double? open;
  final double? dayHigh;
  final double? dayLow;
  final double? changePercent;
  final double? change;

  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;
  final double? fiftyDayAverage;
  final double? twoHundredDayAverage;

  final num? volume;
  final num? regularMarketVolume;
  final num? averageVolume;
  final num? marketCap;

  final double? trailingPE;
  final double? forwardPE;
  final double? priceToBook;

  /// Price-to-sales (TTM) — `1.0` means market cap equals annual revenue.
  final double? priceToSalesTrailing12Months;

  /// Enterprise-value to revenue (TTM).
  final double? enterpriseToRevenue;

  final double? bookValue;
  final double? trailingEps;
  final double? forwardEps;
  final double? pegRatio;

  /// Trailing PEG ratio — same shape as [pegRatio] but uses TTM EPS growth.
  final double? trailingPegRatio;

  /// Beta vs the benchmark index.
  final double? beta;

  final double? dividendRate;

  /// Forward dividend yield, already expressed as a percent
  /// (e.g. `5.18` means 5.18%).
  final double? dividendYield;

  /// Trailing-twelve-month dividend yield as a 0..1 fraction
  /// (e.g. `0.0267` means 2.67%) — same units as [returnOnEquity].
  final double? trailingAnnualDividendYield;

  /// Five-year average dividend yield, already expressed as a percent.
  final double? fiveYearAvgDividendYield;

  final double? payoutRatio;

  /// Industry-average P/E ratio for the company's sector (Screener-style).
  final double? industryPE;

  /// Enterprise value to EBITDA.
  final double? evToEbitda;

  /// Return on capital employed (ratio 0..1, render via [ratioAsPercent]).
  final double? returnOnCapitalEmployed;

  /// Face / par value per share (₹).
  final double? faceValue;

  /// Percentage of promoter shares pledged (0..100).
  final double? pledgedPercent;

  /// Percentage of promoter holdings that are not pledged (0..100).
  final double? unpledgedPromoterHolding;

  /// Insiders / promoter holding as a 0..1 fraction (e.g. `0.718` → 71.8%).
  final double? heldPercentInsiders;

  /// Institutional holding as a 0..1 fraction.
  final double? heldPercentInstitutions;

  final double? returnOnEquity;
  final double? returnOnAssets;
  final double? debtToEquity;
  final double? quickRatio;
  final double? currentRatio;
  final double? profitMargins;
  final double? grossMargins;
  final double? operatingMargins;
  final double? ebitdaMargins;

  /// YoY earnings growth as a 0..1 fraction (`0.122` → 12.2%).
  final double? earningsGrowth;

  /// YoY revenue growth as a 0..1 fraction.
  final double? revenueGrowth;

  /// QoQ earnings growth as a 0..1 fraction.
  final double? earningsQuarterlyGrowth;

  /// Revenue per share (₹).
  final double? revenuePerShare;

  /// Total cash per share (₹).
  final double? totalCashPerShare;

  final num? totalRevenue;
  final num? totalDebt;
  final num? totalCash;

  final int? numberOfAnalystOpinions;
  final String? recommendationKey;
  final double? targetMeanPrice;
  final double? targetHighPrice;
  final double? targetLowPrice;

  final String? longBusinessSummary;
  final String? sector;
  final String? industry;
  final String? website;
  final String? phone;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? zip;
  final String? country;
  final num? fullTimeEmployees;

  final List<StockOfficer> officers;

  /// Best display name — prefers longName, falls back to symbol.
  String get displayName {
    final n = (longName ?? shortName ?? '').trim();
    return n.isNotEmpty ? n : symbol;
  }

  bool get isUp => (changePercent ?? 0) > 0;
  bool get isDown => (changePercent ?? 0) < 0;

  /// Convenience: merge in fresh values onto a previously cached detail (used
  /// when a 1-min refresh comes back and only price / change fields changed).
  StockDetail copyWithLivePrice({
    double? currentPrice,
    double? change,
    double? changePercent,
    double? dayHigh,
    double? dayLow,
    double? open,
    num? volume,
  }) {
    return StockDetail(
      symbol: symbol,
      shortName: shortName,
      longName: longName,
      exchange: exchange,
      currency: currency,
      currentPrice: currentPrice ?? this.currentPrice,
      previousClose: previousClose,
      open: open ?? this.open,
      dayHigh: dayHigh ?? this.dayHigh,
      dayLow: dayLow ?? this.dayLow,
      changePercent: changePercent ?? this.changePercent,
      change: change ?? this.change,
      fiftyTwoWeekHigh: fiftyTwoWeekHigh,
      fiftyTwoWeekLow: fiftyTwoWeekLow,
      fiftyDayAverage: fiftyDayAverage,
      twoHundredDayAverage: twoHundredDayAverage,
      volume: volume ?? this.volume,
      regularMarketVolume: regularMarketVolume,
      averageVolume: averageVolume,
      marketCap: marketCap,
      trailingPE: trailingPE,
      forwardPE: forwardPE,
      priceToBook: priceToBook,
      priceToSalesTrailing12Months: priceToSalesTrailing12Months,
      enterpriseToRevenue: enterpriseToRevenue,
      bookValue: bookValue,
      trailingEps: trailingEps,
      forwardEps: forwardEps,
      pegRatio: pegRatio,
      trailingPegRatio: trailingPegRatio,
      beta: beta,
      dividendRate: dividendRate,
      dividendYield: dividendYield,
      trailingAnnualDividendYield: trailingAnnualDividendYield,
      fiveYearAvgDividendYield: fiveYearAvgDividendYield,
      payoutRatio: payoutRatio,
      industryPE: industryPE,
      evToEbitda: evToEbitda,
      returnOnCapitalEmployed: returnOnCapitalEmployed,
      faceValue: faceValue,
      pledgedPercent: pledgedPercent,
      unpledgedPromoterHolding: unpledgedPromoterHolding,
      heldPercentInsiders: heldPercentInsiders,
      heldPercentInstitutions: heldPercentInstitutions,
      returnOnEquity: returnOnEquity,
      returnOnAssets: returnOnAssets,
      debtToEquity: debtToEquity,
      quickRatio: quickRatio,
      currentRatio: currentRatio,
      profitMargins: profitMargins,
      grossMargins: grossMargins,
      operatingMargins: operatingMargins,
      ebitdaMargins: ebitdaMargins,
      earningsGrowth: earningsGrowth,
      revenueGrowth: revenueGrowth,
      earningsQuarterlyGrowth: earningsQuarterlyGrowth,
      revenuePerShare: revenuePerShare,
      totalCashPerShare: totalCashPerShare,
      totalRevenue: totalRevenue,
      totalDebt: totalDebt,
      totalCash: totalCash,
      numberOfAnalystOpinions: numberOfAnalystOpinions,
      recommendationKey: recommendationKey,
      targetMeanPrice: targetMeanPrice,
      targetHighPrice: targetHighPrice,
      targetLowPrice: targetLowPrice,
      longBusinessSummary: longBusinessSummary,
      sector: sector,
      industry: industry,
      website: website,
      phone: phone,
      address1: address1,
      address2: address2,
      city: city,
      state: state,
      zip: zip,
      country: country,
      fullTimeEmployees: fullTimeEmployees,
      officers: officers,
    );
  }

  /// Build an instant skeleton from a [TopCompany] so the page can render
  /// the symbol / name / price immediately while the full detail loads.
  factory StockDetail.fromTopCompany(TopCompany company) {
    return StockDetail(
      symbol: company.symbol,
      shortName: company.companyName,
      longName: company.companyName,
      currentPrice: company.currentPrice,
      changePercent: company.changePercent,
    );
  }

  /// Parse a Yahoo-style payload (same shape as the gainers/losers rows).
  factory StockDetail.fromJson(Map<String, dynamic> json) {
    String? sym = _str(json['symbol'] ?? json['ticker'] ?? json['stock_symbol']);
    if (sym != null) sym = _stripExchangeSuffix(sym);

    final officersRaw = json['companyOfficers'] ?? json['officers'];
    final officers = <StockOfficer>[];
    if (officersRaw is List) {
      for (final o in officersRaw) {
        if (o is Map) officers.add(StockOfficer.fromJson(Map<String, dynamic>.from(o)));
      }
    }

    return StockDetail(
      symbol: sym ?? '',
      shortName: _str(json['shortName']),
      longName: _str(json['longName'] ?? json['longname'] ?? json['company']),
      exchange: _str(json['fullExchangeName'] ?? json['exchange']),
      currency: _str(json['currency']) ?? 'INR',
      currentPrice: _double(json['currentPrice'] ?? json['regularMarketPrice'] ?? json['current_price']),
      previousClose: _double(json['previousClose'] ?? json['regularMarketPreviousClose']),
      open: _double(json['open'] ?? json['regularMarketOpen']),
      dayHigh: _double(json['dayHigh'] ?? json['regularMarketDayHigh']),
      dayLow: _double(json['dayLow'] ?? json['regularMarketDayLow']),
      changePercent: _double(json['regularMarketChangePercent'] ?? json['change_percent']),
      change: _double(json['regularMarketChange']),
      fiftyTwoWeekHigh: _double(json['fiftyTwoWeekHigh']),
      fiftyTwoWeekLow: _double(json['fiftyTwoWeekLow']),
      fiftyDayAverage: _double(json['fiftyDayAverage']),
      twoHundredDayAverage: _double(json['twoHundredDayAverage']),
      volume: _num(json['volume'] ?? json['regularMarketVolume']),
      regularMarketVolume: _num(json['regularMarketVolume']),
      averageVolume: _num(json['averageVolume']),
      marketCap: _num(json['marketCap']),
      trailingPE: _double(json['trailingPE']),
      forwardPE: _double(json['forwardPE']),
      priceToBook: _double(json['priceToBook']),
      priceToSalesTrailing12Months: _double(
          json['priceToSalesTrailing12Months'] ?? json['price_to_sales']),
      enterpriseToRevenue: _double(json['enterpriseToRevenue']),
      bookValue: _double(json['bookValue']),
      trailingEps: _double(json['trailingEps'] ?? json['epsTrailingTwelveMonths']),
      forwardEps: _double(json['forwardEps'] ?? json['epsForward']),
      pegRatio: _double(json['pegRatio']),
      trailingPegRatio: _double(json['trailingPegRatio']),
      beta: _double(json['beta']),
      dividendRate: _double(json['dividendRate']),
      dividendYield: _double(json['dividendYield']),
      trailingAnnualDividendYield:
          _double(json['trailingAnnualDividendYield']),
      fiveYearAvgDividendYield:
          _double(json['fiveYearAvgDividendYield']),
      payoutRatio: _double(json['payoutRatio']),
      industryPE: _double(json['industryPE'] ?? json['industry_pe']),
      evToEbitda: _double(json['enterpriseToEbitda'] ?? json['evToEbitda']),
      returnOnCapitalEmployed:
          _double(json['returnOnCapitalEmployed'] ?? json['roce']),
      faceValue: _double(json['faceValue'] ?? json['face_value']),
      pledgedPercent:
          _double(json['pledgedPercent'] ?? json['pledged_percent']),
      unpledgedPromoterHolding: _double(
          json['unpledgedPromoterHolding'] ?? json['unpledged_promoter_hold']),
      heldPercentInsiders: _double(json['heldPercentInsiders']),
      heldPercentInstitutions: _double(json['heldPercentInstitutions']),
      returnOnEquity: _double(json['returnOnEquity']),
      returnOnAssets: _double(json['returnOnAssets']),
      debtToEquity: _double(json['debtToEquity']),
      quickRatio: _double(json['quickRatio']),
      currentRatio: _double(json['currentRatio']),
      profitMargins: _double(json['profitMargins']),
      grossMargins: _double(json['grossMargins']),
      operatingMargins: _double(json['operatingMargins']),
      ebitdaMargins: _double(json['ebitdaMargins']),
      earningsGrowth: _double(json['earningsGrowth']),
      revenueGrowth: _double(json['revenueGrowth']),
      earningsQuarterlyGrowth:
          _double(json['earningsQuarterlyGrowth']),
      revenuePerShare: _double(json['revenuePerShare']),
      totalCashPerShare: _double(json['totalCashPerShare']),
      totalRevenue: _num(json['totalRevenue']),
      totalDebt: _num(json['totalDebt']),
      totalCash: _num(json['totalCash']),
      numberOfAnalystOpinions: _int(json['numberOfAnalystOpinions']),
      recommendationKey: _str(json['recommendationKey']),
      targetMeanPrice: _double(json['targetMeanPrice']),
      targetHighPrice: _double(json['targetHighPrice']),
      targetLowPrice: _double(json['targetLowPrice']),
      longBusinessSummary: _str(json['longBusinessSummary']),
      sector: _str(json['sectorDisp'] ?? json['sector']),
      industry: _str(json['industryDisp'] ?? json['industry']),
      website: _str(json['website']),
      phone: _str(json['phone']),
      address1: _str(json['address1']),
      address2: _str(json['address2']),
      city: _str(json['city']),
      state: _str(json['state']),
      zip: _str(json['zip']),
      country: _str(json['country']),
      fullTimeEmployees: _num(json['fullTimeEmployees']),
      officers: officers,
    );
  }
}

// —— internal parsers ————————————————————————————————————————————————————————

double? _double(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

num? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

String _stripExchangeSuffix(String s) {
  final dot = s.lastIndexOf('.');
  if (dot <= 0) return s;
  const suf = {'NS', 'NSE', 'BO', 'BSE', 'NSI'};
  if (suf.contains(s.substring(dot + 1).toUpperCase())) {
    return s.substring(0, dot);
  }
  return s;
}
