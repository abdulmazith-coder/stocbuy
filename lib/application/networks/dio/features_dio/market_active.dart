import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/market_session_status.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

typedef MarketActiveOutcome = ({IndiaMarketStatus? status, bool ok});

/// Public market session endpoint. Call frequency is controlled by
/// [MarketStatusController] (5 min 09:15–09:30 IST, hourly 09:31–15:30 IST,
/// then idle until next 09:15 IST).
class MarketActiveDio {
  static final String path = APISConfigs.marketStatus;

  Future<MarketActiveOutcome> fetchMarketStatus() async {
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
          debugPrint(
            'MarketActiveDio: HTTP ${response.statusCode} for $path',
          );
        }
        return (status: null, ok: false);
      }

      final body = response.data!;
      if (body['success'] != true) {
        return (status: null, ok: false);
      }

      final rawData = body['data'];
      final message = '${body['message'] ?? ''}';

      if (rawData is! Map) {
        return (status: null, ok: false);
      }

      final status = IndiaMarketStatus.tryParse(
        Map<String, dynamic>.from(rawData),
        message,
      );

      if (status == null) {
        return (status: null, ok: false);
      }

      return (status: status, ok: true);
    } on DioException catch (e) {
      if (kDebugMode) {
        final code = e.response?.statusCode;
        final transport = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout;
        final hint = transport ? ' — market status unknown until API reachable (CORS on web?)' : '';
        debugPrint(
          'MarketActiveDio: ${e.message ?? e.type.name}${code != null ? ' [$code]' : ''}$hint',
        );
      }
      return (status: null, ok: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MarketActiveDio: unexpected $e');
      }
      return (status: null, ok: false);
    }
  }
}
