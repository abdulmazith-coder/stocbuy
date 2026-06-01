import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stocbuy_application/application/models/analysis_report_section.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/ai_analysis_dio.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_report_enrich.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_stream_apply.dart';

void main() {
  test('parses cached Python dict in data field', () {
    // Minimal slice matching backend shape (single-quoted keys, double-quoted values).
    const pythonDict = "{'balance_sheet': \"# Balance Sheet\\n\\nScore: 85\", "
        "'final_analysis': \"TCS\\n\\nFinal Verdict\\n\\nBuy\"}";

    final json = <String, dynamic>{
      'status': 'success',
      'message': 'Using cached full analysis',
      'data': pythonDict,
    };

    final event = AiAnalysisStreamEvent.fromJson(json);
    expect(event.reports, isNotEmpty);
    expect(
      event.reports.any((r) => r.fieldKey == 'final_analysis'),
      isTrue,
      reason: 'expected final_analysis report',
    );
    expect(
      event.reports.firstWhere((r) => r.fieldKey == 'final_analysis').markdown,
      contains('Final Verdict'),
    );
  });

  test('parses single-quoted values with apostrophes in text', () {
    const pythonDict = "{'shareholders': '# Shareholding\\n\\nInsiders don't hold much', "
        "'final_analysis': \"Final Action: Buy\"}";

    final parsed = parseCachedPythonDictReports(pythonDict);
    expect(parsed['shareholders_analysis'], contains("don't"));
    expect(parsed['final_analysis'], contains('Buy'));
  });

  test('applyAnalysisStreamEvent parses cached dict when reports empty', () {
    const pythonDict = "{'balance_sheet': \"# Balance Sheet\", "
        "'final_analysis': \"Final Verdict: Buy\"}";
    final event = AiAnalysisStreamEvent(
      status: 'success',
      message: 'Using cached full analysis',
      data: pythonDict,
      reports: const [],
    );

    final message = _TestStreamMessage();
    applyAnalysisStreamEvent(message, event);

    expect(message.analysisReports, isNotEmpty);
    expect(
      message.analysisReports.any((r) => r.isFinalAnalysis),
      isTrue,
    );
    expect(message.text, contains('Buy'));
  });

  test('parses cached dict after JSON round-trip like SSE', () {
    const inner =
        "{'balance_sheet': \"# Balance Sheet Analysis\\n\\n## Overall Score\", "
        "'final_analysis': \"Company Overview\\n\\nFinal Action: Buy\"}";
    final sseJson = jsonEncode({
      'status': 'success',
      'message': 'Using cached full analysis',
      'data': inner,
    });
    final decoded = jsonDecode(sseJson) as Map<String, dynamic>;
    final event = AiAnalysisStreamEvent.fromJson(decoded);
    expect(event.reports.length, greaterThanOrEqualTo(2));
  });

  test('parses data field when it is a JSON map', () {
    final event = AiAnalysisStreamEvent.fromJson({
      'status': 'success',
      'message': 'Using cached full analysis',
      'data': {
        'balance_sheet': '# Balance Sheet',
        'final_analysis': 'Company Overview\n\nBuy',
      },
    });
    expect(event.reports.length, 2);
    expect(
      event.reports
          .lastWhere((r) => r.fieldKey == 'final_analysis')
          .markdown,
      contains('Buy'),
    );
  });
}

class _TestStreamMessage implements AnalysisStreamMessage {
  @override
  String text = '';

  @override
  String? pendingFinalReport;

  @override
  final List<AnalysisReportSection> analysisReports = [];

  @override
  final List<String> stepLog = [];

  @override
  void appendStep(String step) => stepLog.add(step);

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
