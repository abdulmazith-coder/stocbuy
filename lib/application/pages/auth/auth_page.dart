import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/auth_controller.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/register_dio.dart';
import 'package:stocbuy_application/application/navigation/app_navigator.dart';
import 'package:stocbuy_application/application/pages/auth/otp_dialog.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/stocbuy_result_toast.dart';

enum AuthTab { login, signup }

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

void _showInfoSnackbar(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showStocbuyResultToast(
    context,
    kind: StocbuyToastKind.info,
    title: title,
    message: message,
  );
}

Future<void> showAuthDialog(
  BuildContext context, {
  AuthTab initialTab = AuthTab.login,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: AuthDialog(initialTab: initialTab),
      );
    },
  );
}

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key, this.initialTab = AuthTab.login});

  final AuthTab initialTab;

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  final _signupUsername = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPassword = TextEditingController();

  bool _loginTouched = false;
  bool _signupTouched = false;
  bool _submitting = false;
  final RegisterDio _registerDio = RegisterDio();
  final _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == AuthTab.login ? 0 : 1,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    void repaint() => setState(() {});
    _loginEmail.addListener(repaint);
    _loginPassword.addListener(repaint);
    _signupUsername.addListener(repaint);
    _signupEmail.addListener(repaint);
    _signupPassword.addListener(repaint);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _signupUsername.dispose();
    _signupEmail.dispose();
    _signupPassword.dispose();
    super.dispose();
  }

  static final RegExp _emailRegex = RegExp(
    r"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$",
    caseSensitive: false,
  );

  /// Backend rule: password must be **more than** 6 characters (7+).
  static bool _passwordLongEnough(String raw) => raw.trim().length > 6;

  bool get _isLoginValid =>
      _emailRegex.hasMatch(_loginEmail.text.trim()) &&
      _passwordLongEnough(_loginPassword.text);

  bool get _isSignupValid =>
      _signupUsername.text.trim().isNotEmpty &&
      _emailRegex.hasMatch(_signupEmail.text.trim()) &&
      _passwordLongEnough(_signupPassword.text);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final isMobile = Responsive.isMobile(context);
    final isLoginTab = _tabController.index == 0;
    final isValid = isLoginTab ? _isLoginValid : _isSignupValid;

    final maxCardHeight = isMobile
        ? (media.height - padding.vertical - 28).clamp(480.0, 900.0)
        : (media.height * 0.88).clamp(420.0, 720.0);

    final card = _AuthCard(
      layoutMobile: isMobile,
      maxHeight: maxCardHeight,
      tabController: _tabController,
      onClose: () => Navigator.of(context).maybePop(),
      loginEmail: _loginEmail,
      loginPassword: _loginPassword,
      signupUsername: _signupUsername,
      signupEmail: _signupEmail,
      signupPassword: _signupPassword,
      loginTouched: _loginTouched,
      signupTouched: _signupTouched,
      isSubmitting: _submitting,
      onSubmit: () async {
            setState(() {
              if (isLoginTab) {
                _loginTouched = true;
              } else {
                _signupTouched = true;
              }
            });
            if (!isValid) return;

            if (isLoginTab) {
              final email = _loginEmail.text.trim();
              final password = _loginPassword.text.trim();

              setState(() => _submitting = true);
              bool ok = false;
              try {
                ok = await _auth.login(email: email, password: password);
              } finally {
                if (mounted) setState(() => _submitting = false);
              }

              if (!context.mounted) return;
              if (!ok) {
                final narrow = Responsive.isMobile(context);
                _showTopLeftToast(
                  context,
                  title: narrow ? 'Login failed!' : 'Login failed',
                  message: 'Please check your credentials.',
                  success: false,
                );
                return;
              }

              final narrow = Responsive.isMobile(context);
              final okTitle = narrow ? 'Login successful!' : 'Welcome back!';
              final okMsg = narrow ? '' : 'You have successfully logged in.';
              Navigator.of(context).maybePop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showTopLeftToast(
                  null,
                  title: okTitle,
                  message: okMsg,
                  success: true,
                );
              });

              return;
            }

            final email = _signupEmail.text.trim();
            final username = _signupUsername.text.trim();
            final password = _signupPassword.text.trim();

            setState(() => _submitting = true);
            bool ok = false;
            try {
              ok = await _registerDio.signup(
                username: username,
                email: email,
                password: password,
              );
            } finally {
              if (mounted) setState(() => _submitting = false);
            }

            if (!context.mounted) return;
            if (!ok) {
              _showTopLeftToast(
                context,
                title: 'Signup failed',
                message: 'Please try again.',
                success: false,
              );
              return;
            }

            _signupUsername.clear();
            _signupEmail.clear();
            _signupPassword.clear();

            Navigator.of(context).maybePop();
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              _showTopLeftToast(
                null,
                title: 'Check your mail',
                message: 'We sent an OTP to verify your email.',
                success: true,
              );
              final root = AppNavigator.context;
              if (root != null && root.mounted) {
                await showOtpDialog(root, email: email);
              }
            });
          },
      canSubmit: isValid,
    );

    if (isMobile) {
      return Material(
        color: AppColors.pageScaffold,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox.expand(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Center(child: card),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66000000),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  maxHeight: maxCardHeight,
                ),
                child: card,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.layoutMobile,
    required this.maxHeight,
    required this.tabController,
    required this.onClose,
    required this.loginEmail,
    required this.loginPassword,
    required this.signupUsername,
    required this.signupEmail,
    required this.signupPassword,
    required this.loginTouched,
    required this.signupTouched,
    required this.onSubmit,
    required this.canSubmit,
    required this.isSubmitting,
  });

  final bool layoutMobile;
  final double maxHeight;
  final TabController tabController;
  final VoidCallback onClose;
  final TextEditingController loginEmail;
  final TextEditingController loginPassword;
  final TextEditingController signupUsername;
  final TextEditingController signupEmail;
  final TextEditingController signupPassword;
  final bool loginTouched;
  final bool signupTouched;
  final Future<void> Function() onSubmit;
  final bool canSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = layoutMobile ? 20.0 : 16.0;
    final hPad = layoutMobile ? 18.0 : 22.0;
    final tabLabelActive = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: layoutMobile ? 16 : 15,
      color: AppColors.darkblue,
    );
    final tabLabelIdle = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: layoutMobile ? 16 : 15,
      color: AppColors.grey,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF222531).withValues(alpha: layoutMobile ? 0.09 : 0.14),
            blurRadius: layoutMobile ? 28 : 40,
            offset: Offset(0, layoutMobile ? 12 : 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, layoutMobile ? 14 : 16, 6, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: tabController,
                        labelColor: AppColors.darkblue,
                        unselectedLabelColor: AppColors.grey,
                        labelStyle: tabLabelActive,
                        unselectedLabelStyle: tabLabelIdle,
                        indicatorColor: AppColors.lightblue,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorWeight: 3,
                        tabAlignment: TabAlignment.start,
                        isScrollable: true,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.only(right: 20),
                        tabs: const [
                          Tab(text: 'Log In'),
                          Tab(text: 'Sign Up'),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: layoutMobile ? 'Close' : 'Close',
                      onPressed: onClose,
                      icon: Icon(
                        layoutMobile ? Icons.keyboard_arrow_up_rounded : Icons.close_rounded,
                        size: layoutMobile ? 28 : 22,
                      ),
                      color: AppColors.grey,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: AppColors.border.withValues(alpha: 0.9)),
              SizedBox(height: layoutMobile ? 16 : 18),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 22),
                      child: _LoginTab(
                        layoutMobile: layoutMobile,
                        email: loginEmail,
                        password: loginPassword,
                        touched: loginTouched,
                        onSubmit: onSubmit,
                        canSubmit: canSubmit && tabController.index == 0 && !isSubmitting,
                        isSubmitting: isSubmitting && tabController.index == 0,
                      ),
                    ),
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 22),
                      child: _SignupTab(
                        layoutMobile: layoutMobile,
                        username: signupUsername,
                        email: signupEmail,
                        password: signupPassword,
                        touched: signupTouched,
                        onSubmit: onSubmit,
                        canSubmit: canSubmit && tabController.index == 1 && !isSubmitting,
                        isSubmitting: isSubmitting && tabController.index == 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginTab extends StatelessWidget {
  const _LoginTab({
    required this.layoutMobile,
    required this.email,
    required this.password,
    required this.touched,
    required this.onSubmit,
    required this.canSubmit,
    required this.isSubmitting,
  });

  final bool layoutMobile;
  final TextEditingController email;
  final TextEditingController password;
  final bool touched;
  final Future<void> Function() onSubmit;
  final bool canSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final emailText = email.text.trim();
    final passwordText = password.text.trim();
    final emailValid = _AuthDialogState._emailRegex.hasMatch(emailText);
    final passwordValid = _AuthDialogState._passwordLongEnough(passwordText);

    final gap = layoutMobile ? 14.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Email Address',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
        ),
        const SizedBox(height: 8),
        _AuthTextField(
          controller: email,
          hintText: 'Enter your email address...',
          keyboardType: TextInputType.emailAddress,
          errorText: touched && !emailValid ? 'Enter a valid email address' : null,
        ),
        SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Password',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => _showInfoSnackbar(
                context,
                title: 'Reset password',
                message: 'Password reset is not available yet. Please contact support if you need help.',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot password?',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.grey,
                      fontSize: 12,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _AuthTextField(
          controller: password,
          hintText: 'Enter your password...',
          obscureText: true,
          errorText: touched && !passwordValid
              ? 'Password must be more than 6 characters'
              : null,
        ),
        SizedBox(height: layoutMobile ? 22 : 18),
        FilledButton(
          onPressed: canSubmit ? onSubmit : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.lightblue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primaryDisabledFill,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 25),
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                ),
          ),
          child: isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Log In'),
        ),
        SizedBox(height: layoutMobile ? 18 : 14),
        const _OrDivider(),
        SizedBox(height: layoutMobile ? 18 : 14),
        _GoogleButton(
          onPressed: () => _showInfoSnackbar(
            context,
            title: 'Google sign-in',
            message: 'Google sign-in is not configured yet. Use email and password for now.',
          ),
        ),
      ],
    );
  }
}

class _SignupTab extends StatelessWidget {
  const _SignupTab({
    required this.layoutMobile,
    required this.username,
    required this.email,
    required this.password,
    required this.touched,
    required this.onSubmit,
    required this.canSubmit,
    required this.isSubmitting,
  });

  final bool layoutMobile;
  final TextEditingController username;
  final TextEditingController email;
  final TextEditingController password;
  final bool touched;
  final Future<void> Function() onSubmit;
  final bool canSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final usernameText = username.text.trim();
    final emailText = email.text.trim();
    final passwordText = password.text.trim();
    final usernameValid = usernameText.isNotEmpty;
    final emailValid = _AuthDialogState._emailRegex.hasMatch(emailText);
    final passwordValid = _AuthDialogState._passwordLongEnough(passwordText);

    final gap = layoutMobile ? 14.0 : 12.0;
    final labelStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.black,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Username', style: labelStyle),
        const SizedBox(height: 8),
        _AuthTextField(
          controller: username,
          hintText: 'Choose a username...',
          keyboardType: TextInputType.name,
          errorText: touched && !usernameValid ? 'Username is required' : null,
        ),
        SizedBox(height: gap),
        Text('Email Address', style: labelStyle),
        const SizedBox(height: 8),
        _AuthTextField(
          controller: email,
          hintText: 'Enter your email address...',
          keyboardType: TextInputType.emailAddress,
          errorText: touched && !emailValid ? 'Enter a valid email address' : null,
        ),
        SizedBox(height: gap),
        Text('Password', style: labelStyle),
        const SizedBox(height: 8),
        _AuthTextField(
          controller: password,
          hintText: 'Create a password...',
          obscureText: true,
          errorText: touched && !passwordValid
              ? 'Password must be more than 6 characters'
              : null,
        ),
        SizedBox(height: layoutMobile ? 22 : 18),
        FilledButton(
          onPressed: canSubmit ? onSubmit : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.lightblue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primaryDisabledFill,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 25),
            minimumSize: const Size.fromHeight(52),
            elevation: 0,
            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                ),
          ),
          child: isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Sign Up'),
        ),
        SizedBox(height: layoutMobile ? 18 : 14),
        const _OrDivider(),
        SizedBox(height: layoutMobile ? 18 : 14),
        _GoogleButton(
          onPressed: () => _showInfoSnackbar(
            context,
            title: 'Google sign-in',
            message: 'Google sign-in is not configured yet. Use email and password for now.',
          ),
        ),
      ],
    );
  }
}

class _AuthTextField extends StatefulWidget {
  const _AuthTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      cursorColor: AppColors.lightblue,
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscure,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.darkblue,
            fontWeight: FontWeight.w600,
          ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: widget.hintText,
        errorText: widget.errorText,
        hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.grey.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
        contentPadding: const EdgeInsets.symmetric(horizontal:25, vertical:25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.95)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.95)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightblue, width: 1.4),
        ),
        suffixIcon: widget.obscureText
            ? IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                color: AppColors.grey,
              )
            : null,
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final lineColor = AppColors.border.withValues(alpha: 0.85);
    return Row(
      children: [
        Expanded(
          child: Divider(height: 1, thickness: 1, color: lineColor),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppColors.grey,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Divider(height: 1, thickness: 1, color: lineColor),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _OutlineSocialButton(
      label: 'Continue with Google',
      leading: const _GoogleGlyph(),
      onPressed: onPressed,
    );
  }
}

class _OutlineSocialButton extends StatelessWidget {
  const _OutlineSocialButton({
    required this.label,
    required this.leading,
    required this.onPressed,
  });

  final String label;
  final Widget leading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkblue,
        backgroundColor: Colors.white,
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.95)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 30),
        minimumSize: const Size.fromHeight(52),
        textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Column(
          children: [
            Expanded(
              child:FaIcon(
  FontAwesomeIcons.google,
  color: Colors.red,
)
            ),
          ],
        ),
      ),
    );
  }
}

