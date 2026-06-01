import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/stock_search_result.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/secure_storage.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

/// Stock search calls the authenticated API: [DioClient] adds `Authorization`
/// for every request unless `extra[DioClient.extraKeySkipAuth]` is set — this
/// class never sets that flag.
class SearchStocksDio {
  Future<List<StockSearchResult>> searchStocks(String query) async {
    final token = await SecureStorage.getAccessToken();
    if (token.isEmpty) {
      throw const SearchAuthRequiredException();
    }

    final response = await DioClient.dio.get(
      APISConfigs.searchStock,
      queryParameters: {'stock_symbol': query},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to search stocks');
    }
    final body = response.data;
    if (body is! Map) {
      throw Exception('Invalid response');
    }
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Request failed');
    }
    final raw = body['data'];
    if (raw is! List) {
      return const [];
    }
    return raw
        .map(
          (e) => StockSearchResult.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(growable: false);
  }
}

/// Thrown when stock search is attempted without an access token.
class SearchAuthRequiredException implements Exception {
  const SearchAuthRequiredException();

  @override
  String toString() => 'Sign in to search stocks';
}
