import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';


class NormalChatDio {
  static final String path = APISConfigs.noramlChat;

  /// Returns the assistant reply text, or throws [NormalChatException].
  ///
  /// [stockSymbol] is optional — omit it (or leave empty) for general chat
  /// where no specific stock context is needed.
  Future<String> chat({
    String stockSymbol = '',
    required String prompt,
    CancelToken? cancelToken,
  }) async {
    final params = <String, dynamic>{'prompt': prompt};
    if (stockSymbol.trim().isNotEmpty) {
      params['stock_symbol'] = stockSymbol.trim();
    }

    late Response<dynamic> response;
    try {
      response = await DioClient.dio.get<dynamic>(
        path,
        queryParameters: params,
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (code) => code != null && code < 600,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw NormalChatException(
        e.message ?? 'Could not reach the chat server.',
      );
    }

    final code = response.statusCode ?? 0;
    final text = _extractText(response.data);

    if (code == 200) {
      if (text.trim().isEmpty) {
        throw NormalChatException('The server returned an empty response.');
      }
      return text;
    }

    // Non-200: surface any message the server included, else generic.
    final errMsg = text.trim().isNotEmpty
        ? text
        : 'Chat request failed (HTTP $code).';
    throw NormalChatException(errMsg);
  }

  String _extractText(dynamic data) {
    if (data == null) return '';

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) return _extractFromMap(decoded);
        } catch (_) {
          // not JSON — return as-is
        }
      }
      return trimmed;
    }

    if (data is Map) return _extractFromMap(data);
    return data.toString();
  }

  String _extractFromMap(Map<dynamic, dynamic> map) {
    // Try common response keys in priority order.
    // `data` comes first — the backend wraps the reply inside `data`.
    for (final key in [
      'data',
      'response',
      'reply',
      'answer',
      'text',
      'content',
      'result',
      'message',
    ]) {
      final v = map[key];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    // Fallback: serialise whatever was returned.
    return map.toString();
  }
}

class NormalChatException implements Exception {
  NormalChatException(this.message);
  final String message;

  @override
  String toString() => message;
}
