// tts_types.dart
// Place this file at:
// lib/application/pages/stocbuy_gpt/tts_types.dart
//
// Both stocbuy_gpt_chat_page.dart and gpt_chat_message_list.dart import from here.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

// ── TTS state ─────────────────────────────────────────────────────────────────

enum TtsState { idle, speaking }

// ── Speak button (one per assistant bubble) ───────────────────────────────────

class GptSpeakButton extends StatelessWidget {
  const GptSpeakButton({
    super.key,
    required this.isSpeaking,
    required this.onTap,
    this.isPending = false,
  });

  final bool isSpeaking;
  final bool isPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border, bg, fg;
    final IconData icon;
    final String label;

    if (isSpeaking) {
      border = AppColors.lightblue.withValues(alpha: 0.45);
      bg = AppColors.lightblue.withValues(alpha: 0.12);
      fg = AppColors.lightblue;
      icon = Icons.stop_rounded;
      label = 'Stop';
    } else if (isPending) {
      border = Colors.orange.withValues(alpha: 0.55);
      bg = Colors.orange.withValues(alpha: 0.10);
      fg = Colors.orange;
      icon = Icons.touch_app_rounded;
      label = 'Tap to hear';
    } else {
      border = AppColors.border;
      bg = Colors.transparent;
      fg = AppColors.grey;
      icon = Icons.volume_up_rounded;
      label = 'Speak';
    }

    final btn = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: fg),
          ),
        ]),
      ),
    );

    // On web show tooltip only when idle (not speaking/pending)
    if (kIsWeb && !isSpeaking && !isPending) {
      return Tooltip(message: 'Tap to read aloud', child: btn);
    }
    return btn;
  }
}