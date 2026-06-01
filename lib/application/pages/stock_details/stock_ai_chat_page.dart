import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/pages/stock_details/widgets/stock_ai_chat.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/widgets/branding/stocbuy_brand_mark.dart';

/// Full-screen AI chat used on mobile / tablet via [StockAiChatFab].
///
/// Has its own scaffold so it presents like a focused conversation room,
/// not a panel-in-a-page. Uses a sheet-style card so the route looks like
/// it slides up from the bottom.
class StockAiChatPage extends StatelessWidget {
  const StockAiChatPage({
    super.key,
    required this.symbol,
    required this.displayName,
  });

  final String symbol;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final maxWidth = mobile ? double.infinity : 560.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: mobile ? Alignment.bottomCenter : Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: mobile
                  ? MediaQuery.sizeOf(context).height * 0.92
                  : 700,
            ),
            child: Container(
              margin: mobile
                  ? const EdgeInsets.fromLTRB(0, 24, 0, 0)
                  : const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: mobile
                    ? const BorderRadius.vertical(top: Radius.circular(20))
                    : BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                    spreadRadius: -4,
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  _ChatTopBar(
                    symbol: symbol,
                    displayName: displayName,
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: StockAiChatBody(
                      symbol: symbol,
                      displayName: displayName,
                      showHeader: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({
    required this.symbol,
    required this.displayName,
    required this.onClose,
  });

  final String symbol;
  final String displayName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          const StocbuyLogoMark(size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stock Analysis',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkblue,
                    letterSpacing: -0.1,
                  ),
                ),
                Text(
                  '$displayName · $symbol',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.grey,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}
