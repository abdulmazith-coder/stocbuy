/// Helpers for Indian equity market trading hours.
///
/// Polling window: **09:15 – 15:35 IST** on **weekdays only** (Mon–Fri).
/// Saturday and Sunday are always treated as closed (NSE/BSE holiday).
///
/// When [MarketStatusController] has loaded, **`yahoo_state`** from the API
/// (plus weekend rules) drives live polling — not `is_active` or the API
/// `message` string alone.
library;

import 'package:get/get.dart';
import 'package:stocbuy_application/application/controllers/market_status_controller.dart';
import 'package:stocbuy_application/application/models/market_session_status.dart';

const int _istOffsetMinutes = 5 * 60 + 30;
const int _marketOpenMinutes = 9 * 60 + 15;
const int _marketCloseMinutes = 15 * 60 + 35;

/// True when live quotes should refresh (Yahoo open + weekday, or IST fallback).
bool isWithinIndianMarketHours([DateTime? now]) {
  if (MarketSessionState.isIndianMarketWeekend(now)) return false;

  if (Get.isRegistered<MarketStatusController>()) {
    final mc = Get.find<MarketStatusController>();
    if (mc.hasData) {
      return mc.isOpenForTrading;
    }
    final session = mc.sessionState.value;
    if (session == MarketSessionState.open ||
        session == MarketSessionState.preOpen ||
        session == MarketSessionState.postMarket) {
      return true;
    }
    if (session == MarketSessionState.closed) {
      return false;
    }
  }

  return _isWithinIndianMarketHoursByClock(now);
}

/// Weekday IST window only — used when the market-status API has not loaded.
bool _isWithinIndianMarketHoursByClock([DateTime? now]) {
  if (MarketSessionState.isIndianMarketWeekend(now)) return false;
  final ist = _toIst(now ?? DateTime.now());
  final minutes = ist.hour * 60 + ist.minute;
  return minutes >= _marketOpenMinutes && minutes < _marketCloseMinutes;
}

/// Whether the dashboard should show the pulsing green **Live** chip.
bool isMarketLiveForUi() {
  if (MarketSessionState.isIndianMarketWeekend()) return false;

  if (Get.isRegistered<MarketStatusController>()) {
    final mc = Get.find<MarketStatusController>();
    if (mc.sessionState.value == MarketSessionState.closed) return false;
    if (mc.sessionState.value == MarketSessionState.open) return true;
    if (mc.hasData) return mc.isOpenForTrading;
  }

  return _isWithinIndianMarketHoursByClock();
}

DateTime _toIst(DateTime input) {
  final utc = input.toUtc();
  return utc.add(const Duration(minutes: _istOffsetMinutes));
}
