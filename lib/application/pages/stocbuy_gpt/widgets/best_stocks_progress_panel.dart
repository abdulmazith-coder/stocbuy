import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_scroll_behavior.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// One line per SSE `data:` event from penny-stock-filter (no extra labels).
class BestStocksProgressPanel extends StatefulWidget {
  const BestStocksProgressPanel({
    super.key,
    required this.steps,
    this.isStreaming = false,
    this.maxHeight = 320,
  });

  final List<String> steps;
  final bool isStreaming;
  final double maxHeight;

  @override
  State<BestStocksProgressPanel> createState() => _BestStocksProgressPanelState();
}

class _BestStocksProgressPanelState extends State<BestStocksProgressPanel> {
  final ScrollController _scrollController = ScrollController();
  int _lastStepCount = 0;

  @override
  void initState() {
    super.initState();
    _lastStepCount = widget.steps.length;
  }

  @override
  void didUpdateWidget(BestStocksProgressPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.steps.length != _lastStepCount) {
      _lastStepCount = widget.steps.length;
      _scrollToBottomAfterLayout();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// ListView needs two frames after new items before [maxScrollExtent] is final.
  void _scrollToBottomAfterLayout({int frames = 2}) {
    void tick(int left) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToBottom();
        if (left > 1) tick(left - 1);
      });
    }

    tick(frames);
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final target = pos.maxScrollExtent;
    if (target <= 0) return;
    if ((pos.pixels - target).abs() < 1) return;
    _scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      child: SizedBox(
        height: widget.maxHeight,
        child: ScrollConfiguration(
          behavior: const GptScrollBehavior(),
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: widget.steps.length,
            itemBuilder: (context, index) {
            final isLast = index == widget.steps.length - 1;
            final loading = widget.isStreaming && isLast;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == widget.steps.length - 1 ? 0 : 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.lightblue,
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
                      widget.steps[index],
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
              ),
            );
            },
          ),
        ),
      ),
    );
  }
}
