import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Parses SSE `data: {...}` chunks into JSON objects (string-aware braces).
Stream<Map<String, dynamic>> parseSseJsonObjectStream(
  Stream<List<int>> byteStream,
) async* {
  final decoded = byteStream.cast<List<int>>().transform(utf8.decoder);
  var buffer = '';

  await for (final chunk in decoded) {
    buffer += chunk;
    final parsed = _parseBuffer(buffer, flush: false);
    buffer = parsed.remaining;
    for (final map in parsed.objects) {
      yield map;
    }
  }

  if (buffer.trim().isNotEmpty) {
    final parsed = _parseBuffer(buffer, flush: true);
    for (final map in parsed.objects) {
      yield map;
    }
  }
}

({List<Map<String, dynamic>> objects, String remaining}) _parseBuffer(
  String buffer, {
  required bool flush,
}) {
  var extracted = extractSseJsonObjects(buffer, flush: flush);
  if (extracted.objects.isEmpty && !buffer.contains('data:')) {
    extracted = extractBraceDelimitedJsonObjects(buffer, flush: flush);
  }
  return extracted;
}

({List<Map<String, dynamic>> objects, String remaining}) extractSseJsonObjects(
  String buffer, {
  bool flush = false,
}) {
  final objects = <Map<String, dynamic>>[];
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

    final jsonEnd = findJsonObjectEnd(remaining, jsonStart);
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
        objects.add(json);
      } else if (json is Map) {
        objects.add(Map<String, dynamic>.from(json));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SSE parse: bad JSON ($e)');
      }
    }
  }

  if (!flush) {
    final lastData = remaining.lastIndexOf('data:');
    if (lastData > 0) {
      remaining = remaining.substring(lastData);
    }
  } else {
    remaining = '';
  }

  return (objects: objects, remaining: remaining);
}

/// Fallback when chunks are bare `{...}{...}` without `data:` prefixes.
({List<Map<String, dynamic>> objects, String remaining})
    extractBraceDelimitedJsonObjects(
  String buffer, {
  bool flush = false,
}) {
  final objects = <Map<String, dynamic>>[];
  var remaining = buffer.replaceAll('\r\n', '\n');
  var searchFrom = 0;

  while (searchFrom < remaining.length) {
    final start = remaining.indexOf('{', searchFrom);
    if (start < 0) break;

    final jsonEnd = findJsonObjectEnd(remaining, start);
    if (jsonEnd == null) {
      if (flush) break;
      remaining = remaining.substring(start);
      break;
    }

    final jsonStr = remaining.substring(start, jsonEnd);
    searchFrom = jsonEnd;
    try {
      final json = jsonDecode(jsonStr);
      if (json is Map<String, dynamic>) {
        objects.add(json);
      } else if (json is Map) {
        objects.add(Map<String, dynamic>.from(json));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SSE brace parse: bad JSON ($e)');
      }
    }
  }

  if (!flush && objects.isEmpty && remaining.contains('{')) {
    final lastBrace = remaining.lastIndexOf('{');
    if (lastBrace > 0) {
      remaining = remaining.substring(lastBrace);
    }
  } else if (flush) {
    remaining = '';
  }

  return (objects: objects, remaining: remaining);
}

int? findJsonObjectEnd(String text, int start) {
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
