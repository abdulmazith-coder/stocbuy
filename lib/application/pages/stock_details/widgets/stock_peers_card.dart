
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/stock_details_controller.dart';
import 'package:stocbuy_application/application/models/peer_company.dart';
import 'package:stocbuy_application/application/navigation/stock_details_route.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// "Peer Companies" card — surfaces stocks the backend has classified as
/// peers (same sector / industry) for the active symbol.
///
/// Rendered below the About card on the Stock Details page. Each row is
/// tappable and navigates to that peer's own Stock Details page.
///
/// Column set:
///   • # · Symbol · Price · Today % · P/E · EPS · Market cap · Promoter %
///
/// Mobile drops the last two columns (EPS + Promoter %) to keep the table
/// readable on a 360-px viewport without horizontal scrolling.
class StockPeersCard extends StatelessWidget {
  const StockPeersCard({super.key, required this.controller});

  final StockDetailsController controller;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 20,
              mobile ? 16 : 20,
              mobile ? 16 : 20,
              mobile ? 14 : 16,
            ),
            child: Obx(() {
              final count = controller.peers.length;
              return Row(
                children: [
                  Icon(
                    Icons.groups_2_rounded,
                    color: AppColors.darkblue.withValues(alpha: 0.85),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Peer Companies',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: mobile ? 15 : 16.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkblue,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightblue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.lightblue,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.55),
          ),
          Obx(() {
            if (controller.isLoadingPeers.value &&
                controller.peers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.lightblue),
                    ),
                  ),
                ),
              );
            }
            if (controller.peers.isEmpty) {
              return _EmptyPeers(
                unavailable: controller.peersUnavailable.value,
              );
            }
            return _PeersTable(
              peers: controller.peers.toList(growable: false),
              selfSymbol: controller.symbol.toUpperCase(),
              mobile: mobile,
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyPeers extends StatelessWidget {
  const _EmptyPeers({this.unavailable = false});

  /// `true` once the controller has tried and confirmed the backend has
  /// no peers payload for this symbol — surfaces a clearer message
  /// instead of the optimistic "Loading peers…" placeholder.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final text = unavailable
        ? "We couldn't find any peer companies for this stock."
        : 'Loading peers…';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PeersTable extends StatelessWidget {
  const _PeersTable({
    required this.peers,
    required this.selfSymbol,
    required this.mobile,
  });

  final List<PeerCompany> peers;

  /// The page's own symbol — that row is rendered with a subtle "you"
  /// pill so users can locate it among the peers at a glance.
  final String selfSymbol;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Column widths sum to a min width — anything narrower scrolls
        // horizontally so the table is never clipped.
        final hasExtras = !mobile;
        final cols = <_PeerCol>[
          const _PeerCol('#', 38, _PeerAlign.center),
          const _PeerCol('Symbol', 124, _PeerAlign.start),
          const _PeerCol('Price', 96, _PeerAlign.end),
          const _PeerCol('Today %', 90, _PeerAlign.end),
          const _PeerCol('P/E', 70, _PeerAlign.end),
          if (hasExtras) const _PeerCol('EPS', 76, _PeerAlign.end),
          const _PeerCol('Market cap', 128, _PeerAlign.end),
          if (hasExtras) const _PeerCol('Promoter %', 92, _PeerAlign.end),
        ];
        final tableW =
            cols.fold<double>(0, (sum, col) => sum + col.width) + 16;
        final viewportW = c.maxWidth;
        final useScroll = tableW > viewportW;

        final table = SizedBox(
          width: useScroll ? tableW : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(cols: cols),
              for (var i = 0; i < peers.length; i++)
                _PeerRow(
                  cols: cols,
                  peer: peers[i],
                  rank: i + 1,
                  isLast: i == peers.length - 1,
                  isSelf: peers[i].symbol.toUpperCase() == selfSymbol,
                ),
            ],
          ),
        );

        if (useScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            child: table,
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: table,
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.cols});

  final List<_PeerCol> cols;

  static const _hdrStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: AppColors.grey,
    letterSpacing: 0.4,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.55),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      child: Row(
        children: [
          for (final col in cols)
            SizedBox(
              width: col.width,
              child: Align(
                alignment: col.align.alignment,
                child: Text(
                  col.label,
                  style: _hdrStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeerRow extends StatefulWidget {
  const _PeerRow({
    required this.cols,
    required this.peer,
    required this.rank,
    required this.isLast,
    required this.isSelf,
  });

  final List<_PeerCol> cols;
  final PeerCompany peer;
  final int rank;
  final bool isLast;
  final bool isSelf;

  @override
  State<_PeerRow> createState() => _PeerRowState();
}

class _PeerRowState extends State<_PeerRow> {
  bool _hover = false;

  Future<void> _openPeer() async {
    // Tapping the page's own row would just reload it — skip.
    if (widget.isSelf) return;
    await openStockDetails(
      context,
      symbol: widget.peer.symbol,
      companyName: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isSelf
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = !widget.isSelf),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: widget.isSelf
              ? AppColors.lightblue.withValues(alpha: 0.05)
              : (_hover
                  ? AppColors.surfaceMuted.withValues(alpha: 0.55)
                  : Colors.transparent),
          border: Border(
            bottom: widget.isLast
                ? BorderSide.none
                : BorderSide(
                    color: AppColors.border.withValues(alpha: 0.45),
                  ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openPeer,
            hoverColor: Colors.transparent,
            splashColor: AppColors.lightblue.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              child: Row(
                children: [
                  for (final col in widget.cols)
                    SizedBox(
                      width: col.width,
                      child: _cellFor(col),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cellFor(_PeerCol col) {
    final peer = widget.peer;
    Widget body;
    switch (col.label) {
      case '#':
        body = Text(
          '${widget.rank}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.grey,
          ),
        );
      case 'Symbol':
        body = _SymbolCell(symbol: peer.symbol, isSelf: widget.isSelf);
      case 'Price':
        body = _MonoText(
          text: _formatPrice(peer.ltp),
          bold: true,
          align: col.align,
        );
      case 'Today %':
        body = Align(
          alignment: col.align.alignment,
          child: _PctPill(value: peer.pChange),
        );
      case 'P/E':
        body = _MonoText(text: _formatRatio(peer.pe), align: col.align);
      case 'EPS':
        body = _MonoText(text: _formatRatio(peer.eps), align: col.align);
      case 'Market cap':
        body = _MonoText(text: _formatMarketCap(peer.marketCap), align: col.align);
      case 'Promoter %':
        body = _MonoText(
          text: _formatPercent(peer.promoterHolding),
          align: col.align,
        );
      default:
        body = const SizedBox.shrink();
    }
    return Align(alignment: col.align.alignment, child: body);
  }
}

class _SymbolCell extends StatelessWidget {
  const _SymbolCell({required this.symbol, required this.isSelf});

  final String symbol;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            symbol.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.darkblue,
              letterSpacing: 0.1,
            ),
          ),
        ),
        if (isSelf) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lightblue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'YOU',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.lightblue,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MonoText extends StatelessWidget {
  const _MonoText({required this.text, required this.align, this.bold = false});

  final String text;
  final _PeerAlign align;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final muted = text == '—';
    return Text(
      text,
      textAlign: align.textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
        color: muted
            ? AppColors.grey.withValues(alpha: 0.7)
            : AppColors.darkblue,
        letterSpacing: -0.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _PctPill extends StatelessWidget {
  const _PctPill({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const Text(
        '—',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.grey,
        ),
      );
    }
    final up = value! > 0;
    final flat = value == 0;
    final color = flat
        ? AppColors.grey
        : (up ? AppColors.green : AppColors.red);
    final arrow = flat ? '' : (up ? '▲ ' : '▼ ');
    final sign = up ? '+' : '';
    return Text(
      '$arrow$sign${value!.toStringAsFixed(2)}%',
      maxLines: 1,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _PeerCol {
  const _PeerCol(this.label, this.width, this.align);

  final String label;
  final double width;
  final _PeerAlign align;
}

enum _PeerAlign {
  start,
  center,
  end;

  Alignment get alignment {
    switch (this) {
      case _PeerAlign.start:
        return Alignment.centerLeft;
      case _PeerAlign.center:
        return Alignment.center;
      case _PeerAlign.end:
        return Alignment.centerRight;
    }
  }

  TextAlign get textAlign {
    switch (this) {
      case _PeerAlign.start:
        return TextAlign.left;
      case _PeerAlign.center:
        return TextAlign.center;
      case _PeerAlign.end:
        return TextAlign.right;
    }
  }
}

// —— Formatters ——————————————————————————————————————————————————————————

String _formatPrice(double? v) {
  if (v == null || !v.isFinite || v == 0) return '—';
  return '₹${_groupIndianFloat(v, decimals: 2)}';
}

String _formatRatio(double? v) {
  if (v == null || !v.isFinite || v == 0) return '—';
  if (v.abs() >= 1000) return v.toStringAsFixed(0);
  if (v.abs() >= 100) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}

String _formatPercent(double? v) {
  if (v == null || !v.isFinite || v == 0) return '—';
  return '${v.toStringAsFixed(2)}%';
}

/// ₹ Cr / L / K — Indian compact rupee, same convention as the rest
/// of the app.
String _formatMarketCap(num? v) {
  if (v == null) return '—';
  final d = v.toDouble();
  if (!d.isFinite || d == 0) return '—';
  final neg = d < 0;
  final abs = d.abs();
  String body;
  if (abs >= 1e7) {
    body = '₹${_groupIndianInt((abs / 1e7).round())} Cr';
  } else if (abs >= 1e5) {
    body = '₹${(abs / 1e5).toStringAsFixed(2)} L';
  } else if (abs >= 1e3) {
    body = '₹${(abs / 1e3).toStringAsFixed(1)} K';
  } else {
    body = '₹${abs.toStringAsFixed(0)}';
  }
  return neg ? '-$body' : body;
}

String _groupIndianInt(int v) {
  final s = v.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buf = StringBuffer();
  for (var i = 0; i < rest.length; i++) {
    if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
    buf.write(rest[i]);
  }
  return '$buf,$last3';
}

String _groupIndianFloat(double v, {int decimals = 2}) {
  final neg = v < 0;
  final abs = v.abs();
  final fixed = abs.toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  final intPart = dot < 0 ? fixed : fixed.substring(0, dot);
  final fracPart = dot < 0 ? '' : fixed.substring(dot);
  final grouped = _groupIndianInt(int.parse(intPart));
  return '${neg ? '-' : ''}$grouped$fracPart';
}
