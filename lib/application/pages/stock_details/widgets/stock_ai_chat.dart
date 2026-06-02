import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:translator/translator.dart';
import 'package:stocbuy_application/application/models/analysis_report_section.dart';
import 'package:stocbuy_application/application/models/stock_detail.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_dio.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/normal_chat_dio.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_error_message.dart';
import 'package:stocbuy_application/application/controllers/stock_details_controller.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_prompt.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_report_enrich.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_run.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_stream_apply.dart';
import 'package:stocbuy_application/application/utils/chat_auto_scroll.dart';
import 'package:stocbuy_application/application/widgets/ai_chat_bubbles.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';

// ── Indian Language definitions ───────────────────────────────────────────────

class IndianLanguage {
  const IndianLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    this.speechLocale,
  });
  final String code;
  final String name;
  final String nativeName;

  /// BCP-47 locale used by speech_to_text (e.g. 'ta-IN', 'hi-IN').
  /// null → falls back to device default.
  final String? speechLocale;
}

const List<IndianLanguage> kIndianLanguages = [
  IndianLanguage(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    speechLocale: 'en-US',
  ),
  IndianLanguage(
    code: 'hi',
    name: 'Hindi',
    nativeName: 'हिंदी',
    speechLocale: 'hi-IN',
  ),
  IndianLanguage(
    code: 'bn',
    name: 'Bengali',
    nativeName: 'বাংলা',
    speechLocale: 'bn-IN',
  ),
  IndianLanguage(
    code: 'te',
    name: 'Telugu',
    nativeName: 'తెలుగు',
    speechLocale: 'te-IN',
  ),
  IndianLanguage(
    code: 'mr',
    name: 'Marathi',
    nativeName: 'मराठी',
    speechLocale: 'mr-IN',
  ),
  IndianLanguage(
    code: 'ta',
    name: 'Tamil',
    nativeName: 'தமிழ்',
    speechLocale: 'ta-IN',
  ),
  IndianLanguage(
    code: 'gu',
    name: 'Gujarati',
    nativeName: 'ગુજરાતી',
    speechLocale: 'gu-IN',
  ),
  IndianLanguage(
    code: 'kn',
    name: 'Kannada',
    nativeName: 'ಕನ್ನಡ',
    speechLocale: 'kn-IN',
  ),
  IndianLanguage(
    code: 'ml',
    name: 'Malayalam',
    nativeName: 'മലയാളം',
    speechLocale: 'ml-IN',
  ),
  IndianLanguage(
    code: 'pa',
    name: 'Punjabi',
    nativeName: 'ਪੰਜਾਬੀ',
    speechLocale: 'pa-IN',
  ),
  IndianLanguage(
    code: 'or',
    name: 'Odia',
    nativeName: 'ଓଡ଼ିଆ',
    speechLocale: null,
  ),
  IndianLanguage(
    code: 'ur',
    name: 'Urdu',
    nativeName: 'اردو',
    speechLocale: 'ur-IN',
  ),
  IndianLanguage(
    code: 'as',
    name: 'Assamese',
    nativeName: 'অসমীয়া',
    speechLocale: null,
  ),
  IndianLanguage(
    code: 'ne',
    name: 'Nepali',
    nativeName: 'नेपाली',
    speechLocale: 'ne-NP',
  ),
  IndianLanguage(
    code: 'sd',
    name: 'Sindhi',
    nativeName: 'سنڌي',
    speechLocale: null,
  ),
  IndianLanguage(
    code: 'bho',
    name: 'Bhojpuri',
    nativeName: 'भोजपुरी',
    speechLocale: null,
  ),
  IndianLanguage(
    code: 'mai',
    name: 'Maithili',
    nativeName: 'मैथिली',
    speechLocale: null,
  ),
  IndianLanguage(
    code: 'kok',
    name: 'Konkani',
    nativeName: 'कोंकणी',
    speechLocale: null,
  ),
  IndianLanguage(
    code: 'ks',
    name: 'Kashmiri',
    nativeName: 'کٲشُر',
    speechLocale: null,
  ),
];

// ── Sender / message model ────────────────────────────────────────────────────

enum AiChatRole { user, assistant }

class AiChatMessage implements AnalysisStreamMessage {
  AiChatMessage({
    required this.role,
    this.text = '',
    this.pendingFinalReport,
    List<AnalysisReportSection>? analysisReports,
    List<String>? stepLog,
    this.isStreaming = false,
    DateTime? sentAt,
  }) : analysisReports = analysisReports ?? [],
       stepLog = stepLog ?? [],
       sentAt = sentAt ?? DateTime.now();

  final AiChatRole role;

  @override
  String text;

  String? translatedText;
  List<AnalysisReportSection>? translatedReports;
  String? translatedToCode;
  bool isTranslating = false;

  @override
  String? pendingFinalReport;

  @override
  final List<AnalysisReportSection> analysisReports;

  @override
  final List<String> stepLog;

  bool isStreaming;
  final DateTime sentAt;

  String get displayText => translatedText ?? text;
  List<AnalysisReportSection> get displayReports =>
      translatedReports ?? analysisReports;

  @override
  void appendStep(String step) {
    final label = step.trim();
    if (label.isEmpty) return;
    if (stepLog.isEmpty || stepLog.last != label) stepLog.add(label);
  }

  @override
  void appendAnalysisReport(
    String markdown, {
    String? fieldKey,
    String? title,
  }) {
    upsertAnalysisReport(
      analysisReports,
      markdown: markdown,
      fieldKey: fieldKey,
      title: title,
    );
  }
}

// ── Main chat body ────────────────────────────────────────────────────────────

class StockAiChatBody extends StatefulWidget {
  const StockAiChatBody({
    super.key,
    required this.symbol,
    required this.displayName,
    this.showHeader = true,
    this.maxHeight,
  });

  final String symbol;
  final String displayName;
  final bool showHeader;
  final double? maxHeight;

  @override
  State<StockAiChatBody> createState() => _StockAiChatBodyState();
}

class _StockAiChatBodyState extends State<StockAiChatBody> {
  late final List<AiChatMessage> _messages;
  late final TextEditingController _input;
  late final ScrollController _scroll;
  final AiAnalysisDio _analysisDio = AiAnalysisDio();
  final NormalChatDio _normalChatDio = NormalChatDio();
  final GoogleTranslator _translator = GoogleTranslator();
  CancelToken? _analysisCancel;
  bool _typing = false;

  IndianLanguage _selectedLanguage = kIndianLanguages.first;
  bool _isDeepAnalysis = false;

  bool get _showTypingDots {
    if (!_typing) return false;
    if (_messages.isEmpty) return true;
    return _messages.last.role == AiChatRole.user;
  }

  @override
  void initState() {
    super.initState();
    _input = TextEditingController();
    _scroll = ScrollController();
    _messages = _initialMessages();
  }

  List<AiChatMessage> _initialMessages() {
    return [
      AiChatMessage(
        role: AiChatRole.assistant,
        text:
            "Hi! I'm your AI analyst for ${widget.displayName} (${widget.symbol}). "
            "Ask me about price action, valuation, financials, news, or "
            "anything else — I'll keep it concise.",
      ),
    ];
  }

  // ── Language selection ────────────────────────────────────────────────────

  void _onLanguageChanged(IndianLanguage lang) {
    if (lang.code == _selectedLanguage.code) return;
    setState(() => _selectedLanguage = lang);
    for (final msg in _messages) {
      if (msg.role == AiChatRole.assistant && !msg.isStreaming) {
        _translateMessage(msg, lang);
      }
    }
  }

  Future<void> _translateMessage(AiChatMessage msg, IndianLanguage lang) async {
    if (lang.code == 'en') {
      setState(() {
        msg.translatedText = null;
        msg.translatedReports = null;
        msg.translatedToCode = null;
        msg.isTranslating = false;
      });
      return;
    }

    if (msg.translatedToCode == lang.code &&
        (msg.translatedText != null || msg.translatedReports != null)) {
      return;
    }

    setState(() => msg.isTranslating = true);

    try {
      String? newText;
      if (msg.text.trim().isNotEmpty) {
        final result = await _translator.translate(msg.text, to: lang.code);
        newText = result.text;
      }

      List<AnalysisReportSection>? newReports;
      if (msg.analysisReports.isNotEmpty) {
        newReports = [];
        for (final section in msg.analysisReports) {
          if (section.markdown.trim().isEmpty) {
            newReports.add(section);
            continue;
          }
          try {
            final result = await _translator.translate(
              section.markdown,
              to: lang.code,
            );
            newReports.add(
              AnalysisReportSection(
                fieldKey: section.fieldKey,
                title: section.title,
                markdown: result.text,
              ),
            );
          } catch (_) {
            newReports.add(section);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        msg.translatedText = newText;
        msg.translatedReports = newReports;
        msg.translatedToCode = lang.code;
        msg.isTranslating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => msg.isTranslating = false);
    }
  }

  // ── Sending helpers ───────────────────────────────────────────────────────

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty || _typing) return;
    if (_isDeepAnalysis) {
      await _runStockAnalysis(prompt: text);
    } else {
      await _runNormalChat(prompt: text);
    }
  }

  Future<void> _runNormalChat({required String prompt}) async {
    if (_typing) return;

    _analysisCancel?.cancel();
    _analysisCancel = CancelToken();

    setState(() {
      _typing = true;
      _messages.add(AiChatMessage(role: AiChatRole.user, text: prompt));
      _input.clear();
    });
    scrollChatToBottom(_scroll);

    try {
      final reply = await _normalChatDio.chat(
        stockSymbol: apiStockSymbol(widget.symbol),
        prompt: prompt,
        cancelToken: _analysisCancel,
      );
      if (!mounted) return;

      final msg = AiChatMessage(role: AiChatRole.assistant, text: reply);
      setState(() {
        _messages.add(msg);
        _typing = false;
      });

      if (_selectedLanguage.code != 'en') {
        _translateMessage(msg, _selectedLanguage);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.type == DioExceptionType.cancel) return;
      _addErrorMessage(
        formatAiAnalysisErrorMessage(e.message ?? 'Request failed.'),
      );
    } on NormalChatException catch (e) {
      if (!mounted) return;
      _addErrorMessage(formatAiAnalysisErrorMessage(e.message));
    } catch (e) {
      if (!mounted) return;
      _addErrorMessage(formatAiAnalysisErrorMessage('Unexpected error: $e'));
    }
    scrollChatToBottom(_scroll);
  }

  void _addErrorMessage(String text) {
    setState(() {
      _messages.add(AiChatMessage(role: AiChatRole.assistant, text: text));
      _typing = false;
    });
  }

  String _analysisPromptForUser(String userPrompt) {
    StockDetail? snapshot;
    final tag = widget.symbol.trim();
    if (tag.isNotEmpty && Get.isRegistered<StockDetailsController>(tag: tag)) {
      snapshot = Get.find<StockDetailsController>(tag: tag).detail.value;
    }
    return composeStockAnalysisRequest(
      symbol: widget.symbol,
      displayName: widget.displayName,
      userPrompt: userPrompt,
      detailSnapshot: snapshot,
    );
  }

  Future<void> _runStockAnalysis({required String prompt}) async {
    if (_typing) return;

    _analysisCancel?.cancel();
    _analysisCancel = CancelToken();

    final symbol = apiStockSymbol(widget.symbol);
    final apiPrompt = _analysisPromptForUser(prompt);

    setState(() {
      _typing = true;
      _messages.add(AiChatMessage(role: AiChatRole.user, text: prompt));
      _messages.add(
        AiChatMessage(role: AiChatRole.assistant, isStreaming: true),
      );
      _input.clear();
    });
    scrollChatToBottom(_scroll);

    final assistantIdx = _messages.length - 1;

    try {
      await for (final event in streamAnalysisWithRetry(
        _analysisDio,
        stockSymbol: symbol,
        prompt: apiPrompt,
        cancelToken: _analysisCancel,
      )) {
        if (!mounted) return;
        applyAnalysisStreamEvent(_messages[assistantIdx], event);
        if (event.isError) _messages[assistantIdx].isStreaming = false;
        setState(() {});
        SchedulerBinding.instance.scheduleFrame();
        scrollChatToBottom(_scroll);
        await Future<void>.delayed(Duration.zero);
      }

      if (!mounted) return;
      setState(() {
        final assistant = _messages[assistantIdx];
        finalizeAnalysisReport(assistant);
        assistant.isStreaming = false;
        if (!analysisHasVisibleReport(assistant)) {
          assistant.text = 'Analysis finished but no report text was returned.';
        }
        _typing = false;
      });

      if (_selectedLanguage.code != 'en') {
        _translateMessage(_messages[assistantIdx], _selectedLanguage);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.type == DioExceptionType.cancel) return;
      _failAnalysis(assistantIdx, e.message ?? 'Request failed.');
    } on AiAnalysisException catch (e) {
      if (!mounted) return;
      _failAnalysis(assistantIdx, e.message);
    } catch (e) {
      if (!mounted) return;
      _failAnalysis(assistantIdx, 'Unexpected error: $e');
    }
    scrollChatToBottom(_scroll);
  }

  void _failAnalysis(int assistantIdx, String error) {
    setState(() {
      final assistant = _messages[assistantIdx];
      assistant.isStreaming = false;
      assistant.text = formatAiAnalysisErrorMessage(error);
      _typing = false;
    });
  }

  @override
  void dispose() {
    _analysisCancel?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHeader)
          _Header(
            symbol: widget.symbol,
            selectedLanguage: _selectedLanguage,
            onLanguageChanged: _onLanguageChanged,
          ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
            itemCount: _messages.length + (_showTypingDots ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length && _showTypingDots) {
                return const StocbuyThinkingIndicator();
              }
              final msg = _messages[i];
              return _MessageBubble(
                message: msg,
                onRetranslate: msg.role == AiChatRole.assistant
                    ? () => _translateMessage(msg, _selectedLanguage)
                    : null,
              );
            },
          ),
        ),
        _InputBar(
          controller: _input,
          onSend: () => _send(),
          onVoiceSend: (englishText) => _send(englishText),
          enabled: !_typing,
          isDeepAnalysis: _isDeepAnalysis,
          onModeToggled: (v) => setState(() => _isDeepAnalysis = v),
          selectedLanguage: _selectedLanguage,
          translator: _translator,
        ),
        const AiChatDisclaimerFooter(),
      ],
    );

    if (widget.maxHeight != null) {
      return SizedBox(height: widget.maxHeight, child: body);
    }
    return body;
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.symbol,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  final String symbol;
  final IndianLanguage selectedLanguage;
  final ValueChanged<IndianLanguage> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const StocbuyLogoMark(size: 20),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Stock Analysis',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.darkblue,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _LanguageDropdown(
            selected: selectedLanguage,
            onChanged: onLanguageChanged,
          ),
        ],
      ),
    );
  }
}

// ── Language dropdown ─────────────────────────────────────────────────────────

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.selected, required this.onChanged});

  final IndianLanguage selected;
  final ValueChanged<IndianLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<IndianLanguage>(
          value: selected,
          isDense: true,
          menuMaxHeight: 320,
          icon: const Icon(
            Icons.language_rounded,
            size: 14,
            color: AppColors.grey,
          ),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.darkblue,
          ),
          borderRadius: BorderRadius.circular(12),
          items: kIndianLanguages.map((lang) {
            return DropdownMenuItem<IndianLanguage>(
              value: lang,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        lang.nativeName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkblue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${lang.name})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (lang) {
            if (lang != null) onChanged(lang);
          },
          selectedItemBuilder: (_) => kIndianLanguages.map((lang) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lang.nativeName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkblue,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Message bubble wrapper ────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onRetranslate});

  final AiChatMessage message;
  final VoidCallback? onRetranslate;

  @override
  Widget build(BuildContext context) {
    final m = message;

    if (m.role == AiChatRole.user) {
      return AiChatUserBubble(text: m.text, sentAt: m.sentAt);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiChatAssistantBubble(
          text: m.isTranslating ? m.text : m.displayText,
          analysisReports: m.isTranslating
              ? m.analysisReports
              : m.displayReports,
          isStreaming: m.isStreaming,
          stepLog: m.stepLog,
          sentAt: m.sentAt,
        ),

        if (m.isTranslating)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.grey,
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  'Translating…',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        if (!m.isTranslating &&
            (m.translatedText != null || m.translatedReports != null))
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.translate_rounded,
                  size: 10,
                  color: AppColors.grey,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Translated',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onRetranslate != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRetranslate,
                    child: const Text(
                      '· Retry',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.lightblue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

/// Voice recording state machine.
enum _VoiceState {
  idle, // default — mic or send button shown
  listening, // actively recording
  processing, // stopped recording; translating speech → English
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onVoiceSend,
    required this.enabled,
    required this.isDeepAnalysis,
    required this.onModeToggled,
    required this.selectedLanguage,
    required this.translator,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  /// Fired with the English text captured via voice.
  final ValueChanged<String> onVoiceSend;
  final bool enabled;
  final bool isDeepAnalysis;
  final ValueChanged<bool> onModeToggled;
  final IndianLanguage selectedLanguage;
  final GoogleTranslator translator;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar>
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
  bool _speechInitialized = false;

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
  }

  Future<bool> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('STT error: ${error.errorMsg}');
          if (!mounted) return;

          // Timeout / no-match = user paused long enough → treat as done.
          if (error.errorMsg == 'error_speech_timeout' ||
              error.errorMsg == 'error_no_match') {
            // Only finish if we actually have something to work with.
            if (_voiceState == _VoiceState.listening) {
              if (_liveTranscript.trim().isNotEmpty) {
                _finishVoice();
              } else {
                _resetVoice();
              }
            }
          } else {
            // Hard error → cancel cleanly.
            _cancelVoice();
          }
        },
        onStatus: (status) {
          debugPrint('STT status: $status');
          if (!mounted) return;

          // 'done' fires after the engine has fully stopped and delivered its
          // last result. It is safe to call _finishVoice here.
          if (status == SpeechToText.doneStatus &&
              _voiceState == _VoiceState.listening) {
            _finishVoice();
          }

          // 'notListening' fires on every short inter-word pause. Ignore it.
        },
      );
      if (mounted) setState(() {});
      return _speechAvailable;
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      _speechAvailable = false;
      if (mounted) setState(() {});
      return false;
    }
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  // ── Voice helpers ───────────────────────────────────────────────────────

  void _toggleVoice() {
    if (_voiceState == _VoiceState.listening) {
      _finishVoice();
    } else if (_voiceState == _VoiceState.idle) {
      _startVoice();
    }
    // While processing, ignore taps.
  }

  // ─────────────────────────────────────────────
  // START VOICE
  // ─────────────────────────────────────────────

  Future<void> _startVoice() async {
    if (!widget.enabled) return;
    if (_voiceState != _VoiceState.idle) return;

    if (!_speechInitialized) {
      _speechInitialized = await _initSpeech();
    }
    if (!_speechAvailable) return;

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
      // Give up to 2 minutes of total recording time.
      listenFor: const Duration(minutes: 2),
      // Stop automatically after 4 s of silence (longer = fewer cut-offs).
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        if (!mounted) return;

        final text = result.recognizedWords.trim().toLowerCase();
        debugPrint(
          'STT result — text: "$text"  isFinal: ${result.finalResult}  confidence: ${result.confidence}',
        );

        setState(() {
          // Always update with the latest recognised text — even partial
          // results are usually pretty good on modern devices.
          if (text.isNotEmpty) _liveTranscript = text;
        });

        // Mark when we receive a final result so _finishVoice knows the
        // engine has committed to this text.
        if (result.finalResult) {
          _gotFinalResult = true;
          // Auto-finish now that the engine itself says it's done.
          if (_voiceState == _VoiceState.listening) _finishVoice();
        }
      },
    );
  }

  // ─────────────────────────────────────────────
  // STOP + TRANSLATE + SEND
  // ─────────────────────────────────────────────

  Future<void> _finishVoice() async {
    // Guard: only one call goes through at a time.
    if (_isFinishing) return;
    if (_voiceState != _VoiceState.listening) return;

    _isFinishing = true;

    setState(() => _voiceState = _VoiceState.processing);

    // Stop the engine (safe to call even if already stopped).
    await _speech.stop();

    // If we haven't received a final result yet, wait a short moment for
    // the engine to deliver the last partial as a final result.
    if (!_gotFinalResult) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    final rawText = _liveTranscript.trim();
    debugPrint('STT finish — rawText: "$rawText"');

    if (rawText.isEmpty) {
      _resetVoice();
      _isFinishing = false;
      return;
    }

    // ── Translate to English if the selected language is not English ──────
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
        // Fall back to raw text if translation fails.
        englishText = rawText;
      }
    }

    // Put the English text into the text field so the user can see / edit it.
    widget.controller.text = englishText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );

    _resetVoice();
    _isFinishing = false;

    // Fire the callback — parent will call _send(englishText).
    if (englishText.isNotEmpty) {
      widget.onVoiceSend(englishText);
    }
  }

  // ─────────────────────────────────────────────
  // CANCEL
  // ─────────────────────────────────────────────

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
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _pulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled && _hasText;
    final deep = widget.isDeepAnalysis;

    final activeBorder = deep ? AppColors.green : AppColors.lightblue;
    final fieldBorderColor = deep
        ? AppColors.green.withValues(alpha: 0.5)
        : AppColors.border;

    final effectiveBorder = _voiceState == _VoiceState.listening
        ? Colors.red.withValues(alpha: 0.55)
        : fieldBorderColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Mode toggle ──────────────────────────────────────────
          Row(
            children: [
              _ModeChip(
                label: 'Chat',
                icon: Icons.chat_bubble_outline_rounded,
                active: !deep,
                activeColor: AppColors.lightblue,
                onTap: () => widget.onModeToggled(false),
              ),
              const SizedBox(width: 6),
              _ModeChip(
                label: 'AI Analysis',
                icon: Icons.auto_awesome_rounded,
                active: deep,
                activeColor: AppColors.green,
                onTap: () => widget.onModeToggled(true),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Live transcript hint ─────────────────────────────────
          if (_voiceState != _VoiceState.idle)
            _VoiceHintBar(
              voiceState: _voiceState,
              transcript: _liveTranscript,
              langName: widget.selectedLanguage.nativeName,
              onCancel: _cancelVoice,
            ),

          if (_voiceState != _VoiceState.idle) const SizedBox(height: 4),

          // ── Text field + send/voice button ───────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: effectiveBorder,
                      width: deep || _voiceState != _VoiceState.idle
                          ? 1.4
                          : 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    enabled: widget.enabled && _voiceState == _VoiceState.idle,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => widget.onSend(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: _voiceState == _VoiceState.listening
                          ? 'Listening in ${widget.selectedLanguage.nativeName}…'
                          : _voiceState == _VoiceState.processing
                          ? 'Translating to English…'
                          : deep
                          ? 'Ask for deep analysis…'
                          : 'Ask the AI…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: _voiceState == _VoiceState.listening
                            ? Colors.red
                            : AppColors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.darkblue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // ── Send / Voice button ──────────────────────────────
              _SendVoiceButton(
                canSend: canSend,
                voiceState: _voiceState,
                deep: deep,
                activeBorder: activeBorder,
                speechAvailable: _speechAvailable,
                pulseAnim: _pulseAnim,
                onSendTap: canSend ? widget.onSend : null,
                onVoiceTap: _toggleVoice,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Send + Voice button ───────────────────────────────────────────────────────

class _SendVoiceButton extends StatelessWidget {
  const _SendVoiceButton({
    required this.canSend,
    required this.voiceState,
    required this.deep,
    required this.activeBorder,
    required this.speechAvailable,
    required this.pulseAnim,
    required this.onSendTap,
    required this.onVoiceTap,
  });

  final bool canSend;
  final _VoiceState voiceState;
  final bool deep;
  final Color activeBorder;
  final bool speechAvailable;
  final Animation<double> pulseAnim;
  final VoidCallback? onSendTap;
  final VoidCallback onVoiceTap;

  Color get _btnColor {
    if (voiceState == _VoiceState.listening) return Colors.red;
    if (voiceState == _VoiceState.processing) return Colors.orange;
    final base = deep ? AppColors.green : AppColors.lightblue;
    return canSend ? base : base.withValues(alpha: 0.45);
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
    return onVoiceTap;
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

    return circle;
  }
}

// ── Voice hint bar ────────────────────────────────────────────────────────────

class _VoiceHintBar extends StatelessWidget {
  const _VoiceHintBar({
    required this.voiceState,
    required this.transcript,
    required this.langName,
    required this.onCancel,
  });

  final _VoiceState voiceState;
  final String transcript;
  final String langName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isListening = voiceState == _VoiceState.listening;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isListening
            ? Colors.red.withValues(alpha: 0.07)
            : Colors.orange.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isListening
              ? Colors.red.withValues(alpha: 0.25)
              : Colors.orange.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isListening ? Icons.mic_rounded : Icons.translate_rounded,
            size: 12,
            color: isListening ? Colors.red : Colors.orange,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isListening
                  ? transcript.isEmpty
                        ? 'Listening in $langName… tap mic to stop'
                        : transcript
                  : 'Translating to English…',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isListening ? Colors.red[700] : Colors.orange[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (isListening)
            GestureDetector(
              onTap: onCancel,
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.grey,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Mode chip ─────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: active
            ? activeColor.withValues(alpha: 0.12)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? activeColor.withValues(alpha: 0.55)
              : AppColors.border,
          width: active ? 1.2 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          hoverColor: activeColor.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: active ? activeColor : AppColors.grey,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? activeColor : AppColors.grey,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Desktop right-rail panel ──────────────────────────────────────────────────

class StockAiChatPanel extends StatelessWidget {
  const StockAiChatPanel({
    super.key,
    required this.symbol,
    required this.displayName,
  });

  final String symbol;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: StockAiChatBody(symbol: symbol, displayName: displayName),
      ),
    );
  }
}
