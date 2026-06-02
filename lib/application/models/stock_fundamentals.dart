import 'package:flutter/foundation.dart';

/// One row of a balance sheet.
///
/// All money fields live as **raw rupees** (the wire shape) — the UI
/// formatter is the one that decides whether to render as `₹ X Cr` or just
/// a plain number. Storing raw values means we don't have to thread a
/// `unit` flag through every cell.
@immutable
class BalanceSheetRow {
  const BalanceSheetRow({
    required this.fiscalYear,
    // Assets
    this.totalAssets,
    this.currentAssets,
    this.cashAndCashEquivalents,
    this.cashAndShortTermInvestments,
    this.otherShortTermInvestments,
    this.accountsReceivable,
    this.otherReceivables,
    this.inventory,
    this.prepaidAssets,
    this.totalNonCurrentAssets,
    this.netPpe,
    this.grossPpe,
    this.accumulatedDepreciation,
    this.goodwill,
    this.otherIntangibleAssets,
    this.goodwillAndIntangibles,
    this.investmentsInFinancialAssets,
    // Liabilities
    this.totalLiabilities,
    this.currentLiabilities,
    this.accountsPayable,
    this.totalTaxPayable,
    this.payables,
    this.currentDebt,
    this.totalNonCurrentLiabilities,
    this.longTermDebt,
    this.totalDebt,
    // Equity / capital
    this.stockholdersEquity,
    this.totalEquityGrossMinority,
    this.minorityInterest,
    this.retainedEarnings,
    this.additionalPaidInCapital,
    this.commonStock,
    this.workingCapital,
    this.tangibleBookValue,
    this.investedCapital,
    this.netTangibleAssets,
    this.shareIssued,
    this.ordinaryShares,
  });

  final int fiscalYear;

  // Assets
  final double? totalAssets;
  final double? currentAssets;
  final double? cashAndCashEquivalents;
  final double? cashAndShortTermInvestments;
  final double? otherShortTermInvestments;
  final double? accountsReceivable;
  final double? otherReceivables;
  final double? inventory;
  final double? prepaidAssets;
  final double? totalNonCurrentAssets;
  final double? netPpe;
  final double? grossPpe;
  final double? accumulatedDepreciation;
  final double? goodwill;
  final double? otherIntangibleAssets;
  final double? goodwillAndIntangibles;
  final double? investmentsInFinancialAssets;

  // Liabilities
  final double? totalLiabilities;
  final double? currentLiabilities;
  final double? accountsPayable;
  final double? totalTaxPayable;
  final double? payables;
  final double? currentDebt;
  final double? totalNonCurrentLiabilities;
  final double? longTermDebt;
  final double? totalDebt;

  // Equity / capital
  final double? stockholdersEquity;
  final double? totalEquityGrossMinority;
  final double? minorityInterest;
  final double? retainedEarnings;
  final double? additionalPaidInCapital;
  final double? commonStock;
  final double? workingCapital;
  final double? tangibleBookValue;
  final double? investedCapital;
  final double? netTangibleAssets;

  /// Share counts are non-money — rendered without a ₹ Cr suffix.
  final double? shareIssued;
  final double? ordinaryShares;

  factory BalanceSheetRow.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) => _double(v);
    return BalanceSheetRow(
      fiscalYear: _year(json['date']),
      totalAssets: d(json['Total Assets']),
      currentAssets: d(json['Current Assets']),
      cashAndCashEquivalents: d(json['Cash And Cash Equivalents']),
      cashAndShortTermInvestments: d(
        json['Cash Cash Equivalents And Short Term Investments'],
      ),
      otherShortTermInvestments: d(json['Other Short Term Investments']),
      accountsReceivable: d(json['Accounts Receivable']),
      otherReceivables: d(json['Other Receivables']),
      inventory: d(json['Inventory']),
      prepaidAssets: d(json['Prepaid Assets']),
      totalNonCurrentAssets: d(json['Total Non Current Assets']),
      netPpe: d(json['Net PPE']),
      grossPpe: d(json['Gross PPE']),
      accumulatedDepreciation: d(json['Accumulated Depreciation']),
      goodwill: d(json['Goodwill']),
      otherIntangibleAssets: d(json['Other Intangible Assets']),
      goodwillAndIntangibles: d(json['Goodwill And Other Intangible Assets']),
      investmentsInFinancialAssets: d(json['Investmentin Financial Assets']),
      totalLiabilities: d(json['Total Liabilities Net Minority Interest']),
      currentLiabilities: d(json['Current Liabilities']),
      accountsPayable: d(json['Accounts Payable']),
      totalTaxPayable: d(json['Total Tax Payable']),
      payables: d(json['Payables']),
      currentDebt: d(json['Current Debt And Capital Lease Obligation']),
      totalNonCurrentLiabilities: d(
        json['Total Non Current Liabilities Net Minority Interest'],
      ),
      longTermDebt: d(json['Long Term Debt And Capital Lease Obligation']),
      totalDebt: d(json['Total Debt']),
      stockholdersEquity: d(json['Stockholders Equity']),
      totalEquityGrossMinority: d(json['Total Equity Gross Minority Interest']),
      minorityInterest: d(json['Minority Interest']),
      retainedEarnings: d(json['Retained Earnings']),
      additionalPaidInCapital: d(json['Additional Paid In Capital']),
      commonStock: d(json['Common Stock'] ?? json['Capital Stock']),
      workingCapital: d(json['Working Capital']),
      tangibleBookValue: d(json['Tangible Book Value']),
      investedCapital: d(json['Invested Capital']),
      netTangibleAssets: d(json['Net Tangible Assets']),
      shareIssued: d(json['Share Issued']),
      ordinaryShares: d(json['Ordinary Shares Number']),
    );
  }
}

/// One row of an income statement.
///
/// Same storage convention as [BalanceSheetRow]: raw rupees for money,
/// fractions for ratios (`Tax Rate For Calcs` = 0.245 ⇒ 24.5%), per-share
/// fields kept as-is.
@immutable
class IncomeStatementRow {
  const IncomeStatementRow({
    required this.fiscalYear,
    // Revenue & margins
    this.totalRevenue,
    this.operatingRevenue,
    this.costOfRevenue,
    this.grossProfit,
    // Operating
    this.operatingExpense,
    this.otherOperatingExpenses,
    this.sellingGeneralAdmin,
    this.depreciation,
    this.operatingIncome,
    // EBITDA / EBIT
    this.ebitda,
    this.normalizedEbitda,
    this.ebit,
    // Non-operating
    this.interestExpense,
    this.interestIncome,
    this.netInterestIncome,
    this.otherNonOperatingIncomeExpenses,
    this.specialIncomeCharges,
    this.totalUnusualItems,
    // Tax & net income
    this.pretaxIncome,
    this.taxProvision,
    this.taxRate,
    this.netIncome,
    this.netIncomeCommonStockholders,
    this.netIncomeContinuousOperations,
    this.normalizedIncome,
    this.minorityInterests,
    // Per share
    this.dilutedEps,
    this.basicEps,
    this.dilutedAverageShares,
    this.basicAverageShares,
    // Totals
    this.totalExpenses,
  });

  final int fiscalYear;

  final double? totalRevenue;
  final double? operatingRevenue;
  final double? costOfRevenue;
  final double? grossProfit;

  final double? operatingExpense;
  final double? otherOperatingExpenses;
  final double? sellingGeneralAdmin;
  final double? depreciation;
  final double? operatingIncome;

  final double? ebitda;
  final double? normalizedEbitda;
  final double? ebit;

  final double? interestExpense;
  final double? interestIncome;
  final double? netInterestIncome;
  final double? otherNonOperatingIncomeExpenses;
  final double? specialIncomeCharges;
  final double? totalUnusualItems;

  final double? pretaxIncome;
  final double? taxProvision;

  /// Effective tax rate, 0..1 fraction (e.g. `0.245` ⇒ 24.5%).
  final double? taxRate;

  final double? netIncome;
  final double? netIncomeCommonStockholders;
  final double? netIncomeContinuousOperations;
  final double? normalizedIncome;
  final double? minorityInterests;

  /// Per-share figures rendered as plain numbers (no ₹ Cr suffix).
  final double? dilutedEps;
  final double? basicEps;
  final double? dilutedAverageShares;
  final double? basicAverageShares;

  final double? totalExpenses;

  factory IncomeStatementRow.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) => _double(v);
    return IncomeStatementRow(
      fiscalYear: _year(json['date']),
      totalRevenue: d(json['Total Revenue']),
      operatingRevenue: d(json['Operating Revenue']),
      costOfRevenue: d(
        json['Cost Of Revenue'] ?? json['Reconciled Cost Of Revenue'],
      ),
      grossProfit: d(json['Gross Profit']),
      operatingExpense: d(json['Operating Expense']),
      otherOperatingExpenses: d(json['Other Operating Expenses']),
      sellingGeneralAdmin: d(json['Selling General And Administration']),
      depreciation: d(
        json['Depreciation And Amortization In Income Statement'],
      ),
      operatingIncome: d(json['Operating Income']),
      ebitda: d(json['EBITDA']),
      normalizedEbitda: d(json['Normalized EBITDA']),
      ebit: d(json['EBIT']),
      interestExpense: d(json['Interest Expense']),
      interestIncome: d(json['Interest Income']),
      netInterestIncome: d(json['Net Interest Income']),
      otherNonOperatingIncomeExpenses: d(
        json['Other Non Operating Income Expenses'],
      ),
      specialIncomeCharges: d(json['Special Income Charges']),
      totalUnusualItems: d(json['Total Unusual Items']),
      pretaxIncome: d(json['Pretax Income']),
      taxProvision: d(json['Tax Provision']),
      taxRate: d(json['Tax Rate For Calcs']),
      netIncome: d(json['Net Income']),
      netIncomeCommonStockholders: d(json['Net Income Common Stockholders']),
      netIncomeContinuousOperations: d(
        json['Net Income Continuous Operations'],
      ),
      normalizedIncome: d(json['Normalized Income']),
      minorityInterests: d(json['Minority Interests']),
      dilutedEps: d(json['Diluted EPS']),
      basicEps: d(json['Basic EPS']),
      dilutedAverageShares: d(json['Diluted Average Shares']),
      basicAverageShares: d(json['Basic Average Shares']),
      totalExpenses: d(json['Total Expenses']),
    );
  }
}

/// One row of a cash-flow statement.
@immutable
class CashFlowRow {
  const CashFlowRow({
    required this.fiscalYear,
    this.operatingCashFlow,
    this.investingCashFlow,
    this.financingCashFlow,
    this.freeCashFlow,
    this.capitalExpenditure,
    this.netChangeInCash,
    this.beginningCashPosition,
    this.endCashPosition,
    this.effectOfExchangeRateChanges,
    // Operating items
    this.depreciationAndAmortization,
    this.deferredTax,
    this.changeInWorkingCapital,
    this.changeInReceivables,
    this.changeInPayable,
    this.changeInInventory,
    this.taxesRefundPaid,
    this.netIncomeFromContinuingOps,
    // Investing items
    this.netInvestmentPurchaseAndSale,
    this.purchaseOfInvestment,
    this.saleOfInvestment,
    this.purchaseOfPpe,
    this.netPpePurchaseAndSale,
    this.netBusinessPurchaseAndSale,
    this.netIntangiblesPurchaseAndSale,
    this.interestReceivedCfi,
    this.dividendsReceivedCfi,
    // Financing items
    this.cashDividendsPaid,
    this.repurchaseOfCapitalStock,
    this.issuanceOfCapitalStock,
    this.interestPaidCff,
    this.netCommonStockIssuance,
  });

  final int fiscalYear;

  final double? operatingCashFlow;
  final double? investingCashFlow;
  final double? financingCashFlow;
  final double? freeCashFlow;
  final double? capitalExpenditure;
  final double? netChangeInCash;
  final double? beginningCashPosition;
  final double? endCashPosition;
  final double? effectOfExchangeRateChanges;

  final double? depreciationAndAmortization;
  final double? deferredTax;
  final double? changeInWorkingCapital;
  final double? changeInReceivables;
  final double? changeInPayable;
  final double? changeInInventory;
  final double? taxesRefundPaid;
  final double? netIncomeFromContinuingOps;

  final double? netInvestmentPurchaseAndSale;
  final double? purchaseOfInvestment;
  final double? saleOfInvestment;
  final double? purchaseOfPpe;
  final double? netPpePurchaseAndSale;
  final double? netBusinessPurchaseAndSale;
  final double? netIntangiblesPurchaseAndSale;
  final double? interestReceivedCfi;
  final double? dividendsReceivedCfi;

  final double? cashDividendsPaid;
  final double? repurchaseOfCapitalStock;
  final double? issuanceOfCapitalStock;
  final double? interestPaidCff;
  final double? netCommonStockIssuance;

  factory CashFlowRow.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) => _double(v);
    return CashFlowRow(
      fiscalYear: _year(json['date']),
      operatingCashFlow: d(json['Operating Cash Flow']),
      investingCashFlow: d(json['Investing Cash Flow']),
      financingCashFlow: d(json['Financing Cash Flow']),
      freeCashFlow: d(json['Free Cash Flow']),
      capitalExpenditure: d(json['Capital Expenditure']),
      netChangeInCash: d(json['Changes In Cash']),
      beginningCashPosition: d(json['Beginning Cash Position']),
      endCashPosition: d(json['End Cash Position']),
      effectOfExchangeRateChanges: d(json['Effect Of Exchange Rate Changes']),
      depreciationAndAmortization: d(json['Depreciation And Amortization']),
      deferredTax: d(json['Deferred Tax']),
      changeInWorkingCapital: d(json['Change In Working Capital']),
      changeInReceivables: d(json['Change In Receivables']),
      changeInPayable: d(json['Change In Payable']),
      changeInInventory: d(json['Change In Inventory']),
      taxesRefundPaid: d(json['Taxes Refund Paid']),
      netIncomeFromContinuingOps: d(
        json['Net Income From Continuing Operations'],
      ),
      netInvestmentPurchaseAndSale: d(json['Net Investment Purchase And Sale']),
      purchaseOfInvestment: d(json['Purchase Of Investment']),
      saleOfInvestment: d(json['Sale Of Investment']),
      purchaseOfPpe: d(json['Purchase Of PPE']),
      netPpePurchaseAndSale: d(json['Net PPE Purchase And Sale']),
      netBusinessPurchaseAndSale: d(json['Net Business Purchase And Sale']),
      netIntangiblesPurchaseAndSale: d(
        json['Net Intangibles Purchase And Sale'],
      ),
      interestReceivedCfi: d(json['Interest Received Cfi']),
      dividendsReceivedCfi: d(json['Dividends Received Cfi']),
      cashDividendsPaid: d(json['Cash Dividends Paid']),
      repurchaseOfCapitalStock: d(json['Repurchase Of Capital Stock']),
      issuanceOfCapitalStock: d(json['Issuance Of Capital Stock']),
      interestPaidCff: d(json['Interest Paid Cff']),
      netCommonStockIssuance: d(json['Net Common Stock Issuance']),
    );
  }
}

/// Shareholding breakdown (percentages, sum ≈ 100).
///
/// Primary source: `share_holders` on `features/stock-financial-data/`
/// (`insidersPercentHeld`, `institutionsPercentHeld` as 0–1 fractions).
///
/// Fallback: `stock-info` (`heldPercentInsiders`, `heldPercentInstitutions`).
///
/// Institution totals are surfaced in [foreignInstitutions] (with
/// [domesticInstitutions] = 0) until the API splits FII vs DII. The pie
/// widget hides zero-valued slices.
@immutable
class ShareholdingBreakdown {
  const ShareholdingBreakdown({
    required this.asOf,
    required this.promoters,
    required this.foreignInstitutions,
    required this.domesticInstitutions,
    required this.publicRetail,
    required this.others,
  });

  final DateTime asOf;
  final double promoters;
  final double foreignInstitutions;
  final double domesticInstitutions;
  final double publicRetail;
  final double others;

  /// Latest row from `stock-financial-data` → `share_holders` (fractions
  /// 0–1 converted to chart %). Returns `null` when the list is missing or
  /// has no usable values.
  static ShareholdingBreakdown? fromShareHoldersList(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        rows.add(e);
      } else if (e is Map) {
        rows.add(Map<String, dynamic>.from(e));
      }
    }
    if (rows.isEmpty) return null;
    rows.sort((a, b) {
      final da = _parseShareHolderDate(a['date']);
      final db = _parseShareHolderDate(b['date']);
      if (da != null && db != null) return db.compareTo(da);
      if (da != null) return -1;
      if (db != null) return 1;
      return 0;
    });
    for (final row in rows) {
      final b = _fromShareHolderRow(row);
      if (b != null) return b;
    }
    return null;
  }

  /// Build a breakdown from the `stock-info` payload. Returns `null` when
  /// the response doesn't carry any usable percentages.
  static ShareholdingBreakdown? fromStockInfo(Map<String, dynamic> info) {
    final insiders = (_double(info['heldPercentInsiders']) ?? 0) * 100;
    final institutions = (_double(info['heldPercentInstitutions']) ?? 0) * 100;
    if (insiders <= 0 && institutions <= 0) return null;
    final remainder = (100 - insiders - institutions)
        .clamp(0.0, 100.0)
        .toDouble();
    return ShareholdingBreakdown(
      asOf: DateTime.now(),
      promoters: insiders,
      foreignInstitutions: institutions,
      domesticInstitutions: 0,
      publicRetail: remainder,
      others: 0,
    );
  }

  static ShareholdingBreakdown? _fromShareHolderRow(Map<String, dynamic> row) {
    final insidersFrac = _double(row['insidersPercentHeld']) ?? 0;
    final instFrac = _double(row['institutionsPercentHeld']) ?? 0;
    if (insidersFrac <= 0 && instFrac <= 0) return null;
    final promoters = (insidersFrac * 100).clamp(0.0, 100.0);
    final institutions = (instFrac * 100).clamp(0.0, 100.0);
    final publicRetail = (100.0 - promoters - institutions)
        .clamp(0.0, 100.0)
        .toDouble();
    final asOf = _parseShareHolderDate(row['date']) ?? DateTime.now();
    return ShareholdingBreakdown(
      asOf: asOf,
      promoters: promoters,
      foreignInstitutions: institutions,
      domesticInstitutions: 0,
      publicRetail: publicRetail,
      others: 0,
    );
  }
}

DateTime? _parseShareHolderDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty || s == 'Value' || s == '-' || s == '—') return null;
  return DateTime.tryParse(s);
}

/// One news / corporate-action headline.
@immutable
class StockNewsItem {
  const StockNewsItem({
    required this.headline,
    required this.source,
    required this.publishedAt,
    this.summary,
    this.url,
  });

  final String headline;
  final String source;
  final DateTime publishedAt;
  final String? summary;
  final String? url;

  /// Parses one row from `GET features/company-news/` (`title`, `time`, `link`).
  static StockNewsItem? tryFromCompanyNewsRow(dynamic row) {
    if (row is! Map) return null;
    final map = row is Map<String, dynamic>
        ? row
        : Map<String, dynamic>.from(row);

    final content = <String, dynamic>{};
    if (map['content'] is Map) {
      content.addAll(Map<String, dynamic>.from(map['content']));
    }
    content.addAll(map);

    var title = content['title']?.toString().trim() ?? '';
    if (title.isEmpty) {
      title = content['headline']?.toString().trim() ?? '';
    }
    title = _stripSurroundingQuotes(title);

    final summary = content['summary']?.toString().trim();
    final fallbackSummary = content['description']?.toString().trim();
    final link =
        content['link']?.toString().trim() ??
        (content['clickThroughUrl'] is Map
            ? content['clickThroughUrl']['url']?.toString().trim()
            : null) ??
        (content['canonicalUrl'] is Map
            ? content['canonicalUrl']['url']?.toString().trim()
            : null) ??
        content['previewUrl']?.toString().trim() ??
        '';

    if (title.isEmpty) return null;

    final timeRaw =
        content['time']?.toString().trim() ??
        content['displayTime']?.toString().trim() ??
        content['pubDate']?.toString().trim();
    final publishedAt = DateTime.tryParse(timeRaw ?? '') ?? DateTime.now();

    var source = 'News';
    if (content['provider'] is Map) {
      final provider = Map<String, dynamic>.from(content['provider']);
      source = provider['displayName']?.toString().trim() ?? source;
    }
    if (source.isEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null && uri.hasAuthority) {
        var host = uri.host.toLowerCase();
        if (host.startsWith('www.')) host = host.substring(4);
        if (host.isNotEmpty) source = host;
      }
    }

    return StockNewsItem(
      headline: title,
      source: source.isNotEmpty ? source : 'News',
      publishedAt: publishedAt,
      summary: summary?.isNotEmpty == true ? summary : fallbackSummary,
      url: link.isNotEmpty ? link : null,
    );
  }
}

String _stripSurroundingQuotes(String s) {
  if (s.length >= 2) {
    final first = s[0];
    final last = s[s.length - 1];
    if ((first == "'" || first == '"') && first == last) {
      return s.substring(1, s.length - 1).trim();
    }
  }
  return s;
}

/// Bundle for the financial-statement section of the Stock Details page.
@immutable
class StockFundamentals {
  const StockFundamentals({
    this.balanceSheet = const <BalanceSheetRow>[],
    this.incomeStatement = const <IncomeStatementRow>[],
    this.cashFlow = const <CashFlowRow>[],
    this.shareholding,
    this.news = const <StockNewsItem>[],
  });

  final List<BalanceSheetRow> balanceSheet;
  final List<IncomeStatementRow> incomeStatement;
  final List<CashFlowRow> cashFlow;
  final ShareholdingBreakdown? shareholding;
  final List<StockNewsItem> news;

  /// True only when every section is empty / unset. Useful to decide
  /// whether the card cluster should show a single empty state.
  bool get isEmpty =>
      balanceSheet.isEmpty &&
      incomeStatement.isEmpty &&
      cashFlow.isEmpty &&
      shareholding == null &&
      news.isEmpty;

  /// Build from `stock-financial-data` (statements + `share_holders`) and
  /// optional `stock-info` (shareholding fallback when `share_holders` is
  /// absent).
  ///
  /// `news` is filled from `features/company-news/` on the stock details
  /// screen; this factory leaves it empty unless passed explicitly.
  factory StockFundamentals.fromJson({
    Map<String, dynamic>? financials,
    Map<String, dynamic>? info,
    List<StockNewsItem> news = const <StockNewsItem>[],
  }) {
    final balance = <BalanceSheetRow>[];
    final income = <IncomeStatementRow>[];
    final cash = <CashFlowRow>[];

    if (financials != null) {
      balance.addAll(
        _rowsFrom(
          financials['balance_sheet'],
          (m) => BalanceSheetRow.fromJson(m),
        ),
      );
      income.addAll(
        _rowsFrom(
          financials['income_statement'],
          (m) => IncomeStatementRow.fromJson(m),
        ),
      );
      cash.addAll(
        _rowsFrom(financials['cash_flow'], (m) => CashFlowRow.fromJson(m)),
      );
    }

    // Latest fiscal year first → handier for tables that read left-to-right
    // with the most-recent column on the right. (Sort ascending by year so
    // FY22 … FY26 read left → right in the rendered table.)
    balance.sort((a, b) => a.fiscalYear.compareTo(b.fiscalYear));
    income.sort((a, b) => a.fiscalYear.compareTo(b.fiscalYear));
    cash.sort((a, b) => a.fiscalYear.compareTo(b.fiscalYear));

    ShareholdingBreakdown? shareholding;
    if (financials != null) {
      shareholding = ShareholdingBreakdown.fromShareHoldersList(
        financials['share_holders'] ?? financials['shareholders'],
      );
    }
    shareholding ??= info != null
        ? ShareholdingBreakdown.fromStockInfo(info)
        : null;

    return StockFundamentals(
      balanceSheet: balance,
      incomeStatement: income,
      cashFlow: cash,
      shareholding: shareholding,
      news: news,
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

/// Pull the year out of an ISO-ish date string like "2026-03-31".
int _year(dynamic v) {
  if (v == null) return 0;
  final s = v.toString().trim();
  if (s.length < 4) return 0;
  return int.tryParse(s.substring(0, 4)) ?? 0;
}

/// Map a list of JSON rows through [build]; tolerates nulls, non-list
/// payloads, and rows that aren't maps.
Iterable<T> _rowsFrom<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) build,
) sync* {
  if (raw is! List) return;
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      yield build(item);
    } else if (item is Map) {
      yield build(Map<String, dynamic>.from(item));
    }
  }
}
