import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/top_company.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

/// Result of a top-companies request. [ok] is false for HTTP errors, transport
/// failures, or malformed payloads (caller may keep cached [companies]).
typedef TopCompaniesOutcome = ({List<TopCompany> companies, bool ok});

class TopCompaniesDio {
  /// Relative to [DioClient.dio] `baseUrl` (`…/api/`).
  static final String path = APISConfigs.topCompanies;

  /// Does not throw: maps 404/5xx/network errors to `ok: false` so callers
  /// avoid unhandled async errors and can retain last-good quotes.
  Future<TopCompaniesOutcome> fetchTopCompanies() async {
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
            'TopCompaniesDio: HTTP ${response.statusCode} for $path — check backend route vs baseUrl.',
          );
        }
        return (companies: const <TopCompany>[], ok: false);
      }

      final body = response.data!;
      if (body['success'] != true) {
        return (companies: const <TopCompany>[], ok: false);
      }

      final raw = body['data'];
      if (raw is! List<dynamic>) {
        return (companies: const <TopCompany>[], ok: false);
      }

      final out = <TopCompany>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final row = TopCompany.fromJson(item);
          if (row.symbol.isNotEmpty) out.add(row);
        } else if (item is Map) {
          final row = TopCompany.fromJson(Map<String, dynamic>.from(item));
          if (row.symbol.isNotEmpty) out.add(row);
        }
      }
      return (companies: out, ok: true);
    } on DioException catch (e) {
      if (kDebugMode) {
        final code = e.response?.statusCode;
        final transport = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout;
        final hint = transport ? ' — using fallback data (check API / CORS on web)' : '';
        debugPrint(
          'TopCompaniesDio: ${e.message ?? e.type.name}${code != null ? ' [$code]' : ''}$hint',
        );
      }
      return (companies: const <TopCompany>[], ok: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TopCompaniesDio: unexpected $e');
      }
      return (companies: const <TopCompany>[], ok: false);
    }
  }
}
