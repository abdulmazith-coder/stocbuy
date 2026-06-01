/// One completed markdown report from the AI analysis SSE stream.
class AnalysisReportSection {
  const AnalysisReportSection({
    required this.title,
    required this.markdown,
    this.fieldKey,
  });

  final String title;
  final String markdown;

  /// API field name when present (e.g. `balance_sheet_analysis`).
  final String? fieldKey;

  static const finalAnalysisFieldKey = 'final_analysis';

  bool get isFinalAnalysis => fieldKey == finalAnalysisFieldKey;

  /// Display label for a named SSE field.
  static String titleFromFieldKey(String fieldKey) {
    switch (fieldKey) {
      case 'balance_sheet_analysis':
        return 'Balance Sheet';
      case 'income_statement_analysis':
        return 'Income Statement';
      case 'cash_flow_analysis':
        return 'Cash Flow';
      case 'shareholders_analysis':
        return 'Shareholding';
      case 'financial_ratios_analysis':
        return 'Financial Ratios';
      case 'news_analysis':
        return 'News';
      case finalAnalysisFieldKey:
        return 'Final Analysis';
      case 'data':
        return 'Analysis';
      default:
        return _humanizeFieldKey(fieldKey);
    }
  }

  static String _humanizeFieldKey(String fieldKey) {
    var label = fieldKey.replaceAll('_', ' ').trim();
    if (label.endsWith(' analysis')) {
      label = label.substring(0, label.length - ' analysis'.length);
    }
    if (label.isEmpty) return 'Analysis';
    return label.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  /// First `# ` heading in [markdown], or a short fallback label.
  static String titleFromMarkdown(String markdown) {
    for (final line in markdown.replaceAll('\r\n', '\n').split('\n')) {
      final t = line.trim();
      if (t.startsWith('# ')) {
        return t.substring(2).trim();
      }
    }
    return 'Analysis';
  }

  factory AnalysisReportSection.fromMarkdown(String markdown) {
    final trimmed = markdown.trim();
    return AnalysisReportSection(
      title: titleFromMarkdown(trimmed),
      markdown: trimmed,
    );
  }

  factory AnalysisReportSection.fromField({
    required String fieldKey,
    required String markdown,
  }) {
    final trimmed = markdown.trim();
    return AnalysisReportSection(
      fieldKey: fieldKey,
      title: titleFromFieldKey(fieldKey),
      markdown: trimmed,
    );
  }
}

/// Named analysis fields emitted by `features/ai-analysis/` (full + partial runs).
const kAiAnalysisReportFieldKeys = <String>[
  'balance_sheet_analysis',
  'income_statement_analysis',
  'cash_flow_analysis',
  'shareholders_analysis',
  'financial_ratios_analysis',
  'news_analysis',
  AnalysisReportSection.finalAnalysisFieldKey,
];
