import 'package:stocbuy_application/application/networks/dio/features_dio/penny_stock_filter_dio.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/gpt_chat_message.dart';

/// Applies scanner SSE events to a GPT message.
void applyBestStocksStreamEvent(
  GptChatMessage message,
  PennyStockFilterEvent event,
) {
  if (event.isCompleted) {
    final label = event.stepLabel;
    if (label != null && label.isNotEmpty) {
      message.appendStep(label);
    }
    final stocks = event.goodStocks;
    message.matchedStocks = stocks;
    final total = event.totalGoodStocks ?? stocks.length;
    message.text = 'Found **$total** stocks matching your filters.';
    return;
  }

  final label = event.stepLabel;
  if (label != null && label.isNotEmpty) {
    message.appendStep(label);
  }
}

void finalizeBestStocksMessage(GptChatMessage message) {
  if (message.matchedStocks != null && message.matchedStocks!.isNotEmpty) {
    if (message.text.trim().isEmpty) {
      message.text =
          'Found **${message.matchedStocks!.length}** stocks matching your filters.';
    }
    return;
  }
  if (message.text.trim().isEmpty) {
    message.text = 'Scan finished but no matching stocks were returned.';
  }
}
