import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

// ── Breakpoints ───────────────────────────────────────────────────────────────

const double _kMobileBreakpoint = 600.0;
const double _kTabletBreakpoint = 900.0;

// ── Markdown → clean speech text ─────────────────────────────────────────────

String _stripMarkdown(String md) {
  if (md.trim().isEmpty) return '';
  var text = md;
  text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
  text = text.replaceAll(RegExp(r'`[^`]*`'), '');
  text = text.replaceAllMapped(RegExp(r'^\s*\|(.+)\|\s*$', multiLine: true), (m) {
    final row = (m[1] ?? '');
    final cells = row
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty && !RegExp(r'^[-:]+$').hasMatch(c))
        .join(', ');
    return cells;
  });
  text = text.replaceAllMapped(
      RegExp(r'^#{1,6}\s*(.+)$', multiLine: true), (m) => '${m[1]}.');
  text = text.replaceAll(RegExp(r'^\s*>\s*', multiLine: true), '');
  text = text.replaceAllMapped(RegExp(r'\*{3}([^*\n]+?)\*{3}'), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'_{3}([^_\n]+?)_{3}'), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'\*{2}([^*\n]+?)\*{2}'), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'_{2}([^_\n]+?)_{2}'), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'\*([^*\n]+?)\*'), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'_([^_\n]+?)_'), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'~~([^~\n]+?)~~'), (m) => m[1] ?? '');
  text = text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1] ?? '');
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '');
  text = text.replaceAll(RegExp(r'^\s*[-*•+]\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '.');
  text = text.replaceAll(RegExp(r'[*_~\\#`]'), '');
  text = text.replaceAllMapped(
      RegExp(r'([A-Za-z/%₹\$€£])(\d)'), (m) => '${m[1]} ${m[2]}');
  text = text.replaceAll(RegExp(r'\n{2,}'), '\n');
  text = text.replaceAll('\n', ' ');
  text = text.replaceAll(RegExp(r' {2,}'), ' ');
  text = text.replaceAll(RegExp(r'\.{2,}'), '.');
  text = text.replaceAll(RegExp(r',{2,}'), ',');
  return text.trim();
}

String _readableText(AiChatMessage msg) {
  final buf = StringBuffer();
  final body = _stripMarkdown(msg.displayText.trim());
  if (body.isNotEmpty) {
    buf.write(body);
    if (!body.endsWith('.') && !body.endsWith('!') && !body.endsWith('?')) {
      buf.write('.');
    }
    buf.write(' ');
  }
  for (final s in msg.displayReports) {
    final t = s.markdown.trim();
    if (t.isEmpty) continue;
    if (s.title != null && s.title!.isNotEmpty) {
      buf.write('${_stripMarkdown(s.title!)}. ');
    }
    final c = _stripMarkdown(t);
    if (c.isNotEmpty) {
      buf.write(c);
      if (!c.endsWith('.') && !c.endsWith('!') && !c.endsWith('?')) {
        buf.write('.');
      }
      buf.write(' ');
    }
  }
  return buf.toString().trim();
}

// ── Indian languages ──────────────────────────────────────────────────────────

class IndianLanguage {
  const IndianLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    this.speechLocale,
    this.ttsLocale,
    this.fallbackTtsLocale,
    this.speechRate,
    this.pitch,
  });
  final String code;
  final String name;
  final String nativeName;
  final String? speechLocale;
  final String? ttsLocale;
  final String? fallbackTtsLocale;
  // Per-language TTS tuning for clear pronunciation
  final double? speechRate;
  final double? pitch;
}

const List<IndianLanguage> kIndianLanguages = [
  IndianLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      speechLocale: 'en-US',
      ttsLocale: 'en-US',
      speechRate: 0.50,
      pitch: 1.0),
  IndianLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिंदी',
      speechLocale: 'hi-IN',
      ttsLocale: 'hi-IN',
      fallbackTtsLocale: 'hi-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      speechLocale: 'bn-IN',
      ttsLocale: 'bn-IN',
      fallbackTtsLocale: 'bn-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'te',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      speechLocale: 'te-IN',
      ttsLocale: 'te-IN',
      fallbackTtsLocale: 'te-IN',
      speechRate: 0.38,
      pitch: 1.0),
  IndianLanguage(
      code: 'mr',
      name: 'Marathi',
      nativeName: 'मराठी',
      speechLocale: 'mr-IN',
      ttsLocale: 'mr-IN',
      fallbackTtsLocale: 'hi-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'ta',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      speechLocale: 'ta-IN',
      ttsLocale: 'ta-IN',
      fallbackTtsLocale: 'ta-IN',
      speechRate: 0.38,
      pitch: 1.0),
  IndianLanguage(
      code: 'gu',
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      speechLocale: 'gu-IN',
      ttsLocale: 'gu-IN',
      fallbackTtsLocale: 'hi-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'kn',
      name: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      speechLocale: 'kn-IN',
      ttsLocale: 'kn-IN',
      fallbackTtsLocale: 'kn-IN',
      speechRate: 0.38,
      pitch: 1.0),
  IndianLanguage(
      code: 'ml',
      name: 'Malayalam',
      nativeName: 'മലയാളം',
      speechLocale: 'ml-IN',
      ttsLocale: 'ml-IN',
      fallbackTtsLocale: 'ml-IN',
      speechRate: 0.38,
      pitch: 1.0),
  IndianLanguage(
      code: 'pa',
      name: 'Punjabi',
      nativeName: 'ਪੰਜਾਬੀ',
      speechLocale: 'pa-IN',
      ttsLocale: 'pa-IN',
      fallbackTtsLocale: 'hi-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'or',
      name: 'Odia',
      nativeName: 'ଓଡ଼ିଆ',
      ttsLocale: null,
      fallbackTtsLocale: 'en-US',
      speechRate: 0.42,
      pitch: 1.0),
  IndianLanguage(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      speechLocale: 'ur-IN',
      ttsLocale: 'ur-IN',
      fallbackTtsLocale: 'hi-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'as',
      name: 'Assamese',
      nativeName: 'অসমীয়া',
      ttsLocale: null,
      fallbackTtsLocale: 'bn-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'ne',
      name: 'Nepali',
      nativeName: 'नेपाली',
      speechLocale: 'ne-NP',
      ttsLocale: 'ne-NP',
      fallbackTtsLocale: 'hi-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'sd',
      name: 'Sindhi',
      nativeName: 'سنڌي',
      ttsLocale: null,
      fallbackTtsLocale: 'ur-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'bho',
      name: 'Bhojpuri',
      nativeName: 'भोजपुरी',
      ttsLocale: null,
      fallbackTtsLocale: 'hi-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'mai',
      name: 'Maithili',
      nativeName: 'मैथिली',
      ttsLocale: null,
      fallbackTtsLocale: 'hi-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'kok',
      name: 'Konkani',
      nativeName: 'कोंकणी',
      ttsLocale: null,
      fallbackTtsLocale: 'mr-IN',
      speechRate: 0.40,
      pitch: 1.0),
  IndianLanguage(
      code: 'ks',
      name: 'Kashmiri',
      nativeName: 'کٲشُر',
      ttsLocale: null,
      fallbackTtsLocale: 'ur-IN',
      speechRate: 0.40,
      pitch: 1.0),
];

// ── Message model ─────────────────────────────────────────────────────────────

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
  })  : analysisReports = analysisReports ?? [],
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
  void appendAnalysisReport(String markdown,
      {String? fieldKey, String? title}) {
    upsertAnalysisReport(analysisReports,
        markdown: markdown, fieldKey: fieldKey, title: title);
  }
}

// ── State enums ───────────────────────────────────────────────────────────────

enum _TtsState { idle, speaking }

enum _AlwaysOnState { off, listening, processing, waiting }

// ══════════════════════════════════════════════════════════════════════════════
// StockAiChatBody
// ══════════════════════════════════════════════════════════════════════════════

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

  // ── TTS ────────────────────────────────────────────────────────────────────
  FlutterTts? _tts;
  _TtsState _ttsState = _TtsState.idle;
  int _speakingMsgIndex = -1;
  bool _isMuted = false;
  bool _ttsAvailable = false;
  bool _webUnlocked = false;
  int? _pendingSpeakIdx;

  final List<String> _ttsQueue = [];
  bool _ttsSpeakingFromQueue = false;

  // ── Always-on mic ──────────────────────────────────────────────────────────
  bool _alwaysOnEnabled = false;
  _AlwaysOnState _alwaysOnState = _AlwaysOnState.off;
  final _inputBarKey = GlobalKey<_InputBarState>();
  bool _browserWarningShown = false;

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
    _messages = [
      AiChatMessage(
        role: AiChatRole.assistant,
        text: "Hi! I'm your AI analyst for ${widget.displayName} "
            "(${widget.symbol}). Ask me about price action, valuation, "
            "financials, news, or anything else — I'll keep it concise.",
      ),
    ];
    _initTts();
  }

  // ── TTS init ──────────────────────────────────────────────────────────────

  Future<void> _initTts() async {
    final tts = FlutterTts();
    _tts = tts;
    try {
      await tts.setVolume(1.0);
      await tts.setSpeechRate(_selectedLanguage.speechRate ?? 0.45);
      await tts.setPitch(_selectedLanguage.pitch ?? 1.0);
      final locale = _resolveTtsLocale(_selectedLanguage);
      await tts.setLanguage(locale);
      if (mounted) setState(() => _ttsAvailable = true);
      debugPrint('[TTS] init OK web=$kIsWeb locale=$locale');
    } catch (e) {
      debugPrint('[TTS] init error: $e');
      if (mounted) setState(() => _ttsAvailable = false);
    }

    tts.setCompletionHandler(() {
      if (!mounted) return;
      _speakNextFromQueue();
    });
  }

  void _showBrowserTtsWarning() {
    if (_browserWarningShown) return;
    _browserWarningShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1E293B),
          content: Row(children: [
            const Icon(Icons.volume_off_rounded, color: Colors.orange, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Voice blocked by browser shields.\n'
                'Brave: tap the 🛡 Shield icon → disable "Block fingerprinting".\n'
                'Or switch to Chrome / Edge for full voice support.',
                style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
              ),
            ),
          ]),
        ),
      );
    });
  }

  void _speakNextFromQueue() {
    if (!mounted) return;
    if (_ttsQueue.isEmpty) {
      _clearQueueAndFinish();
      return;
    }
    if (_ttsState != _TtsState.speaking) return;
    final next = _ttsQueue.removeAt(0);
    _tts?.speak(next).catchError((e) {
      debugPrint('[TTS] speak next error: $e');
      _speakNextFromQueue();
    });
  }

  void _clearQueueAndFinish() {
    _ttsQueue.clear();
    _ttsSpeakingFromQueue = false;
    if (mounted) {
      setState(() {
        _ttsState = _TtsState.idle;
        _speakingMsgIndex = -1;
      });
    }
    _alwaysOnTick();
  }

  // ── Resolve TTS locale — prefer native, fallback only if native is null ───
  String _resolveTtsLocale(IndianLanguage lang) {
    if (lang.ttsLocale != null) return lang.ttsLocale!;
    return lang.fallbackTtsLocale ?? 'en-US';
  }

  // ── Text chunking ─────────────────────────────────────────────────────────
  static const int _kChunkMax = 200;

  List<String> _chunkText(String text) {
    if (text.length <= _kChunkMax) return [text];
    final chunks = <String>[];
    // Split on sentence boundaries including Indian punctuation
    final sentences = text.split(RegExp(r'(?<=[।॥.!?])\s+'));
    final buf = StringBuffer();
    for (final s in sentences) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (buf.length + t.length + 1 > _kChunkMax) {
        if (buf.isNotEmpty) {
          chunks.add(_ensureEnding(buf.toString().trim()));
          buf.clear();
        }
        if (t.length > _kChunkMax) {
          // Sub-split on commas/semicolons
          final sub = StringBuffer();
          for (final p in t.split(RegExp(r'(?<=[,;।])\s+'))) {
            final part = p.trim();
            if (part.isEmpty) continue;
            if (sub.length + part.length + 2 > _kChunkMax) {
              if (sub.isNotEmpty) {
                chunks.add(_ensureEnding(sub.toString().trim()));
                sub.clear();
              }
            }
            if (sub.isNotEmpty) sub.write(' ');
            sub.write(part);
          }
          if (sub.isNotEmpty) chunks.add(_ensureEnding(sub.toString().trim()));
        } else {
          buf.write(t);
        }
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(t);
      }
    }
    if (buf.isNotEmpty) chunks.add(_ensureEnding(buf.toString().trim()));
    return chunks.where((c) => c.isNotEmpty).toList();
  }

  String _ensureEnding(String text) {
    if (text.isEmpty) return text;
    if (text.endsWith('।') || text.endsWith('॥') ||
        text.endsWith('.') || text.endsWith('!') || text.endsWith('?')) {
      return text;
    }
    return '$text.';
  }

  // ── Core speak ────────────────────────────────────────────────────────────
  // KEY FIX: Always set language + rate BEFORE speaking.
  // This ensures Tamil, Telugu, etc. are spoken in the correct voice,
  // not defaulted to English TTS engine.

  Future<void> _speakMessage(AiChatMessage msg, int idx) async {
    final tts = _tts;
    if (!_ttsAvailable || tts == null) return;

    if (_ttsState == _TtsState.speaking && _speakingMsgIndex == idx) {
      await tts.stop();
      _clearQueueAndFinish();
      return;
    }

    await tts.stop();
    _ttsQueue.clear();
    _ttsSpeakingFromQueue = false;

    // Use the DISPLAYED text (translated if active, else original)
    final fullText = _readableText(msg);
    if (fullText.isEmpty) return;

    // Always apply correct locale + rate for the current language
    final locale = _resolveTtsLocale(_selectedLanguage);
    final rate = _selectedLanguage.speechRate ?? 0.45;
    final pitch = _selectedLanguage.pitch ?? 1.0;

    debugPrint('[TTS] speak locale=$locale rate=$rate len=${fullText.length}');

    bool localeSet = false;
    try {
      // Step 1: set language
      final result = await tts.setLanguage(locale);
      // On some engines result == 0 means success, 1 means failure
      localeSet = (result == null || result == 1 || result == true);
      await tts.setVolume(1.0);
      await tts.setSpeechRate(rate);
      await tts.setPitch(pitch);
    } catch (e) {
      debugPrint('[TTS] locale set error ($locale): $e — trying fallback');
      localeSet = false;
    }

    // Step 2: if preferred locale failed, try fallback
    if (!localeSet && _selectedLanguage.fallbackTtsLocale != null) {
      try {
        await tts.setLanguage(_selectedLanguage.fallbackTtsLocale!);
        await tts.setVolume(1.0);
        await tts.setSpeechRate(rate);
        await tts.setPitch(pitch);
        debugPrint('[TTS] using fallback locale=${_selectedLanguage.fallbackTtsLocale}');
      } catch (e) {
        debugPrint('[TTS] fallback locale error: $e — using en-US');
        try {
          await tts.setLanguage('en-US');
        } catch (_) {}
      }
    }

    final chunks = _chunkText(fullText);
    _ttsQueue.addAll(chunks.skip(1));

    if (!mounted) return;
    setState(() {
      _ttsState = _TtsState.speaking;
      _speakingMsgIndex = idx;
      _pendingSpeakIdx = null;
      _ttsSpeakingFromQueue = true;
    });
    _alwaysOnTick();

    try {
      await tts.speak(chunks[0]);
    } catch (e) {
      debugPrint('[TTS] speak error: $e');
      _clearQueueAndFinish();
    }
  }

  Future<void> _maybeAutoSpeak(AiChatMessage msg, int idx) async {
    if (_isMuted || !_ttsAvailable) return;
    if (!mounted) return;
    if (kIsWeb) {
      if (!_webUnlocked) {
        setState(() => _pendingSpeakIdx = idx);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) await _speakMessage(msg, idx);
      return;
    }
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) await _speakMessage(msg, idx);
  }

  void _handleUserTap() {
    if (kIsWeb && !_webUnlocked) {
      setState(() => _webUnlocked = true);
    }
    if (_pendingSpeakIdx != null) {
      final idx = _pendingSpeakIdx!;
      setState(() => _pendingSpeakIdx = null);
      if (idx < _messages.length) {
        _speakMessage(_messages[idx], idx);
      }
    }
  }

  // ── Always-on mic ─────────────────────────────────────────────────────────

  void _alwaysOnTick() {
    if (!_alwaysOnEnabled) {
      _setAlwaysOnState(_AlwaysOnState.off);
      return;
    }
    final isTtsSpeaking = _ttsState == _TtsState.speaking;
    final isAiBusy = _typing;
    final micState = _inputBarKey.currentState?._voiceState;
    final micListening = micState == _VoiceState.listening;
    final micProcessing = micState == _VoiceState.processing;
    if (isTtsSpeaking) {
      _setAlwaysOnState(_AlwaysOnState.waiting);
      _inputBarKey.currentState?._pauseAlwaysOn();
      return;
    }
    if (isAiBusy || micProcessing) {
      _setAlwaysOnState(_AlwaysOnState.waiting);
      return;
    }
    if (micListening) {
      _setAlwaysOnState(_AlwaysOnState.listening);
      return;
    }
    _setAlwaysOnState(_AlwaysOnState.listening);
    _inputBarKey.currentState?._startVoice();
  }

  void _setAlwaysOnState(_AlwaysOnState next) {
    if (_alwaysOnState == next) return;
    setState(() => _alwaysOnState = next);
  }

  void _onVoiceSent(String text) {
    _setAlwaysOnState(_AlwaysOnState.processing);
    _send(text);
  }

  void _onVoiceIdle() {
    if (!_alwaysOnEnabled) return;
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _alwaysOnTick();
    });
  }

  void _toggleAlwaysOn() {
    setState(() {
      _alwaysOnEnabled = !_alwaysOnEnabled;
      if (!_alwaysOnEnabled) {
        _alwaysOnState = _AlwaysOnState.off;
        _inputBarKey.currentState?._pauseAlwaysOn();
      }
    });
    if (_alwaysOnEnabled) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _alwaysOnTick());
    }
  }

  // ── Language ──────────────────────────────────────────────────────────────

  void _onLanguageChanged(IndianLanguage lang) {
    if (lang.code == _selectedLanguage.code) return;
    _tts?.stop();
    _clearQueueAndFinish();
    setState(() {
      _selectedLanguage = lang;
      _ttsState = _TtsState.idle;
      _speakingMsgIndex = -1;
    });
    // Apply new language settings to TTS engine immediately
    _applyTtsLanguage(lang);
    for (final msg in _messages) {
      if (msg.role == AiChatRole.assistant && !msg.isStreaming) {
        _translateMessage(msg, lang);
      }
    }
  }

  Future<void> _applyTtsLanguage(IndianLanguage lang) async {
    final tts = _tts;
    if (tts == null) return;
    final locale = _resolveTtsLocale(lang);
    try {
      await tts.setLanguage(locale);
      await tts.setSpeechRate(lang.speechRate ?? 0.45);
      await tts.setPitch(lang.pitch ?? 1.0);
      debugPrint('[TTS] language applied: $locale rate=${lang.speechRate}');
    } catch (e) {
      debugPrint('[TTS] apply language error: $e');
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
        (msg.translatedText != null || msg.translatedReports != null)) return;

    setState(() => msg.isTranslating = true);
    try {
      String? newText;
      if (msg.text.trim().isNotEmpty) {
        final r = await _translator.translate(msg.text, to: lang.code);
        newText = r.text;
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
            final r = await _translator.translate(section.markdown, to: lang.code);
            newReports.add(AnalysisReportSection(
                fieldKey: section.fieldKey,
                title: section.title,
                markdown: r.text));
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

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    _handleUserTap();
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
    });
    _alwaysOnTick();
    scrollChatToBottom(_scroll);
    try {
      final reply = await _normalChatDio.chat(
        stockSymbol: apiStockSymbol(widget.symbol),
        prompt: prompt,
        cancelToken: _analysisCancel,
      );
      if (!mounted) return;
      final msg = AiChatMessage(role: AiChatRole.assistant, text: reply);
      final msgIdx = _messages.length;
      setState(() {
        _messages.add(msg);
        _typing = false;
      });
      if (_selectedLanguage.code != 'en') {
        await _translateMessage(msg, _selectedLanguage);
      }
      await _maybeAutoSpeak(msg, msgIdx);
      if (_isMuted) _alwaysOnTick();
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.type == DioExceptionType.cancel) return;
      _addError(formatAiAnalysisErrorMessage(e.message ?? 'Request failed.'));
    } on NormalChatException catch (e) {
      if (!mounted) return;
      _addError(formatAiAnalysisErrorMessage(e.message));
    } catch (e) {
      if (!mounted) return;
      _addError(formatAiAnalysisErrorMessage('Unexpected error: $e'));
    }
    scrollChatToBottom(_scroll);
  }

  void _addError(String text) {
    setState(() {
      _messages.add(AiChatMessage(role: AiChatRole.assistant, text: text));
      _typing = false;
    });
    _alwaysOnTick();
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
    setState(() {
      _typing = true;
      _messages.add(AiChatMessage(role: AiChatRole.user, text: prompt));
      _messages.add(AiChatMessage(role: AiChatRole.assistant, isStreaming: true));
    });
    _alwaysOnTick();
    scrollChatToBottom(_scroll);
    final assistantIdx = _messages.length - 1;
    try {
      await for (final event in streamAnalysisWithRetry(
        _analysisDio,
        stockSymbol: apiStockSymbol(widget.symbol),
        prompt: _analysisPromptForUser(prompt),
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
        final a = _messages[assistantIdx];
        finalizeAnalysisReport(a);
        a.isStreaming = false;
        if (!analysisHasVisibleReport(a)) {
          a.text = 'Analysis finished but no report text was returned.';
        }
        _typing = false;
      });
      if (_selectedLanguage.code != 'en') {
        await _translateMessage(_messages[assistantIdx], _selectedLanguage);
      }
      await _maybeAutoSpeak(_messages[assistantIdx], assistantIdx);
      if (_isMuted) _alwaysOnTick();
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

  void _failAnalysis(int idx, String error) {
    setState(() {
      _messages[idx].isStreaming = false;
      _messages[idx].text = formatAiAnalysisErrorMessage(error);
      _typing = false;
    });
    _alwaysOnTick();
  }

  @override
  void dispose() {
    _tts?.stop();
    _tts = null;
    _ttsQueue.clear();
    _analysisCancel?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Language bottom sheet (mobile/tablet only) ────────────────────────────

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageBottomSheet(
        selectedLanguage: _selectedLanguage,
        onLanguageChanged: (lang) {
          _onLanguageChanged(lang);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder so we react to the AI panel's actual width,
    // not the full screen width (important when panel is a sidebar).
    return LayoutBuilder(builder: (context, constraints) {
      final panelWidth = constraints.maxWidth;
      final isMobile = panelWidth < _kMobileBreakpoint;
      final isMobileOrTablet = panelWidth < _kTabletBreakpoint;

      final chatList = ListView.builder(
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
            isSpeaking: _ttsState == _TtsState.speaking && _speakingMsgIndex == i,
            isPendingSpeak: kIsWeb && _pendingSpeakIdx == i && !_isMuted,
            onRetranslate: msg.role == AiChatRole.assistant
                ? () => _translateMessage(msg, _selectedLanguage)
                : null,
            onSpeak: msg.role == AiChatRole.assistant &&
                    !msg.isStreaming &&
                    _ttsAvailable
                ? () {
                    _handleUserTap();
                    _speakMessage(msg, i);
                  }
                : null,
          );
        },
      );

      // Mobile/Tablet: long-press on chat opens language picker bottom sheet
      // Desktop: no long-press needed — language dropdown is in the header bar
      final chatArea = isMobileOrTablet
          ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _handleUserTap,
              onLongPress: () => _showLanguageBottomSheet(context),
              child: chatList,
            )
          : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _handleUserTap,
              child: chatList,
            );

      final body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showHeader)
            _Header(
              displayName: widget.displayName,
              selectedLanguage: _selectedLanguage,
              onLanguageChanged: _onLanguageChanged,
              isMuted: _isMuted,
              onMuteToggled: () {
                setState(() => _isMuted = !_isMuted);
                if (_isMuted) {
                  _tts?.stop();
                  _clearQueueAndFinish();
                }
              },
              alwaysOnEnabled: _alwaysOnEnabled,
              alwaysOnState: _alwaysOnState,
              onAlwaysOnToggled: _toggleAlwaysOn,
              // Pass panel width so _Header uses the same breakpoints
              panelWidth: panelWidth,
            ),
          if (kIsWeb && _pendingSpeakIdx != null && !_isMuted)
            GestureDetector(
              onTap: _handleUserTap,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.lightblue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.lightblue.withValues(alpha: 0.45)),
                ),
                child: Row(children: [
                  Icon(Icons.volume_up_rounded, size: 15, color: AppColors.lightblue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap to hear the AI response read aloud',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lightblue),
                    ),
                  ),
                  Icon(Icons.touch_app_rounded, size: 15, color: AppColors.lightblue),
                ]),
              ),
            ),
          Expanded(child: chatArea),
          _InputBar(
            key: _inputBarKey,
            controller: _input,
            onSend: () => _send(),
            onVoiceSent: _onVoiceSent,
            onVoiceIdle: _onVoiceIdle,
            enabled: !_typing,
            isDeepAnalysis: _isDeepAnalysis,
            onModeToggled: (v) => setState(() => _isDeepAnalysis = v),
            selectedLanguage: _selectedLanguage,
            translator: _translator,
            alwaysOnState: _alwaysOnState,
            onBrowserBlocked: _showBrowserTtsWarning,
          ),
          const AiChatDisclaimerFooter(),
        ],
      );

      if (widget.maxHeight != null) {
        return SizedBox(height: widget.maxHeight, child: body);
      }
      return body;
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _Header
// KEY: Uses panelWidth (actual widget width) instead of MediaQuery screen width.
// Desktop (panelWidth >= 900): logo | name | language dropdown | mic | mute
// Tablet (600–899):            logo+name row / language+controls row
// Mobile (<600):               logo+name+controls, NO dropdown (long-press chat)
// ══════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({
    required this.displayName,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isMuted,
    required this.onMuteToggled,
    required this.alwaysOnEnabled,
    required this.alwaysOnState,
    required this.onAlwaysOnToggled,
    required this.panelWidth,
  });

  final String displayName;
  final IndianLanguage selectedLanguage;
  final ValueChanged<IndianLanguage> onLanguageChanged;
  final bool isMuted;
  final VoidCallback onMuteToggled;
  final bool alwaysOnEnabled;
  final _AlwaysOnState alwaysOnState;
  final VoidCallback onAlwaysOnToggled;
  final double panelWidth;

  @override
  Widget build(BuildContext context) {
    final isMobile = panelWidth < _kMobileBreakpoint;
    final isTablet = panelWidth >= _kMobileBreakpoint && panelWidth < _kTabletBreakpoint;
    final isDesktop = panelWidth >= _kTabletBreakpoint;

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
          )
        ],
      ),
      child: isDesktop
          ? _buildDesktop()
          : isTablet
              ? _buildTablet()
              : _buildMobile(),
    );
  }

  List<Widget> get _controls => [
        _AlwaysOnMicButton(
          state: alwaysOnState,
          isEnabled: alwaysOnEnabled,
          onTap: onAlwaysOnToggled,
        ),
        const SizedBox(width: 8),
        _MuteButton(isMuted: isMuted, onTap: onMuteToggled),
      ];

  // ── Desktop: single row with language dropdown always visible ─────────────
  Widget _buildDesktop() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const StocbuyLogoMark(size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.darkblue,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Language dropdown — always visible on desktop
          SizedBox(
            width: 155,
            child: _LanguageDropdown(
              selected: selectedLanguage,
              onChanged: onLanguageChanged,
            ),
          ),
          const SizedBox(width: 8),
          ..._controls,
        ],
      );

  // ── Tablet: two rows ──────────────────────────────────────────────────────
  Widget _buildTablet() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const StocbuyLogoMark(size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkblue,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          // Tablet also shows dropdown for convenience (no long-press needed)
          Row(children: [
            Expanded(
              child: _LanguageDropdown(
                selected: selectedLanguage,
                onChanged: onLanguageChanged,
              ),
            ),
            const SizedBox(width: 8),
            ..._controls,
          ]),
        ],
      );

  // ── Mobile: compact single row, NO dropdown ───────────────────────────────
  // Language changed via long-press on the chat list area
  Widget _buildMobile() => Row(
        children: [
          const StocbuyLogoMark(size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkblue,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(children: [
                  const Icon(Icons.language_rounded, size: 9, color: AppColors.grey),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '${selectedLanguage.nativeName} · Hold to change',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ..._controls,
        ],
      );
}

// ── Language Bottom Sheet (Mobile / Tablet only) ──────────────────────────────

class _LanguageBottomSheet extends StatelessWidget {
  const _LanguageBottomSheet({
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  final IndianLanguage selectedLanguage;
  final ValueChanged<IndianLanguage> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              const Icon(Icons.language_rounded, size: 18, color: AppColors.darkblue),
              const SizedBox(width: 10),
              const Text(
                'Select Language',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkblue,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: AppColors.grey),
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          // Language list
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: kIndianLanguages.length,
              itemBuilder: (context, index) {
                final lang = kIndianLanguages[index];
                final isSelected = selectedLanguage.code == lang.code;
                return InkWell(
                  onTap: () => onLanguageChanged(lang),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.lightblue.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.lightblue.withValues(alpha: 0.45)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.nativeName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? AppColors.lightblue : AppColors.darkblue,
                              ),
                            ),
                            Text(
                              lang.name,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.lightblue.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_rounded,
                              size: 14, color: AppColors.lightblue),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Always-On Mic Button ──────────────────────────────────────────────────────

class _AlwaysOnMicButton extends StatelessWidget {
  const _AlwaysOnMicButton(
      {required this.state, required this.isEnabled, required this.onTap});
  final _AlwaysOnState state;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg, border, fg;
    IconData icon;
    String label;
    switch (state) {
      case _AlwaysOnState.listening:
        bg = Colors.red.withValues(alpha: 0.12);
        border = Colors.red.withValues(alpha: 0.55);
        fg = Colors.red;
        icon = Icons.mic_rounded;
        label = 'Listening';
        break;
      case _AlwaysOnState.processing:
        bg = Colors.orange.withValues(alpha: 0.12);
        border = Colors.orange.withValues(alpha: 0.55);
        fg = Colors.orange;
        icon = Icons.translate_rounded;
        label = 'Processing';
        break;
      case _AlwaysOnState.waiting:
        bg = Colors.blue.withValues(alpha: 0.10);
        border = Colors.blue.withValues(alpha: 0.40);
        fg = Colors.blue;
        icon = Icons.hourglass_top_rounded;
        label = 'Waiting';
        break;
      default:
        bg = AppColors.surfaceMuted;
        border = AppColors.border;
        fg = AppColors.grey;
        icon = Icons.mic_off_rounded;
        label = 'Mic OFF';
    }
    if (isEnabled && state == _AlwaysOnState.off) {
      bg = Colors.green.withValues(alpha: 0.10);
      border = Colors.green.withValues(alpha: 0.40);
      fg = Colors.green;
      icon = Icons.mic_none_rounded;
      label = 'Mic ON';
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: isEnabled ? 1.4 : 1.0)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
        ]),
      ),
    );
  }
}

// ── Mute Button ───────────────────────────────────────────────────────────────

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.isMuted, required this.onTap});
  final bool isMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMuted ? Colors.red.withValues(alpha: 0.12) : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isMuted ? Colors.red.withValues(alpha: 0.45) : AppColors.border),
          ),
          child: Icon(
              isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: 16,
              color: isMuted ? Colors.red : AppColors.grey),
        ),
      );
}

// ── Language Dropdown ─────────────────────────────────────────────────────────

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.selected, required this.onChanged});
  final IndianLanguage selected;
  final ValueChanged<IndianLanguage> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<IndianLanguage>(
            value: selected,
            isDense: true,
            isExpanded: true,
            menuMaxHeight: 320,
            icon: const Icon(Icons.language_rounded, size: 14, color: AppColors.grey),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkblue),
            borderRadius: BorderRadius.circular(12),
            items: kIndianLanguages
                .map((lang) => DropdownMenuItem<IndianLanguage>(
                      value: lang,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                              child: Text(lang.nativeName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkblue))),
                          const SizedBox(width: 4),
                          Text('(${lang.name})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.grey)),
                        ]),
                      ),
                    ))
                .toList(),
            onChanged: (l) {
              if (l != null) onChanged(l);
            },
            selectedItemBuilder: (_) => kIndianLanguages
                .map((lang) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(lang.nativeName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkblue)),
                    ))
                .toList(),
          ),
        ),
      );
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isSpeaking,
    this.isPendingSpeak = false,
    this.onRetranslate,
    this.onSpeak,
  });
  final AiChatMessage message;
  final bool isSpeaking;
  final bool isPendingSpeak;
  final VoidCallback? onRetranslate;
  final VoidCallback? onSpeak;

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
            analysisReports: m.isTranslating ? m.analysisReports : m.displayReports,
            isStreaming: m.isStreaming,
            stepLog: m.stepLog,
            sentAt: m.sentAt,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8, top: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (m.isTranslating) ...[
                const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppColors.grey)),
                const SizedBox(width: 5),
                const Text('Translating…',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.grey, fontWeight: FontWeight.w500)),
              ],
              if (!m.isTranslating &&
                  (m.translatedText != null || m.translatedReports != null)) ...[
                const Icon(Icons.translate_rounded, size: 10, color: AppColors.grey),
                const SizedBox(width: 4),
                const Text('Translated',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.grey, fontWeight: FontWeight.w500)),
                if (onRetranslate != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                      onTap: onRetranslate,
                      child: const Text('· Retry',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.lightblue,
                              fontWeight: FontWeight.w600))),
                ],
              ],
              if (onSpeak != null) ...[
                if (m.isTranslating ||
                    (!m.isTranslating &&
                        (m.translatedText != null || m.translatedReports != null)))
                  const SizedBox(width: 8),
                _SpeakButton(
                    isSpeaking: isSpeaking, isPending: isPendingSpeak, onTap: onSpeak!),
              ],
            ]),
          ),
        ]);
  }
}

// ── Speak Button ──────────────────────────────────────────────────────────────

class _SpeakButton extends StatelessWidget {
  const _SpeakButton(
      {required this.isSpeaking, required this.onTap, this.isPending = false});
  final bool isSpeaking;
  final bool isPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border, bg, fg;
    final IconData icon;
    final String label;
    if (isSpeaking) {
      border = AppColors.lightblue.withValues(alpha: 0.45);
      bg = AppColors.lightblue.withValues(alpha: 0.12);
      fg = AppColors.lightblue;
      icon = Icons.stop_rounded;
      label = 'Stop';
    } else if (isPending) {
      border = Colors.orange.withValues(alpha: 0.55);
      bg = Colors.orange.withValues(alpha: 0.10);
      fg = Colors.orange;
      icon = Icons.touch_app_rounded;
      label = 'Tap to hear';
    } else {
      border = AppColors.border;
      bg = Colors.transparent;
      fg = AppColors.grey;
      icon = Icons.volume_up_rounded;
      label = 'Speak';
    }
    final btn = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
        ]),
      ),
    );
    if (kIsWeb && !isSpeaking && !isPending) {
      return Tooltip(message: 'Tap to read aloud', child: btn);
    }
    return btn;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _InputBar
// ══════════════════════════════════════════════════════════════════════════════

enum _VoiceState { idle, listening, processing }

class _InputBar extends StatefulWidget {
  const _InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onVoiceSent,
    required this.onVoiceIdle,
    required this.enabled,
    required this.isDeepAnalysis,
    required this.onModeToggled,
    required this.selectedLanguage,
    required this.translator,
    required this.alwaysOnState,
    required this.onBrowserBlocked,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<String> onVoiceSent;
  final VoidCallback onVoiceIdle;
  final bool enabled;
  final bool isDeepAnalysis;
  final ValueChanged<bool> onModeToggled;
  final IndianLanguage selectedLanguage;
  final GoogleTranslator translator;
  final _AlwaysOnState alwaysOnState;
  final VoidCallback onBrowserBlocked;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> with SingleTickerProviderStateMixin {
  bool _hasText = false;
  _VoiceState _voiceState = _VoiceState.idle;
  String _liveTranscript = '';
  int _sessionId = 0;
  bool _finishing = false;
  DateTime? _listenStart;
  bool _finalResultReceived = false;
  String _bestTranscript = '';

  SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _speechInitialized = false;
  bool _browserBlockedWarningShown = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.22)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  void _onTextChanged() {
    final h = widget.controller.text.trim().isNotEmpty;
    if (h != _hasText) setState(() => _hasText = h);
  }

  Future<bool> _initSpeech() async {
    if (kIsWeb) {
      _speech = SpeechToText();
      _speechInitialized = false;
    }
    if (_speechInitialized && _speechAvailable) return true;
    try {
      _speechAvailable = await _speech.initialize(
        onError: (err) {
          final code = err?.errorMsg ?? err.toString();
          debugPrint('[STT] error: $code');
          if (!mounted) return;
          final lower = code.toLowerCase();
          if (kIsWeb && lower.contains('network') && !_browserBlockedWarningShown) {
            _browserBlockedWarningShown = true;
            widget.onBrowserBlocked();
            _forceReset();
            return;
          }
          if (lower.contains('network') || lower.contains('connection')) return;
          if (lower.contains('timeout') ||
              lower.contains('no_match') ||
              lower.contains('no match')) {
            if (_voiceState == _VoiceState.listening) {
              _liveTranscript.trim().isNotEmpty ? _finishVoice() : _onSilence();
            }
            return;
          }
          _forceReset();
        },
        onStatus: (status) {
          debugPrint('[STT] status: $status');
          if (!mounted) return;
          if (status == SpeechToText.doneStatus &&
              _voiceState == _VoiceState.listening &&
              !_finishing) {
            Future<void>.delayed(const Duration(milliseconds: 300), () {
              if (!mounted || _finishing || _voiceState != _VoiceState.listening) return;
              if (_finalResultReceived) return;
              final elapsed = DateTime.now()
                  .difference(_listenStart ?? DateTime.now())
                  .inMilliseconds;
              if (elapsed >= 600 && _liveTranscript.trim().isNotEmpty) {
                _finishVoice();
              } else {
                _onSilence();
              }
            });
          }
        },
      );
      _speechInitialized = true;
      if (!_speechAvailable && kIsWeb && !_browserBlockedWarningShown) {
        _browserBlockedWarningShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onBrowserBlocked();
        });
      }
      if (mounted) setState(() {});
      return _speechAvailable;
    } catch (e) {
      debugPrint('[STT] init error: $e');
      _speechAvailable = false;
      _speechInitialized = false;
      if (mounted) setState(() {});
      return false;
    }
  }

  Future<void> _startVoice() async {
    if (_voiceState != _VoiceState.idle || !widget.enabled) return;
    final ok = await _initSpeech();
    if (!ok || !mounted) return;

    final mySession = ++_sessionId;
    _finishing = false;
    _finalResultReceived = false;
    _liveTranscript = '';
    _bestTranscript = '';
    _listenStart = DateTime.now();

    setState(() => _voiceState = _VoiceState.listening);
    final locale = widget.selectedLanguage.speechLocale ?? 'en-US';
    debugPrint('[STT] listen session=$mySession locale=$locale');
    try {
      // ignore: deprecated_member_use
      await _speech.listen(
        localeId: locale,
        listenMode: ListenMode.confirmation,
        partialResults: kIsWeb,
        cancelOnError: false,
        listenFor: const Duration(minutes: 3),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          if (!mounted || mySession != _sessionId) return;
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty && words.length >= _bestTranscript.length) {
            _bestTranscript = words;
            if (mounted) setState(() => _liveTranscript = words);
          }
          if (result.finalResult && words.isNotEmpty) {
            _finalResultReceived = true;
            _finishVoice(session: mySession);
          }
        },
      );
    } catch (e) {
      debugPrint('[STT] listen error: $e');
      _forceReset();
    }
  }

  void _pauseAlwaysOn() {
    if (_voiceState == _VoiceState.listening) {
      _sessionId++;
      _speech.stop();
      if (mounted) setState(() => _voiceState = _VoiceState.idle);
    }
  }

  void _toggleVoice() {
    if (_voiceState == _VoiceState.listening) {
      _finishVoice();
    } else if (_voiceState == _VoiceState.idle) {
      _startVoice();
    }
  }

  void _onSilence() {
    if (!mounted) return;
    setState(() {
      _voiceState = _VoiceState.idle;
      _liveTranscript = '';
      _bestTranscript = '';
    });
    widget.onVoiceIdle();
  }

  Future<void> _finishVoice({int? session}) async {
    if (_finishing || _voiceState != _VoiceState.listening) return;
    if (session != null && session != _sessionId) return;
    _finishing = true;
    if (!mounted) {
      _finishing = false;
      return;
    }
    setState(() => _voiceState = _VoiceState.processing);
    await _speech.stop();

    final rawText = _bestTranscript.trim().isNotEmpty
        ? _bestTranscript.trim()
        : _liveTranscript.trim();

    debugPrint('[STT] finish raw="$rawText"');
    if (rawText.isEmpty) {
      _forceReset();
      _finishing = false;
      widget.onVoiceIdle();
      return;
    }

    String englishText = rawText;
    if (widget.selectedLanguage.code != 'en') {
      try {
        final r = await widget.translator.translate(rawText, to: 'en');
        final t = r.text.trim();
        if (t.isNotEmpty) englishText = t;
      } catch (e) {
        debugPrint('[STT] translation error: $e');
      }
    }

    if (!mounted) {
      _finishing = false;
      return;
    }
    _forceReset();
    _finishing = false;
    widget.onVoiceSent(englishText);
  }

  void _forceReset() {
    _sessionId++;
    _speech.stop();
    _finishing = false;
    _finalResultReceived = false;
    if (mounted) {
      setState(() {
        _voiceState = _VoiceState.idle;
        _liveTranscript = '';
        _bestTranscript = '';
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _pulseCtrl.dispose();
    _sessionId++;
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.enabled && _hasText;
    final deep = widget.isDeepAnalysis;
    final alwaysOn = widget.alwaysOnState != _AlwaysOnState.off;
    final fieldBorderColor = _voiceState == _VoiceState.listening
        ? Colors.red.withValues(alpha: 0.55)
        : alwaysOn
            ? Colors.green.withValues(alpha: 0.55)
            : deep
                ? AppColors.green.withValues(alpha: 0.5)
                : AppColors.border;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.7)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _ModeChip(
              label: 'Chat',
              icon: Icons.chat_bubble_outline_rounded,
              active: !deep,
              activeColor: AppColors.lightblue,
              onTap: () => widget.onModeToggled(false)),
          const SizedBox(width: 6),
          _ModeChip(
              label: 'AI Analysis',
              icon: Icons.auto_awesome_rounded,
              active: deep,
              activeColor: AppColors.green,
              onTap: () => widget.onModeToggled(true)),
          if (alwaysOn) ...[
            const SizedBox(width: 8),
            _AlwaysOnStatusPill(state: widget.alwaysOnState),
          ],
        ]),
        const SizedBox(height: 8),
        if (_voiceState != _VoiceState.idle) ...[
          _VoiceHintBar(
              voiceState: _voiceState,
              transcript: _liveTranscript,
              langName: widget.selectedLanguage.nativeName,
              onCancel: alwaysOn ? null : _forceReset),
          const SizedBox(height: 4),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: fieldBorderColor,
                    width: alwaysOn || deep || _voiceState != _VoiceState.idle
                        ? 1.4
                        : 1.0),
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
                  hintText: _hintText(alwaysOn, deep),
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: _voiceState == _VoiceState.listening
                          ? Colors.red
                          : alwaysOn
                              ? Colors.green
                              : AppColors.grey,
                      fontWeight: FontWeight.w600),
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.darkblue, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendVoiceButton(
              canSend: canSend,
              voiceState: _voiceState,
              deep: deep,
              alwaysOn: alwaysOn,
              pulseAnim: _pulseAnim,
              onSendTap: canSend ? widget.onSend : null,
              onVoiceTap: alwaysOn ? null : _toggleVoice),
        ]),
      ]),
    );
  }

  String _hintText(bool alwaysOn, bool deep) {
    if (_voiceState == _VoiceState.listening) {
      return 'Listening in ${widget.selectedLanguage.nativeName}…';
    }
    if (_voiceState == _VoiceState.processing) return 'Translating…';
    if (alwaysOn) return 'Always-on mic active — speak any time…';
    if (deep) return 'Ask for deep analysis…';
    return 'Ask the AI…';
  }
}

// ── Always-On Status Pill ─────────────────────────────────────────────────────

class _AlwaysOnStatusPill extends StatelessWidget {
  const _AlwaysOnStatusPill({required this.state});
  final _AlwaysOnState state;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    IconData icon;
    switch (state) {
      case _AlwaysOnState.listening:
        label = 'Listening…';
        color = Colors.red;
        icon = Icons.mic_rounded;
        break;
      case _AlwaysOnState.processing:
        label = 'Processing…';
        color = Colors.orange;
        icon = Icons.translate_rounded;
        break;
      case _AlwaysOnState.waiting:
        label = 'Waiting…';
        color = Colors.blue;
        icon = Icons.hourglass_top_rounded;
        break;
      default:
        label = 'Ready';
        color = Colors.green;
        icon = Icons.mic_none_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.40))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── Send + Voice Button ───────────────────────────────────────────────────────

class _SendVoiceButton extends StatelessWidget {
  const _SendVoiceButton({
    required this.canSend,
    required this.voiceState,
    required this.deep,
    required this.alwaysOn,
    required this.pulseAnim,
    required this.onSendTap,
    required this.onVoiceTap,
  });
  final bool canSend, deep, alwaysOn;
  final _VoiceState voiceState;
  final Animation<double> pulseAnim;
  final VoidCallback? onSendTap, onVoiceTap;

  Color get _color {
    if (alwaysOn) {
      if (voiceState == _VoiceState.listening) return Colors.red;
      if (voiceState == _VoiceState.processing) return Colors.orange;
      return Colors.green;
    }
    if (voiceState == _VoiceState.listening) return Colors.red;
    if (voiceState == _VoiceState.processing) return Colors.orange;
    final base = deep ? AppColors.green : AppColors.lightblue;
    return canSend ? base : base.withValues(alpha: 0.45);
  }

  IconData get _icon {
    if (voiceState == _VoiceState.listening) return Icons.mic_rounded;
    if (voiceState == _VoiceState.processing) return Icons.translate_rounded;
    if (alwaysOn) return Icons.mic_none_rounded;
    return canSend ? Icons.send_rounded : Icons.mic_none_rounded;
  }

  VoidCallback? get _tap {
    if (voiceState == _VoiceState.processing || alwaysOn) return null;
    if (voiceState == _VoiceState.listening) return onVoiceTap;
    return canSend ? onSendTap : onVoiceTap;
  }

  @override
  Widget build(BuildContext context) {
    Widget circle = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: (canSend || voiceState != _VoiceState.idle || alwaysOn)
            ? [
                BoxShadow(
                    color: _color.withValues(alpha: 0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                    spreadRadius: -3)
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _tap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: voiceState == _VoiceState.processing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

// ── Voice Hint Bar ────────────────────────────────────────────────────────────

class _VoiceHintBar extends StatelessWidget {
  const _VoiceHintBar({
    required this.voiceState,
    required this.transcript,
    required this.langName,
    this.onCancel,
  });
  final _VoiceState voiceState;
  final String transcript, langName;
  final VoidCallback? onCancel;

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
                : Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(isListening ? Icons.mic_rounded : Icons.translate_rounded,
            size: 12, color: isListening ? Colors.red : Colors.orange),
        const SizedBox(width: 6),
        Expanded(
            child: Text(
          isListening
              ? transcript.isEmpty
                  ? 'Listening in $langName…'
                  : transcript
              : 'Translating…',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11,
              color: isListening ? Colors.red[700] : Colors.orange[800],
              fontWeight: FontWeight.w600),
        )),
        if (onCancel != null) ...[
          const SizedBox(width: 6),
          GestureDetector(
              onTap: onCancel,
              child: const Icon(Icons.close_rounded, size: 14, color: AppColors.grey)),
        ],
      ]),
    );
  }
}

// ── Mode Chip ─────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.12) : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? activeColor.withValues(alpha: 0.55) : AppColors.border,
              width: active ? 1.2 : 1.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            hoverColor: activeColor.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 12, color: active ? activeColor : AppColors.grey),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active ? activeColor : AppColors.grey,
                        letterSpacing: 0.1)),
              ]),
            ),
          ),
        ),
      );
}

// ── Desktop Panel ─────────────────────────────────────────────────────────────

class StockAiChatPanel extends StatelessWidget {
  const StockAiChatPanel(
      {super.key, required this.symbol, required this.displayName});
  final String symbol, displayName;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.border.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.darkblue.withValues(alpha: 0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                  spreadRadius: -6)
            ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: StockAiChatBody(symbol: symbol, displayName: displayName)),
      );
}