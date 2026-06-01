// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation of [openInNewTab].
///
/// Calls `window.open(url, '_blank')` directly so the request is fully
/// synchronous to the user-gesture frame. The `url_launcher_web` plugin
/// also wraps `window.open`, but it routes through async plugin
/// channels — by the time the call actually fires Chrome's popup
/// blocker has lost the "this is a real click" signal and silently
/// returns `null`, which the launcher reports back as `false`.
///
/// `noopener,noreferrer` is set on the windowFeatures argument so the
/// new tab gets an isolated browsing context (best practice for
/// cross-site links and recommended by every "secure window.open"
/// checklist).
Future<bool> openInNewTab(String url) async {
  try {
    final win = html.window.open(url, '_blank', 'noopener,noreferrer');
    // `window.open` returns the new WindowProxy, or `null` when the
    // browser's popup blocker refused the request. Treat the null
    // case as failure so the caller can surface a toast.
    // ignore: unnecessary_null_comparison
    return win != null;
  } catch (_) {
    return false;
  }
}
