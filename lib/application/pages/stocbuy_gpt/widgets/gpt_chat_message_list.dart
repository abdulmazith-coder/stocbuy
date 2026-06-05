import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/gpt_chat_message.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_message_bubble.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_scroll_behavior.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_scroll_to_bottom_button.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/filtered_stock.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/tts_speak.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat.dart'
    show AiChatRole;
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/ai_chat_bubbles.dart';

class GptChatMessageList extends StatefulWidget {
  const GptChatMessageList({
    super.key,
    required this.scrollController,
    required this.messages,
    required this.showTypingDots,
    required this.onOpenMatchedStockDetails,
    required this.onAnalyzeMatchedStock,
    required this.stockActionsEnabled,
    // TTS props — all optional with safe defaults
    this.ttsAvailable = false,
    this.ttsState = TtsState.idle,
    this.speakingMsgIndex = -1,
    this.pendingSpeakIdx,
    this.isMuted = false,
    this.onSpeak,
  });

  final ScrollController scrollController;
  final List<GptChatMessage> messages;
  final bool showTypingDots;
  final void Function(FilteredStock stock) onOpenMatchedStockDetails;
  final void Function(FilteredStock stock) onAnalyzeMatchedStock;
  final bool stockActionsEnabled;

  // TTS
  final bool ttsAvailable;
  final TtsState ttsState;
  final int speakingMsgIndex;
  final int? pendingSpeakIdx;
  final bool isMuted;
  final Future<void> Function(GptChatMessage msg, int idx)? onSpeak;

  @override
  State<GptChatMessageList> createState() => _GptChatMessageListState();
}

class _GptChatMessageListState extends State<GptChatMessageList> {
  static const _awayThreshold = 100.0;
  bool _showJumpToBottom = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(GptChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _updateJumpVisibility());
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => _updateJumpVisibility();

  void _updateJumpVisibility() {
    final c = widget.scrollController;
    if (!c.hasClients) return;
    final away =
        c.position.maxScrollExtent - c.position.pixels > _awayThreshold;
    if (away != _showJumpToBottom && mounted) {
      setState(() => _showJumpToBottom = away);
    }
  }

  // ── Per-bubble footer: translation badge + speak button ───────────────────

  Widget _buildBubbleFooter(GptChatMessage msg, int index) {
    final showSpeak = widget.ttsAvailable &&
        !widget.isMuted &&
        widget.onSpeak != null &&
        !msg.isStreaming;

    final isSpeaking = widget.ttsState == TtsState.speaking &&
        widget.speakingMsgIndex == index;

    final isPending =
        kIsWeb && widget.pendingSpeakIdx == index && !widget.isMuted;

    // Skip row entirely when there is nothing to render
    if (!msg.isTranslating &&
        msg.translatedText == null &&
        msg.translatedReports == null &&
        !showSpeak) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Translating spinner
          if (msg.isTranslating) ...[
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: AppColors.grey),
            ),
            const SizedBox(width: 5),
            const Text(
              'Translating…',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.grey,
                  fontWeight: FontWeight.w500),
            ),
          ],

          // Translated badge
          if (!msg.isTranslating &&
              (msg.translatedText != null ||
                  msg.translatedReports != null)) ...[
            const Icon(Icons.translate_rounded,
                size: 10, color: AppColors.grey),
            const SizedBox(width: 4),
            const Text(
              'Translated',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.grey,
                  fontWeight: FontWeight.w500),
            ),
          ],

          // Speak button
          if (showSpeak) ...[
            if (msg.isTranslating ||
                (!msg.isTranslating &&
                    (msg.translatedText != null ||
                        msg.translatedReports != null)))
              const SizedBox(width: 8),
            GptSpeakButton(
              isSpeaking: isSpeaking,
              isPending: isPending,
              onTap: () => widget.onSpeak!(msg, index),
            ),
          ],
        ],
      ),
    );
  }

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

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ScrollConfiguration(
              behavior: const GptScrollBehavior(),
              child: ListView.builder(
                controller: widget.scrollController,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 56),
                itemCount: widget.messages.length +
                    (widget.showTypingDots ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == widget.messages.length &&
                      widget.showTypingDots) {
                    return const StocbuyThinkingIndicator();
                  }

                  final msg = widget.messages[i];

                  // Assistant bubbles get speak button + translation badge
                  if (msg.role == AiChatRole.assistant) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GptMessageBubble(
                          message: msg,
                          onOpenMatchedStockDetails:
                              widget.onOpenMatchedStockDetails,
                          onAnalyzeMatchedStock:
                              widget.onAnalyzeMatchedStock,
                          stockActionsEnabled:
                              widget.stockActionsEnabled,
                        ),
                        _buildBubbleFooter(msg, i),
                      ],
                    );
                  }

                  // User bubbles — unchanged
                  return GptMessageBubble(
                    message: msg,
                    onOpenMatchedStockDetails:
                        widget.onOpenMatchedStockDetails,
                    onAnalyzeMatchedStock: widget.onAnalyzeMatchedStock,
                    stockActionsEnabled: widget.stockActionsEnabled,
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: GptScrollToBottomButton(
                scrollController: widget.scrollController,
                visible: _showJumpToBottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}