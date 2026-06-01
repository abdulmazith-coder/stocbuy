import 'package:dio/dio.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_dio.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_error_message.dart';

/// Streams AI analysis with automatic retries on transient connection drops.
Stream<AiAnalysisStreamEvent> streamAnalysisWithRetry(
  AiAnalysisDio dio, {
  required String stockSymbol,
  required String prompt,
  CancelToken? cancelToken,
  int maxAttempts = 3,
}) async* {
  Object? lastFailure;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (cancelToken?.isCancelled == true) return;

    if (attempt > 1) {
      yield AiAnalysisStreamEvent(
        status: 'processing',
        message:
            'Connection lost — retrying analysis ($attempt/$maxAttempts)…',
      );
      await Future<void>.delayed(Duration(milliseconds: 900 * attempt));
      if (cancelToken?.isCancelled == true) return;
    }

    var shouldRetry = false;

    try {
      await for (final event in dio.streamAnalysis(
        stockSymbol: stockSymbol,
        prompt: prompt,
        cancelToken: cancelToken,
      )) {
        if (event.isError) {
          if (isTransientAnalysisConnectionError(event.message) &&
              attempt < maxAttempts) {
            lastFailure = event.message;
            shouldRetry = true;
            break;
          }
          yield event;
          return;
        }
        yield event;
      }
    } on AiAnalysisException catch (e) {
      lastFailure = e.message;
      if (!isTransientAnalysisConnectionError(e.message) ||
          attempt >= maxAttempts) {
        yield AiAnalysisStreamEvent(status: 'error', message: e.message);
        return;
      }
      shouldRetry = true;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      final msg = e.message ?? 'Request failed.';
      lastFailure = msg;
      if (!isTransientAnalysisConnectionError(msg) || attempt >= maxAttempts) {
        yield AiAnalysisStreamEvent(status: 'error', message: msg);
        return;
      }
      shouldRetry = true;
    }

    if (!shouldRetry) return;
  }

  yield AiAnalysisStreamEvent(
    status: 'error',
    message: lastFailure?.toString() ??
        'Analysis failed after $maxAttempts attempts.',
  );
}
