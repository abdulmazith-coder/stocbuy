import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const String accessToken = "access_token";
  static const String refreshToken = "refresh_token";
  static const String _emailKey = "user_email";

  static Future<void> saveToken(
    String? accessToken,
    String? refreshToken, {
    String? email,
  }) async {
    final at = accessToken?.trim() ?? '';
    final rt = refreshToken?.trim() ?? '';

    // ✅ Only write access token if provided — don't throw if absent
    // (during token refresh only access token comes back)
    if (at.isNotEmpty) {
      await _storage.write(key: SecureStorage.accessToken, value: at);
    }

    if (rt.isNotEmpty) {
      await _storage.write(key: SecureStorage.refreshToken, value: rt);
    }

    if (email != null && email.trim().isNotEmpty) {
      await _storage.write(
        key: _emailKey,
        value: email.trim().toLowerCase(),
      );
    }
  }

  static Future<String> getAccessToken() async {
    return await _storage.read(key: accessToken) ?? '';
  }

  static Future<String> getRefreshToken() async {
    return await _storage.read(key: refreshToken) ?? '';
  }

  static Future<String> getUserEmail() async {
    return await _storage.read(key: _emailKey) ?? '';
  }

  static Future<void> deleteAccessToken() async {
    await _storage.delete(key: accessToken);
  }

  static Future<void> deleteRefreshToken() async {
    await _storage.delete(key: SecureStorage.refreshToken);
  }

  static Future<void> deleteUserEmail() async {
    await _storage.delete(key: _emailKey);
  }
}