import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/chat_auto_scroll.dart';

/// Floating down-arrow control (ChatGPT-style) when the user scrolls up.
class GptScrollToBottomButton extends StatelessWidget {
  const GptScrollToBottomButton({
    super.key,
    required this.scrollController,
    required this.visible,
  });

  final ScrollController scrollController;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: !visible,
        child: Center(
          child: Material(
            color: AppColors.white,
            elevation: 3,
            shadowColor: AppColors.darkblue.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
            ),
            child: InkWell(
              onTap: () => scrollChatToBottom(scrollController),
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 22,
                  color: AppColors.darkblue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
