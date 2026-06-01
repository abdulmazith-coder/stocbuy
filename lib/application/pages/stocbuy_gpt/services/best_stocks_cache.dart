import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/secure_storage.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/best_stocks_cap_type.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/filtered_stock.dart';

// ─── helper ────────────────────────────────────────────────────────────────

Future<String> _currentUserKey() async {
  final email = await SecureStorage.getUserEmail();
  return email.isNotEmpty
      ? email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
      : 'guest';
}

// ─── BestStocksCache ────────────────────────────────────────────────────────

/// Persists completed scanner results per [BestStocksCapType] for 3 days.
class BestStocksCache {
  static const _ttl = Duration(days: 3);
  static const _prefix = 'best_stocks_cache_';

  /// Key: best_stocks_cache_{sanitizedEmail}_{capType}
  static Future<String> _key(BestStocksCapType cap) async {
    final userKey = await _currentUserKey();
    return '$_prefix${userKey}_${cap.apiValue}';
  }

  static Future<BestStocksCachePayload?> load(BestStocksCapType capType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _key(capType);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;

      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final payload = BestStocksCachePayload.fromJson(json);
      if (DateTime.now().difference(payload.savedAt) > _ttl) {
        await prefs.remove(key);
        return null;
      }
      return payload;
    } catch (_) {
      return null;
    }
  }

  // No _ensureValidToken needed — DioClient interceptor handles it globally
  static Future<void> save(BestStocksCachePayload payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _key(payload.capType);
      await prefs.setString(key, jsonEncode(payload.toJson()));
    } catch (_) {
      // Web / plugin unavailable — skip cache write.
    }
  }

  static Future<void> clearExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final cap in BestStocksCapType.values) {
        final key = await _key(cap);
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final json = jsonDecode(raw);
          if (json is Map<String, dynamic>) {
            final payload = BestStocksCachePayload.fromJson(json);
            if (DateTime.now().difference(payload.savedAt) > _ttl) {
              await prefs.remove(key);
            }
          }
        } catch (_) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }

  /// Clears all cap types for the currently logged-in user only.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final cap in BestStocksCapType.values) {
        final key = await _key(cap);
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}