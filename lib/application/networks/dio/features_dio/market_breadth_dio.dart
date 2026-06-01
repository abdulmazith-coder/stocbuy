import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/market_breadth.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

typedef MarketBreadthOutcome = ({MarketBreadth? data, String? error, bool ok});

class MarketBreadthDio {
  static final String path = APISConfigs.marketBreadth;

  /// Fetch market breadth data for the specified index
  /// [indexName] - The index name (e.g., 'NIFTY 50')
  Future<MarketBreadthOutcome> fetchMarketBreadth({
    String indexName = 'NIFTY 50',
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (indexName.isNotEmpty) {
        queryParams['index'] = indexName;
      }

      final response = await DioClient.dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParams,
        options: Options(
          extra: {DioClient.extraKeySkipAuth: true},
          validateStatus: (code) => code != null && code < 600,
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        if (kDebugMode) {
          debugPrint('MarketBreadthDio: HTTP ${response.statusCode} for $path');
        }
        final errorMsg = 'HTTP ${response.statusCode}';
        return (data: null, error: errorMsg, ok: false);
      }

      final body = response.data!;
      if (body['success'] != true) {
        final errorMsg = body['message'] is String
            ? body['message'] as String
            : 'Request failed';
        return (data: null, error: errorMsg, ok: false);
      }

      // Extract the market breadth data from nested structure
      // Response format: { success, message, data: { success, message, data: { ...breadth data... } } }
      var breadthData = body['data'];

      if (breadthData is Map<String, dynamic>) {
        // Check if data is nested (inner response wrapper)
        if (breadthData['data'] is Map<String, dynamic>) {
          breadthData = breadthData['data'];
        }
      }

      if (breadthData is! Map<String, dynamic>) {
        return (data: null, error: 'Invalid response format', ok: false);
      }

      final breadth = MarketBreadth.fromJson(breadthData);
      if (breadth == null) {
        return (data: null, error: 'Failed to parse breadth data', ok: false);
      }

      return (data: breadth, error: null, ok: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MarketBreadthDio exception: $e');
      }
      return (data: null, error: e.toString(), ok: false);
    }
  }
}
