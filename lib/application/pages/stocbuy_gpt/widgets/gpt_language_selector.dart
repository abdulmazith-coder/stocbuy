import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';

/// Language dropdown selector widget for GPT chat (shows in header).
class GptLanguageDropdown extends StatelessWidget {
  const GptLanguageDropdown({required this.selected, required this.onChanged});

  final IndianLanguage selected;
  final ValueChanged<IndianLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<IndianLanguage>(
          value: selected,
          isDense: true,
          menuMaxHeight: 320,
          icon: const Icon(
            Icons.language_rounded,
            size: 14,
            color: AppColors.grey,
          ),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.darkblue,
          ),
          borderRadius: BorderRadius.circular(12),
          items: kIndianLanguages.map((lang) {
            return DropdownMenuItem<IndianLanguage>(
              value: lang,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        lang.nativeName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkblue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${lang.name})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (lang) {
            if (lang != null) onChanged(lang);
          },
          selectedItemBuilder: (_) => kIndianLanguages.map((lang) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lang.nativeName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkblue,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Header with Stocbuy brand and language selector
class GptChatHeader extends StatelessWidget {
  const GptChatHeader({
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  final IndianLanguage selectedLanguage;
  final ValueChanged<IndianLanguage> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const StocbuyLogoMark(size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Stocbuy AI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.darkblue,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GptLanguageDropdown(
            selected: selectedLanguage,
            onChanged: onLanguageChanged,
          ),
        ],
      ),
    );
  }
}
