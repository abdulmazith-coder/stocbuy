import 'package:url_launcher/url_launcher.dart';

/// Non-web implementation of [openInNewTab].
///
/// Used on Android, iOS, macOS, Windows, Linux — every target where
/// `dart:html` doesn't exist. `url_launcher` handles the platform
/// channel dance to the system browser.
Future<bool> openInNewTab(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
