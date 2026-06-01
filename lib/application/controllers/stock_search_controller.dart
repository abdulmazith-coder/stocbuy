import 'dart:async';

import 'package:get/get.dart';
import 'package:stocbuy_application/application/models/stock_search_suggestion.dart';
import 'package:stocbuy_application/application/networks/dio/features_dio/search_stocks.dart';

class StockSearchController extends GetxController {
  StockSearchController({SearchStocksDio? dio}) : _dio = dio ?? SearchStocksDio();

  final SearchStocksDio _dio;

  final query = ''.obs;
  final suggestions = <StockSearchSuggestion>[].obs;
  /// `all` | `nse` | `bse` — filters merged rows by listing.
  final filterExchange = 'all'.obs;
  final isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final selectedIndex = 0.obs;

  Timer? _debounce;

  static const Duration _debounceDelay = Duration(milliseconds: 360);

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      suggestions.clear();
      filterExchange.value = 'all';
      errorMessage.value = null;
      isLoading.value = false;
      selectedIndex.value = -1;
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    _debounce = Timer(_debounceDelay, () => unawaited(_fetch(trimmed)));
  }

  Future<void> _fetch(String q) async {
    try {
      final list = await _dio.searchStocks(q);
      suggestions.assignAll(mergeStockSearchResults(list));
      _syncSelectionToVisible();
    } catch (e) {
      errorMessage.value = e.toString();
      suggestions.clear();
      selectedIndex.value = -1;
    } finally {
      isLoading.value = false;
    }
  }

  List<StockSearchSuggestion> get visibleRows {
    filterExchange.value;
    switch (filterExchange.value) {
      case 'nse':
        return suggestions
            .where((s) => s.exchangesLine.toUpperCase().contains('NSE'))
            .toList();
      case 'bse':
        return suggestions
            .where((s) => s.exchangesLine.toUpperCase().contains('BSE'))
            .toList();
      default:
        return suggestions.toList();
    }
  }

  void setExchangeFilter(String value) {
    filterExchange.value = value;
    _syncSelectionToVisible();
  }

  void _syncSelectionToVisible() {
    final rows = visibleRows;
    selectedIndex.value = rows.isEmpty ? -1 : 0;
  }

  void selectIndex(int index) {
    final rows = visibleRows;
    if (index >= 0 && index < rows.length) {
      selectedIndex.value = index;
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
