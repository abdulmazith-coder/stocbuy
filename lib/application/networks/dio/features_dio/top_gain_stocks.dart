import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/top_company.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

/// Container for an NSE / BSE top-gainers or top-losers response.
class GainLossOutcome {
  const GainLossOutcome({
    required this.nse,
    required this.bse,
    required this.ok,
    this.unauthorized = false,
  });

  const GainLossOutcome.empty()
      : nse = const <TopCompany>[],
        bse = const <TopCompany>[],
        ok = false,
        unauthorized = false;

  /// Server returned 401 (token missing, invalid or expired after refresh).
  const GainLossOutcome.unauthorizedRes()
      : nse = const <TopCompany>[],
        bse = const <TopCompany>[],
        ok = false,
        unauthorized = true;

  final List<TopCompany> nse;
  final List<TopCompany> bse;


  final bool ok;


  final bool unauthorized;
}


class TopGainAndLossStocksDio {
  static final String gainersPath =  APISConfigs.topGainStocks;
  static final String losersPath = APISConfigs.topLossStocks;

  /// Public — no auth header.
  Future<GainLossOutcome> getTopGainStocks() =>
      _fetch(gainersPath, requireAuth: false);

  /// Auth-required — Bearer token attached by [DioClient]'s interceptor.
  Future<GainLossOutcome> getTopLossStocks() =>
      _fetch(losersPath, requireAuth: true);

  Future<GainLossOutcome> _fetch(
    String path, {
    required bool requireAuth,
  }) async {
    try {
      final response = await DioClient.dio.get<Map<String, dynamic>>(
        path,
        options: Options(
          extra: requireAuth
              ? const <String, dynamic>{}
              : {DioClient.extraKeySkipAuth: true},
          validateStatus: (code) => code != null && code < 600,
        ),
      );

      if (response.statusCode == 401) {
        return const GainLossOutcome.unauthorizedRes();
      }
      if (response.statusCode != 200 || response.data == null) {
        if (kDebugMode) {
          debugPrint(
            'TopGainAndLossStocksDio: HTTP ${response.statusCode} for $path',
          );
        }
        return const GainLossOutcome.empty();
      }

      final body = response.data!;
      if (body['success'] != true) {
        return const GainLossOutcome.empty();
      }

      final raw = body['data'];
      List<TopCompany> nse = const <TopCompany>[];
      List<TopCompany> bse = const <TopCompany>[];

      if (raw is List && raw.isNotEmpty) {
        final first = raw.first;
        if (first is Map &&
            (first.containsKey('nse') || first.containsKey('bse'))) {
          final m = Map<String, dynamic>.from(first);
          nse = _parseRows(m['nse']);
          bse = _parseRows(m['bse']);
        } else {
          // Legacy flat list — surface under NSE so existing UI still works.
          nse = _parseRows(raw);
        }
      } else if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        nse = _parseRows(m['nse']);
        bse = _parseRows(m['bse']);
      }

      return GainLossOutcome(nse: nse, bse: bse, ok: true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return const GainLossOutcome.unauthorizedRes();
      }
      if (kDebugMode) {
        debugPrint(
          'TopGainAndLossStocksDio($path): ${e.message ?? e.type.name}',
        );
      }
      return const GainLossOutcome.empty();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TopGainAndLossStocksDio($path): unexpected $e');
      }
      return const GainLossOutcome.empty();
    }
  }

  List<TopCompany> _parseRows(dynamic raw) {
    if (raw is! List || raw.isEmpty) return const <TopCompany>[];
    final out = <TopCompany>[];
    for (final item in raw) {
      Map<String, dynamic>? map;
      if (item is Map<String, dynamic>) {
        map = item;
      } else if (item is Map) {
        map = Map<String, dynamic>.from(item);
      }
      if (map == null) continue;
      final row = TopCompany.fromJson(map);
      if (row.symbol.isNotEmpty) out.add(row);
    }
    return out;
  }
}
