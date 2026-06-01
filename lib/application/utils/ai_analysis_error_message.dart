/// True when the analysis stream failed due to a dropped HTTP/DB connection.
bool isTransientAnalysisConnectionError(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('server closed the connection') ||
      lower.contains('connection already closed') ||
      lower.contains('connection reset') ||
      lower.contains('broken pipe') ||
      lower.contains('connection refused') ||
      lower.contains('connection timed out') ||
      lower.contains('receive timeout') ||
      lower.contains('analysis stream failed');
}

/// Turns raw API / provider errors into a short message for the chat bubble.
String formatAiAnalysisErrorMessage(String raw) {
  final trimmed = _dedupeLines(raw.trim());
  if (trimmed.isEmpty) {
    return '**Analysis could not be completed.**\n\nPlease try again later.';
  }

  final lower = trimmed.toLowerCase();

  if (isTransientAnalysisConnectionError(trimmed)) {
    return '**Connection lost** while the server was analysing this stock.\n\n'
        'Full analyses can take up to a minute. Please tap **Send** to try again — '
        'the app will retry automatically if the connection drops.';
  }

  if (lower.contains('rate limit') || lower.contains('rate_limit')) {
    final retry = RegExp(
      r'please try again in\s+(\d+m[\d.]*s|\d+\s*minutes?)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (retry != null) {
      return '**Rate limit reached.** The AI service is busy. '
          'Please try again in ${retry.group(1)}.';
    }
    return '**Rate limit reached.** The AI service is busy. '
        'Please try again in a few minutes.';
  }

  // JWT / auth errors must be checked BEFORE the generic token+expiry check
  // because JWT bodies also contain "token" and "expir".
  if (lower.contains('unauthorized') ||
      lower.contains('401') ||
      _looksLikeJwtError(trimmed)) {
    return '**Session expired.** Please sign in again and retry.';
  }

  if (lower.contains('token') &&
      (lower.contains('expir') ||
          lower.contains('limit') ||
          lower.contains('quota'))) {
    return '**Usage limit reached.**';
  }

  if (_looksLikeMissingFieldError(trimmed)) {
    return '**Company data is incomplete** for this symbol from our data provider. '
        'Try a more specific question (e.g. financial ratios or news), or retry in a moment.';
  }

  if (_looksLikeDuplicateAnalysisError(trimmed)) {
    return '**Analysis already saved.** '
        'The result for this stock was cached successfully. '
        'Please ask a follow-up question or request a different analysis.';
  }

  if (_looksLikeInternalDbError(trimmed)) {
    return '**Analysis could not be completed.**\n\nPlease try again later.';
  }

  final stripped = _stripAnalysisFailedPrefix(trimmed);
  if (stripped != trimmed ||
      lower.startsWith('analysis failed') ||
      lower.startsWith('request failed') ||
      lower.startsWith('unexpected error')) {
    return _shorten(stripped, 480);
  }

  return '**Analysis could not be completed.**\n\n${_shorten(_innerMessage(trimmed), 480)}';
}

String _stripAnalysisFailedPrefix(String raw) {
  return raw
      .replaceFirst(
        RegExp(r'^Analysis failed \(HTTP \d+\):\s*', caseSensitive: false),
        '',
      )
      .trim();
}

String _innerMessage(String raw) {
  var msg = raw;
  final codePrefix = RegExp(r'^Error code:\s*\d+\s*-\s*', caseSensitive: false);
  if (codePrefix.hasMatch(msg)) {
    msg = msg.replaceFirst(codePrefix, '').trim();
  }

  final singleQuoted = RegExp(
    r"message'\s*:\s*'([^']+)'",
    caseSensitive: false,
  ).firstMatch(msg);
  if (singleQuoted != null) {
    return singleQuoted.group(1)!.trim();
  }
  final doubleQuoted = RegExp(
    r'message"\s*:\s*"([^"]+)"',
    caseSensitive: false,
  ).firstMatch(msg);
  if (doubleQuoted != null) {
    return doubleQuoted.group(1)!.trim();
  }

  return msg;
}

/// Python KeyError strings from the backend, e.g. `'longName'`.
bool _looksLikeMissingFieldError(String raw) {
  final t = raw.trim();
  if (t.length > 80) return false;
  final keyOnly = RegExp(r"^'?[A-Za-z][A-Za-z0-9_]*'?$");
  if (keyOnly.hasMatch(t)) return true;
  return RegExp(r"keyerror", caseSensitive: false).hasMatch(t);
}

String _shorten(String text, int maxLen) {
  if (text.length <= maxLen) return text;
  return '${text.substring(0, maxLen)}…';
}

/// Django REST / Simple JWT token-rejection errors.
///
/// These contain `token_not_valid`, `token_class`, or `Token is expired` in the
/// body — they look like "token + expiry" but are authentication errors, not
/// usage-quota errors.
bool _looksLikeJwtError(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('token_not_valid') ||
      lower.contains('token_class') ||
      lower.contains('token is expired') ||
      lower.contains('token is invalid') ||
      lower.contains('given token not valid') ||
      lower.contains('simplejwt') ||
      lower.contains('accesstoken') ||
      lower.contains('token_type: access');
}

/// Postgres / Django unique-constraint violation — the analysis row already exists.
bool _looksLikeDuplicateAnalysisError(String raw) {
  final lower = raw.toLowerCase();
  return (lower.contains('duplicate key') ||
          lower.contains('unique constraint') ||
          lower.contains('already exists')) &&
      (lower.contains('analysis_type') ||
          lower.contains('stock_symbol') ||
          lower.contains('uniq'));
}

/// Any other raw database / server-internal error that should never be shown as-is.
bool _looksLikeInternalDbError(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('violates') ||
      lower.contains('constraint') ||
      lower.contains('detail: key') ||
      lower.contains('integrityerror') ||
      lower.contains('operationalerror') ||
      lower.contains('programmingerror') ||
      lower.contains('django.db') ||
      lower.contains('psycopg') ||
      lower.contains('sqlstate');
}

/// Removes repeated lines (common when backend + transport both report the same fault).
String _dedupeLines(String text) {
  final lines = text.split(RegExp(r'\n+'));
  final seen = <String>{};
  final out = <String>[];
  for (final line in lines) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final key = t.toLowerCase();
    if (seen.add(key)) out.add(t);
  }
  return out.join('\n');
}
