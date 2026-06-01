import 'package:stocbuy_application/application/models/analysis_report_section.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/filtered_stock.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_report_enrich.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_stream_apply.dart';

/// Chat line in Stocbuy GPT (extends plain text with streaming metadata).
class GptChatMessage implements AnalysisStreamMessage {
  GptChatMessage({
    required this.role,
    this.text = '',
    this.pendingFinalReport,
    List<AnalysisReportSection>? analysisReports,
    List<String>? stepLog,
    this.isStreaming = false,
    this.matchedStocks,
    this.bestStocksFromCache = false,
    this.bestStocksCapLabel,
    DateTime? sentAt,
  }) : analysisReports = analysisReports ?? [],
       stepLog = stepLog ?? [],
       sentAt = sentAt ?? DateTime.now();

  final AiChatRole role;

  @override
  String text;

  /// Translated message text (if language != English).
  String? translatedText;

  /// Translated analysis reports.
  List<AnalysisReportSection>? translatedReports;

  /// Language code that the translation was done to (e.g. 'hi', 'ta').
  String? translatedToCode;

  /// True while translation is in progress.
  bool isTranslating = false;

  @override
  String? pendingFinalReport;

  @override
  final List<AnalysisReportSection> analysisReports;

  /// Every status line from the SSE stream, in order (deduped if repeated).
  @override
  final List<String> stepLog;

  bool isStreaming;

  /// Populated when a best-stocks scan completes.
  List<FilteredStock>? matchedStocks;

  bool bestStocksFromCache;
  String? bestStocksCapLabel;

  final DateTime sentAt;

  bool get hasBestStocksResults =>
      matchedStocks != null && matchedStocks!.isNotEmpty;

  /// Get display text (translated or original).
  String get displayText => translatedText ?? text;

  /// Get display reports (translated or original).
  List<AnalysisReportSection> get displayReports =>
      translatedReports ?? analysisReports;

  @override
  void appendStep(String step) {
    final label = step.trim();
    if (label.isEmpty) return;
    if (stepLog.isEmpty || stepLog.last != label) {
      stepLog.add(label);
    }
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
