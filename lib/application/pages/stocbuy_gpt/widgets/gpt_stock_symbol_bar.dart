import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/utils/stock_symbol_util.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// Shows the stock picked for analysis; prompt is typed in the main input.
class GptStockSymbolBar extends StatelessWidget {
  const GptStockSymbolBar({
    super.key,
    required this.symbol,
    required this.onClear,
  });

  final String symbol;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = displayStockSymbol(symbol);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.lightblue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.lightblue.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    size: 18,
                    color: AppColors.lightblue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stock: $label — type your prompt below, then send',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkblue,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onClear,
            tooltip: 'Clear stock',
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.grey,
          ),
        ],
      ),
    );
  }
}
