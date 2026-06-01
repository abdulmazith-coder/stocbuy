/// Non-web fallback for the network-status helpers.
///
/// On Android / iOS / macOS / Windows / Linux there's no cheap built-in
/// browser-style `online` / `offline` event stream. Without bringing in
/// the `connectivity_plus` package, the best we can do is rely on
/// reactive detection inside the Dio interceptor (5xx / connection
/// errors → flip the flag).
bool isInitiallyOnline() => true;

void listenToConnectivity({
  required void Function() onOnline,
  required void Function() onOffline,
}) {
  // no-op
}
