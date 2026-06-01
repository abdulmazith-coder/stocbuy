

import 'package:flutter/material.dart';

enum ScreenSize{
  mobile,
  tablet,
  desktop,
}

class Responsive{
  static const double mobileBreakpoint  = 768;
  static const double tabletBreakpoint  = 1100;

    static ScreenSize of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint)  return ScreenSize.mobile;
    if (width < tabletBreakpoint)  return ScreenSize.tablet;
    return ScreenSize.desktop;
  }
 
   static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;
 
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobileBreakpoint && w < tabletBreakpoint;
  }
 
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;
 

 static T value<T>(BuildContext context, {
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    switch (of(context)) {
      case ScreenSize.mobile:  return mobile;
      case ScreenSize.tablet:  return tablet;
      case ScreenSize.desktop: return desktop;
    }
  }
 
  /// Horizontal page padding adapts to viewport.
  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final h = width < mobileBreakpoint
        ? 20.0
        : width < tabletBreakpoint
            ? 40.0
            : ((width - 1200) / 2).clamp(60.0, 200.0);
    return EdgeInsets.symmetric(horizontal: h);
  }

  /// Tight horizontal insets so dashboard + table use nearly full viewport width.
  static EdgeInsets dashboardBodyPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      // Wider on large phones; tighter on very small devices so lists breathe.
      final h = width < 340
          ? 14.0
          : width < 400
              ? 18.0
              : width > 520
                  ? 24.0
                  : 20.0;
      return EdgeInsets.symmetric(horizontal: h);
    }
    if (width < tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 24);
  }

  /// Full-bleed header rows (e.g. ticker under app bar): no artificial side margins.
  /// Uses only [MediaQuery.viewPadding] so notched devices stay safe; web is 0.
  static EdgeInsets fullBleedChromePadding(
    BuildContext context, {
    double vertical = 8,
  }) {
    final v = MediaQuery.viewPaddingOf(context);
    return EdgeInsets.fromLTRB(v.left, vertical, v.right, vertical);
  }



}



class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });
 
  final Widget Function(BuildContext) mobile;
  final Widget Function(BuildContext) tablet;
  final Widget Function(BuildContext) desktop;
 
  @override
  Widget build(BuildContext context) {
    return switch (Responsive.of(context)) {
      ScreenSize.mobile  => mobile(context),
      ScreenSize.tablet  => tablet(context),
      ScreenSize.desktop => desktop(context),
    };
  }
}