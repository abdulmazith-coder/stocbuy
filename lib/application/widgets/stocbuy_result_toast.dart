import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stocbuy_application/application/navigation/app_navigator.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

OverlayState? _resolveOverlay(BuildContext? context) {
  if (context != null && context.mounted) {
    final fromCtx = Overlay.maybeOf(context, rootOverlay: true);
    if (fromCtx != null) return fromCtx;
  }
  return AppNavigator.overlay;
}

/// Visual variant for [showStocbuyResultToast].
enum StocbuyToastKind {
  success,
  error,
  info,
}

OverlayEntry? _activeStocbuyToast;

/// Dismisses any toast shown via [showStocbuyResultToast].
void dismissStocbuyResultToast() {
  _activeStocbuyToast?.remove();
  _activeStocbuyToast = null;
}

/// App-wide toast: desktop & tablet = top-right card; mobile = full-width top.
/// Use [StocbuyToastKind.success], [StocbuyToastKind.error], or [StocbuyToastKind.info].
///
/// Pass the current [BuildContext] when a dialog/route is visible; after [Navigator.pop],
/// pass `null` and rely on [AppNavigator] (requires [AppNavigator.rootKey] on [GetMaterialApp]).
void showStocbuyResultToast(
  BuildContext? context, {
  required StocbuyToastKind kind,
  required String title,
  required String message,
  Duration displayDuration = const Duration(seconds: 4),
}) {
  final overlay = _resolveOverlay(context);
  if (overlay == null) return;

  _activeStocbuyToast?.remove();
  _activeStocbuyToast = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => _ToastOverlayLayer(
      kind: kind,
      title: title,
      message: message,
      onDismiss: () {
        if (_activeStocbuyToast == entry) {
          _activeStocbuyToast = null;
        }
        entry.remove();
      },
    ),
  );

  _activeStocbuyToast = entry;
  overlay.insert(entry);

  Timer(displayDuration, () {
    if (entry.mounted) {
      if (_activeStocbuyToast == entry) {
        _activeStocbuyToast = null;
      }
      entry.remove();
    }
  });
}

class _ToastOverlayLayer extends StatelessWidget {
  const _ToastOverlayLayer({
    required this.kind,
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  final StocbuyToastKind kind;
  final String title;
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final top = MediaQuery.paddingOf(context).top + (mobile ? 8 : 14);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (mobile)
            Positioned(
              top: top,
              left: 12,
              right: 12,
              child: _StocbuyToastCard(
                kind: kind,
                title: title,
                message: message,
                compact: true,
                onClose: onDismiss,
              ),
            )
          else
            Positioned(
              top: top,
              right: 16,
              child: SizedBox(
                width: 392,
                child: _StocbuyToastCard(
                  kind: kind,
                  title: title,
                  message: message,
                  compact: false,
                  onClose: onDismiss,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StocbuyToastCard extends StatelessWidget {
  const _StocbuyToastCard({
    required this.kind,
    required this.title,
    required this.message,
    required this.compact,
    required this.onClose,
  });

  final StocbuyToastKind kind;
  final String title;
  final String message;
  final bool compact;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final Color iconBg;
    final IconData iconData;

    switch (kind) {
      case StocbuyToastKind.success:
        accent = AppColors.green;
        iconBg = AppColors.greenMutedBg;
        iconData = Icons.check_rounded;
      case StocbuyToastKind.error:
        accent = AppColors.red;
        iconBg = AppColors.red.withValues(alpha: 0.12);
        iconData = Icons.error_outline_rounded;
      case StocbuyToastKind.info:
        accent = AppColors.lightblue;
        iconBg = AppColors.lightblue.withValues(alpha: 0.12);
        iconData = Icons.info_outline_rounded;
    }

    final titleStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: compact ? 14 : 15,
      color: AppColors.textPrimaryAlt,
      height: 1.2,
    );
    final bodyStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: compact ? 12.5 : 13,
      color: AppColors.grey,
      height: 1.35,
    );

    final iconSize = compact ? 34.0 : 40.0;
    final iconInner = compact ? 20.0 : 22.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkblue.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 14,
                  compact ? 12 : 14,
                  4,
                  compact ? 12 : 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: accent, size: iconInner),
                    ),
                    SizedBox(width: compact ? 10 : 12),
                    Expanded(
                      child: compact && message.trim().isEmpty
                          ? Text(title, style: titleStyle)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: titleStyle),
                                if (message.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(message, style: bodyStyle),
                                ],
                              ],
                            ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.grey.withValues(alpha: 0.85),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
