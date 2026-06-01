import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/models/stock_detail.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/stock_formatters.dart';

/// "About the company" card — long business summary that collapses to ~5
/// lines on mobile (read-more toggle) plus a small key-people grid built
/// from [StockDetail.officers].
class StockAboutCard extends StatefulWidget {
  const StockAboutCard({super.key, required this.detail});

  final StockDetail detail;

  @override
  State<StockAboutCard> createState() => _StockAboutCardState();
}

class _StockAboutCardState extends State<StockAboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final body = widget.detail.longBusinessSummary?.trim() ?? '';
    final hasBody = body.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(mobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.business_rounded,
                  color: AppColors.darkblue.withValues(alpha: 0.85),
                  size: 18,
                ),
                const SizedBox(width: 8),
                // Wrap in Expanded so long names like "Oil and Natural Gas
                // Corporation Limited" can ellipsise instead of pushing the
                // row past the card edge on the narrow desktop column.
                Expanded(
                  child: Text(
                    'About ${widget.detail.displayName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mobile ? 15 : 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkblue,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasBody)
              Text(
                'Company overview will appear here once it loads.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.grey,
                  fontWeight: FontWeight.w500,
                ),
              )
            else ...[
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  body,
                  maxLines: mobile ? 5 : 7,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(mobile),
                ),
                secondChild: Text(body, style: _bodyStyle(mobile)),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Read less' : 'Read more',
                    style: TextStyle(
                      color: AppColors.lightblue,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ],
            if (widget.detail.officers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 14),
              Text(
                'Key people',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth < 360
                      ? 1
                      : c.maxWidth < 560
                          ? 2
                          : 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final o in widget.detail.officers)
                        SizedBox(
                          width: (c.maxWidth - (cols - 1) * 12) / cols,
                          child: _OfficerTile(officer: o),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _bodyStyle(bool mobile) => TextStyle(
        fontSize: mobile ? 13 : 13.5,
        color: AppColors.darkblue.withValues(alpha: 0.85),
        height: 1.6,
        fontWeight: FontWeight.w500,
      );
}

class _OfficerTile extends StatelessWidget {
  const _OfficerTile({required this.officer});

  final StockOfficer officer;

  @override
  Widget build(BuildContext context) {
    final initials = officer.name
        .split(' ')
        .where((p) => p.isNotEmpty && p[0].toUpperCase() != p[0].toLowerCase())
        .take(2)
        .map((p) => p[0])
        .join();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.lightblue.withValues(alpha: 0.12),
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.lightblue,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  officer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkblue,
                    letterSpacing: -0.1,
                  ),
                ),
                if (officer.title != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    officer.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (officer.totalPay != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    StockFormatters.compactRupees(officer.totalPay),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.darkblue.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
