import 'package:flutter/material.dart';

/// Root [Navigator] key for [GetMaterialApp] / [MaterialApp].
/// Use [context] or [overlay] after the first frame when you need a stable
/// overlay (e.g. toasts after closing a dialog).
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>();

  static BuildContext? get context => rootKey.currentContext;

  static OverlayState? get overlay => rootKey.currentState?.overlay;
}
