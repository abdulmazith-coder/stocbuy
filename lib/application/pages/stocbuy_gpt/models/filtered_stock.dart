import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stocbuy_application/application/networks/dio/auth_dio/secure_storage.dart';
import 'package:stocbuy_application/application/pages/stocbuy_gpt/models/best_stocks_cap_type.dart';

// ─── helper ────────────────────────────────────────────────────────────────

/// Sanitized email → safe for use inside a storage key.
Future<String> _currentUserKey() async {
  final email = await SecureStorage.getUserEmail();
  return email.isNotEmpty
      ? email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
      : 'guest';
}

// ─── FilteredStock ──────────────────────────────────────────────────────────

@immutable
class FilteredStock {
  const FilteredStock({
    required this.symbol,
    required this.name,
    required this.sector,
    required this.price,
    this.eps,
    this.pe,
    this.roe,
    this.revenueGrowth,
    this.profitMargin,
    this.operatingMargin,
    this.debtEquity,
    this.pb,
    this.institution,
    this.currentRatio,
    this.marketCapCr,
    this.volume,
    this.change52w,
  });

  final String symbol;
  final String name;
  final String sector;
  final double price;
  final double? eps;
  final double? pe;
  final double? roe;
  final double? revenueGrowth;
  final double? profitMargin;
  final double? operatingMargin;
  final double? debtEquity;
  final double? pb;
  final double? institution;
  final double? currentRatio;
  final double? marketCapCr;
  final double? volume;
  final double? change52w;

  factory FilteredStock.fromJson(Map<String, dynamic> json) {
    return FilteredStock(
      symbol: '${json['symbol'] ?? ''}',
      name: '${json['name'] ?? ''}',
      sector: '${json['sector'] ?? ''}',
      price: _toDouble(json['price']),
      eps: _toDoubleOrNull(json['eps']),
      pe: _toDoubleOrNull(json['pe']),
      roe: _toDoubleOrNull(json['roe']),
      revenueGrowth: _toDoubleOrNull(json['revenue_growth']),
      profitMargin: _toDoubleOrNull(json['profit_margin']),
      operatingMargin: _toDoubleOrNull(json['operating_margin']),
      debtEquity: _toDoubleOrNull(json['debt_equity']),
      pb: _toDoubleOrNull(json['pb']),
      institution: _toDoubleOrNull(json['institution']),
      currentRatio: _toDoubleOrNull(json['current_ratio']),
      marketCapCr: _toDoubleOrNull(json['market_cap_cr']),
      volume: _toDoubleOrNull(json['volume']),
      change52w: _toDoubleOrNull(json['change_52w']),
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'sector': sector,
        'price': price,
        'eps': eps,
        'pe': pe,
        'roe': roe,
        'revenue_growth': revenueGrowth,
        'profit_margin': profitMargin,
        'operating_margin': operatingMargin,
        'debt_equity': debtEquity,
        'pb': pb,
        'institution': institution,
        'current_ratio': currentRatio,
        'market_cap_cr': marketCapCr,
        'volume': volume,
        'change_52w': change52w,
      };

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }
}

// ─── BestStocksCachePayload ─────────────────────────────────────────────────

@immutable
class BestStocksCachePayload {
  const BestStocksCachePayload({
    required this.capType,
    required this.savedAt,
    required this.totalGoodStocks,
    required this.stocks,
  });

  final BestStocksCapType capType;
  final DateTime savedAt;
  final int totalGoodStocks;
  final List<FilteredStock> stocks;

  Map<String, dynamic> toJson() => {
        'cap_type': capType.apiValue,
        'saved_at': savedAt.toIso8601String(),
        'total_good_stocks': totalGoodStocks,
        'good_stocks': stocks.map((s) => s.toJson()).toList(),
      };

  factory BestStocksCachePayload.fromJson(Map<String, dynamic> json) {
    final cap = BestStocksCapType.fromApiValue('${json['cap_type'] ?? ''}') ??
        BestStocksCapType.growth;
    final list = json['good_stocks'];
    final stocks = <FilteredStock>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          stocks.add(FilteredStock.fromJson(item));
        } else if (item is Map) {
          stocks.add(FilteredStock.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return BestStocksCachePayload(
      capType: cap,
      savedAt: DateTime.tryParse('${json['saved_at']}') ?? DateTime.now(),
      totalGoodStocks:
          (json['total_good_stocks'] as num?)?.toInt() ?? stocks.length,
      stocks: stocks,
    );
  }
}

// ─── FilterCacheService ─────────────────────────────────────────────────────

class FilterCacheService {
  FilterCacheService._();
  static final FilterCacheService instance = FilterCacheService._();

  static const _storage = FlutterSecureStorage();

  /// Key: filter_cache_{sanitizedEmail}_{capType}
  Future<String> _cacheKey(String capType) async {
    final userKey = await _currentUserKey();
    return 'filter_cache_${userKey}_$capType';
  }

  // No _ensureValidToken needed — DioClient interceptor handles it globally
  Future<void> saveFilter({
    required String capType,
    required List<FilteredStock> stocks,
    required int totalGoodStocks,
  }) async {
    final cap =
        BestStocksCapType.fromApiValue(capType) ?? BestStocksCapType.growth;
    final payload = BestStocksCachePayload(
      capType: cap,
      savedAt: DateTime.now(),
      totalGoodStocks: totalGoodStocks,
      stocks: stocks,
    );
    final key = await _cacheKey(capType);
    await _storage.write(key: key, value: jsonEncode(payload.toJson()));
  }

  Future<BestStocksCachePayload?> getFilter({required String capType}) async {
    final key = await _cacheKey(capType);
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    try {
      final payload = BestStocksCachePayload.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final today = DateTime.now();
      final savedAt = payload.savedAt;
      final isSameDay = savedAt.year == today.year &&
          savedAt.month == today.month &&
          savedAt.day == today.day;
      if (!isSameDay) {
        await clearFilter(capType: capType);
        return null;
      }
      return payload;
    } catch (_) {
      await clearFilter(capType: capType);
      return null;
    }
  }

  Future<bool> hasCachedFilter({required String capType}) async {
    final result = await getFilter(capType: capType);
    return result != null && result.stocks.isNotEmpty;
  }

  Future<void> clearFilter({required String capType}) async {
    final key = await _cacheKey(capType);
    await _storage.delete(key: key);
  }

  /// Clears all cap types for the currently logged-in user only.
  Future<void> clearAll() async {
    for (final cap in BestStocksCapType.values) {
      await clearFilter(capType: cap.apiValue);
    }
  }
}