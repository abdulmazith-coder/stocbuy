import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/useage_locally.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_dio.dart'
    show AiAnalysisException;
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_sse_stub.dart'
    if (dart.library.html) 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_sse_web.dart'
    as ai_analysis_sse;
import 'package:stocbuy_application/application/networks/dio/auth_dio/secure_storage.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/sse_json_stream_parser.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/filtered_stock.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_usage_dio.dart';

@immutable
class PennyStockFilterEvent {
  const PennyStockFilterEvent({
    required this.type,
    this.message,
    this.symbol,
    this.reason,
    this.stock,
    this.totalGoodStocks,
    this.goodStocks = const [],
    this.fromCache = false,
  });

  final String type;
  final String? message;
  final String? symbol;
  final String? reason;
  final FilteredStock? stock;
  final int? totalGoodStocks;
  final List<FilteredStock> goodStocks;

  /// True when this event was served from local cache.
  final bool fromCache;

  bool get isCompleted => type == 'completed';

  factory PennyStockFilterEvent.fromJson(Map<String, dynamic> json) {
    final stocks = <FilteredStock>[];
    final rawList = json['good_stocks'];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          stocks.add(FilteredStock.fromJson(item));
        } else if (item is Map) {
          stocks.add(FilteredStock.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    FilteredStock? one;
    final rawStock = json['stock'];
    if (rawStock is Map<String, dynamic>) {
      one = FilteredStock.fromJson(rawStock);
    } else if (rawStock is Map) {
      one = FilteredStock.fromJson(Map<String, dynamic>.from(rawStock));
    }

    return PennyStockFilterEvent(
      type: '${json['type'] ?? ''}',
      message: json['message']?.toString(),
      symbol: json['symbol']?.toString(),
      reason: json['reason']?.toString(),
      stock: one,
      totalGoodStocks: (json['total_good_stocks'] as num?)?.toInt(),
      goodStocks: stocks,
    );
  }

  String? get stepLabel {
    switch (type) {
      case 'info':
      case 'checking':
        return message?.trim();
      case 'passed':
        final sym = symbol ?? '';
        final msg = message?.trim() ?? 'Passed';
        return sym.isEmpty ? msg : '$sym — $msg';
      case 'rejected':
        final sym = symbol ?? '';
        final r = reason?.trim() ?? 'Rejected';
        return sym.isEmpty ? r : '$sym — $r';
      case 'success':
        final sym = symbol ?? stock?.symbol ?? '';
        return sym.isEmpty ? 'Stock passed all filters' : '$sym matched';
      case 'completed':
        return message?.trim() ?? 'Filtering completed';
      default:
        return message?.trim();
    }
  }
}

class PennyStockFilterDio {
  static final String path = APISConfigs.stockFilter;

  static const _acceptAttempts = <String>[
    'application/json, text/event-stream;q=0.9, */*;q=0.8',
    'text/event-stream, application/json;q=0.9, */*;q=0.8',
    '*/*',
  ];

  Stream<PennyStockFilterEvent> streamFilter({
    required String capType,
    CancelToken? cancelToken,
  }) async* {
    final cap = capType.trim().toLowerCase();
    if (cap.isEmpty) throw ArgumentError('cap_type is required');

    // ── 1. Block if limit exhausted — even cached data is hidden ─────────
    final exhausted = await UsageCacheService.instance.isLimitExhausted();
    if (exhausted) {
      throw PennyStockFilterLimitException(
        'You have reached your daily AI analysis limit. Connect with us to upgrade.',
      );
    }

    // ── 2. Serve from local cache if saved today ──────────────────────────
    final cached = await FilterCacheService.instance.getFilter(capType: cap);
    if (cached != null && cached.stocks.isNotEmpty) {
      for (final stock in cached.stocks) {
        yield PennyStockFilterEvent(
          type: 'success',
          stock: stock,
          symbol: stock.symbol,
          goodStocks: const [],
          fromCache: true,
        );
      }
      yield PennyStockFilterEvent(
        type: 'completed',
        message: 'Loaded from cache',
        goodStocks: cached.stocks,
        totalGoodStocks: cached.totalGoodStocks,
        fromCache: true,
      );
      return;
    }

    // ── 3. Fetch from backend ─────────────────────────────────────────────
    final collectedStocks = <FilteredStock>[];
    int totalGoodStocks = 0;

    Object? lastError;
    for (final accept in _acceptAttempts) {
      try {
        await for (final event in _streamWithAccept(
          cap: cap,
          accept: accept,
          cancelToken: cancelToken,
        )) {
          // Collect stocks as they arrive
          if (event.stock != null) {
            collectedStocks.add(event.stock!);
          }
          if (event.goodStocks.isNotEmpty) {
            for (final s in event.goodStocks) {
              if (!collectedStocks.any((e) => e.symbol == s.symbol)) {
                collectedStocks.add(s);
              }
            }
          }
          if (event.totalGoodStocks != null) {
            totalGoodStocks = event.totalGoodStocks!;
          }

          yield event;

          // On completed → save to local cache + refresh usage from backend
          if (event.isCompleted) {
            if (collectedStocks.isNotEmpty) {
              await FilterCacheService.instance.saveFilter(
                capType: cap,
                stocks: collectedStocks,
                totalGoodStocks: totalGoodStocks > 0
                    ? totalGoodStocks
                    : collectedStocks.length,
              );
            }
            await _refreshUsage();
          }
        }
        return;
      } on PennyStockFilterException catch (e) {
        lastError = e;
        if (!e.message.contains('406')) rethrow;
      }
    }
    throw lastError as PennyStockFilterException? ??
        PennyStockFilterException('Scanner request failed (HTTP 406).');
  }

  /// Refresh usage from backend and persist locally.
  Future<void> _refreshUsage() async {
    try {
      final usage = await AiAnalysisUsageDio().fetchUsage();
      await UsageCacheService.instance.saveUsage(usage);
    } catch (_) {
      // Non-fatal — syncs on next app start
    }
  }

  Stream<PennyStockFilterEvent> _streamWithAccept({
    required String cap,
    required String accept,
    CancelToken? cancelToken,
  }) async* {
    if (kIsWeb) {
      final parsedPath = Uri.parse(path);
      final baseUri = Uri.parse(DioClient.dio.options.baseUrl);
      final uri = parsedPath.hasScheme
          ? parsedPath.replace(queryParameters: {'cap_type': cap})
          : baseUri
                .resolveUri(parsedPath)
                .replace(queryParameters: {'cap_type': cap});
      final headers = <String, String>{'Accept': accept};
      final token = await SecureStorage.getAccessToken();
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final webStream = ai_analysis_sse.openAiAnalysisProgressStream(
        uri: uri,
        headers: headers,
        cancelToken: cancelToken,
      );
      if (webStream != null) {
        yield* _mapJsonStream(parseSseJsonObjectStream(webStream));
        return;
      }
    }

    Response<ResponseBody> response;
    try {
      response = await DioClient.dio.get<ResponseBody>(
        path,
        queryParameters: {'cap_type': cap},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 30),
          headers: {'Accept': accept},
          validateStatus: (code) => code != null && code < 600,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw PennyStockFilterException(
        e.message ?? 'Could not reach the scanner.',
      );
    }

    // ── Handle 403 — no feature access ───────────────────────────────────
    if (response.statusCode == 403) {
      final body = await _readResponseBody(response.data);
      final message = _formatHttpError(403, body);
      throw PennyStockFilterLimitException(message);
    }

    // ── Handle 429 — daily limit reached ─────────────────────────────────
    if (response.statusCode == 429) {
      final body = await _readResponseBody(response.data);
      final message = _formatHttpError(429, body);
      throw PennyStockFilterLimitException(message);
    }

    if (response.statusCode != 200 || response.data == null) {
      final body = await _readResponseBody(response.data);
      final code = response.statusCode ?? 0;
      final message = _formatHttpError(code, body);
      throw PennyStockFilterException('Scanner failed (HTTP $code): $message');
    }

    yield* _mapJsonStream(parseSseJsonObjectStream(response.data!.stream));
  }

  Future<String> _readResponseBody(ResponseBody? body) async {
    if (body == null) return '';
    try {
      final bytes = <int>[];
      await for (final chunk in body.stream) {
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  String _formatHttpError(int code, String body) {
    if (body.trim().isEmpty) return 'HTTP $code.';
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final msg = json['message'] ?? json['detail'] ?? json['error'];
        if (msg != null) return msg.toString();
      }
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  Stream<PennyStockFilterEvent> _mapJsonStream(
    Stream<Map<String, dynamic>> jsonStream,
  ) async* {
    try {
      await for (final json in jsonStream) {
        if (_isErrorPayload(json)) {
          throw _createErrorException(json);
        }
        yield PennyStockFilterEvent.fromJson(json);
      }
    } on AiAnalysisException catch (e) {
      throw PennyStockFilterException(e.message);
    }
  }

  Exception _createErrorException(Map<String, dynamic> json) {
    final message =
        json['message']?.toString() ??
        json['detail']?.toString() ??
        json['error']?.toString() ??
        'Scanner failed.';
    if (_isPremiumAccessError(message)) {
      return PennyStockFilterLimitException(message);
    }
    return PennyStockFilterException(message);
  }

  bool _isErrorPayload(Map<String, dynamic> json) {
    return json['success'] == false && json['message'] != null;
  }

  bool _isPremiumAccessError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('premium') ||
        normalized.contains('connect with us') ||
        normalized.contains('request access') ||
        normalized.contains('not enable') ||
        normalized.contains('not enabled') ||
        normalized.contains('feature access') ||
        normalized.contains('access denied');
  }
}

class PennyStockFilterException implements Exception {
  PennyStockFilterException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PennyStockFilterLimitException implements Exception {
  PennyStockFilterLimitException(this.message);
  final String message;
  @override
  String toString() => message;
}
