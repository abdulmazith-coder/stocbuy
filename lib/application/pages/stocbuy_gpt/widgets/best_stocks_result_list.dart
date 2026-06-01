import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/filtered_stock.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

class BestStocksResultList extends StatelessWidget {
  const BestStocksResultList({
    super.key,
    required this.stocks,
    this.fromCache = false,
    this.capLabel,
    this.onViewDetails,
    this.onAnalyze,
    this.actionsEnabled = true,
  });

  final List<FilteredStock> stocks;
  final bool fromCache;
  final String? capLabel;
  final void Function(FilteredStock stock)? onViewDetails;
  final void Function(FilteredStock stock)? onAnalyze;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightblue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${stocks.length}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.lightblue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Matched stocks',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkblue,
                        ),
                      ),
                      if (fromCache)
                        Text(
                          'Cached · valid 3 days${capLabel != null ? ' · $capLabel' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey.withValues(alpha: 0.95),
                          ),
                        )
                      else if (capLabel != null && capLabel!.isNotEmpty)
                        Text(
                          capLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.grey.withValues(alpha: 0.9),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (stocks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No stocks matched the filter criteria.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.grey.withValues(alpha: 0.95),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: List.generate(stocks.length, (i) {
                  return Padding(
                    padding:
                        EdgeInsets.only(bottom: i == stocks.length - 1 ? 0 : 10),
                    child: _StockCard(
                      stock: stocks[i],
                      rank: i + 1,
                      onViewDetails: onViewDetails,
                      onAnalyze: onAnalyze,
                      actionsEnabled: actionsEnabled,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.stock,
    required this.rank,
    this.onViewDetails,
    this.onAnalyze,
    this.actionsEnabled = true,
  });

  final FilteredStock stock;
  final int rank;
  final void Function(FilteredStock stock)? onViewDetails;
  final void Function(FilteredStock stock)? onAnalyze;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final change = stock.change52w;
    final changeColor = change == null
        ? AppColors.grey
        : change >= 0
            ? AppColors.green
            : Colors.red.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lightblue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.lightblue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.symbol.replaceAll('.BO', '').replaceAll('.NS', ''),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkblue,
                      ),
                    ),
                    Text(
                      stock.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.grey.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${stock.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkblue,
                    ),
                  ),
                  if (change != null)
                    Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}% 52w',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: changeColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (stock.pe != null) _Chip('P/E ${stock.pe!.toStringAsFixed(1)}'),
              if (stock.roe != null) _Chip('ROE ${stock.roe!.toStringAsFixed(1)}%'),
              if (stock.marketCapCr != null)
                _Chip('Mcap ₹${stock.marketCapCr!.toStringAsFixed(0)} cr'),
              if (stock.sector.isNotEmpty) _Chip(stock.sector),
            ],
          ),
          if (onViewDetails != null || onAnalyze != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onViewDetails != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: actionsEnabled
                          ? () => onViewDetails!(stock)
                          : null,
                      icon: const Icon(Icons.candlestick_chart_outlined, size: 18),
                      label: const Text('Stock details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkblue,
                        side: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.9),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (onViewDetails != null && onAnalyze != null)
                  const SizedBox(width: 8),
                if (onAnalyze != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          actionsEnabled ? () => onAnalyze!(stock) : null,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('AI analysis'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lightblue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.grey.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}
