import 'dart:async';

import 'package:dio/dio.dart';

/// Non-web platforms use Dio's byte stream; no XHR transport.
Stream<List<int>>? openAiAnalysisProgressStream({
  required Uri uri,
  required Map<String, String> headers,
  CancelToken? cancelToken,
}) =>
    null;
