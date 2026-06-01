import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/stock_search_controller.dart';
import 'package:stocbuy_application/application/controllers/top_gain_loss_controller.dart';
import 'package:stocbuy_application/application/models/stock_search_result.dart';
import 'package:stocbuy_application/application/models/stock_search_suggestion.dart';
import 'package:stocbuy_application/application/models/top_company.dart';
import 'package:stocbuy_application/application/responsive/responsive.dart';
import 'package:stocbuy_application/application/themes/colors.dart';
import 'package:stocbuy_application/application/utils/stock_formatters.dart';

/// Opens stock search: bottom sheet on mobile/tablet, centered dialog on desktop.
/// Returns the selected [StockSearchResult], or null if dismissed.
Future<StockSearchResult?> showStocksSearchOverlay(BuildContext context) async {
  if (Responsive.isDesktop(context)) {
    return showDialog<StockSearchResult?>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => const _DesktopStocksSearchDialog(),
    );
  }

  final h = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<StockSearchResult?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => SizedBox(
      height: h * 0.92,
      child: const _SheetStocksSearch(layout: _SearchSurfaceLayout.mobileOrTablet),
    ),
  );
}

class _DesktopStocksSearchDialog extends StatelessWidget {
  const _DesktopStocksSearchDialog();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width < 640 ? width - 32 : 600.0;

    final screenH = MediaQuery.sizeOf(context).height;
    final dialogHeight = (screenH * 0.82).clamp(480.0, 660.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: maxWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                blurRadius: 44,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            child: const _SheetStocksSearch(layout: _SearchSurfaceLayout.desktopDialog),
          ),
        ),
      ),
    );
  }
}

enum _SearchSurfaceLayout { mobileOrTablet, desktopDialog }

class _SheetStocksSearch extends StatefulWidget {
  const _SheetStocksSearch({required this.layout});

  final _SearchSurfaceLayout layout;

  @override
  State<_SheetStocksSearch> createState() => _SheetStocksSearchState();
}

class _SheetStocksSearchState extends State<_SheetStocksSearch> {
  late final String _controllerTag;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  StockSearchController get _c => Get.find<StockSearchController>(tag: _controllerTag);

  @override
  void initState() {
    super.initState();
    _controllerTag = 'stock_search_${identityHashCode(this)}';
    Get.put(StockSearchController(), tag: _controllerTag);
    if (Get.isRegistered<TopGainLossController>()) {
      unawaited(Get.find<TopGainLossController>().ensureGainersLoaded());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _pickTopCompany(TopCompany company) {
    final name = company.companyName?.trim();
    _textController.text = name != null && name.isNotEmpty
        ? name
        : company.symbol.toUpperCase();
    _c.onQueryChanged(_textController.text);
    _popWith(
      StockSearchResult(
        symbol: company.symbol,
        longname: company.companyName,
        shortname: company.companyName,
      ),
    );
  }

  void _typeRecentSearch(String label) {
    _textController.text = label;
    _c.onQueryChanged(label);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    Get.delete<StockSearchController>(tag: _controllerTag);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _popWith(StockSearchResult? result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final isDesktop = widget.layout == _SearchSurfaceLayout.desktopDialog;
    final showBack = !isDesktop;
    final showDragHandle = widget.layout == _SearchSurfaceLayout.mobileOrTablet;

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDragHandle) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
        _SearchChrome(
          focusNode: _focusNode,
          textController: _textController,
          onQueryChanged: _c.onQueryChanged,
          showBack: showBack,
          onBack: () => _popWith(null),
          onClose: () => _popWith(null),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        Obx(() {
          if (_c.isLoading.value) {
            return const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Color(0xFFF3F4F6),
              color: AppColors.lightblue,
            );
          }
          return const SizedBox(height: 2);
        }),
        Expanded(
          child: _SuggestionsScrollView(
            controllerTag: _controllerTag,
            onSelect: _popWith,
            onPickTopCompany: _pickTopCompany,
            onTypeRecentSearch: _typeRecentSearch,
          ),
        ),
      ],
    );

    if (widget.layout == _SearchSurfaceLayout.mobileOrTablet && isTablet) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: body,
        ),
      );
    }

    return Material(
      color: Colors.white,
      child: body,
    );
  }
}

class _SearchChrome extends StatelessWidget {
  const _SearchChrome({
    required this.focusNode,
    required this.textController,
    required this.onQueryChanged,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });

  final FocusNode focusNode;
  final TextEditingController textController;
  final ValueChanged<String> onQueryChanged;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  void _clearField() {
    textController.clear();
    onQueryChanged('');
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
              color: const Color(0xFF111827),
              tooltip: 'Back',
            )
          else
            const SizedBox(width: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.search_rounded, size: 22, color: Colors.grey.shade500),
                  ),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.search,
                      onChanged: onQueryChanged,
                      style: const TextStyle(
                        color: AppColors.darkblue,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search stocks, indices, mutual funds…',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          ListenableBuilder(
            listenable: textController,
            builder: (context, _) {
              if (textController.text.isEmpty) {
                return const SizedBox.shrink();
              }
              if (showBack) {
                return IconButton(
                  onPressed: _clearField,
                  icon: const Icon(Icons.clear_rounded, size: 22),
                  color: const Color(0xFF6B7280),
                  tooltip: 'Clear',
                );
              }
              return TextButton.icon(
                onPressed: _clearField,
                icon: Icon(Icons.cleaning_services_outlined, size: 18, color: Colors.grey.shade700),
                label: Text(
                  'Clear',
                  style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              );
            },
          ),
          if (!showBack)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              color: const Color(0xFF9CA3AF),
              tooltip: 'Close',
            ),
        ],
      ),
    );
  }
}

class _SuggestionsScrollView extends StatelessWidget {
  const _SuggestionsScrollView({
    required this.controllerTag,
    required this.onSelect,
    required this.onPickTopCompany,
    required this.onTypeRecentSearch,
  });

  final String controllerTag;
  final ValueChanged<StockSearchResult?> onSelect;
  final ValueChanged<TopCompany> onPickTopCompany;
  final ValueChanged<String> onTypeRecentSearch;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<StockSearchController>(tag: controllerTag);
    final horizontal = Responsive.value(
      context,
      mobile: 16.0,
      tablet: 20.0,
      desktop: 20.0,
    );

    return Obx(() {
      final q = c.query.value.trim();
      final loading = c.isLoading.value;
      final err = c.errorMessage.value;
      final items = c.visibleRows;
      final selected = c.selectedIndex.value;

      if (q.isEmpty) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _SearchIdleContent(
                horizontal: horizontal,
                onPickTopCompany: onPickTopCompany,
                onTypeRecentSearch: onTypeRecentSearch,
              ),
            ),
          ],
        );
      }

      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 10),
              child: _ExchangeFilterChips(controllerTag: controllerTag),
            ),
          ),
          if (c.suggestions.isNotEmpty || loading || err != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 6),
                child: Text(
                  'Stocks',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          if (err != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Text(
                  err,
                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 14),
                ),
              ),
            )
          else if (!loading && items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Text(
                  'No symbols match your search.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  final isSelected = selected == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SymbolSuggestionTile(
                      item: item,
                      selected: isSelected,
                      onHover: () => c.selectIndex(index),
                      onTap: () => onSelect(item.primaryResult),
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _ExchangeFilterChips extends StatelessWidget {
  const _ExchangeFilterChips({required this.controllerTag});

  final String controllerTag;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<StockSearchController>(tag: controllerTag);
    return Obx(() {
      final cur = c.filterExchange.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              selected: cur == 'all',
              onTap: () => c.setExchangeFilter('all'),
            ),
            _FilterChip(
              label: 'NSE',
              selected: cur == 'nse',
              onTap: () => c.setExchangeFilter('nse'),
            ),
            _FilterChip(
              label: 'BSE',
              selected: cur == 'bse',
              onTap: () => c.setExchangeFilter('bse'),
            ),
          ],
        ),
      );
    });
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? const Color(0xFF2563EB) : const Color(0xFF374151),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Idle state ────────────────────────────────────────────────────────────

class _SearchIdleContent extends StatelessWidget {
  const _SearchIdleContent({
    required this.horizontal,
    required this.onPickTopCompany,
    required this.onTypeRecentSearch,
  });

  final double horizontal;
  final ValueChanged<TopCompany> onPickTopCompany;
  final ValueChanged<String> onTypeRecentSearch;

  static const _recentSearches = [
    'Reliance Industries',
    'Zomato',
    'HDFC Bank',
    'NIFTY 50',
  ];

  static const _sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.grey,
    letterSpacing: 0.3,
  );

  static const _sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.darkblue,
  );

  @override
  Widget build(BuildContext context) {
    final h = horizontal;
    final tgl = Get.isRegistered<TopGainLossController>()
        ? Get.find<TopGainLossController>()
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),

          const Text('Recent Searches', style: _sectionLabel),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches
                .map(
                  (s) => _RecentSearchChip(
                    label: s,
                    onTap: () => onTypeRecentSearch(s),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 22),

          Row(
            children: const [
              Text('Top Gainers', style: _sectionTitle),
              SizedBox(width: 6),
              Text('🔥', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          if (tgl == null)
            const _TopGainersLoadingRow()
          else
            Obx(() {
              final gainers = tgl.gainersNse.take(4).toList();
              if (tgl.isLoadingGainers.value && gainers.isEmpty) {
                return const _TopGainersLoadingRow();
              }
              if (gainers.isEmpty) {
                return const Text(
                  'Top gainers will appear here shortly.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, c) {
                  const gap = 10.0;
                  final cols = c.maxWidth > 360 ? 4 : 2;
                  final cardW = (c.maxWidth - (gap * (cols - 1))) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: gainers
                        .map(
                          (company) => SizedBox(
                            width: cardW,
                            child: _TopGainerCard(
                              company: company,
                              onTap: () => onPickTopCompany(company),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              );
            }),

          const SizedBox(height: 22),

          Row(
            children: const [
              Text('Trending Stocks', style: _sectionTitle),
              SizedBox(width: 6),
              Text('🔥', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          if (tgl == null)
            const SizedBox.shrink()
          else
            Obx(() {
              final trending = tgl.gainersNse.take(4).toList();
              if (trending.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  for (var i = 0; i < trending.length; i++)
                    _TrendingStockTile(
                      rank: i + 1,
                      company: trending[i],
                      onTap: () => onPickTopCompany(trending[i]),
                    ),
                ],
              );
            }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _TopGainersLoadingRow extends StatelessWidget {
  const _TopGainersLoadingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.lightblue,
          ),
        ),
      ),
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  const _RecentSearchChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.darkblue,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopGainerCard extends StatelessWidget {
  const _TopGainerCard({
    required this.company,
    required this.onTap,
  });

  final TopCompany company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final up = company.changePercent >= 0;
    final color = up ? AppColors.green : AppColors.red;
    final bgColor =
        up ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final change = StockFormatters.percent(company.changePercent);
    final price = StockFormatters.price(company.currentPrice);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                company.symbol.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkblue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkblue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingStockTile extends StatelessWidget {
  const _TrendingStockTile({
    required this.rank,
    required this.company,
    required this.onTap,
  });

  final int rank;
  final TopCompany company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final up = company.changePercent >= 0;
    final color = up ? AppColors.green : AppColors.red;
    final name = company.companyName?.trim().isNotEmpty == true
        ? company.companyName!.trim()
        : company.symbol.toUpperCase();
    final sector = company.sector?.trim().isNotEmpty == true
        ? company.sector!
        : '—';
    final mcap = StockFormatters.compactRupees(company.marketCap);
    final vol = StockFormatters.compactNumber(company.volume);
    final price = StockFormatters.price(company.currentPrice);
    final change = StockFormatters.percent(company.changePercent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + symbol + sector
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkblue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              company.symbol.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sector,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // MCap + Vol
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'MCap $mcap',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vol(24h) $vol',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkblue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Existing symbol suggestion tile ───────────────────────────────────────

class _SymbolSuggestionTile extends StatelessWidget {
  const _SymbolSuggestionTile({
    required this.item,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  final StockSearchSuggestion item;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  static String _avatarLetter(StockSearchSuggestion item) {
    final name = item.companyLine.trim();
    if (name.isNotEmpty) {
      final ch = name.characters.first;
      return ch.toUpperCase();
    }
    final sym = item.headlineSymbol.trim();
    if (sym.isNotEmpty) return sym.characters.first.toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        onHover: (hovered) {
          if (hovered) onHover();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.lightblue : const Color(0xFFE5E7EB),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              if (!selected)
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFF3F4F6),
                child: Text(
                  _avatarLetter(item),
                  style: const TextStyle(
                    color: AppColors.lightblue,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.companyLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.headlineSymbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.exchangesLine,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
