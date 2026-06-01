import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/peer_company.dart';
import 'package:stocbuy_application/application/models/stock_detail.dart';
import 'package:stocbuy_application/application/models/stock_fundamentals.dart';
import 'package:stocbuy_application/application/models/stock_ohlc.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';
import 'package:stocbuy_application/application/models/target_price_analysis.dart';


typedef StockInfoBundle = ({
  StockDetail detail,
  ShareholdingBreakdown? shareholding,
});

@immutable
class StockDetailsOutcome<T> {
  const StockDetailsOutcome({
    required this.ok,
    required this.unauthorized,
    this.data,
  });

  const StockDetailsOutcome.empty()
    : ok = false,
      unauthorized = false,
      data = null;
  const StockDetailsOutcome.unauthorizedRes()
    : ok = false,
      unauthorized = true,
      data = null;

  final bool ok;
  final bool unauthorized;
  final T? data;
}


class StockDetailsDio {
  StockDetailsDio({Dio? dio}) : _dio = dio ?? DioClient.dio;

  final Dio _dio;

  static final String _stockInfoPath = APISConfigs.stockInfo;
  static final String _financialsPath = APISConfigs.financials;
  static final String _historyPath = APISConfigs.historicalData;
  static final String _historyOneMinPath = APISConfigs.one_minuteData;
  static final String _peersPath = APISConfigs.peers_companys;
  static final String _companyNewsPath = APISConfigs.news;
  static final String _targetPricePath = APISConfigs.targetPrice;

  /// Fetch the live snapshot + ratios for [symbol], together with an
  /// optional shareholding breakdown from the same payload (fallback only).
  Future<StockDetailsOutcome<StockInfoBundle>> fetchStockInfo({
    required String symbol,
  }) async {
    return _get<StockInfoBundle>(
      path: _stockInfoPath,
      symbol: symbol,
      parse: (body) {
        final data = body['data'];
        if (data is! Map) return null;
        final raw = Map<String, dynamic>.from(data);
        final detail = StockDetail.fromJson(raw);
        final shareholding = ShareholdingBreakdown.fromStockInfo(raw);
        return (detail: detail, shareholding: shareholding);
      },
      tag: 'fetchStockInfo',
    );
  }


  Future<StockDetailsOutcome<StockFundamentals>> fetchFinancials({
    required String symbol,
    ShareholdingBreakdown? shareholding,
  }) async {
    return _get<StockFundamentals>(
      path: _financialsPath,
      symbol: symbol,
      parse: (body) {
        final data = body['data'];
        if (data is! Map) return null;
        final base = StockFundamentals.fromJson(
          financials: Map<String, dynamic>.from(data),
        );
        final mergedShareholding = base.shareholding ?? shareholding;
        return StockFundamentals(
          balanceSheet: base.balanceSheet,
          incomeStatement: base.incomeStatement,
          cashFlow: base.cashFlow,
          shareholding: mergedShareholding,
          news: base.news,
        );
      },
      tag: 'fetchFinancials',
    );
  }


  Future<StockDetailsOutcome<List<StockOhlc>>> fetchHistoryPrice({
    required String symbol,
    required ChartSelection selection,
  }) async {
    final (path, extra) = _historyTarget(selection);
    return _get<List<StockOhlc>>(
      path: path,
      symbol: symbol,
      extraQuery: extra,
      parse: _parseOhlcList,
      tag: 'fetchHistoryPrice[${selection.cacheKey}]',
    );
  }


  Future<StockDetailsOutcome<List<PeerCompany>>> fetchPeers({
    required String symbol,
  }) async {
    return _get<List<PeerCompany>>(
      path: _peersPath,
      symbol: symbol,
      parse: _parsePeerList,
      tag: 'fetchPeers',
    );
  }


  Future<StockDetailsOutcome<List<StockNewsItem>>> fetchCompanyNews({
    required String symbol,
    int days = 7,
  }) async {
    return _get<List<StockNewsItem>>(
      path: _companyNewsPath,
      symbol: symbol,
      extraQuery: {'days': '$days'},
      parse: _parseCompanyNewsList,
      tag: 'fetchCompanyNews',
    );
  }

  /// Fetch target price analysis for [symbol].
  ///
  /// Contains multiple valuation methods (P/E, P/B, EV/EBITDA),
  /// consensus, and analyst targets.
  Future<StockDetailsOutcome<TargetPriceAnalysis>> fetchTargetPrice({
    required String symbol,
  }) async {
    return _get<TargetPriceAnalysis>(
      path: _targetPricePath,
      symbol: symbol,
      parse: (body) {
        try {
          return TargetPriceAnalysis.fromJson(body);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing target price: $e');
          }
          return null;
        }
      },
      tag: 'fetchTargetPrice',
    );
  }

  static List<PeerCompany>? _parsePeerList(Map<String, dynamic> body) {


    dynamic raw = body['data'];
    if (raw is Map) {
      raw = (raw)['data'] ?? raw['peers'] ?? raw['rows'];
    }
    if (raw is! List) return const <PeerCompany>[];
    final out = <PeerCompany>[];
    for (final row in raw) {
      Map<String, dynamic>? map;
      if (row is Map<String, dynamic>) {
        map = row;
      } else if (row is Map) {
        map = Map<String, dynamic>.from(row);
      }
      if (map == null) continue;
      final peer = PeerCompany.fromJson(map);
      if (peer.symbol.isNotEmpty) out.add(peer);
    }
    return out;
  }

  /// Resolve the URL + query-params for a given [selection]. Pulled out so
  /// the per-mode wiring stays in one place.
  (String, Map<String, String>) _historyTarget(ChartSelection selection) {
    return switch (selection) {
      ChartSelectionOneMinuteLive() => (
        _historyOneMinPath,
        const <String, String>{},
      ),
      ChartSelectionQuickInterval(:final interval) => (
        _historyPath,
        {'timing': interval.code, 'istread': 'true'},
      ),
      ChartSelectionRangeInterval(:final range, :final interval) => (
        _historyPath,
        {'timing': range.code, 'interval': interval.code, 'istread': 'false'},
      ),
    };
  }


  static String _stripExchangeSuffix(String s) {
    final dot = s.lastIndexOf('.');
    if (dot <= 0) return s;
    const suffixes = {'NS', 'NSE', 'BO', 'BSE', 'NSI'};
    if (suffixes.contains(s.substring(dot + 1).toUpperCase())) {
      return s.substring(0, dot);
    }
    return s;
  }

  static List<StockNewsItem>? _parseCompanyNewsList(Map<String, dynamic> body) {
    final raw = body['data'];
    if (raw is! List) return const <StockNewsItem>[];
    final out = <StockNewsItem>[];
    for (final row in raw) {
      final item = StockNewsItem.tryFromCompanyNewsRow(row);
      if (item != null) out.add(item);
    }
    return out;
  }

  static List<StockOhlc>? _parseOhlcList(Map<String, dynamic> body) {
    final raw = body['data'];
    if (raw is! List) return const <StockOhlc>[];
    final out = <StockOhlc>[];
    for (final row in raw) {
      Map<String, dynamic>? map;
      if (row is Map<String, dynamic>) {
        map = row;
      } else if (row is Map) {
        map = Map<String, dynamic>.from(row);
      }
      if (map == null) continue;
      final c = StockOhlc.tryFromJson(map);
      if (c != null) out.add(c);
    }
    return out;
  }

  // —— shared HTTP helper ————————————————————————————————————————————————

  Future<StockDetailsOutcome<T>> _get<T>({
    required String path,
    required String symbol,
    required T? Function(Map<String, dynamic> body) parse,
    Map<String, String> extraQuery = const <String, String>{},
    required String tag,
  }) async {
    final cleanSymbol = _stripExchangeSuffix(symbol.trim());
    if (cleanSymbol.isEmpty) {
      return const StockDetailsOutcome.empty();
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: <String, dynamic>{
          'stock_symbol': cleanSymbol,
          ...extraQuery,
        },
        options: Options(validateStatus: (code) => code != null && code < 600),
      );

      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return const StockDetailsOutcome.unauthorizedRes();
      }
      if (status != 200 || response.data == null) {
        _logUnavailable(tag, cleanSymbol, status);
        return const StockDetailsOutcome.empty();
      }

      final body = response.data!;
      if (body['success'] == false) {
        _logUnavailable(tag, cleanSymbol, status, reason: 'success=false');
        return const StockDetailsOutcome.empty();
      }
      final parsed = parse(body);
      if (parsed == null) {
        _logUnavailable(tag, cleanSymbol, status, reason: 'no parsable data');
        return const StockDetailsOutcome.empty();
      }
      return StockDetailsOutcome<T>(
        ok: true,
        unauthorized: false,
        data: parsed,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return const StockDetailsOutcome.unauthorizedRes();
      }
      _logUnavailable(
        tag,
        cleanSymbol,
        e.response?.statusCode ?? 0,
        reason: e.message ?? e.type.name,
      );
      return const StockDetailsOutcome.empty();
    } catch (e) {
      _logUnavailable(tag, cleanSymbol, 0, reason: 'unexpected: $e');
      return const StockDetailsOutcome.empty();
    }
  }


  static void _logUnavailable(
    String tag,
    String symbol,
    int status, {
    String? reason,
  }) {
    if (!kDebugMode) return;
    final bits = <String>[
      'data unavailable',
      if (status > 0) 'HTTP $status',
      if (reason != null && reason.isNotEmpty) reason,
    ];
    debugPrint('StockDetailsDio.$tag($symbol): ${bits.join(' · ')}');
  }
}
