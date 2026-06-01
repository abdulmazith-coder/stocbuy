import 'package:flutter/material.dart';

/// Exact Figma palette — all tokens from the design file colour panel.
class AppColors {
  // ── Neutrals ─────────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// Primary text / chrome.
  static const Color darkblue = Color(0xFF222531);

  /// Near-black text alternative.
  static const Color textPrimaryAlt = Color(0xFF1E1E1E);

  /// Muted labels / secondary text.
  static const Color grey = Color(0xFF58667E);

  // ── Brand / CTAs ─────────────────────────────────────────────────────────
  /// Main brand blue — #3861FB.
  static const Color lightblue = Color(0xFF3861FB);

  static const Color primaryBlueDark = Color(0xFF004C8F);
  static const Color primaryBlueBright = Color(0xFF0052FF);
  static const Color primaryBlueMid = Color(0xFF0078D6);
  static const Color primaryBlueDeep = Color(0xFF0F4A8A);
  static const Color primaryBlueSteel = Color(0xFF1A5B9B);

  /// Alias for charts / links.
  static const Color dashboardAccent = lightblue;

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color green = Color(0xFF16C784);
  static const Color greenMutedBg = Color(0x1A16C784); // 16C784 @ 10 %

  static const Color red = Color(0xFFEA3943);

  // ── Accents ───────────────────────────────────────────────────────────────
  static const Color purple = Color(0xFF6D28D9);
  static const Color peach = Color(0xFFF5B97F);
  static const Color orangeAccent = Color(0xFFF18221);

  // ── Surface / chrome ─────────────────────────────────────────────────────
  /// Dividers, light borders — #EFF2F5.
  static const Color lightWhite = Color(0xFFEFF2F5);

  /// Card / input backgrounds — #F8F9FA.
  static const Color surfaceMuted = Color(0xFFF8F9FA);

  /// Page scaffold behind cards.
  static const Color pageScaffold = Color(0xFFF4F5F7);

  /// General border — slightly darker than lightWhite.
  static const Color border = Color(0xFFE5E7EB);

  // ── Disabled ─────────────────────────────────────────────────────────────
  /// Muted primary for disabled filled buttons.
  static const Color primaryDisabledFill = Color(0xFFA8B7FF);
}
