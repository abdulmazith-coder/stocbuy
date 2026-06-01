import 'dart:async';

import 'package:get/get.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/register_dio.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/secure_storage.dart';

class AuthController extends GetxController {
  final _dio = RegisterDio();

  final isLoggedIn = false.obs;
  final isRefreshing = false.obs;

  Completer<bool>? _refreshCompleter;

  @override
  Future<void> onInit() async {
    super.onInit();
    await hydrate();
  }

  Future<void> hydrate() async {
    final rt = await SecureStorage.getRefreshToken();

    // ✅ Session is valid as long as refresh token exists.
    // Access token can be empty — DioClient will auto-refresh it on next call.
    isLoggedIn.value = rt.isNotEmpty;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final ok = await _dio.login(email: email, password: password);
    await hydrate();
    return ok;
  }

  Future<bool> logout() async {
    final ok = await _dio.logout();
    await hydrate();
    return ok;
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    isRefreshing.value = true;

    try {
      final ok = await _dio.refreshAccessToken();
      // ✅ Don't call hydrate() here — refresh token didn't change,
      // calling hydrate() risks a flicker of isLoggedIn = false
      // if timing is unlucky. Only hydrate on login/logout.
      completer.complete(ok);
      return ok;
    } catch (e) {
      completer.complete(false);
      return false;
    } finally {
      isRefreshing.value = false;
      _refreshCompleter = null;
    }
  }
}