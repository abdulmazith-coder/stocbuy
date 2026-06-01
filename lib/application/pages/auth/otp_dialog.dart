import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/navigation/app_navigator.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/register_dio.dart';
import 'package:stocbuy_application/application/pages/auth/auth_page.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/stocbuy_result_toast.dart';

Future<void> showOtpDialog(
  BuildContext context, {
  required String email,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x99000000),
    builder: (context) => OtpDialog(email: email),
  );
}

class OtpDialog extends StatefulWidget {
  const OtpDialog({super.key, required this.email});

  final String email;

  @override
  State<OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<OtpDialog> {
  static const int _resendSeconds = 60;

  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _touched = false;
  bool _submitting = false;
  bool _resending = false;
  final _registerDio = RegisterDio();

  void _showTopLeftToast(
    BuildContext? context, {
    required String title,
    required String message,
    required bool success,
  }) {
    showStocbuyResultToast(
      context,
      kind: success ? StocbuyToastKind.success : StocbuyToastKind.error,
      title: title,
      message: message,
    );
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String get _normalizedCode => _code.text.replaceAll(RegExp(r'\s+'), '');

  bool get _isValidCode => RegExp(r'^\d{6}$').hasMatch(_normalizedCode);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final horizontalPadding = media.width < 420 ? 16.0 : 24.0;
    final cardWidth = media.width < 520 ? media.width - (horizontalPadding * 2) : 420.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18),
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: cardWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Verify Email',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: AppColors.darkblue,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the 6-digit code sent to',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.darkblue,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  'OTP Code',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.darkblue,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  cursorColor: AppColors.lightblue,
                  maxLength: 6,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.darkblue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                  decoration: InputDecoration(
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    hintText: '------',
                    errorText: _touched && !_isValidCode ? 'Enter 6 digits' : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.lightblue, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: (!_isValidCode || _submitting)
                      ? null
                      : () async {
                          setState(() {
                            _touched = true;
                            _submitting = true;
                          });

                          bool ok = false;
                          try {
                            ok = await _registerDio.verifyEmail(
                              email: widget.email,
                              Otpcode: _normalizedCode,
                            );
                          } finally {
                            if (mounted) setState(() => _submitting = false);
                          }

                          if (!context.mounted) return;
                          if (!ok) {
                            _showTopLeftToast(
                              context,
                              title: 'Invalid OTP',
                              message: 'Please check the code and try again.',
                              success: false,
                            );
                            return;
                          }

                          // Close OTP dialog, and also close auth dialog if it's still open.
                          final nav = Navigator.of(context, rootNavigator: true);
                          nav.pop(); // OTP
                          Future.microtask(() => nav.maybePop()); // Auth (if still open)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _showTopLeftToast(
                              null,
                              title: 'Verified',
                              message: 'Email verified successfully.',
                              success: true,
                            );
                          });

                          // Open login automatically after verification.
                          Future.delayed(const Duration(milliseconds: 250), () {
                            final ctx = AppNavigator.context;
                            if (ctx != null && ctx.mounted) {
                              showAuthDialog(ctx, initialTab: AuthTab.login);
                            }
                          });
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lightblue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primaryDisabledFill,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify'),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't get a code?",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: (_secondsLeft > 0 || _submitting || _resending)
                          ? null
                          : () async {
                              setState(() => _resending = true);
                              var ok = false;
                              try {
                                ok = await _registerDio.resendOtp(email: widget.email);
                              } finally {
                                if (mounted) setState(() => _resending = false);
                              }
                              if (!context.mounted) return;
                              if (ok) {
                                _showTopLeftToast(
                                  context,
                                  title: 'Code sent',
                                  message: 'Check your inbox for a new OTP.',
                                  success: true,
                                );
                                _startTimer();
                              } else {
                                _showTopLeftToast(
                                  context,
                                  title: 'Could not resend',
                                  message: 'Please try again in a moment.',
                                  success: false,
                                );
                              }
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.lightblue,
                        textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      child: _resending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.lightblue,
                              ),
                            )
                          : Text(
                              _secondsLeft > 0 ? 'Resend in ${_secondsLeft}s' : 'Resend',
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

