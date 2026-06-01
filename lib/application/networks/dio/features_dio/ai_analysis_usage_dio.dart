import 'package:dio/dio.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/ai_analysis_usage.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

class AiAnalysisUsageDio {
  static  String path = APISConfigs.aiUsage;

  Future<AiAnalysisUsage> fetchUsage() async {
    try {
      final response = await DioClient.dio.get<Map<String, dynamic>>(
        path,
        options: Options(
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return AiAnalysisUsage.fromJson(response.data!);
      }
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Failed to fetch AI usage',
      );
    } on DioException {
      rethrow;
    } catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        error: e,
      );
    }
  }
}
