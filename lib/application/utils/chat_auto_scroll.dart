import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Pins a chat [ScrollController] to the bottom (ChatGPT-style follow mode).
void scrollChatToBottom(
  ScrollController scroll, {
  bool animated = true,
  /// Extra frame(s) so layout (e.g. growing step log) finishes before scroll.
  int layoutFrames = 1,
}) {
  void jump() {
    if (!scroll.hasClients) return;
    final target = scroll.position.maxScrollExtent;
    if (animated) {
      scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      scroll.jumpTo(target);
    }
  }

  void schedule(int framesLeft) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      jump();
      if (framesLeft > 1) schedule(framesLeft - 1);
    });
  }

  schedule(layoutFrames.clamp(1, 4));
}
