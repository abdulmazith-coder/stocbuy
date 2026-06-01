// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:dio/dio.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_dio.dart'
    show AiAnalysisException;

/// Web: XHR [onProgress] exposes partial [responseText] so SSE steps paint live.
/// (Dio's stream adapter on web often buffers the full body until complete.)
Stream<List<int>>? openAiAnalysisProgressStream({
  required Uri uri,
  required Map<String, String> headers,
  CancelToken? cancelToken,
}) {
  final controller = StreamController<List<int>>();

  final xhr = html.HttpRequest();
  xhr.open('GET', uri.toString());
  xhr.responseType = 'text';
  headers.forEach(xhr.setRequestHeader);

  var lastLen = 0;

  void emitNewBytes() {
    final text = xhr.responseText;
    if (text == null || text.length <= lastLen) return;
    final delta = text.substring(lastLen);
    lastLen = text.length;
    controller.add(utf8.encode(delta));
  }

  xhr.onProgress.listen((_) => emitNewBytes());

  // Some browsers buffer SSE until load; poll partial responseText anyway.
  final poll = Timer.periodic(const Duration(milliseconds: 120), (_) {
    if (xhr.readyState == html.HttpRequest.DONE) return;
    emitNewBytes();
  });

  void finish() {
    poll.cancel();
  }

  xhr.onLoad.listen((_) {
    emitNewBytes();
    finish();
    final status = xhr.status ?? 0;
    if (status != 200) {
      final body = xhr.responseText ?? '';
      if (!controller.isClosed) {
        controller.addError(
          AiAnalysisException(_formatHttpError(status, body)),
        );
      }
      return;
    }
    if (!controller.isClosed) controller.close();
  });
  xhr.onError.listen((_) {
    finish();
    if (!controller.isClosed) {
      final status = xhr.status ?? 0;
      if (status == 0 && lastLen > 0) {
        // Partial SSE body before the browser closed the socket — let the
        // parser finish; retry logic handles empty/failed analysis.
        if (!controller.isClosed) controller.close();
        return;
      }
      controller.addError(
        AiAnalysisException(
          status == 0
              ? 'Network error while streaming analysis.'
              : 'Analysis stream failed on web (HTTP $status).',
        ),
      );
    }
  });
  xhr.onAbort.listen((_) {
    finish();
    if (!controller.isClosed) controller.close();
  });

  cancelToken?.whenCancel.then((_) {
    finish();
    if (xhr.readyState != html.HttpRequest.DONE) {
      xhr.abort();
    }
  });

  xhr.send();

  controller.onCancel = () {
    finish();
    if (xhr.readyState != html.HttpRequest.DONE) {
      xhr.abort();
    }
  };

  return controller.stream;
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
