// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation — reads `navigator.onLine` and subscribes to the
/// browser's `online` / `offline` events. Both are widely supported
/// (every browser since 2018) and switch instantly when the user pulls
/// their wifi cable or kills the connection.
bool isInitiallyOnline() {
  // `onLine` is nullable in the typing but in practice every browser
  // returns a bool. Treat `null` as optimistic-online.
  final v = html.window.navigator.onLine;
  return v ?? true;
}

void listenToConnectivity({
  required void Function() onOnline,
  required void Function() onOffline,
}) {
  html.window.onOnline.listen((_) => onOnline());
  html.window.onOffline.listen((_) => onOffline());
}
