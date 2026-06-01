import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/market_breadth_controller.dart';
import 'package:stocbuy_application/application/themes/colors.dart';

/// Detailed market breadth display widget
/// Shows A/D ratio, sentiment, and individual stock lists
class MarketBreadthWidget extends StatefulWidget {
  const MarketBreadthWidget({super.key});

  @override
  State<MarketBreadthWidget> createState() => _MarketBreadthWidgetState();
}

class _MarketBreadthWidgetState extends State<MarketBreadthWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Breadth'),
        elevation: 0,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.darkblue,
      ),
      body: GetX<MarketBreadthController>(
        builder: (controller) {
          final breadth = controller.marketBreadth.value;

          if (breadth == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (controller.isLoading.value)
                    const CircularProgressIndicator()
                  else
                    Column(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 48,
                          color: AppColors.grey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          controller.errorMessage.value ??
                              'No market breadth data available',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => controller.refreshMarketBreadth(),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // ──── Header Card ────
              _buildHeaderCard(controller, breadth),

              // ──── Statistics Row ────
              _buildStatsRow(breadth),

              // ──── Tab Bar & Content ────
              Expanded(
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.darkblue,
                      unselectedLabelColor: AppColors.grey,
                      indicatorColor: AppColors.green,
                      tabs: const [
                        Tab(text: 'Advancers'),
                        Tab(text: 'Decliners'),
                        Tab(text: 'Unchanged'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStocksList(
                            breadth.stocks.where((s) => s.isUp).toList(),
                            'advancers',
                          ),
                          _buildStocksList(
                            breadth.stocks.where((s) => s.isDown).toList(),
                            'decliners',
                          ),
                          _buildStocksList(
                            breadth.stocks
                                .where((s) => !s.isUp && !s.isDown)
                                .toList(),
                            'unchanged',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(MarketBreadthController controller, dynamic breadth) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightWhite, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ──── Title & Update Time ────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                breadth.indexName ?? 'Market Breadth',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkblue,
                ),
              ),
              GestureDetector(
                onTap: () => controller.refreshMarketBreadth(),
                child: Obx(
                  () => Text(
                    controller.isLoading.value
                        ? 'Updating...'
                        : 'Updated ${controller.formattedLastUpdate}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ──── Breadth Ratio ────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Breadth Ratio',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      breadth.formattedBreadthRatio,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkblue,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sentiment',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getSentimentColor(
                          breadth.sentiment,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        breadth.sentiment ?? 'NEUTRAL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _getSentimentColor(breadth.sentiment),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ──── Progress Bar ────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (breadth.advancePercent * 1000).round().clamp(
                      1,
                      1000,
                    ),
                    child: Container(color: AppColors.green),
                  ),
                  Expanded(
                    flex: (breadth.declinePercent * 1000).round().clamp(
                      1,
                      1000,
                    ),
                    child: Container(
                      color: AppColors.red.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(dynamic breadth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildStatItem(
            'Total',
            breadth.totalStocks.toString(),
            AppColors.grey,
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            'Advance',
            breadth.advancers.toString(),
            AppColors.green,
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            'Decline',
            breadth.decliners.toString(),
            AppColors.red,
          ),
          const SizedBox(width: 12),
          _buildStatItem(
            'Unchanged',
            breadth.unchanged.toString(),
            AppColors.orangeAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStocksList(List<dynamic> stocks, String type) {
    if (stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_flat,
              size: 48,
              color: AppColors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No ${type.toLowerCase()} stocks',
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: stocks.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final stock = stocks[index];
        final isPositive = stock.isUp;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPositive
                ? AppColors.green.withValues(alpha: 0.05)
                : AppColors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPositive
                  ? AppColors.green.withValues(alpha: 0.3)
                  : AppColors.red.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.symbol,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkblue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stock.prevClose.toStringAsFixed(2)} → ${stock.currentClose.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 16,
                        color: isPositive ? AppColors.green : AppColors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stock.formattedChange,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isPositive ? AppColors.green : AppColors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stock.formattedChangePct}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPositive ? AppColors.green : AppColors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getSentimentColor(String? sentiment) {
    switch (sentiment) {
      case 'POSITIVE':
        return AppColors.green;
      case 'NEGATIVE':
        return AppColors.red;
      default:
        return AppColors.orangeAccent;
    }
  }
}
