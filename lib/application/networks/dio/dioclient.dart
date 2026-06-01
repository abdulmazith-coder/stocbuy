import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/controllers/network_controller.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/secure_storage.dart';

class DioClient {
  /// Set on [Options.extra] for routes that must not send `Authorization`
  /// (e.g. public market lists). See [TopCompaniesDio].
  static const String extraKeySkipAuth = 'skipAuth';

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: APISConfigs.baseURL,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  static bool _initialized = false;

  static bool _skipAuth(RequestOptions o) =>
      o.extra[extraKeySkipAuth] == true;

  static NetworkController? get _net => Get.isRegistered<NetworkController>()
      ? Get.find<NetworkController>()
      : null;

  /// Dio error types that mean "we never reached the server" — wifi off,
  /// captive portal, DNS failure, etc. These flip [NetworkController]
  /// into offline mode; any HTTP status (even 5xx) is treated as
  /// "reachable" because the box answered.
  static bool _isConnectivityError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        // `unknown` is the catch-all Dio uses when the underlying
        // adapter throws something it doesn't have a code for — on
        // Flutter web that's typically a `SocketException` /
        // `XMLHttpRequestError` for "Failed to fetch", which is what
        // browsers raise when there's no internet.
        return e.response == null;
      default:
        return false;
    }
  }

  /// Attach interceptors once. Does not poll any API — periodic top-companies
  /// refresh lives in [TopCompaniesController] only.
  static void init() {
    if (_initialized) return;
    _initialized = true;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_skipAuth(options)) {
            options.headers.remove('Authorization');
            handler.next(options);
            return;
          }
          final token = await SecureStorage.getAccessToken();
          if (token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Any successful round-trip is proof we're online.
          _net?.markOnline();
          handler.next(response);
        },
        onError: (e, handler) async {
          if (_isConnectivityError(e)) {
            _net?.markOffline();
          } else if (e.response != null) {
            // Server answered (even with an error) — connection is OK.
            _net?.markOnline();
          }

          final status = e.response?.statusCode;
          final requestOptions = e.requestOptions;
          final alreadyRetried = requestOptions.extra['retried'] == true;

          if (status == 401 &&
              !alreadyRetried &&
              !_skipAuth(requestOptions)) {
            final auth = Get.isRegistered<AuthController>()
                ? Get.find<AuthController>()
                : null;

            final refreshed = await auth?.refreshAccessToken() ?? false;
            if (refreshed) {
              final newToken = await SecureStorage.getAccessToken();
              final clone = await dio.request<dynamic>(
                requestOptions.path,
                data: requestOptions.data,
                queryParameters: requestOptions.queryParameters,
                options: Options(
                  method: requestOptions.method,
                  headers: {
                    ...requestOptions.headers,
                    'Authorization': 'Bearer $newToken',
                  },
                  extra: {
                    ...requestOptions.extra,
                    'retried': true,
                  },
                ),
              );
              return handler.resolve(clone);
            } else {
              // Only force logout when the refresh token has been invalidated
              // by the server (RegisterDio deletes it on 400/401/403).
              // Transient failures (network, 5xx) leave the token intact — we
              // do NOT log the user out in those cases.
              final rt = await SecureStorage.getRefreshToken();
              if (rt.isEmpty) {
                await SecureStorage.deleteAccessToken();
                await auth?.hydrate();
              }
            }
          }

          handler.next(e);
        },
      ),
    );
  }
}
