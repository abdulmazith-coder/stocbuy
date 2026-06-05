// stocbuy_gpt_chat_page.dart
// ─────────────────────────────────────────────────────────────────────────────
// Merged: all TTS + always-on mic features from stock_ai_chat.dart added on
// top of the existing StocbuyGptChatPage structure.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/ai_usage_controller.dart';
import 'package:stocbuy_application/application/models/analysis_report_section.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/tts_speak.dart';
import 'package:translator/translator.dart';
import 'package:stocbuy_application/application/navigation/app_routes.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_dio.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/normal_chat_dio.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/penny_stock_filter_dio.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/best_stocks_cap_type.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/filtered_stock.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/gpt_chat_message.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/services/best_stocks_cache.dart';
import 'package:stocbuy_application/application/navigation/stock_details_route.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/utils/stock_symbol_util.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/best_stocks_cap_dialog.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_input_bar.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_chat_message_list.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_stock_symbol_bar.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_language_selector.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/stock_analysis_dialog.dart';
import 'package:stocbuy_application/application/utils/best_stocks_stream_apply.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat.dart'
    show kIndianLanguages, IndianLanguage, AiChatRole;
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_error_message.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_prompt.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_run.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_stream_apply.dart';
import 'package:stocbuy_application/application/utils/chat_auto_scroll.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/ai_chat_bubbles.dart';
import 'package:stocbuy_application/application/widgets/network_offline_banner.dart';

// ── Always-on state enum ─────────────────────────────────────────────────────

enum _AlwaysOnState { off, listening, processing, waiting }

// ── Markdown → clean speech text (identical to stock_ai_chat.dart) ────────────

String _stripMarkdown(String md) {
  final lines = md.split('\n');
  final processed = lines.map((line) {
    var l = line;
    if (l.trim().startsWith('|')) {
      l = l
          .replaceAll(RegExp(r'^\s*\||\|\s*$'), '')
          .split('|')
          .map((cell) => cell.trim())
          .where((cell) =>
              cell.isNotEmpty && !RegExp(r'^[-:]+$').hasMatch(cell))
          .join(', ');
    }
    l = l.replaceAllMapped(
        RegExp(r'\*{3}([^*\n]+)\*{3}'), (m) => m[1] ?? '');
    l = l.replaceAllMapped(
        RegExp(r'\*{2}([^*\n]+)\*{2}'), (m) => m[1] ?? '');
    l = l.replaceAllMapped(RegExp(r'\*([^*\n]+)\*'), (m) => m[1] ?? '');
    l = l.replaceAllMapped(RegExp(r'__([^_\n]+)__'), (m) => m[1] ?? '');
    l = l.replaceAllMapped(RegExp(r'_([^_\n]+)_'), (m) => m[1] ?? '');
    l = l.replaceAllMapped(
        RegExp(r'^#{1,6}\s*(.+)$'), (m) => '${m[1]}. ');
    l = l.replaceAll(RegExp(r'^\s*>\s*'), '');
    l = l.replaceAll(RegExp(r'^\s*[-*•]\s+'), '');
    l = l.replaceAll(RegExp(r'^\s*\d+\.\s+'), '');
    l = l.replaceAll(RegExp(r'`[^`]*`'), '');
    l = l.replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1] ?? '');
    l = l.replaceAll(RegExp(r'^[-*_]{3,}\s*$'), '. ');
    l = l.replaceAll(RegExp(r'[_~\\]'), '');
    l = l.replaceAll(RegExp(r'\*+'), '');
    l = l.replaceAllMapped(
        RegExp(r'([A-Za-z/%₹$€£])(\d)'), (m) => '${m[1]} ${m[2]}');
    return l.trim();
  }).toList();

  final buf = StringBuffer();
  for (var i = 0; i < processed.length; i++) {
    final line = processed[i].trim();
    if (line.isEmpty) {
      if (buf.isNotEmpty) {
        final s = buf.toString();
        if (!s.endsWith('. ') &&
            !s.endsWith('! ') &&
            !s.endsWith('? ')) {
          buf.write('. ');
        }
      }
    } else {
      buf.write(line);
      buf.write(' ');
    }
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'  +'), ' ')
      .replaceAll(RegExp(r'\.\s*\.+'), '.')
      .replaceAll(RegExp(r',\s*,'), ',')
      .trim();
}

String _readableGptText(GptChatMessage msg) {
  final buf = StringBuffer();
  final body = _stripMarkdown(msg.displayText.trim());
  if (body.isNotEmpty) {
    buf.write(body);
    if (!body.endsWith('.') &&
        !body.endsWith('!') &&
        !body.endsWith('?')) buf.write('.');
    buf.write(' ');
  }
  for (final s in msg.displayReports) {
    final t = s.markdown.trim();
    if (t.isEmpty) continue;
    if (s.title != null && s.title!.isNotEmpty) {
      buf.write('${s.title}. ');
    }
    final c = _stripMarkdown(t);
    if (c.isNotEmpty) {
      buf.write(c);
      if (!c.endsWith('.') && !c.endsWith('!') && !c.endsWith('?'))
        buf.write('.');
      buf.write(' ');
    }
  }
  return buf.toString().trim();
}

// ══════════════════════════════════════════════════════════════════════════════
// StocbuyGptChatPage
// ══════════════════════════════════════════════════════════════════════════════

/// Global Stocbuy GPT landing + chat (opened from navbar → Stocbuy AI).
class StocbuyGptChatPage extends StatefulWidget {
  const StocbuyGptChatPage({super.key});

  static const String route = '/stocbuy-ai';

  /// Navbar / drawer index for "Stocbuy AI".
  static const int menuIndex = 1;

  @override
  State<StocbuyGptChatPage> createState() => _StocbuyGptChatPageState();
}

class _StocbuyGptChatPageState extends State<StocbuyGptChatPage> {
  // ── Chat state ─────────────────────────────────────────────────────────────
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final List<GptChatMessage> _messages = [];
  final AiAnalysisDio _analysisDio = AiAnalysisDio();
  final NormalChatDio _normalChatDio = NormalChatDio();
  final PennyStockFilterDio _filterDio = PennyStockFilterDio();
  final GoogleTranslator _translator = GoogleTranslator();
  CancelToken? _analysisCancel;
  bool _typing = false;

  IndianLanguage _selectedLanguage = kIndianLanguages.first;
  String? _analysisStockSymbol;

  // ── TTS state ──────────────────────────────────────────────────────────────
  FlutterTts? _tts;
  TtsState _ttsState = TtsState.idle;
  int _speakingMsgIndex = -1;
  bool _isMuted = false;
  bool _ttsAvailable = false;
  bool _webUnlocked = false;
  int? _pendingSpeakIdx;
  List<String> _ttsChunks = [];
  int _ttsChunkIndex = 0;
  int _ttsSpeakSession = 0;
  bool _browserWarningShown = false;

  // ── Always-on mic state ────────────────────────────────────────────────────
  bool _alwaysOnEnabled = false;
  _AlwaysOnState _alwaysOnState = _AlwaysOnState.off;

  // ── Quick actions ──────────────────────────────────────────────────────────
  static const _quickActions = <_GptQuickAction>[
    _GptQuickAction(
      label: 'Stock analysis',
      icon: Icons.analytics_outlined,
      toolAction: GptToolAction.stockAnalysis,
    ),
    _GptQuickAction(
      label: 'Filter best stocks',
      icon: Icons.filter_alt_outlined,
      toolAction: GptToolAction.bestStocks,
    ),
    _GptQuickAction(
      label: 'SEBI advisor',
      icon: Icons.verified_user_outlined,
      toolAction: GptToolAction.sebiAdvisor,
    ),
  ];

  bool get _showLanding => _messages.isEmpty && !_typing;
  bool get _showConversation => _messages.isNotEmpty || _typing;

  bool get _showTypingDots {
    if (!_typing) return false;
    if (_messages.isEmpty) return true;
    return _messages.last.role == AiChatRole.user;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    unawaited(BestStocksCache.clearExpired());
    _initTts();
  }

  @override
  void dispose() {
    _tts?.stop();
    _tts = null;
    _analysisCancel?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── TTS init ──────────────────────────────────────────────────────────────

  Future<void> _initTts() async {
    final tts = FlutterTts();
    _tts = tts;
    try {
      if (!kIsWeb) await tts.awaitSpeakCompletion(true);
      await tts.setVolume(1.0);
      await tts.setSpeechRate(kIsWeb ? 0.9 : 0.42);
      await tts.setPitch(1.0);
      if (mounted) setState(() => _ttsAvailable = true);
    } catch (e) {
      debugPrint('[TTS] init error: $e');
      if (mounted) setState(() => _ttsAvailable = false);
      return;
    }

    tts.setCompletionHandler(() {
      if (!mounted) return;
      _ttsChunkIndex++;
      if (_ttsState != TtsState.speaking) return;
      if (_ttsChunkIndex < _ttsChunks.length) {
        tts.speak(_ttsChunks[_ttsChunkIndex]);
      } else {
        _onTtsDone();
      }
    });

    tts.setCancelHandler(() {
      if (!mounted) return;
      _onTtsDone();
    });

    tts.setErrorHandler((e) {
      if (!mounted) return;
      final s = e.toString().toLowerCase();
      if (s.contains('synthesis-failed') || s.contains('synthesis_failed')) {
        setState(() {
          _ttsAvailable = false;
          _ttsState = TtsState.idle;
          _speakingMsgIndex = -1;
        });
        _showBrowserTtsWarning();
        return;
      }
      if (s.contains('interrupted') || s.contains('cancel')) {
        _onTtsDone();
        return;
      }
      _ttsChunkIndex++;
      if (_ttsState == TtsState.speaking &&
          _ttsChunkIndex < _ttsChunks.length) {
        tts.speak(_ttsChunks[_ttsChunkIndex]);
      } else {
        _onTtsDone();
      }
    });

    if (kIsWeb) {
      try {
        await tts.setVolume(0.0);
        await tts.speak(' ');
        await tts.setVolume(1.0);
      } catch (_) {
        await tts.setVolume(1.0);
      }
    }
  }

  void _onTtsDone() {
    _ttsChunks = [];
    _ttsChunkIndex = 0;
    if (!mounted) return;
    setState(() {
      _ttsState = TtsState.idle;
      _speakingMsgIndex = -1;
    });
    _alwaysOnTick();
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1E293B),
          content: Row(children: [
            const Icon(Icons.volume_off_rounded,
                color: Colors.orange, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Voice blocked by browser shields.\n'
                'Brave: tap the 🛡 Shield icon → disable "Block fingerprinting".\n'
                'Or switch to Chrome / Edge for full voice support.',
                style: TextStyle(
                    fontSize: 12, color: Colors.white, height: 1.4),
              ),
            ),
          ]),
        ),
      );
    });
  }

  String _resolveTtsLocale(IndianLanguage lang) =>
      lang.ttsLocale ?? lang.fallbackTtsLocale ?? 'en-US';

  // ── Text chunking ─────────────────────────────────────────────────────────

  static const int _kChunkMax = 400;

  List<String> _chunkText(String text) {
    if (text.length <= _kChunkMax) return [text];
    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.!?।॥])\s+'));
    final buf = StringBuffer();
    for (final s in sentences) {
      final t = s.trim();
      if (t.isEmpty) continue;
      if (buf.length + t.length + 1 > _kChunkMax) {
        if (buf.isNotEmpty) {
          chunks.add(buf.toString().trim());
          buf.clear();
        }
        if (t.length > _kChunkMax) {
          final sub = StringBuffer();
          for (final p in t.split(RegExp(r'(?<=[,;])\s+'))) {
            final part = p.trim();
            if (part.isEmpty) continue;
            if (sub.length + part.length + 2 > _kChunkMax) {
              if (sub.isNotEmpty) {
                chunks.add(sub.toString().trim());
                sub.clear();
              }
            }
            if (sub.isNotEmpty) sub.write(' ');
            sub.write(part);
          }
          if (sub.isNotEmpty) chunks.add(sub.toString().trim());
        } else {
          buf.write(t);
        }
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(t);
      }
    }
    if (buf.isNotEmpty) chunks.add(buf.toString().trim());
    return chunks
        .where((c) => c.isNotEmpty)
        .map((c) {
          if (!c.endsWith('.') &&
              !c.endsWith('!') &&
              !c.endsWith('?') &&
              !c.endsWith('।') &&
              !c.endsWith('॥')) return '$c.';
          return c;
        })
        .toList();
  }

  // ── Core speak ─────────────────────────────────────────────────────────────

  Future<void> _speakMessage(GptChatMessage msg, int idx) async {
    final tts = _tts;
    if (!_ttsAvailable || tts == null) return;

    if (_ttsState == TtsState.speaking && _speakingMsgIndex == idx) {
      _ttsSpeakSession++;
      await tts.stop();
      return;
    }

    _ttsSpeakSession++;
    await tts.stop();

    final fullText = _readableGptText(msg);
    if (fullText.isEmpty) return;

    final locale = _resolveTtsLocale(_selectedLanguage);
    try {
      await tts.setLanguage(locale);
      await tts.setVolume(1.0);
      await tts.setSpeechRate(kIsWeb ? 0.9 : 0.70);
      await tts.setPitch(1.0);
    } catch (e) {
      try {
        await tts.setLanguage('en-US');
      } catch (_) {}
    }

    _ttsChunks = _chunkText(fullText);
    _ttsChunkIndex = 0;

    if (!mounted) return;
    setState(() {
      _ttsState = TtsState.speaking;
      _speakingMsgIndex = idx;
      _pendingSpeakIdx = null;
    });
    _alwaysOnTick();

    try {
      await tts.speak(_ttsChunks[0]);
    } catch (e) {
      _onTtsDone();
    }
  }

  Future<void> _maybeAutoSpeak(GptChatMessage msg, int idx) async {
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

  // ── Always-on mic ──────────────────────────────────────────────────────────

  void _alwaysOnTick() {
    if (!_alwaysOnEnabled) {
      _setAlwaysOnState(_AlwaysOnState.off);
      return;
    }
    if (_ttsState == TtsState.speaking) {
      _setAlwaysOnState(_AlwaysOnState.waiting);
      return;
    }
    if (_typing) {
      _setAlwaysOnState(_AlwaysOnState.waiting);
      return;
    }
    _setAlwaysOnState(_AlwaysOnState.listening);
  }

  void _setAlwaysOnState(_AlwaysOnState next) {
    if (_alwaysOnState == next) return;
    if (mounted) setState(() => _alwaysOnState = next);
  }

  void _toggleAlwaysOn() {
    setState(() {
      _alwaysOnEnabled = !_alwaysOnEnabled;
      if (!_alwaysOnEnabled) _alwaysOnState = _AlwaysOnState.off;
    });
    if (_alwaysOnEnabled) {
      SchedulerBinding.instance
          .addPostFrameCallback((_) => _alwaysOnTick());
    }
  }

  // ── Language handling ──────────────────────────────────────────────────────

  void _onLanguageChanged(IndianLanguage lang) {
    if (lang.code == _selectedLanguage.code) return;
    _tts?.stop();
    setState(() {
      _selectedLanguage = lang;
      _ttsState = TtsState.idle;
      _speakingMsgIndex = -1;
    });
    for (final msg in _messages) {
      if (msg.role == AiChatRole.assistant && !msg.isStreaming) {
        _translateMessage(msg, lang);
      }
    }
  }

  Future<void> _translateMessage(
      GptChatMessage msg, IndianLanguage lang) async {
    if (lang.code == 'en') {
      setState(() {
        msg.translatedText = null;
        msg.translatedReports = null;
        msg.translatedToCode = null;
        msg.isTranslating = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => msg.isTranslating = true);
    try {
      final textResult =
          await _translator.translate(msg.text, to: lang.code);
      final translated = textResult.text.trim();
      if (!mounted) return;
      setState(() {
        msg.translatedText = translated;
        msg.translatedToCode = lang.code;
      });
      if (msg.analysisReports.isNotEmpty) {
        final translatedReports = <AnalysisReportSection>[];
        for (final report in msg.analysisReports) {
          final markdown = report.markdown.trim();
          if (markdown.isEmpty) {
            translatedReports.add(report);
            continue;
          }
          try {
            final transReport =
                await _translator.translate(markdown, to: lang.code);
            translatedReports.add(AnalysisReportSection(
              title: report.title,
              markdown: transReport.text,
              fieldKey: report.fieldKey,
            ));
          } catch (e) {
            translatedReports.add(report);
          }
        }
        if (!mounted) return;
        setState(() => msg.translatedReports = translatedReports);
      }
    } catch (e) {
      debugPrint('Translation error: $e');
    } finally {
      if (!mounted) return;
      setState(() => msg.isTranslating = false);
    }
  }

  // ── Tool / action handlers ─────────────────────────────────────────────────

  Future<void> _onToolSelected(GptToolAction action) async {
    switch (action) {
      case GptToolAction.stockAnalysis:
        final symbol = await showStockAnalysisDialog(context);
        if (symbol != null && mounted) {
          setState(
              () => _analysisStockSymbol = normalizeStockSymbol(symbol));
        }
        break;
      case GptToolAction.bestStocks:
        await _startBestStocksFlow();
        break;
      case GptToolAction.sebiAdvisor:
        await _send(
            'How do I find and verify a SEBI-registered investment advisor in India?');
        break;
    }
  }

  // ── Best Stocks flow ───────────────────────────────────────────────────────

  Future<void> _startBestStocksFlow() async {
    await showBestStocksCapDialog(
      context,
      onSelected: (cap) {
        if (!mounted) return;
        unawaited(_handleBestStocksCapSelected(cap));
      },
    );
  }

  Future<void> _handleBestStocksCapSelected(BestStocksCapType cap) async {
    try {
      _prepareBestStocksChat(cap);
      final cached = await BestStocksCache.load(cap);
      if (!mounted) return;
      await _runBestStocksScan(cap, skipPrepare: true, cached: cached);
    } catch (e) {
      if (!mounted) return;
      final idx = _messages.length - 1;
      if (idx >= 0 && _messages[idx].role == AiChatRole.assistant) {
        _failBestStocks(idx, 'Could not start stock scan: $e');
      }
    }
  }

  void _prepareBestStocksChat(BestStocksCapType cap) {
    _analysisCancel?.cancel();
    setState(() {
      _typing = true;
      _messages.add(GptChatMessage(
          role: AiChatRole.user,
          text: 'Get best stocks — ${cap.label}'));
      _messages.add(GptChatMessage(
          role: AiChatRole.assistant,
          isStreaming: true,
          bestStocksCapLabel: cap.label));
    });
    _alwaysOnTick();
    scrollChatToBottom(_scroll);
  }

  void _applyCachedBestStocks(
      BestStocksCapType cap, BestStocksCachePayload cached) {
    setState(() {
      _typing = false;
      final assistant = _messages.last;
      if (assistant.role == AiChatRole.assistant) {
        assistant.isStreaming = false;
        assistant.text =
            'Found **${cached.totalGoodStocks}** stocks matching your filters.';
        assistant.matchedStocks = cached.stocks;
        assistant.bestStocksFromCache = true;
        assistant.bestStocksCapLabel = cap.label;
        assistant.stepLog.clear();
      }
    });
    scrollChatToBottom(_scroll);
    _alwaysOnTick();
  }

  Future<void> _runBestStocksScan(
    BestStocksCapType cap, {
    bool skipPrepare = false,
    BestStocksCachePayload? cached,
  }) async {
    if (!skipPrepare) {
      if (_typing) return;
      _prepareBestStocksChat(cap);
    }
    _analysisCancel?.cancel();
    _analysisCancel = CancelToken();
    final assistantIdx = _messages.length - 1;
    BestStocksCachePayload? toCache;

    try {
      await for (final event in _filterDio.streamFilter(
          capType: cap.apiValue, cancelToken: _analysisCancel)) {
        if (!mounted) return;
        applyBestStocksStreamEvent(_messages[assistantIdx], event);
        if (event.isCompleted) {
          final stocks =
              _messages[assistantIdx].matchedStocks ?? event.goodStocks;
          toCache = BestStocksCachePayload(
            capType: cap,
            savedAt: DateTime.now(),
            totalGoodStocks: event.totalGoodStocks ?? stocks.length,
            stocks: stocks,
          );
        }
        setState(() {});
        scrollChatToBottom(_scroll, animated: false, layoutFrames: 2);
        await Future<void>.delayed(Duration.zero);
      }
      if (!mounted) return;
      setState(() {
        final assistant = _messages[assistantIdx];
        finalizeBestStocksMessage(assistant);
        assistant.isStreaming = false;
        _typing = false;
      });
      _alwaysOnTick();
      if (toCache != null) {
        try {
          await BestStocksCache.save(toCache);
        } catch (_) {}
      }
      try {
        await Get.find<AiUsageController>().fetchUsage();
      } catch (_) {}
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.type == DioExceptionType.cancel) return;
      _failBestStocks(assistantIdx, e.message ?? 'Request failed.');
    } on PennyStockFilterLimitException catch (e) {
      if (!mounted) return;
      await BestStocksCache.save(BestStocksCachePayload(
          capType: cap,
          savedAt: DateTime(2000),
          totalGoodStocks: 0,
          stocks: const []));
      try {
        await Get.find<AiUsageController>().fetchUsage();
      } catch (_) {}
      _showLimitDialog(e.message);
      setState(() {
        if (_messages.isNotEmpty &&
            _messages.last.role == AiChatRole.assistant)
          _messages.removeLast();
        if (_messages.isNotEmpty &&
            _messages.last.role == AiChatRole.user) _messages.removeLast();
        _typing = false;
      });
      _alwaysOnTick();
    } on PennyStockFilterException catch (e) {
      if (!mounted) return;
      if (cached != null && cached.stocks.isNotEmpty) {
        _applyCachedBestStocks(cap, cached);
        return;
      }
      _failBestStocks(assistantIdx, e.message);
    } catch (e) {
      if (!mounted) return;
      if (cached != null && cached.stocks.isNotEmpty) {
        _applyCachedBestStocks(cap, cached);
        return;
      }
      _failBestStocks(assistantIdx, 'Unexpected error: $e');
    }
    scrollChatToBottom(_scroll);
  }

  void _showLimitDialog(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.lock_outline_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Limit Reached'),
        ]),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'))
        ],
      ),
    );
  }

  void _failBestStocks(int assistantIdx, String error) {
    setState(() {
      _messages[assistantIdx].isStreaming = false;
      _messages[assistantIdx].text = error;
      _typing = false;
    });
    _alwaysOnTick();
  }

  void _openMatchedStockDetails(FilteredStock stock) {
    unawaited(openStockDetails(
      context,
      symbol: stock.symbol,
      companyName: stock.name,
      initialPrice: stock.price,
      initialChangePercent: stock.change52w ?? 0,
    ));
  }

  void _prepareMatchedStockForAnalysis(FilteredStock stock) {
    if (_typing) return;
    setState(() {
      _analysisStockSymbol = normalizeStockSymbol(stock.symbol);
      _input.clear();
    });
    scrollChatToBottom(_scroll, animated: false, layoutFrames: 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inputFocus.requestFocus();
    });
  }

  // ── Stock analysis streaming ───────────────────────────────────────────────

  Future<void> _runStockAnalysis({
    required String stockSymbol,
    required String prompt,
  }) async {
    if (_typing) return;
    _analysisCancel?.cancel();
    _analysisCancel = CancelToken();
    final symbol = apiStockSymbol(stockSymbol);
    final apiPrompt = buildStockAnalysisPrompt(
        symbol: symbol,
        displayName: displayStockSymbol(symbol),
        userPrompt: prompt);
    final userLabel = '${displayStockSymbol(symbol)}: $prompt';

    setState(() {
      _typing = true;
      _messages.add(GptChatMessage(role: AiChatRole.user, text: userLabel));
      _messages.add(
          GptChatMessage(role: AiChatRole.assistant, isStreaming: true));
    });
    _alwaysOnTick();
    _autoScroll();
    final assistantIdx = _messages.length - 1;

    try {
      await for (final event in streamAnalysisWithRetry(
          _analysisDio,
          stockSymbol: symbol,
          prompt: apiPrompt,
          cancelToken: _analysisCancel)) {
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
      _alwaysOnTick();
      if (_selectedLanguage.code != 'en') {
        await _translateMessage(_messages[assistantIdx], _selectedLanguage);
      }
      await _maybeAutoSpeak(_messages[assistantIdx], assistantIdx);
      if (_isMuted) _alwaysOnTick();
      try {
        await Get.find<AiUsageController>().fetchUsage();
      } catch (_) {}
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.type == DioExceptionType.cancel) return;
      _failAnalysis(assistantIdx, e.message ?? 'Request failed.');
    } on AiAnalysisException catch (e) {
      if (!mounted) return;
      try {
        await Get.find<AiUsageController>().fetchUsage();
      } catch (_) {}
      _failAnalysis(assistantIdx, e.message);
    } catch (e) {
      if (!mounted) return;
      _failAnalysis(assistantIdx, 'Unexpected error: $e');
    }
    _autoScroll();
  }

  void _failAnalysis(int assistantIdx, String error) {
    setState(() {
      final a = _messages[assistantIdx];
      a.isStreaming = false;
      final alreadyErrored =
          a.text.contains('Analysis could not be completed') ||
              a.text.contains('Connection lost');
      if (!alreadyErrored) a.text = formatAiAnalysisErrorMessage(error);
      _typing = false;
    });
    _alwaysOnTick();
  }

  // ── Normal chat ────────────────────────────────────────────────────────────

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty || _typing) return;
    _handleUserTap();

    var symbol = _analysisStockSymbol;
    var prompt = text;
    final prefixed = parseSymbolPrefixPrompt(text);
    if (prefixed != null) {
      symbol = prefixed.symbol;
      prompt = prefixed.prompt;
    }

    if (symbol != null && symbol.isNotEmpty) {
      final normalized = apiStockSymbol(symbol);
      _input.clear();
      setState(() => _analysisStockSymbol = normalized);
      await _runStockAnalysis(stockSymbol: normalized, prompt: prompt);
      return;
    }

    _analysisCancel?.cancel();
    _analysisCancel = CancelToken();
    final cancelToken = _analysisCancel;

    setState(() {
      _messages.add(GptChatMessage(role: AiChatRole.user, text: text));
      _input.clear();
      _typing = true;
    });
    _alwaysOnTick();
    _autoScroll();

    try {
      final reply =
          await _normalChatDio.chat(prompt: text, cancelToken: cancelToken);
      if (!mounted) return;
      final assistantMessage =
          GptChatMessage(role: AiChatRole.assistant, text: reply);
      final msgIdx = _messages.length;
      setState(() {
        _messages.add(assistantMessage);
        _typing = false;
      });
      _alwaysOnTick();
      if (_selectedLanguage.code != 'en') {
        unawaited(_translateMessage(assistantMessage, _selectedLanguage));
      }
      await _maybeAutoSpeak(assistantMessage, msgIdx);
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
    _autoScroll();
  }

  void _addError(String text) {
    setState(() {
      _messages
          .add(GptChatMessage(role: AiChatRole.assistant, text: text));
      _typing = false;
    });
    _alwaysOnTick();
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Get.back();
    } else {
      Get.offAllNamed(AppRoutes.dashboard);
    }
  }

  void _resetChat() {
    _tts?.stop();
    setState(() {
      _messages.clear();
      _typing = false;
      _analysisStockSymbol = null;
      _input.clear();
      _ttsState = TtsState.idle;
      _speakingMsgIndex = -1;
    });
    _alwaysOnTick();
  }

  void _stopGeneration() {
    _analysisCancel?.cancel();
    _analysisCancel = null;
    if (!mounted) return;
    setState(() {
      _typing = false;
      if (_messages.isNotEmpty &&
          _messages.last.role == AiChatRole.assistant &&
          _messages.last.text.trim().isEmpty &&
          _messages.last.analysisReports.isEmpty &&
          !_messages.last.hasBestStocksResults) {
        _messages.removeLast();
      }
    });
    _alwaysOnTick();
  }

  void _autoScroll() => scrollChatToBottom(_scroll);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const NetworkOfflineBanner(),
        Expanded(
          child: PopScope(
            canPop: Navigator.of(context).canPop(),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _goBack();
            },
            child: Scaffold(
              backgroundColor: AppColors.white,
              body: SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _handleUserTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Web "tap to hear" banner
                      if (kIsWeb &&
                          _pendingSpeakIdx != null &&
                          !_isMuted)
                        _WebSpeakUnlockBanner(
                            onTap: _handleUserTap),

                      _GptSubHeader(
                        onBack: _goBack,
                        onNewChat: _resetChat,
                        selectedLanguage: _selectedLanguage,
                        onLanguageChanged: _onLanguageChanged,
                        isMuted: _isMuted,
                        onMuteToggled: () {
                          setState(() => _isMuted = !_isMuted);
                          if (_isMuted) _tts?.stop();
                        },
                        alwaysOnEnabled: _alwaysOnEnabled,
                        alwaysOnState: _alwaysOnState,
                        onAlwaysOnToggled: _toggleAlwaysOn,
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            if (_showConversation)
                              _GptConversationBody(
                                messages: _messages,
                                showTypingDots: _showTypingDots,
                                scrollController: _scroll,
                                input: _input,
                                analysisSymbol: _analysisStockSymbol,
                                onClearAnalysisSymbol: () => setState(
                                    () => _analysisStockSymbol = null),
                                onSend: _send,
                                onStop: _stopGeneration,
                                onToolSelected: _onToolSelected,
                                enabled: !_typing,
                                onOpenMatchedStockDetails:
                                    _openMatchedStockDetails,
                                onAnalyzeMatchedStock:
                                    _prepareMatchedStockForAnalysis,
                                inputFocus: _inputFocus,
                                selectedLanguage: _selectedLanguage,
                                translator: _translator,
                                // TTS props
                                ttsAvailable: _ttsAvailable,
                                ttsState: _ttsState,
                                speakingMsgIndex: _speakingMsgIndex,
                                pendingSpeakIdx: _pendingSpeakIdx,
                                isMuted: _isMuted,
                                onSpeak: _speakMessage,
                                alwaysOnState: _alwaysOnState,
                              ),
                            if (_showLanding)
                              _GptLandingBody(
                                input: _input,
                                analysisSymbol: _analysisStockSymbol,
                                onClearAnalysisSymbol: () => setState(
                                    () => _analysisStockSymbol = null),
                                quickActions: _quickActions,
                                onSend: _send,
                                onStop: _stopGeneration,
                                onToolSelected: _onToolSelected,
                                enabled: !_typing,
                                selectedLanguage: _selectedLanguage,
                                translator: _translator,
                                alwaysOnState: _alwaysOnState,
                              ),
                          ],
                        ),
                      ),
                      AiChatDisclaimerFooter(
                        padding: EdgeInsets.fromLTRB(
                          Responsive.value(context,
                              mobile: 16.0, tablet: 24.0, desktop: 32.0),
                          8,
                          Responsive.value(context,
                              mobile: 16.0, tablet: 24.0, desktop: 32.0),
                          Responsive.isMobile(context) ? 14 : 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Web speak-unlock banner ────────────────────────────────────────────────────

class _WebSpeakUnlockBanner extends StatelessWidget {
  const _WebSpeakUnlockBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.lightblue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.lightblue.withValues(alpha: 0.45)),
        ),
        child: Row(children: [
          Icon(Icons.volume_up_rounded,
              size: 15, color: AppColors.lightblue),
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
          Icon(Icons.touch_app_rounded,
              size: 15, color: AppColors.lightblue),
        ]),
      ),
    );
  }
}

// ── Sub-header (with TTS controls added) ─────────────────────────────────────

class _GptSubHeader extends StatelessWidget {
  const _GptSubHeader({
    required this.onBack,
    required this.onNewChat,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isMuted,
    required this.onMuteToggled,
    required this.alwaysOnEnabled,
    required this.alwaysOnState,
    required this.onAlwaysOnToggled,
  });

  final VoidCallback onBack;
  final VoidCallback onNewChat;
  final IndianLanguage selectedLanguage;
  final ValueChanged<IndianLanguage> onLanguageChanged;
  final bool isMuted;
  final VoidCallback onMuteToggled;
  final bool alwaysOnEnabled;
  final _AlwaysOnState alwaysOnState;
  final VoidCallback onAlwaysOnToggled;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final usageController = Get.find<AiUsageController>();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.value(context,
            mobile: 16.0, tablet: 20.0, desktop: 24.0),
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
            bottom: BorderSide(
                color: AppColors.lightWhite.withValues(alpha: 0.95))),
      ),
      child: compact
          ? _buildMobileHeader(context, usageController)
          : isTablet
              ? _buildTabletHeader(context, usageController)
              : _buildDesktopHeader(context, usageController),
    );
  }

  Widget _buildDesktopHeader(
      BuildContext context, AiUsageController usageController) {
    return Row(children: [
      _GptBackButton(onPressed: onBack, compact: false),
      const SizedBox(width: 4),
      _titleMenu(context, compact: false),
      const Spacer(),
      GptLanguageDropdown(
          selected: selectedLanguage, onChanged: onLanguageChanged),
      const SizedBox(width: 10),
      _GptAlwaysOnMicButton(
          state: alwaysOnState,
          isEnabled: alwaysOnEnabled,
          onTap: onAlwaysOnToggled),
      const SizedBox(width: 6),
      _GptMuteButton(isMuted: isMuted, onTap: onMuteToggled),
      const SizedBox(width: 12),
      _planPill(context, usageController, compact: false),
    ]);
  }

  Widget _buildTabletHeader(
      BuildContext context, AiUsageController usageController) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            _GptBackButton(onPressed: onBack, compact: true),
            const SizedBox(width: 4),
            _titleMenu(context, compact: true),
            const Spacer(),
            _planPill(context, usageController, compact: true),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            GptLanguageDropdown(
                selected: selectedLanguage, onChanged: onLanguageChanged),
            const SizedBox(width: 8),
            _GptAlwaysOnMicButton(
                state: alwaysOnState,
                isEnabled: alwaysOnEnabled,
                onTap: onAlwaysOnToggled),
            const SizedBox(width: 6),
            _GptMuteButton(isMuted: isMuted, onTap: onMuteToggled),
          ]),
        ]);
  }

  Widget _buildMobileHeader(
      BuildContext context, AiUsageController usageController) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            _GptBackButton(onPressed: onBack, compact: true),
            const SizedBox(width: 4),
            _titleMenu(context, compact: true),
            const Spacer(),
            _GptAlwaysOnMicButton(
                state: alwaysOnState,
                isEnabled: alwaysOnEnabled,
                onTap: onAlwaysOnToggled),
            const SizedBox(width: 6),
            _GptMuteButton(isMuted: isMuted, onTap: onMuteToggled),
            const SizedBox(width: 8),
            _planPill(context, usageController, compact: true),
          ]),
        ]);
  }

  Widget _titleMenu(BuildContext context, {required bool compact}) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'new') onNewChat();
      },
      itemBuilder: (context) =>
          [const PopupMenuItem(value: 'new', child: Text('New chat'))],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          'Stocbuy',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 14 : 15,
                color: const Color(0xFF111827),
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down_rounded,
            size: compact ? 20 : 22, color: const Color(0xFF374151)),
      ]),
    );
  }

  Widget _planPill(BuildContext context, AiUsageController usageController,
      {required bool compact}) {
    return Obx(() {
      final usage = usageController.usage.value;
      final isExhausted =
          usage != null && !usage.isUnlimited && usage.remaining <= 0;
      final planLabel = usage == null
          ? 'Free Plan'
          : usage.isUnlimited
              ? 'Unlimited'
              : usage.plan == 'premium'
                  ? 'Premium'
                  : 'Free Plan';
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                isExhausted
                    ? Icons.lock_outline_rounded
                    : Icons.card_giftcard_outlined,
                size: compact ? 16 : 17,
                color: isExhausted ? AppColors.red : AppColors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                isExhausted ? 'Limit reached' : planLabel,
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 12 : 13,
                          color:
                              isExhausted ? AppColors.red : AppColors.grey,
                        ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

// ── Always-on mic button (ported from stock_ai_chat.dart) ─────────────────────

class _GptAlwaysOnMicButton extends StatelessWidget {
  const _GptAlwaysOnMicButton(
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: border, width: isEnabled ? 1.4 : 1.0),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg)),
        ]),
      ),
    );
  }
}

// ── Mute button (ported from stock_ai_chat.dart) ──────────────────────────────

class _GptMuteButton extends StatelessWidget {
  const _GptMuteButton({required this.isMuted, required this.onTap});
  final bool isMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMuted
                ? Colors.red.withValues(alpha: 0.12)
                : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isMuted
                    ? Colors.red.withValues(alpha: 0.45)
                    : AppColors.border),
          ),
          child: Icon(
              isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              size: 16,
              color: isMuted ? Colors.red : AppColors.grey),
        ),
      );
}


// ── Back button ────────────────────────────────────────────────────────────────

class _GptBackButton extends StatefulWidget {
  const _GptBackButton(
      {required this.onPressed, required this.compact});
  final VoidCallback onPressed;
  final bool compact;

  @override
  State<_GptBackButton> createState() => _GptBackButtonState();
}

class _GptBackButtonState extends State<_GptBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 36.0 : 38.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: 'Back',
        child: Material(
          color: _hover ? AppColors.surfaceMuted : Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(10),
            hoverColor: Colors.transparent,
            splashColor:
                AppColors.lightblue.withValues(alpha: 0.1),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(Icons.arrow_back_rounded,
                  size: widget.compact ? 22 : 24,
                  color: const Color(0xFF111827)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Landing (empty state) ─────────────────────────────────────────────────────

class _GptLandingBody extends StatelessWidget {
  const _GptLandingBody({
    required this.input,
    required this.analysisSymbol,
    required this.onClearAnalysisSymbol,
    required this.quickActions,
    required this.onSend,
    required this.onStop,
    required this.onToolSelected,
    required this.enabled,
    required this.selectedLanguage,
    required this.translator,
    required this.alwaysOnState,
  });

  final TextEditingController input;
  final String? analysisSymbol;
  final VoidCallback onClearAnalysisSymbol;
  final List<_GptQuickAction> quickActions;
  final Future<void> Function([String?]) onSend;
  final VoidCallback onStop;
  final Future<void> Function(GptToolAction) onToolSelected;
  final bool enabled;
  final IndianLanguage selectedLanguage;
  final GoogleTranslator translator;
  final _AlwaysOnState alwaysOnState;

  @override
  Widget build(BuildContext context) {
    final maxW = Responsive.value(context,
        mobile: double.infinity, tablet: 640.0, desktop: 720.0);
    final hPad = Responsive.value(context,
        mobile: 20.0, tablet: 32.0, desktop: 24.0);
    final headlineSize = Responsive.value(context,
        mobile: 26.0, tablet: 30.0, desktop: 34.0);

    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      height: Responsive.value(context,
                          mobile: 48.0, tablet: 72.0, desktop: 96.0)),
                  Text(
                    'Where should we begin?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: headlineSize,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0A0A0A),
                      letterSpacing: -0.8,
                      height: 1.15,
                    ),
                  ),
                  // Always-on state pill (landing page)
                  if (alwaysOnState != _AlwaysOnState.off) ...[
                    const SizedBox(height: 12),
                    _AlwaysOnStatusPill(state: alwaysOnState),
                  ],
                  SizedBox(
                      height: Responsive.value(context,
                          mobile: 28.0, tablet: 32.0, desktop: 36.0)),
                  if (analysisSymbol != null)
                    GptStockSymbolBar(
                        symbol: analysisSymbol!,
                        onClear: onClearAnalysisSymbol),
                  GptInputBar(
                    controller: input,
                    onSend: () => onSend(),
                    onStop: onStop,
                    onToolSelected: onToolSelected,
                    enabled: enabled,
                    selectedLanguage: selectedLanguage,
                    translator: translator,
                    onVoiceSend: (text) => onSend(text),
                    autofocus: Responsive.isDesktop(context),
                    hintText: analysisSymbol != null
                        ? 'e.g. analysis this stock'
                        : 'Ask anything',
                  ),
                  const SizedBox(height: 20),
                  _GptQuickActionRow(
                      actions: quickActions,
                      onToolSelected: onToolSelected),
                  SizedBox(
                      height: Responsive.value(context,
                          mobile: 40.0, tablet: 56.0, desktop: 72.0)),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ── Always-on status pill (reused on landing + input bar) ─────────────────────

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
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }
}

// ── Conversation body (TTS props threaded through) ───────────────────────────

class _GptConversationBody extends StatelessWidget {
  const _GptConversationBody({
    required this.messages,
    required this.showTypingDots,
    required this.scrollController,
    required this.input,
    required this.analysisSymbol,
    required this.onClearAnalysisSymbol,
    required this.onSend,
    required this.onStop,
    required this.onToolSelected,
    required this.enabled,
    required this.onOpenMatchedStockDetails,
    required this.onAnalyzeMatchedStock,
    required this.inputFocus,
    required this.selectedLanguage,
    required this.translator,
    // TTS
    required this.ttsAvailable,
    required this.ttsState,
    required this.speakingMsgIndex,
    required this.pendingSpeakIdx,
    required this.isMuted,
    required this.onSpeak,
    required this.alwaysOnState,
  });

  final List<GptChatMessage> messages;
  final bool showTypingDots;
  final ScrollController scrollController;
  final TextEditingController input;
  final FocusNode inputFocus;
  final String? analysisSymbol;
  final VoidCallback onClearAnalysisSymbol;
  final Future<void> Function([String?]) onSend;
  final VoidCallback onStop;
  final Future<void> Function(GptToolAction) onToolSelected;
  final bool enabled;
  final void Function(FilteredStock) onOpenMatchedStockDetails;
  final void Function(FilteredStock) onAnalyzeMatchedStock;
  final IndianLanguage selectedLanguage;
  final GoogleTranslator translator;
  // TTS
  final bool ttsAvailable;
  final TtsState ttsState;
  final int speakingMsgIndex;
  final int? pendingSpeakIdx;
  final bool isMuted;
  final Future<void> Function(GptChatMessage, int) onSpeak;
  final _AlwaysOnState alwaysOnState;

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.value(context,
        mobile: 16.0, tablet: 24.0, desktop: 32.0);
    final maxW = Responsive.value(context,
        mobile: double.infinity, tablet: 680.0, desktop: 768.0);

    return Column(
      children: [
        Expanded(
          child: GptChatMessageList(
            scrollController: scrollController,
            messages: messages,
            showTypingDots: showTypingDots,
            onOpenMatchedStockDetails: onOpenMatchedStockDetails,
            onAnalyzeMatchedStock: onAnalyzeMatchedStock,
            stockActionsEnabled: enabled,
            // TTS per-bubble props
            ttsAvailable: ttsAvailable,
            ttsState: ttsState,
            speakingMsgIndex: speakingMsgIndex,
            pendingSpeakIdx: pendingSpeakIdx,
            isMuted: isMuted,
            onSpeak: onSpeak,
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Always-on status pill above input
                  if (alwaysOnState != _AlwaysOnState.off)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        _AlwaysOnStatusPill(state: alwaysOnState)
                      ]),
                    ),
                  if (analysisSymbol != null)
                    GptStockSymbolBar(
                        symbol: analysisSymbol!,
                        onClear: onClearAnalysisSymbol),
                  GptInputBar(
                    controller: input,
                    focusNode: inputFocus,
                    onSend: () => onSend(),
                    onStop: onStop,
                    onToolSelected: onToolSelected,
                    enabled: enabled,
                    selectedLanguage: selectedLanguage,
                    translator: translator,
                    onVoiceSend: (text) => onSend(text),
                    hintText: analysisSymbol != null
                        ? 'e.g. analyse revenue, debt, and outlook'
                        : 'Ask anything',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Quick actions ──────────────────────────────────────────────────────────────

class _GptQuickActionRow extends StatelessWidget {
  const _GptQuickActionRow(
      {required this.actions, required this.onToolSelected});
  final List<_GptQuickAction> actions;
  final Future<void> Function(GptToolAction) onToolSelected;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in actions)
          _GptQuickChip(
            action: a,
            compact: mobile,
            onTap: () => unawaited(onToolSelected(a.toolAction)),
          ),
      ],
    );
  }
}

class _GptQuickChip extends StatefulWidget {
  const _GptQuickChip(
      {required this.action,
      required this.onTap,
      required this.compact});
  final _GptQuickAction action;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_GptQuickChip> createState() => _GptQuickChipState();
}

class _GptQuickChipState extends State<_GptQuickChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(999),
          hoverColor: AppColors.surfaceMuted,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 14 : 16,
                vertical: widget.compact ? 9 : 10),
            decoration: BoxDecoration(
              color: _hover ? AppColors.surfaceMuted : AppColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: _hover
                      ? AppColors.border
                      : AppColors.lightWhite),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.action.icon,
                  size: widget.compact ? 15 : 16,
                  color: const Color(0xFF111827)),
              const SizedBox(width: 8),
              Text(
                widget.action.label,
                style: TextStyle(
                  fontSize: widget.compact ? 12.5 : 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                  letterSpacing: -0.1,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _GptQuickAction {
  const _GptQuickAction(
      {required this.label,
      required this.icon,
      required this.toolAction});
  final String label;
  final IconData icon;
  final GptToolAction toolAction;
}