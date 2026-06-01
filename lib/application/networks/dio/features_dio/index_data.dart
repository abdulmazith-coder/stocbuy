import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/index_quote.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

typedef IndexDataOutcome = ({
  IndexQuote? nifty,
  IndexQuote? sensex,
  double? niftyChangePercent,
  double? sensexChangePercent,
  bool ok,
});

class IndexDataDio {
  static final String path = APISConfigs.index;

  Future<IndexDataOutcome> fetchIndexData() async {
    try {
      final response = await DioClient.dio.get<Map<String, dynamic>>(
        path,
        options: Options(
          extra: {DioClient.extraKeySkipAuth: true},
          validateStatus: (code) => code != null && code < 600,
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        if (kDebugMode) {
          debugPrint('IndexDataDio: HTTP ${response.statusCode} for $path');
        }
        return _failure();
      }

      final body = response.data!;
      if (body['success'] != true) {
        if (kDebugMode) {
          debugPrint('IndexDataDio: success!=true, body=$body');
        }
        return _failure();
      }

      // ── Unwrap to the flat index map ──────────────────────────────────────
      // Supported shapes:
      //   1. { success, data: { nifty: {...}, sensex: {...} } }
      //   2. { success, data: { NSE_BOARD_INDEX: { nifty: {...}, ... } } }
      //   3. { success, data: { NSE: 23719.3, BSE: 75415.35 } }   (bare nums)
      //   4. { success, NSE: 23719.3, BSE: 75415.35 }             (top-level)
      Map<String, dynamic> rawMap;
      if (body['data'] is Map<String, dynamic>) {
        final dataMap = Map<String, dynamic>.from(body['data'] as Map);
        // Unwrap NSE_BOARD_INDEX or any single-key wrapper that holds a Map
        if (dataMap['NSE_BOARD_INDEX'] is Map<String, dynamic>) {
          rawMap = Map<String, dynamic>.from(
              dataMap['NSE_BOARD_INDEX'] as Map);
        } else {
          rawMap = dataMap;
        }
      } else {
        // Top-level fallback — exclude meta keys so they don't confuse parsers
        rawMap = Map<String, dynamic>.from(body)
          ..remove('success')
          ..remove('message')
          ..remove('status')
          ..remove('error');
      }

      if (kDebugMode) debugPrint('IndexDataDio: rawMap keys=${rawMap.keys}');

      // ── Parse quotes ──────────────────────────────────────────────────────
      final niftyRaw = rawMap['nifty'] ??
          rawMap['NIFTY'] ??
          rawMap['nifty50'] ??
          rawMap['nifty_50'] ??
          rawMap['Nifty 50'] ??
          rawMap['NSE'] ??
          rawMap['nse'];

      final sensexRaw = rawMap['sensex'] ??
          rawMap['SENSEX'] ??
          rawMap['sensex_30'] ??
          rawMap['sensex30'] ??
          rawMap['Sensex'] ??
          rawMap['BSE'] ??
          rawMap['bse'];

      final niftyQuote = _parseQuote(niftyRaw);
      final sensexQuote = _parseQuote(sensexRaw);

      // ── Change percent: prefer top-level keys, fall back to quote object ──
      final niftyChangePercent = _parseChangePercent(
            rawMap['NIFTY_Change_%'] ??
                rawMap['NIFTY Change %'] ??
                rawMap['nifty_change_pct'],
          ) ??
          niftyQuote?.changePercent; // ← fall back to parsed quote field

      final sensexChangePercent = _parseChangePercent(
            rawMap['SENSEX_Change_%'] ??
                rawMap['SENSEX Change %'] ??
                rawMap['sensex_change_pct'],
          ) ??
          sensexQuote?.changePercent; // ← fall back to parsed quote field

      if (niftyQuote == null && sensexQuote == null) {
        if (kDebugMode) {
          debugPrint('IndexDataDio: could not parse any quote from rawMap');
        }
        return _failure();
      }

      return (
        nifty: niftyQuote,
        sensex: sensexQuote,
        niftyChangePercent: niftyChangePercent,
        sensexChangePercent: sensexChangePercent,
        ok: true,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        final code = e.response?.statusCode;
        debugPrint(
          'IndexDataDio: ${e.message ?? e.type.name}'
          '${code != null ? ' [$code]' : ''}',
        );
      }
      return _failure();
    } catch (e, st) {
      if (kDebugMode) debugPrint('IndexDataDio: unexpected $e\n$st');
      return _failure();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static IndexDataOutcome _failure() => (
        nifty: null,
        sensex: null,
        niftyChangePercent: null,
        sensexChangePercent: null,
        ok: false,
      );

  IndexQuote? _parseQuote(dynamic raw) {
    if (raw == null) return null;

    // Bare number or numeric string
    if (raw is num || raw is String) {
      final price = IndexQuote.parseDouble(raw);
      if (price == null) return null;
      return IndexQuote(price: price, fetchedAt: DateTime.now().toUtc());
    }

    if (raw is Map) {
      final q = Map<String, dynamic>.from(raw);
      final price = IndexQuote.parseDouble(
        q['price'] ??
            q['last_price'] ??
            q['current'] ??
            q['value'] ??
            q['close'] ??
            q['regularMarketPrice'] ??
            q['currentPrice'] ??
            q['current_price'] ??
            q['lastPrice'] ??
            q['regular_market_price'],
      );
      if (price == null) return null;

      final change = IndexQuote.parseDouble(
        q['change'] ??
            q['chg'] ??
            q['net_change'] ??
            q['delta'] ??
            q['regularMarketChange'] ??
            q['regular_market_change'],
      );
      final changePercent = IndexQuote.parseDouble(
        q['pct_change'] ??
            q['percent'] ??
            q['change_percent'] ??
            q['percentage'] ??
            q['regularMarketChangePercent'] ??
            q['regular_market_change_percent'],
      );
      final changeLabel = q['change_label']?.toString() ??
          q['label']?.toString() ??
          q['changeLabel']?.toString();

      return IndexQuote(
        price: price,
        change: change,
        changePercent: changePercent,
        changeLabel: changeLabel,
        fetchedAt: DateTime.now().toUtc(),
      );
    }

    return null;
  }

  double? _parseChangePercent(dynamic raw) => IndexQuote.parseDouble(raw);
}