import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/controllers/ai_usage_controller.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_sse_stub.dart'
    if (dart.library.html) 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_sse_web.dart'
    as ai_analysis_sse;
import 'package:stocbuy_application/application/models/analysis_report_section.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/secure_storage.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_prompt.dart';

/// One named report block inside a success payload.
@immutable
class AiAnalysisReportPayload {
  const AiAnalysisReportPayload({
    required this.fieldKey,
    required this.markdown,
  });

  final String fieldKey;
  final String markdown;
}

@immutable
class AiAnalysisStreamEvent {
  const AiAnalysisStreamEvent({
    required this.status,
    required this.message,
    this.data,
    this.reports = const [],
  });

  final String status;
  final String message;

  /// Legacy single-report field.
  final String? data;

  /// Named sections (`balance_sheet_analysis`, `final_analysis`, etc.).
  final List<AiAnalysisReportPayload> reports;

  bool get isProcessing => status == 'processing';
  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';

  bool get hasLegacyData => data != null && data!.trim().isNotEmpty;

  bool get hasReportContent => reports.isNotEmpty || hasLegacyData;

  /// @deprecated Use [hasReportContent].
  bool get hasMarkdown => hasReportContent;

  factory AiAnalysisStreamEvent.fromJson(Map<String, dynamic> json) {
    // Build a flat normalized map of report field → markdown.
    //
    // Two event shapes from the backend:
    //   • Individual streaming event: top-level short key
    //     {"status":"success","balance_sheet":"# Balance Sheet…"}
    //   • Final summary event: nested `analyses` object
    //     {"status":"success","analyses":{"balance_sheet_analysis":"…","final_analysis":"…"}}
    //
    // Both short-form ("balance_sheet") and long-form ("balance_sheet_analysis")
    // keys are normalized to the canonical long form before storage.
    final flat = <String, String>{};

    // 1. Top-level fields (individual streaming events).
    for (final entry in json.entries) {
      final canonical = _normalizeReportKey(entry.key);
      if (canonical == null) continue;
      final md = entry.value?.toString().trim() ?? '';
      if (md.isNotEmpty) flat[canonical] = md;
    }

    // 2. Nested `analyses` object (final summary event).
    final analyses = json['analyses'];
    if (analyses is Map) {
      for (final entry in analyses.entries) {
        final canonical = _normalizeReportKey(entry.key as String);
        if (canonical == null) continue;
        final md = entry.value?.toString().trim() ?? '';
        // Individual streaming events win over the bulk final payload.
        if (md.isNotEmpty) flat.putIfAbsent(canonical, () => md);
      }
    }

    // 3. Cached response: `data` as a JSON object or Python-repr dict string.
    final dataField = json['data'];
    if (dataField is Map) {
      for (final entry in dataField.entries) {
        final canonical = _normalizeReportKey('${entry.key}');
        if (canonical == null) continue;
        final md = '${entry.value}'.trim();
        if (md.isNotEmpty) flat.putIfAbsent(canonical, () => md);
      }
    } else {
      final rawData = dataField?.toString().trim() ?? '';
if (rawData.startsWith('{') && flat.isEmpty) {
  flat.addAll(parseCachedPythonDictReports(rawData));
}
    }

    // Emit reports in canonical order so the tab strip is always consistent.
    final reportPayloads = <AiAnalysisReportPayload>[
      for (final key in kAiAnalysisReportFieldKeys)
        if (flat.containsKey(key))
          AiAnalysisReportPayload(fieldKey: key, markdown: flat[key]!),
    ];

    return AiAnalysisStreamEvent(
      status: '${json['status'] ?? ''}',
      message: '${json['message'] ?? ''}',
      data: json['data']?.toString(),
      reports: reportPayloads,
    );
  }
}

/// Streams Server-Sent Events from the AI analysis endpoint.
class AiAnalysisDio {
  static String path = APISConfigs.aiAnalysis;

  static const _acceptAttempts = <String>[
    'application/json, text/event-stream;q=0.9, */*;q=0.8',
    'text/event-stream, application/json;q=0.9, */*;q=0.8',
    '*/*',
  ];

  Stream<AiAnalysisStreamEvent> streamAnalysis({
    required String stockSymbol,
    required String prompt,
    CancelToken? cancelToken,
  }) async* {
    final symbol = apiStockSymbol(stockSymbol);
    if (symbol.isEmpty) {
      throw ArgumentError('stock_symbol is required');
    }

    Object? lastError;
    for (final accept in _acceptAttempts) {
      try {
        yield* _streamWithAccept(
          symbol: symbol,
          prompt: prompt,
          accept: accept,
          cancelToken: cancelToken,
        );
        if (Get.isRegistered<AiUsageController>()) {
          unawaited(Get.find<AiUsageController>().fetchUsage(force: true));
        }
        return;
      } on AiAnalysisException catch (e) {
        lastError = e;
        if (!e.message.contains('406')) rethrow;
        if (kDebugMode) {
          debugPrint('AiAnalysisDio: retry after 406 with Accept: $accept');
        }
      }
    }
    throw lastError as AiAnalysisException? ??
        AiAnalysisException(
          'Analysis failed: server did not accept the request (HTTP 406).',
        );
  }

  Stream<AiAnalysisStreamEvent> _streamWithAccept({
    required String symbol,
    required String prompt,
    required String accept,
    CancelToken? cancelToken,
  }) async* {
    if (kIsWeb) {
      final parsedPath = Uri.parse(path);
      final baseUri = Uri.parse(DioClient.dio.options.baseUrl);
      final uri = parsedPath.hasScheme
          ? parsedPath.replace(
              queryParameters: {
                ...parsedPath.queryParameters,
                'stock_symbol': symbol,
                'prompt': prompt,
              },
            )
          : baseUri
                .resolveUri(parsedPath)
                .replace(
                  queryParameters: {
                    ...baseUri.queryParameters,
                    ...parsedPath.queryParameters,
                    'stock_symbol': symbol,
                    'prompt': prompt,
                  },
                );
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
        yield* _parseSseStream(webStream);
        return;
      }
    }

    Response<ResponseBody> response;
    try {
      response = await DioClient.dio.get<ResponseBody>(
        path,
        queryParameters: {'stock_symbol': symbol, 'prompt': prompt},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 10),
          headers: {'Accept': accept},
          validateStatus: (code) => code != null && code < 600,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw AiAnalysisException(
        e.message ?? 'Could not reach the analysis server.',
      );
    }

    if (response.statusCode != 200 || response.data == null) {
      final body = await _readResponseBody(response.data);
      final code = response.statusCode ?? 0;
      throw AiAnalysisException(_formatHttpError(code, body));
    }

    yield* _parseSseStream(response.data!.stream);
  }

  /// Parses `data: {...}` events from a byte stream (works when chunks are
  /// buffered on web — extracts every complete JSON object per chunk).
  Stream<AiAnalysisStreamEvent> _parseSseStream(
    Stream<List<int>> byteStream,
  ) async* {
    final decoded = byteStream.cast<List<int>>().transform(utf8.decoder);
    var buffer = '';

    await for (final chunk in decoded) {
      buffer += chunk;
      final extracted = _extractEventsFromBuffer(buffer);
      buffer = extracted.remaining;
      for (final event in extracted.events) {
        yield event;
      }
    }

    if (buffer.trim().isNotEmpty) {
      final extracted = _extractEventsFromBuffer(buffer, flush: true);
      for (final event in extracted.events) {
        yield event;
      }
    }
  }

  ({List<AiAnalysisStreamEvent> events, String remaining})
  _extractEventsFromBuffer(String buffer, {bool flush = false}) {
    final events = <AiAnalysisStreamEvent>[];
    var remaining = buffer.replaceAll('\r\n', '\n');

    while (true) {
      final dataIdx = remaining.indexOf('data:');
      if (dataIdx < 0) break;

      var jsonStart = dataIdx + 5;
      while (jsonStart < remaining.length &&
          (remaining[jsonStart] == ' ' || remaining[jsonStart] == '\n')) {
        jsonStart++;
      }
      if (jsonStart >= remaining.length || remaining[jsonStart] != '{') {
        remaining = remaining.substring(dataIdx + 5);
        continue;
      }

      final jsonEnd = _findJsonObjectEnd(remaining, jsonStart);

      if (jsonEnd == null) {
        if (flush) break;
        remaining = remaining.substring(dataIdx);
        break;
      }

      final jsonStr = remaining.substring(jsonStart, jsonEnd);
      remaining = remaining.substring(jsonEnd);

      try {
  final json = jsonDecode(jsonStr);
  if (json is Map<String, dynamic>) {
    // DEBUG: log raw keys so you can see what the backend actually sends
    if (kDebugMode) {
      final keys = json.keys.where((k) => k != 'status' && k != 'message' && k != 'data').toList();
      if (keys.isNotEmpty) {
        debugPrint('AiAnalysisDio: SSE keys=${json['status']} $keys');
      }
    }
    final event = AiAnalysisStreamEvent.fromJson(json);
    if (kDebugMode && event.isSuccess && !event.hasReportContent) {
      debugPrint('AiAnalysisDio: ⚠️ success event has NO report content! raw=$jsonStr');
    }
    events.add(event);
  }
} catch (e) {
  if (kDebugMode) {
    debugPrint('AiAnalysisDio: bad JSON ($e): $jsonStr');
  }
}
    }

    if (!flush) {
  // Keep tail after last complete event for the next chunk.
  final lastData = remaining.lastIndexOf('data:');
  if (lastData >= 0) {                          // ✅ was > 0, missing position-0 case
    remaining = remaining.substring(lastData);
  }
} else {
      remaining = '';
    }

    return (events: events, remaining: remaining);
  }

  /// Locates the end index (exclusive) of a JSON object, respecting strings.
  static int? _findJsonObjectEnd(String text, int start) {
    if (start >= text.length || text[start] != '{') return null;

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }

      if (c == '"') {
        inString = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return i + 1;
      }
    }
    return null;
  }

  Future<String> _readResponseBody(ResponseBody? body) async {
    if (body == null) return '';
    try {
      final chunks = await body.stream.toList();
      final bytes = chunks.expand((c) => c).toList();
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  String _formatHttpError(int code, String body) {
    if (body.trim().isEmpty) {
      return 'Analysis failed (HTTP $code).';
    }
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final msg = json['message'] ?? json['detail'] ?? json['error'];
        if (msg != null) {
          return 'Analysis failed (HTTP $code): $msg';
        }
      }
    } catch (_) {
      // plain text body
    }
    final snippet = body.length > 200 ? '${body.substring(0, 200)}…' : body;
    return 'Analysis failed (HTTP $code): $snippet';
  }
}

class AiAnalysisException implements Exception {
  AiAnalysisException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Normalises both short-form and long-form API keys to the canonical
/// `_analysis`-suffixed form used throughout the app.
///
/// Returns `null` for keys that are not report fields.
String? _normalizeReportKey(String key) {
  switch (key) {
    case 'balance_sheet':
    case 'balance_sheet_analysis':
      return 'balance_sheet_analysis';
    case 'income_statement':
    case 'income_statement_analysis':
      return 'income_statement_analysis';
    case 'cash_flow':
    case 'cash_flow_analysis':
      return 'cash_flow_analysis';
    case 'shareholders':
    case 'shareholders_analysis':
      return 'shareholders_analysis';
    case 'financial_ratios':
    case 'financial_ratios_analysis':
      return 'financial_ratios_analysis';
    case 'news':
    case 'news_analysis':
      return 'news_analysis';
    case 'final_analysis':
      return 'final_analysis';
    default:
      return null;
  }
}

/// Short-form and long-form aliases tried when parsing the Python-repr `data`
/// dict that the backend returns for cached analyses.
const _pythonDictKeyAliases = <String, List<String>>{
  'balance_sheet_analysis': ['balance_sheet', 'balance_sheet_analysis'],
  'income_statement_analysis': [
    'income_statement',
    'income_statement_analysis',
  ],
  'cash_flow_analysis': ['cash_flow', 'cash_flow_analysis'],
  'shareholders_analysis': ['shareholders', 'shareholders_analysis'],
  'financial_ratios_analysis': [
    'financial_ratios',
    'financial_ratios_analysis',
  ],
  'news_analysis': ['news_analysis', 'news'],
  'final_analysis': ['final_analysis'],
};

/// Extracts all known report sections from a cached Python `str(dict)` payload.
Map<String, String> parseCachedPythonDictReports(String rawDict) {
  final flat = <String, String>{};
  for (final canonical in kAiAnalysisReportFieldKeys) {
    if (flat.containsKey(canonical)) continue;
    for (final alias in _pythonDictKeyAliases[canonical] ?? [canonical]) {
      final value = _extractPythonDictValue(rawDict, alias);
      if (value != null && value.isNotEmpty) {
        flat[canonical] = value;
        break;
      }
    }
  }
  return flat;
}

/// Locates `'key':` / `"key":` at dict boundaries (not inside report text).
int? _findPythonDictKeyColon(String dictStr, String key) {
  for (final kq in ["'", '"']) {
    final keyToken = '$kq$key$kq';
    final pattern = RegExp('(?:^|[{,]\\s*)${RegExp.escape(keyToken)}\\s*:');
    final match = pattern.firstMatch(dictStr);
    if (match == null) continue;
    var pos = match.end;
    while (pos < dictStr.length && dictStr[pos] == ' ') {
      pos++;
    }
    return pos;
  }
  return null;
}

/// Extracts the string value for [key] from a Python-repr dict string.
String? _extractPythonDictValue(String dictStr, String key) {
  final valueStart = _findPythonDictKeyColon(dictStr, key);
  if (valueStart == null || valueStart >= dictStr.length) return null;

  var pos = valueStart;
  final vq = dictStr[pos];
  if (vq != "'" && vq != '"') return null;
  pos++;

  final buf = StringBuffer();
  while (pos < dictStr.length) {
    final ch = dictStr[pos];
    if (ch == '\\' && pos + 1 < dictStr.length) {
      final esc = dictStr[pos + 1];
      pos += 2;
      if (esc == 'n') {
        buf.writeCharCode(10);
      } else if (esc == 't') {
        buf.writeCharCode(9);
      } else if (esc == 'r') {
        buf.writeCharCode(13);
      } else {
        buf.write(esc);
      }
      continue;
    }

    if (ch == vq) {
      // Closing quote only when followed by `,` or `}` (dict entry boundary).
      var j = pos + 1;
      while (j < dictStr.length && dictStr[j] == ' ') {
        j++;
      }
      if (j >= dictStr.length || dictStr[j] == ',' || dictStr[j] == '}') {
        break;
      }
      buf.write(ch);
      pos++;
      continue;
    }

    buf.write(ch);
    pos++;
  }

  final result = buf.toString().trim();
  return result.isNotEmpty ? result : null;
}
