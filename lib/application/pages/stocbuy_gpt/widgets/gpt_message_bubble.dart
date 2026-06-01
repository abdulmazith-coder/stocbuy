import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/filtered_stock.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/gpt_chat_message.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/best_stocks_progress_panel.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/best_stocks_result_list.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_markdown_text.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/ai_chat_bubbles.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';

class GptMessageBubble extends StatelessWidget {
  const GptMessageBubble({
    super.key,
    required this.message,
    this.onOpenMatchedStockDetails,
    this.onAnalyzeMatchedStock,
    this.stockActionsEnabled = true,
  });

  final GptChatMessage message;
  final void Function(FilteredStock stock)? onOpenMatchedStockDetails;
  final void Function(FilteredStock stock)? onAnalyzeMatchedStock;
  final bool stockActionsEnabled;

  @override
  Widget build(BuildContext context) {
    if (message.role == AiChatRole.user) {
      return AiChatUserBubble(text: message.text, sentAt: message.sentAt);
    }

    if (message.isStreaming ||
        message.text.trim().isNotEmpty ||
        message.analysisReports.isNotEmpty ||
        message.hasBestStocksResults) {
      return _AssistantBubble(
        message: message,
        onOpenMatchedStockDetails: onOpenMatchedStockDetails,
        onAnalyzeMatchedStock: onAnalyzeMatchedStock,
        stockActionsEnabled: stockActionsEnabled,
      );
    }

    return const SizedBox.shrink();
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.message,
    this.onOpenMatchedStockDetails,
    this.onAnalyzeMatchedStock,
    this.stockActionsEnabled = true,
  });

  final GptChatMessage message;
  final void Function(FilteredStock stock)? onOpenMatchedStockDetails;
  final void Function(FilteredStock stock)? onAnalyzeMatchedStock;
  final bool stockActionsEnabled;

  @override
  Widget build(BuildContext context) {
    final isBestStocks = message.bestStocksCapLabel != null;
    final stocks = message.matchedStocks;
    final showProgress = message.isStreaming;
    final hasReport =
        message.displayText.trim().isNotEmpty ||
        message.displayReports.isNotEmpty;

    if (showProgress && isBestStocks) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: BestStocksProgressPanel(
          steps: message.stepLog,
          isStreaming: true,
        ),
      );
    }

    Widget? childBelow;
    if (!showProgress && isBestStocks && stocks != null) {
      childBelow = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasReport)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: GptMarkdownText(data: message.displayText),
            ),
          if (hasReport) const SizedBox(height: 14),
          BestStocksResultList(
            stocks: stocks,
            fromCache: message.bestStocksFromCache,
            capLabel: message.bestStocksCapLabel,
            onViewDetails: onOpenMatchedStockDetails,
            onAnalyze: onAnalyzeMatchedStock,
            actionsEnabled: stockActionsEnabled,
          ),
        ],
      );
    }

    return AiChatAssistantBubble(
      text: message.isTranslating ? message.text : message.displayText,
      analysisReports: message.isTranslating
          ? message.analysisReports
          : message.displayReports,
      isStreaming: showProgress && !isBestStocks,
      stepLog: message.stepLog,
      sentAt: message.sentAt,
      childBelow: childBelow,
      bubbleColor: AppColors.white,
      showBorder: false,
      footerLeadingAvatar: const StocbuyLogoMark(size: 16),
    );
  }
}
