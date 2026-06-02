import 'package:dio/dio.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/models/useage_locally.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/secure_storage.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/filtered_stock.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/services/best_stocks_cache.dart';

class RegisterDio {
  Future<bool> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      if (username.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('All fields are required');
      }
      final signupURL = APISConfigs.signup;
      final response = await DioClient.dio.post(
        signupURL,
        data: {'username': username, 'email': email, 'password': password},
      );
      if (response.statusCode == 201) {
        return response.data['message'] == true;
      }
      return false;
    } on DioException catch (e) {
      print(e.response?.data);
      return false;
    }
  }

  Future<bool> verifyEmail({
    required String email,
    required String Otpcode,
  }) async {
    try {
      if (email.isEmpty || Otpcode.isEmpty) {
        throw Exception('All fields are required');
      }
      final verifyURL = APISConfigs.verifySignup;
      final response = await DioClient.dio.post(
        verifyURL,
        data: {'email': email, 'otp': Otpcode},
      );
      if (response.statusCode == 200) {
        return response.data['message'] == true;
      }
      return false;
    } on DioException catch (e) {
      print(e.response?.data);
      return false;
    }
  }

  Future<bool> resendOtp({required String email}) async {
    try {
      if (email.isEmpty) throw Exception('All fields are required');
      final resendURL = APISConfigs.resendOtp;
      final response = await DioClient.dio.post(
        resendURL,
        data: {'email': email},
      );
      if (response.statusCode == 200) {
        return response.data['message'] == true;
      }
      return false;
    } on DioException catch (e) {
      print(e.response?.data);
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('All fields are required');
      }
      final loginURL = APISConfigs.login;
      final response = await DioClient.dio.post(
        loginURL,
        data: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['message'] == true) {
          await SecureStorage.saveToken(
            data['access_token'],
            data['refresh_token'],
            email: email,
          );
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      print(e.response?.data);
      return false;
    }
  }

  /// Calls refresh endpoint → on success saves new access token locally
  /// and deletes the old expired one automatically.
  ///
  /// Response expected:
  /// { "message": true, "access_token": "eyJhbG..." }
  ///
  /// Returns true  → new token saved, original request will be retried
  /// Returns false → refresh token is dead, user must login again
  Future<bool> refreshAccessToken() async {
    try {
      final rt = await SecureStorage.getRefreshToken();

      // No refresh token at all → must login
      if (rt.isEmpty) return false;
      final refreshURL = APISConfigs.refreshToken;
      final response = await DioClient.dio.post(
        refreshURL,
        data: {'refresh_token': rt},
        options: Options(
          extra: {DioClient.extraKeySkipAuth: true},
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      final code = response.statusCode ?? 0;

      // Refresh token rejected by server → delete it so hydrate()
      // knows the session is truly dead and shows login screen
      if (code == 400 || code == 401 || code == 403) {
        await SecureStorage.deleteRefreshToken();
        await SecureStorage.deleteAccessToken(); // clean up expired token
        return false;
      }

      if (code == 200) {
        final data = response.data;
        if (data is Map) {
          final newToken = data['access_token']?.toString().trim() ?? '';
          final newRefresh = data['refresh_token']?.toString().trim();
          if (newToken.isNotEmpty) {
            // ✅ Delete old expired access token first
            await SecureStorage.deleteAccessToken();
            // ✅ Save fresh access token locally and update refresh token if provided.
            await SecureStorage.saveToken(newToken, newRefresh);
            return true;
          }

          // Some backend responses do not return access_token under the
          // expected key, but may still indicate success. Accept those too.
          final message = data['message'];
          final normalizedMessage = message?.toString().toLowerCase();
          if (message == true ||
              normalizedMessage == 'true' ||
              normalizedMessage?.contains('success') == true) {
            return true;
          }
        }
      }

      return false;
    } on DioException {
      // Network error — don't delete tokens, just fail silently
      // DioClient will retry on next request
      return false;
    }
  }

  Future<bool> logout() async {
    try {
      final refresh = await SecureStorage.getRefreshToken();
      final logoutURL = APISConfigs.logout;
      if (refresh.isNotEmpty) {
        await DioClient.dio.post(
          logoutURL,
          data: {'refresh_token': refresh},
          options: Options(
            extra: {DioClient.extraKeySkipAuth: true},
            validateStatus: (status) => status != null && status < 600,
          ),
        );
      }
    } on DioException {
    } catch (_) {}

    try {
      await SecureStorage.deleteAccessToken();
      await SecureStorage.deleteRefreshToken();
      await SecureStorage.deleteUserEmail();
      await FilterCacheService.instance.clearAll();
      await BestStocksCache.clearAll();
      await UsageCacheService.instance.clearAll(); // 👈 added
      return true;
    } catch (_) {
      return false;
    }
  }
}
