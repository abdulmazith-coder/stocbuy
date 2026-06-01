import 'dart:async';

import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/models/ai_analysis_usage.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_usage_dio.dart';

class AiUsageController extends GetxController {
  AiUsageController({AiAnalysisUsageDio? dio})
    : _dio = dio ?? AiAnalysisUsageDio();

  final AiAnalysisUsageDio _dio;

  final usage = Rxn<AiAnalysisUsage>();
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  late final AuthController _auth;
  Worker? _authListener;

  @override
  void onInit() {
    super.onInit();
    _auth = Get.find<AuthController>();
    _authListener = ever<bool>(_auth.isLoggedIn, _onAuthChanged);
    if (_auth.isLoggedIn.value) {
      unawaited(fetchUsage());
    }
  }

  @override
  void onClose() {
    _authListener?.dispose();
    _authListener = null;
    super.onClose();
  }

  Future<void> fetchUsage({bool force = false}) async {
    if (!_auth.isLoggedIn.value) {
      usage.value = null;
      errorMessage.value = '';
      return;
    }

    if (isLoading.value && !force) return;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final result = await _dio.fetchUsage();
      usage.value = result;
    } on Exception catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void _onAuthChanged(bool loggedIn) {
    if (loggedIn) {
      unawaited(fetchUsage(force: true));
    } else {
      usage.value = null;
      errorMessage.value = '';
    }
  }
}
