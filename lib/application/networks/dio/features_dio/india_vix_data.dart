import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/india_vix_data.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

typedef IndiaVixOutcome = ({IndiaVixData? vix, bool ok});

class IndiaVixDataDio {
  static final String path = APISConfigs.indiaVIX;

  Future<IndiaVixOutcome> fetchIndiaVixData() async {
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
          debugPrint('IndiaVixDataDio: HTTP ${response.statusCode} for $path');
        }
        return (vix: null, ok: false);
      }

      final body = response.data!;
      if (body['success'] != true) {
        return (vix: null, ok: false);
      }

      final rawData = body['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(body['data'])
          : Map<String, dynamic>.from(body);
      final vixData = IndiaVixData.fromJson(rawData);
      return (vix: vixData, ok: vixData != null);
    } on DioException catch (e) {
      if (kDebugMode) {
        final code = e.response?.statusCode;
        debugPrint(
          'IndiaVixDataDio: ${e.message ?? e.type.name}${code != null ? ' [$code]' : ''}',
        );
      }
      return (vix: null, ok: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('IndiaVixDataDio: unexpected $e');
      }
      return (vix: null, ok: false);
    }
  }
}
