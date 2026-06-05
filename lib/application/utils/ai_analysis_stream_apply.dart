import 'package:stocbuy_application/application/models/analysis_report_section.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_dio.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_error_message.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_report_enrich.dart';

/// Target for [applyAnalysisStreamEvent] (GPT + stock sidebar chat).
abstract class AnalysisStreamMessage {
  List<String> get stepLog;
  String get text;
  set text(String value);

  /// Completed markdown blocks from successive `success` events.
  List<AnalysisReportSection> get analysisReports;

  /// Last report markdown — used when the stream ends.
  String? get pendingFinalReport;
  set pendingFinalReport(String? value);

  void appendStep(String step);
  void appendAnalysisReport(
    String markdown, {
    String? fieldKey,
    String? title,
  });
}

/// Applies one SSE event: progress steps while running; stores each report chunk.
void applyAnalysisStreamEvent(
  AnalysisStreamMessage message,
  AiAnalysisStreamEvent event,
) {
  if (event.isError) {
    message.pendingFinalReport = null;
    message.analysisReports.clear();
    message.text = formatAiAnalysisErrorMessage(event.message);
    return;
  }

  if (event.isProcessing) {
    final step = event.message.trim();
    if (step.toLowerCase().contains('retrying')) {
      message.analysisReports.clear();
      message.text = '';
      message.pendingFinalReport = null;
    }
    if (_shouldShowAsProgressStep(step)) {
      message.appendStep(step);
    }
    return;
  }

  if (!event.isSuccess) return;

  if (event.reports.isNotEmpty) {
    for (final report in event.reports) {
      message.appendAnalysisReport(
        report.markdown,
        fieldKey: report.fieldKey,
      );
    }
    _syncEnrichedReports(message);

    final last = event.reports.last;
    message.pendingFinalReport = last.markdown;

    final finalMarkdown = _latestFinalMarkdown(message);
    if (_isExplicitFinalEvent(event) && finalMarkdown != null) {
      message.text = finalMarkdown;
    }
    return;
  }

  if (event.hasLegacyData) {
    final report = event.data!.trim();

    // Cached bulk payload: Python dict string in `data`.
    if (report.startsWith('{')) {
      final parsed = parseCachedPythonDictReports(report);
      if (parsed.isNotEmpty) {
        for (final key in kAiAnalysisReportFieldKeys) {
          final md = parsed[key];
          if (md == null || md.isEmpty) continue;
          message.appendAnalysisReport(md, fieldKey: key);
        }
        _syncEnrichedReports(message);
        final finalMarkdown = _latestFinalMarkdown(message);
        message.pendingFinalReport =
            finalMarkdown ?? parsed.values.last;
        if (_isExplicitFinalEvent(event) && finalMarkdown != null) {
          message.text = finalMarkdown;
        }
      }
      return;
    }

    // ── Fallback: success event with no recognised report shape ──────────────
  // Backend sent status=success but no reports[] and no parseable data field.
  // Capture the raw message so the user sees something rather than silence.
  if (event.isSuccess && !event.hasReportContent) {
    final fallback = event.message.trim();
    if (fallback.isNotEmpty &&
        fallback.toLowerCase() != 'ai response ready' &&
        fallback.toLowerCase() != 'success') {
      message.appendAnalysisReport(fallback, fieldKey: 'data');
      message.pendingFinalReport = fallback;
    }
  }

    message.appendAnalysisReport(report, fieldKey: 'data');
    message.pendingFinalReport = report;

    if (_isExplicitFinalEvent(event)) {
      message.text = report;
    }
  }
}

/// After the stream closes, show the final report (or last section) by default.
void finalizeAnalysisReport(AnalysisStreamMessage message) {
  _syncEnrichedReports(message);

  // 1. Prefer the enriched final_analysis section
  final finalMarkdown = _latestFinalMarkdown(message);
  if (finalMarkdown != null && finalMarkdown.trim().isNotEmpty) {
    message.text = finalMarkdown;
    return;
  }

  // 2. Already has text (set during streaming)
  if (message.text.trim().isNotEmpty) return;

  // 3. Concatenate all report sections as fallback
  final reports = message.analysisReports;
  if (reports.isNotEmpty) {
    // Prefer the last section with the most content
    final best = reports.reduce((a, b) => 
        a.markdown.length >= b.markdown.length ? a : b);
    message.text = best.markdown;
    return;
  }

  // 4. Last resort: pendingFinalReport
  final draft = message.pendingFinalReport?.trim() ?? '';
  if (draft.isNotEmpty) {
    message.text = draft;
  }
}

void _syncEnrichedReports(AnalysisStreamMessage message) {
  if (message.analysisReports.isEmpty) return;
  final enriched = enrichAnalysisReports(message.analysisReports);
  if (identical(enriched, message.analysisReports)) return;
  message.analysisReports
    ..clear()
    ..addAll(enriched);
}

String? _latestFinalMarkdown(AnalysisStreamMessage message) {
  for (var i = message.analysisReports.length - 1; i >= 0; i--) {
    if (message.analysisReports[i].isFinalAnalysis) {
      return message.analysisReports[i].markdown;
    }
  }
  return null;
}

bool analysisHasVisibleReport(AnalysisStreamMessage message) =>
    message.text.trim().isNotEmpty || message.analysisReports.isNotEmpty;

bool _shouldShowAsProgressStep(String message) {
  if (message.isEmpty) return false;
  final lower = message.toLowerCase();
  if (lower == 'ai response ready') return false;
  return true;
}

bool _isExplicitFinalEvent(AiAnalysisStreamEvent event) {
  final lower = event.message.trim().toLowerCase();
  return lower.contains('full analysis complete') ||
      lower.contains('analysis complete') ||
      lower.contains('cached'); // cached responses deliver all sections at once
}
