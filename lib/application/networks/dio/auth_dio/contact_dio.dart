import 'package:dio/dio.dart';
import 'package:stocbuy_application/apisconfig.dart';
import 'package:stocbuy_application/application/networks/dio/dioclient.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Typed server errors
// ─────────────────────────────────────────────────────────────────────────────

enum ContactErrorKind {
  /// No account found for the email — user must sign up first.
  noAccount,

  /// Premium plan is still active.
  alreadyPremium,

  /// A pending request already exists — wait for the team.
  pending,

  /// Phone number missing.
  phoneRequired,

  /// Requested limit ≤ current limit.
  /// [ContactRequestException.currentLimit] holds the server's current value.
  limitTooLow,

  /// No internet / DNS failure.
  noInternet,

  /// Catch-all.
  unknown,
}

class ContactRequestException implements Exception {
  const ContactRequestException({
    required this.kind,
    required this.message,
    this.currentLimit,
  });

  final ContactErrorKind kind;
  final String message;

  /// Only set when kind == [ContactErrorKind.limitTooLow].
  /// Holds the user's current daily AI analysis limit from the server.
  final int? currentLimit;

  @override
  String toString() => 'ContactRequestException($kind): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Success result — carries back server-confirmed limits
// ─────────────────────────────────────────────────────────────────────────────

class ContactRequestResult {
  const ContactRequestResult({
    required this.currentAnalysisLimit,
    this.requestedAnalysisLimit,
  });

  /// The user's current daily limit (confirmed by the server).
  final int currentAnalysisLimit;

  /// The limit the user asked for (null if unlimited was requested).
  final int? requestedAnalysisLimit;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Payload
// ─────────────────────────────────────────────────────────────────────────────

class ContactRequestPayload {
  const ContactRequestPayload({
    required this.email,
    this.phone = '',
    this.requestedAnalysisLimit,   // null → not sending a limit request
    this.requestFilterPenny = false,
    this.requestFilterMid = false,
    this.requestFilterLarge = false,
    this.requestFilterGrowth = false,
    this.requestAnalysisUnlimited = false,
    this.extraInfo,
  });

  final String email;
  final String phone;

  /// Maps to `requested_analysis_limit` on the backend.
  /// Must be > user's current limit, or null when [requestAnalysisUnlimited] is true.
  final int? requestedAnalysisLimit;

  final bool requestFilterPenny;
  final bool requestFilterMid;
  final bool requestFilterLarge;
  final bool requestFilterGrowth;
  final bool requestAnalysisUnlimited;
  final Map<String, dynamic>? extraInfo;

  Map<String, dynamic> toJson() => {
        'email': email,
        'phone': phone,
        // Only send the key when it has a value — omitting it is valid for unlimited
        if (requestedAnalysisLimit != null)
          'requested_analysis_limit': requestedAnalysisLimit,
        'request_filter_penny': requestFilterPenny,
        'request_filter_mid': requestFilterMid,
        'request_filter_large': requestFilterLarge,
        'request_filter_growth': requestFilterGrowth,
        'request_analysis_unlimited': requestAnalysisUnlimited,
        if (extraInfo != null) 'extra_info': extraInfo,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dio service
// ─────────────────────────────────────────────────────────────────────────────

class ContactRequestDio {
  static const String _path = 'auth/contact-us/';

  /// Returns a [ContactRequestResult] on success.
  /// Throws [ContactRequestException] on any error.
  Future<ContactRequestResult> submitRequest(ContactRequestPayload payload) async {
    try {
      final response = await DioClient.dio.post<Map<String, dynamic>>(
        _path,
        data: payload.toJson(),
        options: Options(
          validateStatus: (s) => s != null && s < 600,
        ),
      );

      final httpStatus = response.statusCode ?? 0;
      final body = response.data;

      // ── Success 201 ──────────────────────────────────────────────────────
      if (httpStatus == 201 || httpStatus == 200) {
        final currentLimit =
            (body is Map ? body!['current_analysis_limit'] : null) as int? ?? 3;
        final requestedLimit =
            (body is Map ? body!['requested_analysis_limit'] : null) as int?;
        return ContactRequestResult(
          currentAnalysisLimit: currentLimit,
          requestedAnalysisLimit: requestedLimit,
        );
      }

      // ── Parse error body ─────────────────────────────────────────────────
      final serverMsg = body is Map
          ? (body?['error'] ?? body?['detail'] ?? body?['message'])
                  ?.toString() ??
              ''
          : '';
      final action = body is Map ? body!['action']?.toString() ?? '' : '';

      ContactErrorKind kind;
      int? currentLimit;

      final msgLower = serverMsg.toLowerCase();

      if (httpStatus == 400 && msgLower.contains('phone')) {
        kind = ContactErrorKind.phoneRequired;
      } else if (httpStatus == 400 && msgLower.contains('requested_analysis_limit')) {
        kind = ContactErrorKind.limitTooLow;
        // Parse "must be greater than your current limit of N" from the message
        final match = RegExp(r'current limit of (\d+)').firstMatch(serverMsg);
        currentLimit = match != null ? int.tryParse(match.group(1) ?? '') : null;
      } else if (httpStatus == 403 && action == 'signup') {
        kind = ContactErrorKind.noAccount;
      } else if (httpStatus == 409 && action == 'already_premium') {
        kind = ContactErrorKind.alreadyPremium;
      } else if (httpStatus == 409 && action == 'pending') {
        kind = ContactErrorKind.pending;
      } else {
        kind = ContactErrorKind.unknown;
      }

      throw ContactRequestException(
        kind: kind,
        message: serverMsg.isNotEmpty ? serverMsg : 'Request failed ($httpStatus)',
        currentLimit: currentLimit,
      );
    } on ContactRequestException {
      rethrow;
    } on DioException catch (e) {
      final isConnectivity = e.response == null ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;

      if (isConnectivity) {
        throw const ContactRequestException(
          kind: ContactErrorKind.noInternet,
          message: 'No internet connection.',
        );
      }
      throw ContactRequestException(
        kind: ContactErrorKind.unknown,
        message: e.message ?? 'Something went wrong.',
      );
    } catch (e) {
      throw ContactRequestException(
        kind: ContactErrorKind.unknown,
        message: e.toString(),
      );
    }
  }
}