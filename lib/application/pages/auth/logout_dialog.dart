import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/stocbuy_result_toast.dart';

Future<void> showLogoutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0x99000000),
    builder: (context) => const _LogoutDialog(),
  );
}

class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog();

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  bool _submitting = false;

  void _toast(
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
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final horizontalPadding = media.width < 420 ? 16.0 : 24.0;
    final cardWidth = media.width < 520 ? media.width - (horizontalPadding * 2) : 420.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: cardWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
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
                        'Log out?',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: const Color(0xFF111827),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: const Color(0xFF6B7280),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You will need to log in again to access your account.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical:20),
                          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting
                            ? null
                            : () async {
                                setState(() => _submitting = true);
                                final ok = await Get.find<AuthController>().logout();
                                if (!context.mounted) return;
                                setState(() => _submitting = false);
                                Navigator.of(context).maybePop();
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _toast(
                                    null,
                                    title: ok ? 'Logged out' : 'Logout failed',
                                    message: ok ? 'See you again.' : 'Please try again.',
                                    success: ok,
                                  );
                                });
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: const Color.fromARGB(255, 27, 27, 27),
                          disabledBackgroundColor: const Color(0xFFA8B7FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                              ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Logout'),
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

