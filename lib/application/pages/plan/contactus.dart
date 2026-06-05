import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/navigation/app_routes.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/contact_dio.dart';
import 'package:stocbuy_application/application/pages/auth/auth_page.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Public helper — call this from PlanPage._openContact()
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showContactUsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ContactUsSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Preset limit options shown as quick-pick chips
// ─────────────────────────────────────────────────────────────────────────────

const _kLimitPresets = [10, 25, 50, 100];

// ─────────────────────────────────────────────────────────────────────────────
//  Sheet root
// ─────────────────────────────────────────────────────────────────────────────

class _ContactUsSheet extends StatefulWidget {
  const _ContactUsSheet();

  @override
  State<_ContactUsSheet> createState() => _ContactUsSheetState();
}

class _ContactUsSheetState extends State<_ContactUsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _customLimitCtrl = TextEditingController();

  // Feature toggles
  bool _penny = false;
  bool _mid = false;
  bool _large = false;
  bool _growth = false;
  bool _unlimited = false;

  // AI limit — null means "custom" text field is active
  int? _selectedPreset = 10;
  bool _isCustomLimit = false;

  bool _loading = false;
  ContactRequestException? _serverError;
  bool _submitted = false;

  /// Returns null when unlimited is requested — backend omits the key entirely.
  int? get _resolvedLimit {
    if (_unlimited) return null;
    if (_isCustomLimit) {
      return int.tryParse(_customLimitCtrl.text.trim());
    }
    return _selectedPreset;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _customLimitCtrl.dispose();
    super.dispose();
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _serverError = null;
    });

    try {
      await ContactRequestDio().submitRequest(
        ContactRequestPayload(
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          requestedAnalysisLimit: _resolvedLimit,
          requestFilterPenny: _penny,
          requestFilterMid: _mid,
          requestFilterLarge: _large,
          requestFilterGrowth: _growth,
          requestAnalysisUnlimited: _unlimited,
        ),
      );
      if (!mounted) return;
      setState(() => _submitted = true);
    } on ContactRequestException catch (e) {
      setState(() => _serverError = e);
    } catch (e) {
      setState(() => _serverError = ContactRequestException(
            kind: ContactErrorKind.unknown,
            message: e.toString(),
          ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(bottom: bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: _submitted
                ? _SuccessBody(onDone: () => Navigator.pop(context))
                : _FormBody(
                    formKey: _formKey,
                    emailCtrl: _emailCtrl,
                    phoneCtrl: _phoneCtrl,
                    customLimitCtrl: _customLimitCtrl,
                    penny: _penny,
                    mid: _mid,
                    large: _large,
                    growth: _growth,
                    unlimited: _unlimited,
                    selectedPreset: _selectedPreset,
                    isCustomLimit: _isCustomLimit,
                    loading: _loading,
                    serverError: _serverError,
                    onPennyChanged: (v) => setState(() => _penny = v),
                    onMidChanged: (v) => setState(() => _mid = v),
                    onLargeChanged: (v) => setState(() => _large = v),
                    onGrowthChanged: (v) => setState(() => _growth = v),
                    onUnlimitedChanged: (v) => setState(() => _unlimited = v),
                    onPresetSelected: (preset) => setState(() {
                      _selectedPreset = preset;
                      _isCustomLimit = false;
                      _customLimitCtrl.clear();
                    }),
                    onCustomLimitTap: () => setState(() {
                      _isCustomLimit = true;
                      _selectedPreset = null;
                    }),
                    onSubmit: _submit,
                    onClose: () => Navigator.pop(context),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Form body
// ─────────────────────────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.formKey,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.customLimitCtrl,
    required this.penny,
    required this.mid,
    required this.large,
    required this.growth,
    required this.unlimited,
    required this.selectedPreset,
    required this.isCustomLimit,
    required this.loading,
    required this.serverError,
    required this.onPennyChanged,
    required this.onMidChanged,
    required this.onLargeChanged,
    required this.onGrowthChanged,
    required this.onUnlimitedChanged,
    required this.onPresetSelected,
    required this.onCustomLimitTap,
    required this.onSubmit,
    required this.onClose,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController customLimitCtrl;
  final bool penny, mid, large, growth, unlimited, isCustomLimit, loading;
  final int? selectedPreset;
  final ContactRequestException? serverError;
  final ValueChanged<bool> onPennyChanged;
  final ValueChanged<bool> onMidChanged;
  final ValueChanged<bool> onLargeChanged;
  final ValueChanged<bool> onGrowthChanged;
  final ValueChanged<bool> onUnlimitedChanged;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onCustomLimitTap;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ──────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Get in touch',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Tell us what you need',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              _SheetIconButton(icon: Icons.close_rounded, onTap: onClose),
            ],
          ),

          const SizedBox(height: 28),

          // ── Email ────────────────────────────────────────────────────
          _SheetLabel('Email address'),
          const SizedBox(height: 8),
          _SheetTextField(
            controller: emailCtrl,
            hint: 'you@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              final valid = RegExp(
                r'^[\w.+\-]+@[a-zA-Z\d\-]+\.[a-zA-Z]{2,}$',
              ).hasMatch(v.trim());
              return valid ? null : 'Enter a valid email address';
            },
          ),

          const SizedBox(height: 16),

          // ── Phone ────────────────────────────────────────────────────
          _SheetLabel('Phone number'),
          const SizedBox(height: 8),
          _SheetTextField(
            controller: phoneCtrl,
            hint: '+91 98765 43210',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 24),

          // ── Market filters ───────────────────────────────────────────
          _SectionDivider(label: 'Market filters you want'),
          const SizedBox(height: 14),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FilterChip(
                label: 'Penny stocks',
                selected: penny,
                icon: Icons.monetization_on_outlined,
                onChanged: onPennyChanged,
              ),
              _FilterChip(
                label: 'Mid cap',
                selected: mid,
                icon: Icons.trending_up_rounded,
                onChanged: onMidChanged,
              ),
              _FilterChip(
                label: 'Large cap',
                selected: large,
                icon: Icons.account_balance_outlined,
                onChanged: onLargeChanged,
              ),
              _FilterChip(
                label: 'Growth stocks',
                selected: growth,
                icon: Icons.rocket_launch_rounded,
                onChanged: onGrowthChanged,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Add-ons ──────────────────────────────────────────────────
          _SectionDivider(label: 'Add-ons'),
          const SizedBox(height: 14),

          // Unlimited AI toggle
          _BigToggleTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Unlimited AI analysis',
            subtitle: 'Remove daily limits on stock analysis',
            value: unlimited,
            onChanged: onUnlimitedChanged,
          ),

          // AI limit picker — only shown when unlimited is OFF
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: unlimited
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                _AiLimitPicker(
                  selectedPreset: selectedPreset,
                  isCustom: isCustomLimit,
                  customCtrl: customLimitCtrl,
                  onPresetSelected: onPresetSelected,
                  onCustomTap: onCustomLimitTap,
                  formKey: formKey,
                ),
              ],
            ),
            // empty placeholder so CrossFade has a second child
            secondChild: const SizedBox.shrink(),
          ),

          // ── Error ────────────────────────────────────────────────────
          if (serverError != null) ...[
            const SizedBox(height: 16),
            _ServerErrorBanner(error: serverError!),
          ],

          const SizedBox(height: 28),

          // ── CTA ──────────────────────────────────────────────────────
          _SubmitButton(loading: loading, onPressed: onSubmit),

          const SizedBox(height: 12),
          Center(
            child: Text(
              'We\'ll get back to you within 24 hours',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AI Limit Picker
// ─────────────────────────────────────────────────────────────────────────────

class _AiLimitPicker extends StatelessWidget {
  const _AiLimitPicker({
    required this.selectedPreset,
    required this.isCustom,
    required this.customCtrl,
    required this.onPresetSelected,
    required this.onCustomTap,
    required this.formKey,
  });

  final int? selectedPreset;
  final bool isCustom;
  final TextEditingController customCtrl;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onCustomTap;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 16,
                  color: Color(0xFF818CF8),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI analysis limit per day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              // Show selected value badge
              if (!isCustom && selectedPreset != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '$selectedPreset / day',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                ),
              if (isCustom && customCtrl.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '${customCtrl.text} / day',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 33),
            child: Text(
              'Must be greater than your current daily limit.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Preset chips row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _kLimitPresets)
                _LimitChip(
                  label: '$preset',
                  selected: !isCustom && selectedPreset == preset,
                  onTap: () => onPresetSelected(preset),
                ),
              // Custom chip
              _LimitChip(
                label: 'Custom',
                selected: isCustom,
                icon: Icons.edit_rounded,
                onTap: onCustomTap,
              ),
            ],
          ),

          // Custom input — slides in when "Custom" chip is selected
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isCustom
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextFormField(
                controller: customCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 200',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.numbers_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  suffixText: '/ day',
                  suffixStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF6366F1),
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFEF4444),
                      width: 1.5,
                    ),
                  ),
                  errorStyle: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                validator: (v) {
                  if (!isCustom) return null;
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter your desired daily limit';
                  }
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1) return 'Enter a number ≥ 1';
                  if (n > 9999) return 'Max value is 9999';
                  return null;
                },
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6366F1).withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF6366F1).withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected
                    ? const Color(0xFF818CF8)
                    : Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF818CF8)
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Success body
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34D399).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Request sent!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We\'ll review your request and get back\nto you within 24 hours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onDone,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.65),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(
          color: Color(0xFFEF4444),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.12),
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.12),
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF6366F1).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? const Color(0xFF818CF8)
                  : Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF818CF8)
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: Color(0xFF818CF8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BigToggleTile extends StatelessWidget {
  const _BigToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value
                ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: value
                    ? const Color(0xFF818CF8)
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: value
                          ? const Color(0xFF818CF8)
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF818CF8),
              activeTrackColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
              inactiveThumbColor: Colors.white.withValues(alpha: 0.4),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Rich server-error banner — one for each ContactErrorKind
// ─────────────────────────────────────────────────────────────────────────────

class _ServerErrorBanner extends StatelessWidget {
  const _ServerErrorBanner({required this.error});
  final ContactRequestException error;

  @override
  Widget build(BuildContext context) {
    final cfg = _bannerConfig(error.kind);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cfg.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(cfg.icon, color: cfg.fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cfg.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: cfg.fg,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cfg.body,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: cfg.fg.withValues(alpha: 0.82),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Optional CTA button for actionable errors
          if (cfg.ctaLabel != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: cfg.ctaAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cfg.fg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: cfg.fg.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  cfg.ctaLabel!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: cfg.fg,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _BannerCfg _bannerConfig(ContactErrorKind kind) {
    switch (kind) {
      case ContactErrorKind.noAccount:
        return _BannerCfg(
          icon: Icons.person_off_outlined,
          title: 'No account found',
          body: 'This email isn\'t registered. Sign up first, then come back '
              'to contact us.',
          fg: const Color(0xFFFBBF24),
          bg: const Color(0xFFFBBF24).withValues(alpha: 0.1),
          border: const Color(0xFFFBBF24).withValues(alpha: 0.3),
          ctaLabel: 'Go to Sign Up →',
          ctaAction:()=>AuthTab.signup
        );

      case ContactErrorKind.alreadyPremium:
        return _BannerCfg(
          icon: Icons.workspace_premium_rounded,
          title: 'You\'re already on Premium',
          body: 'Your premium plan is still active. You can reach out again '
              'once your current plan expires.',
          fg: const Color(0xFF34D399),
          bg: const Color(0xFF34D399).withValues(alpha: 0.08),
          border: const Color(0xFF34D399).withValues(alpha: 0.25),
        );

      case ContactErrorKind.pending:
        return _BannerCfg(
          icon: Icons.hourglass_top_rounded,
          title: 'Request already pending',
          body: 'We\'ve received your request and our team is reviewing it. '
              'We\'ll email you at ${_extractEmail()} within 24 hours.',
          fg: const Color(0xFF818CF8),
          bg: const Color(0xFF6366F1).withValues(alpha: 0.1),
          border: const Color(0xFF6366F1).withValues(alpha: 0.3),
        );

      case ContactErrorKind.limitTooLow:
        final current = error.currentLimit;
        final currentStr = current != null ? '$current' : 'your current';
        return _BannerCfg(
          icon: Icons.bar_chart_rounded,
          title: 'Limit too low',
          body: 'Your requested limit must be greater than your current daily '
              'limit of $currentStr analyses. Please enter a higher number.',
          fg: const Color(0xFFFBBF24),
          bg: const Color(0xFFFBBF24).withValues(alpha: 0.1),
          border: const Color(0xFFFBBF24).withValues(alpha: 0.3),
        );

      case ContactErrorKind.phoneRequired:
        return _BannerCfg(
          icon: Icons.phone_missed_rounded,
          title: 'Phone number required',
          body: 'Please add your phone number so our team can reach you.',
          fg: const Color(0xFFEF4444),
          bg: const Color(0xFFEF4444).withValues(alpha: 0.1),
          border: const Color(0xFFEF4444).withValues(alpha: 0.28),
        );

      case ContactErrorKind.noInternet:
        return _BannerCfg(
          icon: Icons.wifi_off_rounded,
          title: 'No internet connection',
          body: 'Check your network and try again.',
          fg: const Color(0xFFEF4444),
          bg: const Color(0xFFEF4444).withValues(alpha: 0.1),
          border: const Color(0xFFEF4444).withValues(alpha: 0.28),
        );

      case ContactErrorKind.unknown:
        return _BannerCfg(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          body: 'Please try again or email us directly at support@stocbuy.com',
          fg: const Color(0xFFEF4444),
          bg: const Color(0xFFEF4444).withValues(alpha: 0.1),
          border: const Color(0xFFEF4444).withValues(alpha: 0.28),
        );
    }
  }

  /// Try to pull the email out of the error message for the pending banner.
  String _extractEmail() {
    final match = RegExp(
      r'[\w.+\-]+@[a-zA-Z\d\-]+\.[a-zA-Z]{2,}',
    ).firstMatch(error.message);
    return match?.group(0) ?? 'your email';
  }
}

class _BannerCfg {
  const _BannerCfg({
    required this.icon,
    required this.title,
    required this.body,
    required this.fg,
    required this.bg,
    required this.border,
    this.ctaLabel,
    this.ctaAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color fg;
  final Color bg;
  final Color border;
  final String? ctaLabel;
  final VoidCallback? ctaAction;
}


class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: loading ? Colors.white.withValues(alpha: 0.85) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF0F172A),
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Send request',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Color(0xFF0F172A),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  const _SheetIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}