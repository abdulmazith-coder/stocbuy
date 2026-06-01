import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// Live checklist shown while stock analysis is streaming.
class AiAnalysisProgressCard extends StatelessWidget {
  const AiAnalysisProgressCard({
    super.key,
    required this.steps,
    required this.isStreaming,
    this.compact = false,
    this.maxHeight = 280,
  });

  final List<String> steps;
  final bool isStreaming;
  final bool compact;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
        : const EdgeInsets.fromLTRB(16, 14, 16, 14);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(steps.length, (i) {
                    final isLast = i == steps.length - 1;
                    final loading = isStreaming && isLast;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i == steps.length - 1 ? 0 : 8,
                      ),
                      child: _StepRow(label: steps[i], loading: loading),
                    );
                  }),
                ),
              ),
            )
          else if (isStreaming)
            const _StepRow(label: 'Starting scan…', loading: true),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.loading});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.lightblue.withValues(alpha: 0.9),
            ),
          )
        else
          Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: AppColors.green.withValues(alpha: 0.92),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: loading ? FontWeight.w700 : FontWeight.w500,
              color: loading
                  ? AppColors.darkblue
                  : AppColors.grey.withValues(alpha: 0.95),
            ),
          ),
        ),
      ],
    );
  }
}
