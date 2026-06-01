import 'package:flutter_test/flutter_test.dart';
import 'package:stocbuy_application/application/models/analysis_report_section.dart';
import 'package:stocbuy_application/application/utils/ai_analysis_report_enrich.dart';

void main() {
  test('fills News Impact from news_analysis section', () {
    final reports = [
      AnalysisReportSection.fromField(
        fieldKey: 'news_analysis',
        markdown: '''
# News

## Sentiment
Overall sentiment: **Positive** — strong earnings headlines this week.
''',
      ),
      AnalysisReportSection.fromField(
        fieldKey: AnalysisReportSection.finalAnalysisFieldKey,
        markdown: '''
## Final Overview
* **News Impact:** Not Available
* **Risk Level:** 6/10
''',
      ),
    ];

    final enriched = enrichAnalysisReports(reports);
    final finalReport = enriched.lastWhere((r) => r.isFinalAnalysis);

    expect(finalReport.markdown, contains('News Impact:'));
    expect(finalReport.markdown, isNot(contains('Not Available')));
    expect(finalReport.markdown.toLowerCase(), contains('positive'));
  });

  test('upsert replaces prior report for the same field key', () {
    final reports = <AnalysisReportSection>[];
    upsertAnalysisReport(
      reports,
      fieldKey: 'news_analysis',
      markdown: 'draft',
    );
    upsertAnalysisReport(
      reports,
      fieldKey: 'news_analysis',
      markdown: 'final news body',
    );

    expect(reports.length, 1);
    expect(reports.single.markdown, 'final news body');
  });
}
