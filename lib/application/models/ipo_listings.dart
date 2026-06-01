import 'package:flutter/foundation.dart';

/// Exchange-side enum used by the IPO surface so callers don't have to
/// stringly-type `"nse"` / `"bse"` everywhere.
enum IpoExchange {
  nse,
  bse;

  String get label => switch (this) {
        IpoExchange.nse => 'NSE',
        IpoExchange.bse => 'BSE',
      };

  /// Official IPO listing page for this exchange — every IPO row taps
  /// out to its exchange's page (per product spec).
  String get officialIpoListingUrl => switch (this) {
        IpoExchange.nse =>
          'https://www.nseindia.com/market-data/all-upcoming-issues-ipo',
        IpoExchange.bse =>
          'https://www.bseindia.com/markets/publicissues/ipoissues?expandable=4&id=1&Type=p',
      };
}

/// Which calendar slot an IPO sits in. The endpoint splits these out for
/// us — we just preserve the distinction so the UI can stack a
/// "Current IPOs" header above an "Upcoming IPOs" header per exchange.
enum IpoBucket {
  current,
  upcoming;

  String get label => switch (this) {
        IpoBucket.current => 'Current IPOs',
        IpoBucket.upcoming => 'Upcoming IPOs',
      };
}

/// One NSE IPO row from `data.nse_current_ipo.data` / `nse_upcoming_ipo.data`.
///
/// The NSE feed is symbol-centric and gives us subscription telemetry
/// (`noOfTime` = "times subscribed"), which the UI surfaces as a small
/// "1.09×" chip on each row.
@immutable
class NseIpoItem {
  const NseIpoItem({
    required this.symbol,
    this.companyName,
    this.issueStartDate,
    this.issueEndDate,
    this.status,
    this.series,
    this.isBse,
    this.sharesBid,
    this.sharesOffered,
    this.subscribedTimes,
  });

  final String symbol;
  final String? companyName;
  final String? issueStartDate;
  final String? issueEndDate;

  /// Yfinance / NSE-style status string: `Active`, `Closed`, `Forthcoming`.
  final String? status;

  /// `SME` or `Mainboard` (case sensitive in the payload). The UI shows
  /// this as a small tag chip next to the company name.
  final String? series;

  /// String `"0"` / `"1"` in the payload — preserved as raw to avoid
  /// false-positive coercion of other truthy strings.
  final String? isBse;

  final num? sharesBid;
  final num? sharesOffered;

  /// Times subscribed (e.g. `1.09` ⇒ 1.09× the offer was bid).
  final double? subscribedTimes;

  factory NseIpoItem.fromJson(Map<String, dynamic> j) => NseIpoItem(
        symbol: _str(j['symbol']) ?? '',
        companyName: _str(j['companyName']),
        issueStartDate: _str(j['issueStartDate']),
        issueEndDate: _str(j['issueEndDate']),
        status: _str(j['status']),
        series: _str(j['series']),
        isBse: _str(j['isBse']),
        sharesBid: _num(j['noOfsharesBid'] ?? j['noOfSharesBid']),
        sharesOffered: _num(j['noOfSharesOffered']),
        subscribedTimes: _dbl(j['noOfTime']),
      );
}

/// One BSE IPO row from `data.bse_ipo.current_ipo` / `upcoming_ipo`.
///
/// The BSE feed uses Title-Case keys with units in parentheses
/// (`"Offer Price (₹)"`). Price is delivered as a string — `"41.00 - 43.00"`
/// for book-built issues or `"10.00"` for fixed-price.
@immutable
class BseIpoItem {
  const BseIpoItem({
    required this.securityName,
    this.exchangePlatform,
    this.startDate,
    this.endDate,
    this.offerPrice,
    this.faceValue,
    this.typeOfIssue,
    this.issueStatus,
  });

  final String securityName;
  final String? exchangePlatform;
  final String? startDate;
  final String? endDate;

  /// As-delivered offer price string (already includes any range / "₹"
  /// formatting nuance the backend chose). Empty string and `"-"` are
  /// normalised away.
  final String? offerPrice;
  final String? faceValue;

  /// `IPO`, `RI` (rights), `OTB` (offer to buy), `CMN` (common), etc.
  /// Surfaced as a small tag chip alongside the exchange platform.
  final String? typeOfIssue;
  final String? issueStatus;

  factory BseIpoItem.fromJson(Map<String, dynamic> j) => BseIpoItem(
        securityName: _str(j['Security Name']) ?? '',
        exchangePlatform: _str(j['Exchange Platform']),
        startDate: _str(j['Start Date']),
        endDate: _str(j['End Date']),
        offerPrice: _normalisePrice(_str(j['Offer Price (₹)'])),
        faceValue: _str(j['Face Value']),
        typeOfIssue: _str(j['Type of Issue']),
        issueStatus: _str(j['Issue Status']),
      );
}

/// Top-level container returned by the IPO controller. Holds the four
/// distinct buckets the backend hands back as a single payload.
@immutable
class IpoListings {
  const IpoListings({
    required this.nseCurrent,
    required this.nseUpcoming,
    required this.bseCurrent,
    required this.bseUpcoming,
  });

  const IpoListings.empty()
      : nseCurrent = const [],
        nseUpcoming = const [],
        bseCurrent = const [],
        bseUpcoming = const [];

  final List<NseIpoItem> nseCurrent;
  final List<NseIpoItem> nseUpcoming;
  final List<BseIpoItem> bseCurrent;
  final List<BseIpoItem> bseUpcoming;

  /// Convenience getter used by the controller's `unavailable` heuristic:
  /// if every bucket is empty after a successful fetch, we consider the
  /// payload effectively unavailable and surface the corresponding empty
  /// state in the UI.
  bool get isEmpty =>
      nseCurrent.isEmpty &&
      nseUpcoming.isEmpty &&
      bseCurrent.isEmpty &&
      bseUpcoming.isEmpty;

  int countFor(IpoExchange exchange, IpoBucket bucket) {
    return switch ((exchange, bucket)) {
      (IpoExchange.nse, IpoBucket.current) => nseCurrent.length,
      (IpoExchange.nse, IpoBucket.upcoming) => nseUpcoming.length,
      (IpoExchange.bse, IpoBucket.current) => bseCurrent.length,
      (IpoExchange.bse, IpoBucket.upcoming) => bseUpcoming.length,
    };
  }
}

// —— Cheap shared coercion helpers ——————————————————————————————————————

String? _str(dynamic v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

double? _dbl(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble().isFinite ? v.toDouble() : null;
  final s = '$v'.trim();
  if (s.isEmpty) return null;
  final d = double.tryParse(s);
  return (d != null && d.isFinite) ? d : null;
}

num? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  final s = '$v'.trim();
  if (s.isEmpty) return null;
  return num.tryParse(s);
}

/// The BSE feed renders "no price set yet" as the literal string `"-"`.
/// Strip that down so the UI can fall back to its "Price TBA" placeholder
/// without leaking the backend's sentinel into the rendered row.
String? _normalisePrice(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '-' || trimmed == '—') return null;
  return trimmed;
}
