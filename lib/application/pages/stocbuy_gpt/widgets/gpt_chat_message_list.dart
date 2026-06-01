import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/gpt_chat_message.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_message_bubble.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_scroll_behavior.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_scroll_to_bottom_button.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/filtered_stock.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
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
  });

  final ScrollController scrollController;
  final List<GptChatMessage> messages;
  final bool showTypingDots;
  final void Function(FilteredStock stock) onOpenMatchedStockDetails;
  final void Function(FilteredStock stock) onAnalyzeMatchedStock;
  final bool stockActionsEnabled;

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateJumpVisibility());
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
    final away = c.position.maxScrollExtent - c.position.pixels > _awayThreshold;
    if (away != _showJumpToBottom && mounted) {
      setState(() => _showJumpToBottom = away);
    }
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
                itemCount:
                    widget.messages.length + (widget.showTypingDots ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == widget.messages.length && widget.showTypingDots) {
                    return const StocbuyThinkingIndicator();
                  }
                  return GptMessageBubble(
                    message: widget.messages[i],
                    onOpenMatchedStockDetails: widget.onOpenMatchedStockDetails,
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
