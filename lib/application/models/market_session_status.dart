import 'package:flutter/foundation.dart';

/// Four official Indian-equity session states (NSE / BSE timetable).
///
/// UI is driven primarily by each exchange's **`yahoo_state`** from the
/// `exchange-isactive` API. `is_active` (e.g. `REGULAR`) can be stale on
/// weekends; NSE/BSE are **closed Saturday & Sunday (IST)** regardless.
///
/// | State        | Window (IST, Mon–Fri) |
/// | ------------ | --------------------- |
/// | PRE_OPEN     | 09:00 – 09:15         |
/// | OPEN         | 09:15 – 15:30         |
/// | POST_MARKET  | 15:30 – 16:00         |
/// | CLOSED       | Outside hours / weekend |
enum MarketSessionState {
  loading,
  preOpen,
  open,
  postMarket,
  closed;

  /// NSE/BSE are closed every Saturday and Sunday (IST calendar day).
  static bool isIndianMarketWeekend([DateTime? now]) {
    final ist = _toIst(now ?? DateTime.now());
    return ist.weekday == DateTime.saturday || ist.weekday == DateTime.sunday;
  }

  /// Map **`is_active`** (primary source) to a session state.
  ///
  /// Values seen from the exchange-isactive API:
  /// `PRE` → preOpen · `REGULAR` / `OPEN` → open · `POST` → postMarket · `CLOSED` → closed
  static MarketSessionState? fromIsActive(String? raw) {
    if (raw == null) return null;
    final s = raw.toUpperCase().replaceAll('-', '_').trim();
    if (s.isEmpty) return null;
    if (s == 'PRE' || s == 'PRE_MARKET' || s == 'PREMARKET') return preOpen;
    if (s == 'REGULAR' || s == 'OPEN' || s == 'NORMAL') return open;
    if (s == 'POST' ||
        s == 'POST_MARKET' ||
        s == 'POSTMARKET' ||
        s == 'POST_CLOSE') {
      return postMarket;
    }
    if (s == 'CLOSED' || s == 'CLOSE' || s == 'ENDED' || s == 'END') {
      return closed;
    }
    return null;
  }

  /// Map **`yahoo_state`** (fallback only) to a session state.
  static MarketSessionState? fromYahooState(String? raw) {
    if (raw == null) return null;
    final s = raw.toUpperCase().replaceAll('-', '_').trim();
    if (s.isEmpty) return null;
    if (s == 'PRE' ||
        s == 'PREOPEN' ||
        s == 'PRE_OPEN' ||
        s == 'PREMARKET' ||
        s == 'PRE_MARKET') {
      return preOpen;
    }
    if (s == 'OPEN' || s == 'REGULAR' || s == 'NORMAL') return open;
    if (s == 'POST' ||
        s == 'POSTMARKET' ||
        s == 'POST_MARKET' ||
        s == 'POST_CLOSE' ||
        s == 'POSTCLOSE' ||
        s == 'CLOSING') {
      return postMarket;
    }
    if (s == 'CLOSED' || s == 'CLOSE' || s == 'ENDED' || s == 'END') {
      return closed;
    }
    return null;
  }

  /// Derive the state from the IST wall clock (weekends always closed).
  static MarketSessionState fromIstClock([DateTime? now]) {
    if (isIndianMarketWeekend(now)) return closed;
    final ist = _toIst(now ?? DateTime.now());
    final minutes = ist.hour * 60 + ist.minute;
    const preOpenStart = 9 * 60;
    const openStart = 9 * 60 + 15;
    const postStart = 15 * 60 + 30;
    const closeStart = 16 * 60;
    if (minutes >= preOpenStart && minutes < openStart) return preOpen;
    if (minutes >= openStart && minutes < postStart) return open;
    if (minutes >= postStart && minutes < closeStart) return postMarket;
    return closed;
  }

  /// Weekend → closed; else `yahoo_state` (NSE → BSE); else IST clock.
  static MarketSessionState resolve(IndiaMarketStatus? status, [DateTime? now]) {
    if (isIndianMarketWeekend(now)) return closed;

    if (status != null) {
      final combined = status.combinedYahooSession();
      if (combined != null) return combined;
    }

    return fromIstClock(now);
  }

  static DateTime _toIst(DateTime t) {
    final utc = t.toUtc();
    return utc.add(const Duration(hours: 5, minutes: 30));
  }
}

/// One exchange block under `data.NSE` / `data.BSE`.
@immutable
class ExchangeSessionInfo {
  const ExchangeSessionInfo({
    required this.bucketKey,
    required this.rawIsActive,
    required this.yahooState,
    required this.marketTime,
    required this.exchangeCode,
  });

  final String bucketKey;

  /// Exchange session token from `is_active` — **primary** source for open/closed UI.
  final String rawIsActive;

  /// Yahoo feed state — fallback when `is_active` cannot be resolved.
  final String yahooState;
  final String marketTime;
  final String exchangeCode;

  /// Session derived from `is_active` (primary).
  MarketSessionState? get isActiveSession =>
      MarketSessionState.fromIsActive(rawIsActive);

  /// Session derived from `yahoo_state` (fallback).
  MarketSessionState? get yahooSession =>
      MarketSessionState.fromYahooState(yahooState);

  /// `is_active` first; falls back to `yahoo_state` if unrecognised.
  MarketSessionState? get primarySession => isActiveSession ?? yahooSession;

  /// Open only when `is_active` (or `yahoo_state` fallback) maps to a live session.
  bool get isOpenByYahoo {
    if (MarketSessionState.isIndianMarketWeekend()) return false;
    final state = primarySession;
    return state == MarketSessionState.open ||
        state == MarketSessionState.preOpen ||
        state == MarketSessionState.postMarket;
  }

  static ExchangeSessionInfo? tryParse(String bucketKey, dynamic node) {
    if (node is! Map) return null;
    final outer = Map<String, dynamic>.from(node);
    final inner = outer['is_open'];
    if (inner is! Map) return null;
    final m = Map<String, dynamic>.from(inner);
    return ExchangeSessionInfo(
      bucketKey: bucketKey,
      rawIsActive: '${m['is_active'] ?? ''}',
      yahooState: '${m['yahoo_state'] ?? ''}',
      marketTime: '${m['market_time'] ?? ''}',
      exchangeCode: '${m['exchange'] ?? ''}',
    );
  }
}

/// Full payload under `data` plus API `message`.
@immutable
class IndiaMarketStatus {
  const IndiaMarketStatus({
    required this.nse,
    required this.bse,
    required this.apiMessage,
  });

  final ExchangeSessionInfo? nse;
  final ExchangeSessionInfo? bse;
  final String apiMessage;

  /// Both exchanges must report an open Yahoo session (and not weekend).
  bool get isOpenForTrading {
    if (MarketSessionState.isIndianMarketWeekend()) return false;
    final nseOpen = nse?.isOpenByYahoo ?? false;
    final bseOpen = bse?.isOpenByYahoo ?? false;
    return nseOpen && bseOpen;
  }

  /// Single pill state from NSE/BSE `is_active` (primary) with `yahoo_state`
  /// fallback. Stricter rule: closed beats everything.
  MarketSessionState? combinedYahooSession() {
    if (MarketSessionState.isIndianMarketWeekend()) {
      return MarketSessionState.closed;
    }

    final nseState = nse?.primarySession;
    final bseState = bse?.primarySession;

    if (nseState == MarketSessionState.closed ||
        bseState == MarketSessionState.closed) {
      return MarketSessionState.closed;
    }
    if (nseState == MarketSessionState.open ||
        bseState == MarketSessionState.open) {
      return MarketSessionState.open;
    }
    if (nseState == MarketSessionState.preOpen ||
        bseState == MarketSessionState.preOpen) {
      return MarketSessionState.preOpen;
    }
    if (nseState == MarketSessionState.postMarket ||
        bseState == MarketSessionState.postMarket) {
      return MarketSessionState.postMarket;
    }
    if (nseState != null) return nseState;
    if (bseState != null) return bseState;
    return null;
  }

  static IndiaMarketStatus? tryParse(Map<String, dynamic>? data, String message) {
    if (data == null) return null;
    return IndiaMarketStatus(
      nse: ExchangeSessionInfo.tryParse('NSE', data['NSE']),
      bse: ExchangeSessionInfo.tryParse('BSE', data['BSE']),
      apiMessage: message,
    );
  }
}
