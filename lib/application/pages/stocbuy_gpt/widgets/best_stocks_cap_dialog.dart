import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/best_stocks_cap_type.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

Future<void> showBestStocksCapDialog(
  BuildContext context, {
  required ValueChanged<BestStocksCapType> onSelected,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => _BestStocksCapDialog(
      onSelected: (cap) {
        Navigator.of(ctx).pop();
        onSelected(cap);
      },
    ),
  );
}

class _BestStocksCapDialog extends StatelessWidget {
  const _BestStocksCapDialog({required this.onSelected});

  final ValueChanged<BestStocksCapType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Get best stocks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkblue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a category to run the live stock scanner.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.grey.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 18),
              ...BestStocksCapType.values.map(
                (cap) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CapOptionTile(
                    label: cap.label,
                    onTap: () => onSelected(cap),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapOptionTile extends StatelessWidget {
  const _CapOptionTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 20,
                color: AppColors.lightblue.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkblue,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.grey.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
