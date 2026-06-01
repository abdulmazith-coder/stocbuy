import 'package:stocbuy_application/application/models/analysis_report_section.dart';

/// Plain text for one report tab (Financial Ratios, Final Analysis, etc.).
String copyableReportSection(AnalysisReportSection report) =>
    report.markdown.trim();

/// Default tab for copy (Final Analysis when present, else last section).
String? copyableDefaultReportSection(
  List<AnalysisReportSection> reports,
) {
  if (reports.isEmpty) return null;
  for (final report in reports) {
    if (report.isFinalAnalysis) return copyableReportSection(report);
  }
  return copyableReportSection(reports.last);
}

/// Plain text when there is a single report or no tabbed sections.
String copyableAssistantText({
  required String text,
  List<AnalysisReportSection> analysisReports = const [],
}) {
  if (analysisReports.length == 1) {
    return copyableReportSection(analysisReports.first);
  }
  return text.trim();
}
