import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/ai_usage_controller.dart';
import 'package:stocbuy_application/application/models/analysis_report_section.dart';
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
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_error_message.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_prompt.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_run.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_stream_apply.dart';
import 'package:stocbuy_application/application/utils/chat_auto_scroll.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/ai_chat_bubbles.dart';
import 'package:stocbuy_application/application/widgets/network_offline_banner.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(BestStocksCache.clearExpired());
  }

  @override
  void dispose() {
    _analysisCancel?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _showTypingDots {
    if (!_typing) return false;
    if (_messages.isEmpty) return true;
    final last = _messages.last;
    return last.role == AiChatRole.user;
  }

  Future<void> _onToolSelected(GptToolAction action) async {
    switch (action) {
      case GptToolAction.stockAnalysis:
        final symbol = await showStockAnalysisDialog(context);
        if (symbol != null && mounted) {
          setState(() {
            _analysisStockSymbol = normalizeStockSymbol(symbol);
          });
        }
        break;
      case GptToolAction.bestStocks:
        await _startBestStocksFlow();
        break;
      case GptToolAction.sebiAdvisor:
        await _send(
          'How do I find and verify a SEBI-registered investment advisor in India?',
        );
        break;
    }
  }

  // ── Language handling ────────────────────────────────────────────────────

  void _onLanguageChanged(IndianLanguage lang) {
    if (lang.code == _selectedLanguage.code) return;
    setState(() => _selectedLanguage = lang);
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
      final textResult = await _translator.translate(msg.text, to: lang.code);
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
            final transReport = await _translator.translate(
              markdown,
              to: lang.code,
            );
            translatedReports.add(
              AnalysisReportSection(
                title: report.title,
                markdown: transReport.text,
                fieldKey: report.fieldKey,
              ),
            );
          } catch (e) {
            debugPrint('Failed to translate report: $e');
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

  // ── Best Stocks flow ─────────────────────────────────────────────────────

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

      await _runBestStocksScan(
        cap,
        skipPrepare: true,
        cached: cached,
      );
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
      _messages.add(
        GptChatMessage(
          role: AiChatRole.user,
          text: 'Get best stocks — ${cap.label}',
        ),
      );
      _messages.add(
        GptChatMessage(
          role: AiChatRole.assistant,
          isStreaming: true,
          bestStocksCapLabel: cap.label,
        ),
      );
    });
    scrollChatToBottom(_scroll);
  }

  void _applyCachedBestStocks(
    BestStocksCapType cap,
    BestStocksCachePayload cached,
  ) {
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
        capType: cap.apiValue,
        cancelToken: _analysisCancel,
      )) {
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

      if (toCache != null) {
        try {
          await BestStocksCache.save(toCache);
        } catch (_) {}
      }

      // ── Refresh usage pill after filter completes ─────────────────────
      try {
        await Get.find<AiUsageController>().fetchUsage();
      } catch (_) {}

    } on DioException catch (e) {
      if (!mounted) return;
      if (e.type == DioExceptionType.cancel) return;
      _failBestStocks(assistantIdx, e.message ?? 'Request failed.');

    // ── 403 — no feature access / 429 — daily limit reached ──────────────
    } on PennyStockFilterLimitException catch (e) {
      if (!mounted) return;
      // Clear cache so stale data is never shown after limit is hit
      await BestStocksCache.save(
        BestStocksCachePayload(
          capType: cap,
          savedAt: DateTime(2000), // expired instantly
          totalGoodStocks: 0,
          stocks: const [],
        ),
      );
      // Refresh usage so navbar pill updates immediately
      try {
        await Get.find<AiUsageController>().fetchUsage();
      } catch (_) {}

      _showLimitDialog(e.message);
      // Remove the assistant + user bubble — nothing to show
      setState(() {
        if (_messages.isNotEmpty &&
            _messages.last.role == AiChatRole.assistant) {
          _messages.removeLast();
        }
        if (_messages.isNotEmpty &&
            _messages.last.role == AiChatRole.user) {
          _messages.removeLast();
        }
        _typing = false;
      });

    } on PennyStockFilterException catch (e) {
      if (!mounted) return;
      // Fall back to cache on generic error
      if (cached != null && cached.stocks.isNotEmpty) {
        _applyCachedBestStocks(cap, cached);
        return;
      }
      _failBestStocks(assistantIdx, e.message);
    } catch (e) {
      if (!mounted) return;
      // Fall back to cache on generic error
      if (cached != null && cached.stocks.isNotEmpty) {
        _applyCachedBestStocks(cap, cached);
        return;
      }
      _failBestStocks(assistantIdx, 'Unexpected error: $e');
    }
    scrollChatToBottom(_scroll);
  }

  // ── Show limit dialog ─────────────────────────────────────────────────
  void _showLimitDialog(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Limit Reached'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _failBestStocks(int assistantIdx, String error) {
    setState(() {
      final assistant = _messages[assistantIdx];
      assistant.isStreaming = false;
      assistant.text = error;
      _typing = false;
    });
  }

  void _openMatchedStockDetails(FilteredStock stock) {
    unawaited(
      openStockDetails(
        context,
        symbol: stock.symbol,
        companyName: stock.name,
        initialPrice: stock.price,
        initialChangePercent: stock.change52w ?? 0,
      ),
    );
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
      userPrompt: prompt,
    );
    final userLabel = '${displayStockSymbol(symbol)}: $prompt';

    setState(() {
      _typing = true;
      _messages.add(GptChatMessage(role: AiChatRole.user, text: userLabel));
      _messages.add(
        GptChatMessage(role: AiChatRole.assistant, isStreaming: true),
      );
    });
    _autoScroll();

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
        if (event.isError) {
          _messages[assistantIdx].isStreaming = false;
        }
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
        if (_selectedLanguage.code != 'en') {
          unawaited(_translateMessage(assistant, _selectedLanguage));
        }
        if (!analysisHasVisibleReport(assistant)) {
          assistant.text =
              'Analysis finished but no report text was returned.';
        }
        _typing = false;
      });

      // ── Refresh usage pill after analysis completes ───────────────────
      try {
        await Get.find<AiUsageController>().fetchUsage();
      } catch (_) {}

    } on DioException catch (e) {
      if (!mounted) return;
      if (e.type == DioExceptionType.cancel) return;
      _failAnalysis(assistantIdx, e.message ?? 'Request failed.');
    } on AiAnalysisException catch (e) {
      if (!mounted) return;
      // Refresh usage on limit error too
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
      final assistant = _messages[assistantIdx];
      assistant.isStreaming = false;
      final alreadyErrored =
          assistant.text.contains('Analysis could not be completed') ||
              assistant.text.contains('Connection lost');
      if (!alreadyErrored) {
        assistant.text = formatAiAnalysisErrorMessage(error);
      }
      _typing = false;
    });
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Get.back();
    } else {
      Get.offAllNamed(AppRoutes.dashboard);
    }
  }

  void _resetChat() {
    setState(() {
      _messages.clear();
      _typing = false;
      _analysisStockSymbol = null;
      _input.clear();
    });
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
  }

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty || _typing) return;

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
    _autoScroll();

    try {
      final reply = await _normalChatDio.chat(
        prompt: text,
        cancelToken: cancelToken,
      );
      if (!mounted) return;
      final assistantMessage = GptChatMessage(
        role: AiChatRole.assistant,
        text: reply,
      );
      setState(() {
        _messages.add(assistantMessage);
        _typing = false;
      });
      if (_selectedLanguage.code != 'en') {
        unawaited(_translateMessage(assistantMessage, _selectedLanguage));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.type == DioExceptionType.cancel) return;
      setState(() {
        _messages.add(
          GptChatMessage(
            role: AiChatRole.assistant,
            text: formatAiAnalysisErrorMessage(
                e.message ?? 'Request failed.'),
          ),
        );
        _typing = false;
      });
    } on NormalChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          GptChatMessage(
            role: AiChatRole.assistant,
            text: formatAiAnalysisErrorMessage(e.message),
          ),
        );
        _typing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          GptChatMessage(
            role: AiChatRole.assistant,
            text: formatAiAnalysisErrorMessage('Unexpected error: $e'),
          ),
        );
        _typing = false;
      });
    }
    _autoScroll();
  }

  void _autoScroll() => scrollChatToBottom(_scroll);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GptSubHeader(
                      onBack: _goBack,
                      onNewChat: _resetChat,
                      selectedLanguage: _selectedLanguage,
                      onLanguageChanged: _onLanguageChanged,
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
                                () => _analysisStockSymbol = null,
                              ),
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
                            ),
                          if (_showLanding)
                            _GptLandingBody(
                              input: _input,
                              analysisSymbol: _analysisStockSymbol,
                              onClearAnalysisSymbol: () => setState(
                                () => _analysisStockSymbol = null,
                              ),
                              quickActions: _quickActions,
                              onSend: _send,
                              onStop: _stopGeneration,
                              onToolSelected: _onToolSelected,
                              enabled: !_typing,
                              selectedLanguage: _selectedLanguage,
                              translator: _translator,
                            ),
                        ],
                      ),
                    ),
                    AiChatDisclaimerFooter(
                      padding: EdgeInsets.fromLTRB(
                        Responsive.value(
                          context,
                          mobile: 16.0,
                          tablet: 24.0,
                          desktop: 32.0,
                        ),
                        8,
                        Responsive.value(
                          context,
                          mobile: 16.0,
                          tablet: 24.0,
                          desktop: 32.0,
                        ),
                        Responsive.isMobile(context) ? 14 : 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-header ─────────────────────────────────────────────────────────────

class _GptSubHeader extends StatelessWidget {
  const _GptSubHeader({
    required this.onBack,
    required this.onNewChat,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  final VoidCallback onBack;
  final VoidCallback onNewChat;
  final IndianLanguage selectedLanguage;
  final ValueChanged<IndianLanguage> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isMobile(context);
    final usageController = Get.find<AiUsageController>();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.value(
          context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        ),
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.lightWhite.withValues(alpha: 0.95),
          ),
        ),
      ),
      child: Row(
        children: [
          _GptBackButton(onPressed: onBack, compact: compact),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            offset: const Offset(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'new') onNewChat();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new',
                child: Text('New chat'),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: compact ? 20 : 22,
                  color: const Color(0xFF374151),
                ),
              ],
            ),
          ),
          const Spacer(),
          GptLanguageDropdown(
            selected: selectedLanguage,
            onChanged: onLanguageChanged,
          ),
          const SizedBox(width: 12),

          // ── Plan pill — reads live from AiUsageController ─────────────
          Obx(() {
            final usage = usageController.usage.value;
            final isExhausted = usage != null &&
                !usage.isUnlimited &&
                usage.remaining <= 0;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                                  color: isExhausted
                                      ? AppColors.red
                                      : AppColors.grey,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Back button ────────────────────────────────────────────────────────────

class _GptBackButton extends StatefulWidget {
  const _GptBackButton({
    required this.onPressed,
    required this.compact,
  });

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
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(10),
            hoverColor: Colors.transparent,
            splashColor: AppColors.lightblue.withValues(alpha: 0.1),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                Icons.arrow_back_rounded,
                size: widget.compact ? 22 : 24,
                color: const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Landing (empty state) ──────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final maxW = Responsive.value(
      context,
      mobile: double.infinity,
      tablet: 640.0,
      desktop: 720.0,
    );
    final hPad = Responsive.value(
      context,
      mobile: 20.0,
      tablet: 32.0,
      desktop: 24.0,
    );
    final headlineSize = Responsive.value(
      context,
      mobile: 26.0,
      tablet: 30.0,
      desktop: 34.0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: Responsive.value(
                        context,
                        mobile: 48.0,
                        tablet: 72.0,
                        desktop: 96.0,
                      ),
                    ),
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
                    SizedBox(
                      height: Responsive.value(
                        context,
                        mobile: 28.0,
                        tablet: 32.0,
                        desktop: 36.0,
                      ),
                    ),
                    if (analysisSymbol != null)
                      GptStockSymbolBar(
                        symbol: analysisSymbol!,
                        onClear: onClearAnalysisSymbol,
                      ),
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
                      onToolSelected: onToolSelected,
                    ),
                    SizedBox(
                      height: Responsive.value(
                        context,
                        mobile: 40.0,
                        tablet: 56.0,
                        desktop: 72.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Conversation ───────────────────────────────────────────────────────────

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
  final void Function(FilteredStock stock) onOpenMatchedStockDetails;
  final void Function(FilteredStock stock) onAnalyzeMatchedStock;
  final IndianLanguage selectedLanguage;
  final GoogleTranslator translator;

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.value(
      context,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );
    final maxW = Responsive.value(
      context,
      mobile: double.infinity,
      tablet: 680.0,
      desktop: 768.0,
    );

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
                  if (analysisSymbol != null)
                    GptStockSymbolBar(
                      symbol: analysisSymbol!,
                      onClear: onClearAnalysisSymbol,
                    ),
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

// ── Quick actions ─────────────────────────────────────────────────────────

class _GptQuickActionRow extends StatelessWidget {
  const _GptQuickActionRow({
    required this.actions,
    required this.onToolSelected,
  });

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
  const _GptQuickChip({
    required this.action,
    required this.onTap,
    required this.compact,
  });

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
              vertical: widget.compact ? 9 : 10,
            ),
            decoration: BoxDecoration(
              color: _hover ? AppColors.surfaceMuted : AppColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _hover ? AppColors.border : AppColors.lightWhite,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.action.icon,
                  size: widget.compact ? 15 : 16,
                  color: const Color(0xFF111827),
                ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────

class _GptQuickAction {
  const _GptQuickAction({
    required this.label,
    required this.icon,
    required this.toolAction,
  });

  final String label;
  final IconData icon;
  final GptToolAction toolAction;
}