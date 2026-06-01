import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// Non-web stub for the TradingView embed. The TradingView Advanced Chart
/// widget is JS-only, so on mobile / native desktop targets we surface a
/// friendly placeholder instead of crashing the build.
class TradingViewChartView extends StatelessWidget {
  const TradingViewChartView({
    super.key,
    required this.symbol,
    this.exchange = 'BSE',
  });

  final String symbol;
  final String exchange;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'The TradingView advanced chart is only available\n'
          'on the web build of Stocbuy ($exchange:${symbol.toUpperCase()}).',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
