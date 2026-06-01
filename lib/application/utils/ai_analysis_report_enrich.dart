import 'package:stocbuy_application/application/models/analysis_report_section.dart';

/// Appends or replaces a report by [fieldKey] so later SSE chunks win.
void upsertAnalysisReport(
  List<AnalysisReportSection> reports, {
  required String markdown,
  String? fieldKey,
  String? title,
}) {
  final trimmed = markdown.trim();
  if (trimmed.isEmpty) return;

  if (fieldKey != null) {
    final section = AnalysisReportSection.fromField(
      fieldKey: fieldKey,
      markdown: trimmed,
    );
    final idx = reports.indexWhere((r) => r.fieldKey == fieldKey);
    if (idx >= 0) {
      reports[idx] = section;
    } else {
      reports.add(section);
    }
    return;
  }

  reports.add(
    AnalysisReportSection(
      title: title ?? AnalysisReportSection.titleFromMarkdown(trimmed),
      markdown: trimmed,
    ),
  );
}

/// Fills "Not Available" rows in [final_analysis] from other streamed sections.
List<AnalysisReportSection> enrichAnalysisReports(
  List<AnalysisReportSection> reports,
) {
  final finalIdx = reports.lastIndexWhere((r) => r.isFinalAnalysis);
  if (finalIdx < 0) return reports;

  final enriched = enrichFinalAnalysisMarkdown(
    reports[finalIdx].markdown,
    reports,
  );
  if (enriched == reports[finalIdx].markdown) return reports;

  final copy = List<AnalysisReportSection>.from(reports);
  copy[finalIdx] = AnalysisReportSection.fromField(
    fieldKey: AnalysisReportSection.finalAnalysisFieldKey,
    markdown: enriched,
  );
  return copy;
}

/// Patches placeholder lines inside the final overview block.
String enrichFinalAnalysisMarkdown(
  String finalMarkdown,
  List<AnalysisReportSection> reports,
) {
  final lines = finalMarkdown.replaceAll('\r\n', '\n').split('\n');
  final out = <String>[];
  for (final line in lines) {
    out.add(_maybeEnrichOverviewLine(line, reports));
  }
  return out.join('\n');
}

String _maybeEnrichOverviewLine(
  String line,
  List<AnalysisReportSection> reports,
) {
  if (!_lineHasPlaceholderValue(line)) return line;

  if (_lineHasLabel(line, 'News Impact')) {
    final derived = _deriveNewsImpact(_markdownFor(reports, 'news_analysis'));
    if (derived != null) return _replacePlaceholderValue(line, derived);
  }

  if (_lineHasLabel(line, 'Financial Health')) {
    final derived = _deriveFinancialHealth(reports);
    if (derived != null) return _replacePlaceholderValue(line, derived);
  }

  if (_lineHasLabel(line, 'Fundamental Strength')) {
    final derived = _deriveFundamentalStrength(reports);
    if (derived != null) return _replacePlaceholderValue(line, derived);
  }

  return line;
}

bool _lineHasPlaceholderValue(String line) {
  final trimmed = line.trim();
  if (!trimmed.contains(':')) return false;
  return RegExp(
    r'(Not Available|N/A|—|Unavailable|not available|None)\s*$',
    caseSensitive: false,
  ).hasMatch(trimmed);
}

bool _lineHasLabel(String line, String label) {
  return RegExp('${RegExp.escape(label)}\\s*:', caseSensitive: false)
      .hasMatch(line);
}

String _replacePlaceholderValue(String line, String value) {
  return line.replaceFirst(
    RegExp(
      r'(Not Available|N/A|—|Unavailable|not available|None)\s*$',
      caseSensitive: false,
    ),
    value,
  );
}

String? _markdownFor(List<AnalysisReportSection> reports, String fieldKey) {
  for (var i = reports.length - 1; i >= 0; i--) {
    if (reports[i].fieldKey == fieldKey) {
      return reports[i].markdown;
    }
  }
  return null;
}

bool _sectionHasUsableData(String? markdown) {
  if (markdown == null) return false;
  final trimmed = markdown.trim();
  if (trimmed.length < 50) return false;

  final lower = trimmed.toLowerCase();
  const hardEmpty = [
    'no news available',
    'news not available',
    'no recent news',
    'unable to fetch news',
  ];
  if (hardEmpty.any(lower.contains)) {
    return trimmed.length > 120;
  }
  return true;
}

bool _isPlaceholderValue(String value) {
  final v = value.trim().toLowerCase();
  return v.isEmpty ||
      v == 'not available' ||
      v == 'n/a' ||
      v == 'none' ||
      v == 'unavailable' ||
      v == '—';
}

String? _deriveNewsImpact(String? newsMarkdown) {
  if (!_sectionHasUsableData(newsMarkdown)) return null;
  final md = newsMarkdown!;

  final labeled = [
    RegExp(r'(?:news\s+)?impact\s*:+\s*(.+)', caseSensitive: false),
    RegExp(r'(?:overall\s+)?sentiment\s*:+\s*(.+)', caseSensitive: false),
    RegExp(r'market\s+sentiment\s*:+\s*(.+)', caseSensitive: false),
  ];
  for (final re in labeled) {
    final match = re.firstMatch(md);
    if (match != null) {
      final value = _stripMarkdown(match.group(1)!.trim());
      if (!_isPlaceholderValue(value)) return _truncate(value, 140);
    }
  }

  final lower = md.toLowerCase();
  const positive = [
    'bullish',
    'positive',
    'favorable',
    'favourable',
    'upbeat',
    'tailwind',
  ];
  const negative = [
    'bearish',
    'negative',
    'unfavorable',
    'unfavourable',
    'downgrade',
    'headwind',
    'concern',
  ];
  var pos = 0;
  var neg = 0;
  for (final w in positive) {
    if (lower.contains(w)) pos++;
  }
  for (final w in negative) {
    if (lower.contains(w)) neg++;
  }

  if (pos > neg && pos > 0) {
    return 'Positive — recent headlines lean favourable';
  }
  if (neg > pos && neg > 0) {
    return 'Negative — recent headlines lean unfavourable';
  }
  if (lower.contains('neutral')) {
    return 'Neutral — mixed or limited headline impact';
  }

  for (final line in md.split('\n')) {
    final t = line.trim();
    if (!t.startsWith('- ') && !t.startsWith('* ')) continue;
    final body =
        t.replaceFirst(RegExp(r'^[-*]\s+'), '').replaceAll('**', '').trim();
    if (body.length > 24 && !_isPlaceholderValue(body)) {
      return _truncate(body, 140);
    }
  }

  return 'Moderate — see News report for headline details';
}

String? _deriveFinancialHealth(List<AnalysisReportSection> reports) {
  final sources = [
    _markdownFor(reports, 'balance_sheet_analysis'),
    _markdownFor(reports, 'financial_ratios_analysis'),
    _markdownFor(reports, 'cash_flow_analysis'),
  ].where(_sectionHasUsableData).map((e) => e!.toLowerCase());

  if (sources.isEmpty) return null;

  final text = sources.join('\n');
  if (RegExp(r'\b(strong|healthy|robust|solid)\b').hasMatch(text)) {
    return 'Strong';
  }
  if (RegExp(r'\b(weak|stressed|deteriorat|concern)\b').hasMatch(text)) {
    return 'Weak';
  }
  if (RegExp(r'\b(moderate|stable|adequate|fair)\b').hasMatch(text)) {
    return 'Moderate';
  }
  return 'Moderate — derived from financial statement analysis';
}

String? _deriveFundamentalStrength(List<AnalysisReportSection> reports) {
  final ratios = _markdownFor(reports, 'financial_ratios_analysis');
  if (!_sectionHasUsableData(ratios)) return null;

  final score = RegExp(
    r'(?:fundamental\s+strength|overall\s+score|score)\s*:+\s*(\d{1,3})\s*/\s*100',
    caseSensitive: false,
  ).firstMatch(ratios!);
  if (score != null) {
    return '${score.group(1)}/100';
  }

  final lower = ratios.toLowerCase();
  if (RegExp(r'\b(strong|excellent|high quality)\b').hasMatch(lower)) {
    return 'Strong fundamentals';
  }
  if (RegExp(r'\b(weak|poor|low quality)\b').hasMatch(lower)) {
    return 'Weak fundamentals';
  }
  return 'Moderate — see Financial Ratios report';
}

String _truncate(String value, int maxLen) {
  if (value.length <= maxLen) return value;
  return '${value.substring(0, maxLen - 1)}…';
}

String _stripMarkdown(String value) {
  return value.replaceAll(RegExp(r'\*+'), '').trim();
}
