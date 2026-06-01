import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/widgets/stocbuy_result_toast.dart';

// Conditional import:
//   • On web   → external_url_web.dart  (uses dart:html window.open)
//   • Else     → external_url_io.dart   (uses url_launcher)
//
// Web gets `dart:html` directly because `url_launcher_web` routes its
// `window.open` call through async plugin channels — by the time the
// call actually fires, Chrome considers the user-gesture token expired
// and silently blocks the popup. Calling `window.open` synchronously
// in the click handler bypasses that issue and matches the pattern
// the TradingView embed already uses elsewhere in this codebase.
import 'external_url_io.dart'
    if (dart.library.html) 'external_url_web.dart' as platform;

/// One-stop helper for opening external HTTPS URLs (exchange IPO pages,
/// company websites, news articles, …).
///
/// Behaviour:
///   • Quietly normalises bare `domain.com` strings into `https://…`
///     so the half-formed URLs the backend sometimes returns still
///     resolve cleanly.
///   • Dispatches to the right per-platform opener — `dart:html`
///     `window.open` on web, `url_launcher` everywhere else.
///   • Routes failures (malformed scheme, popup blocked, missing
///     browser) into the existing Stocbuy toast system so the user
///     sees a useful message instead of a silent no-op.
Future<bool> openExternalUrl(
  String? rawUrl, {
  BuildContext? context,
  String failureMessage = 'Could not open link.',
}) async {
  final url = _normaliseUrl(rawUrl);
  if (url == null) {
    _toastFailure(context, failureMessage);
    return false;
  }

  // Reject anything that can't even parse as a URI — defensive against
  // garbage backend responses.
  if (Uri.tryParse(url) == null) {
    _toastFailure(context, failureMessage);
    return false;
  }

  try {
    final ok = await platform.openInNewTab(url);
    if (!ok) {
      _toastFailure(context, failureMessage);
    }
    return ok;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('openExternalUrl($url): $e');
    }
    _toastFailure(context, failureMessage);
    return false;
  }
}

/// Promote bare-domain / scheme-less URLs to a sensible https form so
/// values like `www.ongcindia.com` or `https://ongcindia.com` both work.
/// Trims surrounding whitespace and discards empty / placeholder values.
String? _normaliseUrl(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '-' || trimmed == '—') return null;
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  if (lower.startsWith('mailto:') || lower.startsWith('tel:')) {
    return trimmed;
  }
  return 'https://$trimmed';
}

void _toastFailure(BuildContext? context, String message) {
  if (context == null) return;
  if (!context.mounted) return;
  showStocbuyResultToast(
    context,
    kind: StocbuyToastKind.error,
    title: 'Link failed',
    message: message,
  );
}
