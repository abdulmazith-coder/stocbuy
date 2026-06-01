import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/ipo_listings.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';


@immutable
class IposOutcome {
  const IposOutcome({
    required this.ok,
    required this.unauthorized,
    this.data,
  });

  const IposOutcome.empty()
      : ok = false,
        unauthorized = false,
        data = null;
  const IposOutcome.unauthorizedRes()
      : ok = false,
        unauthorized = true,
        data = null;

  final bool ok;
  final bool unauthorized;
  final IpoListings? data;
}

class IposDio {
  IposDio({Dio? dio}) : _dio = dio ?? DioClient.dio;

  final Dio _dio;
  static final String _path = APISConfigs.ipos;

  Future<IposOutcome> fetchIpos() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _path,
        options: Options(
          validateStatus: (code) => code != null && code < 600,
        ),
      );

      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return const IposOutcome.unauthorizedRes();
      }
      if (status != 200 || response.data == null) {
        _logUnavailable(status);
        return const IposOutcome.empty();
      }

      final body = response.data!;
      if (body['success'] == false) {
        _logUnavailable(status, reason: 'success=false');
        return const IposOutcome.empty();
      }

      final data = body['data'];
      if (data is! Map) {
        _logUnavailable(status, reason: 'data not an object');
        return const IposOutcome.empty();
      }

      final parsed = _parseListings(Map<String, dynamic>.from(data));
      return IposOutcome(ok: true, unauthorized: false, data: parsed);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return const IposOutcome.unauthorizedRes();
      }
      _logUnavailable(
        e.response?.statusCode ?? 0,
        reason: e.message ?? e.type.name,
      );
      return const IposOutcome.empty();
    } catch (e) {
      _logUnavailable(0, reason: 'unexpected: $e');
      return const IposOutcome.empty();
    }
  }

  static IpoListings _parseListings(Map<String, dynamic> data) {
    final nseCurrent = _parseNseBucket(data['nse_current_ipo']);
    final nseUpcoming = _parseNseBucket(data['nse_upcoming_ipo']);

    List<BseIpoItem> bseCurrent = const [];
    List<BseIpoItem> bseUpcoming = const [];
    final bse = data['bse_ipo'];
    if (bse is Map) {
      bseCurrent = _parseBseList(bse['current_ipo']);
      bseUpcoming = _parseBseList(bse['upcoming_ipo']);
    }

    return IpoListings(
      nseCurrent: nseCurrent,
      nseUpcoming: nseUpcoming,
      bseCurrent: bseCurrent,
      bseUpcoming: bseUpcoming,
    );
  }

  static List<NseIpoItem> _parseNseBucket(dynamic node) {
    // NSE side is wrapped as `{ type: …, data: [ … ] }`.
    dynamic rows = node;
    if (rows is Map) rows = rows['data'];
    if (rows is! List) return const <NseIpoItem>[];
    final out = <NseIpoItem>[];
    for (final r in rows) {
      Map<String, dynamic>? m;
      if (r is Map<String, dynamic>) {
        m = r;
      } else if (r is Map) {
        m = Map<String, dynamic>.from(r);
      }
      if (m == null) continue;
      final item = NseIpoItem.fromJson(m);
      if (item.symbol.isNotEmpty) out.add(item);
    }
    return out;
  }

  static List<BseIpoItem> _parseBseList(dynamic node) {
    if (node is! List) return const <BseIpoItem>[];
    final out = <BseIpoItem>[];
    for (final r in node) {
      Map<String, dynamic>? m;
      if (r is Map<String, dynamic>) {
        m = r;
      } else if (r is Map) {
        m = Map<String, dynamic>.from(r);
      }
      if (m == null) continue;
      final item = BseIpoItem.fromJson(m);
      if (item.securityName.isNotEmpty) out.add(item);
    }
    return out;
  }

  static void _logUnavailable(int status, {String? reason}) {
    if (!kDebugMode) return;
    final bits = <String>[
      'data unavailable',
      if (status > 0) 'HTTP $status',
      if (reason != null && reason.isNotEmpty) reason,
    ];
    debugPrint('IposDio.fetchIpos: ${bits.join(' · ')}');
  }
}
