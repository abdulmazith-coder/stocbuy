import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:translator/translator.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

enum GptToolAction { stockAnalysis, bestStocks, sebiAdvisor }

/// Voice recording state machine.
enum _VoiceState {
  idle, // default — mic or send button shown
  listening, // actively recording
  processing, // stopped recording; translating speech → English
}

/// Pill input with tools (+) on the left, mic + send/stop on the right.
class GptInputBar extends StatefulWidget {
  const GptInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onToolSelected,
    required this.enabled,
    required this.selectedLanguage,
    required this.translator,
    this.onVoiceSend,
    this.onStop,
    this.focusNode,
    this.autofocus = false,
    this.hintText = 'Ask anything',
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final Future<void> Function(GptToolAction) onToolSelected;
  final bool enabled;

  /// Language for voice input and translation
  final IndianLanguage selectedLanguage;

  /// Translator instance for converting voice to English
  final GoogleTranslator translator;

  /// Called with English text captured via voice.
  final ValueChanged<String>? onVoiceSend;

  /// Called when the user taps the stop button while the AI is generating.
  /// When null the stop button is not shown.
  final VoidCallback? onStop;

  final bool autofocus;
  final String hintText;

  @override
  State<GptInputBar> createState() => _GptInputBarState();
}

class _GptInputBarState extends State<GptInputBar>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  _VoiceState _voiceState = _VoiceState.idle;

  /// The latest partial/final transcript received from speech_to_text.
  String _liveTranscript = '';

  /// Set to true once we get a isFinal=true result so we know we have
  /// a complete sentence even before doneStatus fires.
  bool _gotFinalResult = false;

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  /// Guards against double-calling _finishVoice.
  bool _isFinishing = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.22,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('STT error: ${error.errorMsg}');
          if (!mounted) return;

          // Timeout / no-match = user paused long enough → treat as done.
          if (error.errorMsg == 'error_speech_timeout' ||
              error.errorMsg == 'error_no_match') {
            if (_voiceState == _VoiceState.listening) {
              if (_liveTranscript.trim().isNotEmpty) {
                _finishVoice();
              } else {
                _resetVoice();
              }
            }
          } else {
            _cancelVoice();
          }
        },
        onStatus: (status) {
          debugPrint('STT status: $status');
          if (!mounted) return;

          if (status == SpeechToText.doneStatus &&
              _voiceState == _VoiceState.listening) {
            _finishVoice();
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      _speechAvailable = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _pulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _toggleVoice() {
    if (_voiceState == _VoiceState.listening) {
      _finishVoice();
    } else if (_voiceState == _VoiceState.idle) {
      _startVoice();
    }
  }

  Future<void> _startVoice() async {
    if (!_speechAvailable || !widget.enabled) return;
    if (_voiceState != _VoiceState.idle) return;

    final locale = widget.selectedLanguage.speechLocale ?? 'en-US';

    setState(() {
      _voiceState = _VoiceState.listening;
      _liveTranscript = '';
      _gotFinalResult = false;
    });

    _isFinishing = false;

    debugPrint('STT start — locale: $locale');

    // ignore: deprecated_member_use
    await _speech.listen(
      localeId: locale,
      listenMode: ListenMode.confirmation,
      partialResults: true,
      cancelOnError: false,
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        if (!mounted) return;

        final text = result.recognizedWords.trim().toLowerCase();
        debugPrint(
          'STT result — text: "$text"  isFinal: ${result.finalResult}  confidence: ${result.confidence}',
        );

        if (text.isNotEmpty) {
  setState(() {
    _liveTranscript = text;
  });
}

        if (result.finalResult) {
          _gotFinalResult = true;
          if (_voiceState == _VoiceState.listening) _finishVoice();
        }
      },
    );
  }

  Future<void> _finishVoice() async {
    if (_isFinishing) return;
    if (_voiceState != _VoiceState.listening) return;

    _isFinishing = true;

    setState(() => _voiceState = _VoiceState.processing);

    await _speech.stop();

    if (!_gotFinalResult) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    final rawText = _liveTranscript.trim();
    debugPrint('STT finish — rawText: "$rawText"');

    if (rawText.isEmpty) {
      _resetVoice();
      _isFinishing = false;
      return;
    }

    String englishText = rawText;

    if (widget.selectedLanguage.code != 'en') {
      try {
        debugPrint(
          'Translating from ${widget.selectedLanguage.code} to en: "$rawText"',
        );
        final result = await widget.translator.translate(rawText, to: 'en');
        final translated = result.text.trim();
        if (translated.isNotEmpty) {
          englishText = translated;
        }
        debugPrint('Translated: "$englishText"');
      } catch (e) {
        debugPrint('Translation error (using raw text): $e');
        englishText = rawText;
      }
    }

    widget.controller.text = englishText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );

    _resetVoice();
    _isFinishing = false;

    if (englishText.isNotEmpty && widget.onVoiceSend != null) {
      widget.onVoiceSend!(englishText);
    }
  }

  void _cancelVoice() {
    _speech.stop();
    _resetVoice();
    _isFinishing = false;
  }

  void _resetVoice() {
    if (!mounted) return;
    setState(() {
      _voiceState = _VoiceState.idle;
      _liveTranscript = '';
      _gotFinalResult = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGenerating = !widget.enabled && widget.onStop != null;
    final canSend = widget.enabled && _hasText;
    final mobile = Responsive.isMobile(context);
    final fieldH = mobile ? 52.0 : 56.0;

    final effectiveBorder = _voiceState == _VoiceState.listening
        ? Colors.red.withValues(alpha: 0.55)
        : AppColors.border;

    return Container(
      height: fieldH,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: effectiveBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(mobile ? 6 : 8, 0, mobile ? 8 : 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PopupMenuButton<GptToolAction>(
            enabled: widget.enabled,
            tooltip: 'Tools',
            offset: const Offset(0, -200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (action) {
              unawaited(widget.onToolSelected(action));
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: GptToolAction.stockAnalysis,
                child: _ToolMenuRow(
                  icon: Icons.analytics_outlined,
                  label: 'Stock analysis',
                ),
              ),
              PopupMenuItem(
                value: GptToolAction.bestStocks,
                child: _ToolMenuRow(
                  icon: Icons.trending_up_rounded,
                  label: 'Get best stocks',
                ),
              ),
              PopupMenuItem(
                value: GptToolAction.sebiAdvisor,
                child: _ToolMenuRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Get registered SEBI advisor',
                ),
              ),
            ],
            child: SizedBox(
              width: mobile ? 40 : 42,
              height: mobile ? 40 : 42,
              child: Icon(
                Icons.add_rounded,
                size: mobile ? 24 : 26,
                color: widget.enabled
                    ? const Color(0xFF111827)
                    : AppColors.grey.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _voiceState == _VoiceState.listening
    ? TextEditingController(
        text: _liveTranscript,
      )
    : widget.controller,
              focusNode: widget.focusNode,
              enabled: widget.enabled && _voiceState == _VoiceState.idle,
              autofocus: widget.autofocus,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (canSend) widget.onSend();
              },
              style: TextStyle(
                fontSize: mobile ? 14.5 : 15,
                fontWeight: FontWeight.w500,
                color: AppColors.darkblue,
              ),
              decoration: InputDecoration(
  border: InputBorder.none,

  hintText: _voiceState == _VoiceState.processing
      ? 'Translating to English...'
      : widget.hintText,

  hintStyle: TextStyle(
    fontSize: mobile ? 14.5 : 15,
    fontWeight: FontWeight.w500,
    color: AppColors.grey.withValues(alpha: 0.75),
  ),

  isCollapsed: true,
  contentPadding: const EdgeInsets.symmetric(vertical: 14),
),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: isGenerating
                ? _StopButton(
                    key: const ValueKey('stop'),
                    size: mobile ? 36.0 : 40.0,
                    onTap: widget.onStop!,
                  )
                : _VoiceSendButton(
                    key: const ValueKey('send_voice'),
                    size: mobile ? 36.0 : 40.0,
                    canSend: canSend,
                    voiceState: _voiceState,
                    speechAvailable: _speechAvailable,
                    pulseAnim: _pulseAnim,
                    onSendTap: canSend ? widget.onSend : null,
                    onVoiceTap: _toggleVoice,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Send + Voice button ──────────────────────────────────────────────────────

class _VoiceSendButton extends StatelessWidget {
  const _VoiceSendButton({
    super.key,
    required this.canSend,
    required this.voiceState,
    required this.speechAvailable,
    required this.pulseAnim,
    required this.onSendTap,
    required this.onVoiceTap,
    required this.size,
  });

  final bool canSend;
  final _VoiceState voiceState;
  final bool speechAvailable;
  final Animation<double> pulseAnim;
  final VoidCallback? onSendTap;
  final VoidCallback onVoiceTap;
  final double size;

  Color get _btnColor {
    if (voiceState == _VoiceState.listening) return Colors.red;
    if (voiceState == _VoiceState.processing) return Colors.orange;
    return canSend ? const Color(0xFF1A1F36) : const Color(0xFF9CA3AF);
  }

  IconData get _icon {
    switch (voiceState) {
      case _VoiceState.listening:
        return Icons.mic_rounded;
      case _VoiceState.processing:
        return Icons.translate_rounded;
      case _VoiceState.idle:
        return canSend ? Icons.send_rounded : Icons.mic_none_rounded;
    }
  }

  VoidCallback? get _onTap {
    if (voiceState == _VoiceState.processing) return null;
    if (voiceState == _VoiceState.listening) return onVoiceTap;
    if (canSend) return onSendTap;
    if (speechAvailable) return onVoiceTap;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isVoiceActive = voiceState != _VoiceState.idle;

    Widget circle = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _btnColor,
        shape: BoxShape.circle,
        boxShadow: (canSend || isVoiceActive)
            ? [
                BoxShadow(
                  color: _btnColor.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: voiceState == _VoiceState.processing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_icon, color: Colors.white, size: 17),
          ),
        ),
      ),
    );

    if (voiceState == _VoiceState.listening) {
      circle = ScaleTransition(scale: pulseAnim, child: circle);
    }

    return SizedBox(width: size, height: size, child: circle);
  }
}

// ── Send button ──────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  const _SendButton({
    super.key,
    required this.size,
    required this.active,
    required this.onTap,
  });

  final double size;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF1A1F36) : const Color(0xFF9CA3AF),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.arrow_upward_rounded,
            color: Colors.white,
            size: size * 0.52,
          ),
        ),
      ),
    );
  }
}

// ── Stop button ──────────────────────────────────────────────────────────────

class _StopButton extends StatelessWidget {
  const _StopButton({super.key, required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1F36),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Container(
              width: size * 0.38,
              height: size * 0.38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.07),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tool menu row ─────────────────────────────────────────────────────────────

class _ToolMenuRow extends StatelessWidget {
  const _ToolMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.lightblue),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: AppColors.darkblue,
            ),
          ),
        ),
      ],
    );
  }
}
