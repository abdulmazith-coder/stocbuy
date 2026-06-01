import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stocbuy_application/application/models/analysis_report_section.dart';
import 'package:stocbuy_application/application/utils/ai_chat_copy_text.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/widgets/gpt_markdown_text.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/stock_formatters.dart';
import 'package:stocbuy_application/application/widgets/ai_analysis_multi_report_view.dart';
import 'package:stocbuy_application/application/widgets/ai_analysis_progress_card.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';

/// Shared Claude / ChatGPT-style chat bubbles for stock sidebar + Stocbuy GPT.
class AiChatSparkleAvatar extends StatelessWidget {
  const AiChatSparkleAvatar({super.key, this.size = 18, this.iconSize = 9});

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF16C784), Color(0xFF0EA371)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}

class AiChatUserAvatar extends StatelessWidget {
  const AiChatUserAvatar({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.lightblue.withValues(alpha: 0.18),
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: size * 0.7,
        color: AppColors.lightblue,
      ),
    );
  }
}

/// Body text for completed assistant analysis (markdown or multi-report swap).
class AiChatAssistantReportBody extends StatelessWidget {
  const AiChatAssistantReportBody({
    super.key,
    required this.text,
    required this.analysisReports,
    this.compact = false,
    this.onActiveCopyTextChanged,
  });

  final String text;
  final List<AnalysisReportSection> analysisReports;
  final bool compact;
  final ValueChanged<String>? onActiveCopyTextChanged;

  static const _reportStyle = TextStyle(
    fontSize: 13,
    height: 1.55,
    fontWeight: FontWeight.w500,
    color: AppColors.darkblue,
  );

  @override
  Widget build(BuildContext context) {
    if (analysisReports.length > 1) {
      return AiAnalysisMultiReportView(
        reports: analysisReports,
        compact: compact,
        baseStyle: _reportStyle,
        onActiveCopyTextChanged: onActiveCopyTextChanged,
      );
    }
    if (analysisReports.length == 1) {
      return GptMarkdownText(
        data: analysisReports.first.markdown,
        baseStyle: _reportStyle,
      );
    }
    return GptMarkdownText(data: text, baseStyle: _reportStyle);
  }
}

class AiChatUserBubble extends StatelessWidget {
  const AiChatUserBubble({
    super.key,
    required this.text,
    this.sentAt,
    this.showFooter = true,
  });

  final String text;
  final DateTime? sentAt;
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightblue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (showFooter && sentAt != null)
                  AiChatMessageFooter(isUser: true, sentAt: sentAt!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AiChatAssistantBubble extends StatefulWidget {
  const AiChatAssistantBubble({
    super.key,
    this.text = '',
    this.analysisReports = const [],
    this.isStreaming = false,
    this.stepLog = const [],
    this.sentAt,
    this.showFooter = true,
    this.compactProgress = true,
    this.childBelow,
    this.bubbleColor,
    this.showBorder = true,
    this.footerLeadingAvatar,
  });

  final String text;
  final List<AnalysisReportSection> analysisReports;
  final bool isStreaming;
  final List<String> stepLog;
  final DateTime? sentAt;
  final bool showFooter;
  final bool compactProgress;
  final Widget? childBelow;

  /// Override the bubble background. Defaults to [AppColors.surfaceMuted].
  final Color? bubbleColor;

  /// When false the bubble is rendered without a border. Defaults to true.
  final bool showBorder;

  /// Replace the default sparkle avatar in the footer row.
  final Widget? footerLeadingAvatar;

  @override
  State<AiChatAssistantBubble> createState() => _AiChatAssistantBubbleState();
}

class _AiChatAssistantBubbleState extends State<AiChatAssistantBubble> {
  /// Copy text for the currently selected report tab (multi-section only).
  String? _activeSectionCopyText;

  @override
  void initState() {
    super.initState();
    _syncDefaultSectionCopyText();
  }

  @override
  void didUpdateWidget(covariant AiChatAssistantBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analysisReports != oldWidget.analysisReports) {
      _syncDefaultSectionCopyText();
    }
  }

  void _syncDefaultSectionCopyText() {
    if (widget.analysisReports.length > 1) {
      _activeSectionCopyText = copyableDefaultReportSection(
        widget.analysisReports,
      );
    }
  }

  void _onActiveSectionCopyTextChanged(String copyText) {
    if (_activeSectionCopyText == copyText) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeSectionCopyText == copyText) return;
      setState(() => _activeSectionCopyText = copyText);
    });
  }

  bool get _hasReport =>
      widget.text.trim().isNotEmpty || widget.analysisReports.isNotEmpty;

  String? get _footerCopyText {
    if (!_hasReport) return null;
    if (widget.analysisReports.length > 1) {
      return _activeSectionCopyText;
    }
    return copyableAssistantText(
      text: widget.text,
      analysisReports: widget.analysisReports,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isStreaming && !_hasReport && widget.childBelow == null) {
      return const SizedBox.shrink();
    }

    final Widget? bubble;
    if (widget.isStreaming) {
      bubble = AiAnalysisProgressCard(
        steps: widget.stepLog,
        isStreaming: true,
        compact: widget.compactProgress,
      );
    } else if (_hasReport) {
      final bgColor = widget.bubbleColor ?? AppColors.surfaceMuted;
      bubble = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: widget.showBorder
              ? Border.all(color: AppColors.border.withValues(alpha: 0.8))
              : null,
        ),
        child: AiChatAssistantReportBody(
          text: widget.text,
          analysisReports: widget.analysisReports,
          compact: widget.compactProgress,
          onActiveCopyTextChanged: widget.analysisReports.length > 1
              ? _onActiveSectionCopyTextChanged
              : null,
        ),
      );
    } else {
      bubble = null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ?bubble,
                if (widget.childBelow != null) ...[
                  if (bubble != null) const SizedBox(height: 10),
                  widget.childBelow!,
                ],
                if (widget.showFooter &&
                    widget.sentAt != null &&
                    !widget.isStreaming)
                  AiChatMessageFooter(
                    isUser: false,
                    sentAt: widget.sentAt!,
                    copyText: _footerCopyText,
                    leadingAvatar: widget.footerLeadingAvatar,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AiChatMessageFooter extends StatelessWidget {
  const AiChatMessageFooter({
    super.key,
    required this.isUser,
    required this.sentAt,
    this.copyText,
    this.leadingAvatar,
  });

  final bool isUser;
  final DateTime sentAt;

  /// When set on assistant messages, shows a copy button for this plain text.
  final String? copyText;

  /// Replaces the default [AiChatSparkleAvatar] on assistant messages.
  final Widget? leadingAvatar;

  @override
  Widget build(BuildContext context) {
    final canCopy = !isUser && copyText != null && copyText!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            leadingAvatar ?? const StocbuyLogoMark(size: 16),
            const SizedBox(width: 8),
          ],
          Text(
            StockFormatters.hhmm(sentAt),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.grey,
              letterSpacing: 0.3,
            ),
          ),
          if (canCopy) ...[
            const SizedBox(width: 6),
            AiChatCopyButton(text: copyText!),
          ],
          if (isUser) ...[
            const SizedBox(width: 8),
            const AiChatUserAvatar(size: 16),
          ],
        ],
      ),
    );
  }
}

/// Copies [text] to the system clipboard and shows brief feedback.
class AiChatCopyButton extends StatefulWidget {
  const AiChatCopyButton({super.key, required this.text});

  final String text;

  @override
  State<AiChatCopyButton> createState() => _AiChatCopyButtonState();
}

class _AiChatCopyButtonState extends State<AiChatCopyButton> {
  bool _copied = false;

  Future<void> _onCopy() async {
    final data = widget.text.trim();
    if (data.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: data));
    if (!mounted) return;

    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _copied ? 'Copied' : 'Copy',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onCopy,
          borderRadius: BorderRadius.circular(6),
          hoverColor: AppColors.surfaceMuted,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 14,
              color: _copied ? AppColors.green : AppColors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

class AiChatTypingIndicator extends StatefulWidget {
  const AiChatTypingIndicator({super.key});

  @override
  State<AiChatTypingIndicator> createState() => _AiChatTypingIndicatorState();
}

class _AiChatTypingIndicatorState extends State<AiChatTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.8),
              ),
            ),
            child: AnimatedBuilder(
              animation: _dots,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      _TypingDot(
                        opacity:
                            0.4 +
                            0.6 * ((((_dots.value * 3) - i) % 3) - 1).abs(),
                      ),
                      if (i < 2) const SizedBox(width: 5),
                    ],
                  ],
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AiChatSparkleAvatar(size: 16, iconSize: 9),
                SizedBox(width: 8),
                Text(
                  'Typing…',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot({required this.opacity});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.grey.withValues(alpha: opacity.clamp(0.0, 1.0)),
      ),
    );
  }
}

// ── Stocbuy-branded thinking indicator ──────────────────────────────────────

/// Typing placeholder shown on the Stocbuy GPT page while waiting for a reply.
///
/// Renders the [StocbuyLogoMark] with a smooth pulse (scale + fade) to
/// convey that the AI is "thinking", followed by a "Thinking…" label.
class StocbuyThinkingIndicator extends StatefulWidget {
  const StocbuyThinkingIndicator({super.key});

  @override
  State<StocbuyThinkingIndicator> createState() =>
      _StocbuyThinkingIndicatorState();
}

class _StocbuyThinkingIndicatorState extends State<StocbuyThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
    lowerBound: 0.0,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = _pulse.value;
              return Opacity(
                opacity: (0.35 + 0.65 * t).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.82 + 0.18 * t,
                  alignment: Alignment.centerLeft,
                  child: child,
                ),
              );
            },
            child: const StocbuyLogoMark(size: 30),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thinking…',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.grey,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Disclaimer shown below AI chat inputs (same copy everywhere).
class AiChatDisclaimerFooter extends StatelessWidget {
  const AiChatDisclaimerFooter({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Text(
        'Stocbuy AI may make mistakes. This is for educational purposes only. '
        'If you invest, take your own risk and ask your financial advisor.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: AppColors.grey.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
