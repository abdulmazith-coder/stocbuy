import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/index_rsi.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

typedef MarketRsiOutcome = ({IndexRsi? nifty, IndexRsi? sensex, bool ok});

class MarketRsiDio {
  static final String path = APISConfigs.marketRsi;

  Future<MarketRsiOutcome> fetchMarketRsi() async {
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
          debugPrint('MarketRsiDio: HTTP ${response.statusCode} for $path');
        }
        return (nifty: null, sensex: null, ok: false);
      }

      final body = response.data!;
      if (body['success'] != true) {
        return (nifty: null, sensex: null, ok: false);
      }

      var data = body['data'];
      while (data is Map<String, dynamic> && data['data'] != null) {
        data = data['data'];
      }

      if (data is! Map<String, dynamic>) {
        return (nifty: null, sensex: null, ok: false);
      }

      final rawMap = Map<String, dynamic>.from(data);
      final nifty = _parseRsiQuote(
        rawMap['NIFTY_50'] ??
            rawMap['nifty_50'] ??
            rawMap['Nifty 50'] ??
            rawMap['nifty'],
      );
      final sensex = _parseRsiQuote(
        rawMap['SENSEX'] ?? rawMap['sensex'] ?? rawMap['BSE'],
      );

      return (
        nifty: nifty,
        sensex: sensex,
        ok: nifty != null || sensex != null,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        final code = e.response?.statusCode;
        debugPrint(
          'MarketRsiDio: ${e.message ?? e.type.name}${code != null ? ' [$code]' : ''}',
        );
      }
      return (nifty: null, sensex: null, ok: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MarketRsiDio: unexpected $e');
      }
      return (nifty: null, sensex: null, ok: false);
    }
  }

  IndexRsi? _parseRsiQuote(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return IndexRsi.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}
