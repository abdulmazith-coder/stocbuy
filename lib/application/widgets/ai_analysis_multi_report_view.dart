import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/models/analysis_report_section.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_markdown_text.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/ai_chat_copy_text.dart';

/// Swaps between multiple streamed analysis reports (balance sheet, P&L, etc.).
///
/// Defaults to the last report. Use the down control to cycle through each
/// report in full.
class AiAnalysisMultiReportView extends StatefulWidget {
  const AiAnalysisMultiReportView({
    super.key,
    required this.reports,
    this.baseStyle,
    this.compact = false,
    this.onActiveCopyTextChanged,
  });

  final List<AnalysisReportSection> reports;
  final TextStyle? baseStyle;
  final bool compact;

  /// Fired when the visible tab changes so Copy uses only that section.
  final ValueChanged<String>? onActiveCopyTextChanged;

  @override
  State<AiAnalysisMultiReportView> createState() =>
      _AiAnalysisMultiReportViewState();
}

class _AiAnalysisMultiReportViewState extends State<AiAnalysisMultiReportView> {
  late int _selectedIndex;

  int _defaultReportIndex(List<AnalysisReportSection> reports) {
    for (var i = 0; i < reports.length; i++) {
      if (reports[i].isFinalAnalysis) return i;
    }
    return reports.length - 1;
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = _defaultReportIndex(widget.reports);
    _notifyActiveCopyText();
  }

  @override
  void didUpdateWidget(covariant AiAnalysisMultiReportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reports.length != oldWidget.reports.length) {
      _selectedIndex = _defaultReportIndex(widget.reports);
    } else if (_selectedIndex >= widget.reports.length) {
      _selectedIndex = _defaultReportIndex(widget.reports);
    }
    _notifyActiveCopyText();
  }

  void _notifyActiveCopyText() {
    final callback = widget.onActiveCopyTextChanged;
    final reports = widget.reports;
    if (reports.isEmpty || callback == null) return;

    final text = copyableReportSection(reports[_selectedIndex]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback(text);
    });
  }

  void _selectIndex(int index) {
    setState(() => _selectedIndex = index);
    _notifyActiveCopyText();
  }

  void _selectNext() {
    if (widget.reports.length <= 1) return;
    _selectIndex((_selectedIndex + 1) % widget.reports.length);
  }

  String _shortTitle(String title) {
    if (title.length > 28) {
      return '${title.substring(0, 26)}…';
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final reports = widget.reports;
    if (reports.isEmpty) return const SizedBox.shrink();
    if (reports.length == 1) {
      return GptMarkdownText(
        data: reports.first.markdown,
        baseStyle: widget.baseStyle,
      );
    }

    final report = reports[_selectedIndex];
    final bodyStyle = widget.baseStyle ??
        TextStyle(
          fontSize: widget.compact ? 13 : 15,
          height: 1.6,
          fontWeight: FontWeight.w400,
          color: AppColors.darkblue,
        );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReportSwitcherBar(
              reports: reports,
              selectedIndex: _selectedIndex,
              onSelected: _selectIndex,
              shortTitle: _shortTitle,
            ),
            const SizedBox(height: 12),
            GptMarkdownText(data: report.markdown, baseStyle: bodyStyle),
          ],
        ),
        Positioned(
          right: 0,
          top: 0,
          child: _CycleReportButton(
            current: _selectedIndex + 1,
            total: reports.length,
            onPressed: _selectNext,
          ),
        ),
      ],
    );
  }
}

class _ReportSwitcherBar extends StatelessWidget {
  const _ReportSwitcherBar({
    required this.reports,
    required this.selectedIndex,
    required this.onSelected,
    required this.shortTitle,
  });

  final List<AnalysisReportSection> reports;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String Function(String title) shortTitle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 48),
      child: Row(
        children: [
          for (var i = 0; i < reports.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _ReportChip(
              label: shortTitle(reports[i].title),
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.darkblue : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.darkblue : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : AppColors.darkblue,
            ),
          ),
        ),
      ),
    );
  }
}

class _CycleReportButton extends StatelessWidget {
  const _CycleReportButton({
    required this.current,
    required this.total,
    required this.onPressed,
  });

  final int current;
  final int total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Next report ($current of $total)',
      child: Material(
        color: AppColors.white,
        elevation: 3,
        shadowColor: AppColors.darkblue.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: AppColors.darkblue,
                ),
                Text(
                  '$current/$total',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.grey,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
