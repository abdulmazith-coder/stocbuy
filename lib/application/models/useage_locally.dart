import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stocbuy_application/application/models/ai_analysis_usage.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/secure_storage.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_usage_dio.dart';

class UsageCacheService {
  UsageCacheService._();
  static final UsageCacheService instance = UsageCacheService._();

  static const _storage = FlutterSecureStorage();
  static const _usageKeyPrefix = 'ai_analysis_usage_';

  // ── key scoped per user ──────────────────────────────────────────────────
  Future<String> _usageKey() async {
    final email = await SecureStorage.getUserEmail();
    final userKey = email.isNotEmpty
        ? email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        : 'guest';
    return '$_usageKeyPrefix$userKey';
  }

  Future<void> saveUsage(AiAnalysisUsage usage) async {
    final encoded = jsonEncode({
      'plan': usage.plan,
      'is_unlimited': usage.isUnlimited,
      'used': usage.used,
      'limit': usage.limit,
      'remaining': usage.remaining,
      'message': usage.message,
    });
    final key = await _usageKey();
    await _storage.write(key: key, value: encoded);
  }

  Future<AiAnalysisUsage?> getUsage() async {
    final key = await _usageKey();
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AiAnalysisUsage.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Always fetches fresh usage from backend, saves locally, returns it.
  /// Call this on app start, after login, and after premium upgrade.
  Future<AiAnalysisUsage?> refreshFromBackend() async {
    try {
      final usage = await AiAnalysisUsageDio().fetchUsage();
      await saveUsage(usage);
      return usage;
    } catch (_) {
      // Network error — fall back to cached value
      return getUsage();
    }
  }

  /// True if remaining == 0 and not unlimited.
  /// Always syncs from backend first to avoid stale premium state.
  Future<bool> isLimitExhausted() async {
    // ✅ Always get fresh data from backend before checking limit
    final usage = await refreshFromBackend();
    if (usage == null) return false;          // no data → allow
    if (usage.isUnlimited) return false;      // premium → allow
    return usage.remaining <= 0;              // exhausted → block
  }

  Future<void> clear() async {
    final key = await _usageKey();
    await _storage.delete(key: key);
  }

  /// Call on logout to clear this user's usage cache.
  Future<void> clearAll() async {
    final key = await _usageKey();
    await _storage.delete(key: key);
  }
}