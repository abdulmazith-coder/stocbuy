/// Cross-platform entry-point for the connectivity helpers used by
/// [NetworkController]. Conditional imports keep `dart:html` out of
/// the mobile / desktop bundles while still giving us real
/// `online` / `offline` browser events on the web.
library;
export 'network_status_io.dart'
    if (dart.library.html) 'network_status_web.dart';
