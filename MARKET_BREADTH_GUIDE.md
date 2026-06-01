# Market Breadth Feature - Implementation Guide

## Overview
This document describes the **1-minute auto-update market breadth feature** implemented for the Stocbuy application. The feature fetches market breadth data (advance/decline ratio, stock movements) and updates it every minute during market hours.

## What Was Created

### 1. **Market Breadth Model** 
**File**: [lib/application/models/market_breadth.dart](lib/application/models/market_breadth.dart)

Defines data structures for market breadth information:

```dart
// Main market breadth data
MarketBreadth {
  timestamp, indexName, totalStocks, advancers, decliners, unchanged,
  breadthScore, breadthRatio, sentiment, marketStatus, stocks[], fetchedAt
}

// Individual stock in breadth data
BreadthStock {
  symbol, prevClose, currentClose, change, changePct, status (UP/DOWN/UNCHANGED)
}
```

**Features**:
- Calculates `advancePercent` and `declinePercent` automatically
- Provides formatted strings for UI display
- Includes `toJson()`/`fromJson()` for serialization
- Safe type conversion with `parseDouble()` helper

---

### 2. **API Client (DIO)**
**File**: [lib/application/networks/dio/features_dio/market_breadth_dio.dart](lib/application/networks/dio/features_dio/market_breadth_dio.dart)

Handles API communication with backend:

```dart
class MarketBreadthDio {
  Future<MarketBreadthOutcome> fetchMarketBreadth({
    String indexName = 'NIFTY 50',
  })
}
```

**Handles**:
- Nested response parsing (double-wrapped success objects)
- Error handling and validation
- Query parameters for index selection
- Skips authentication (public endpoint)

---

### 3. **State Management Controller**
**File**: [lib/application/controllers/market_breadth_controller.dart](lib/application/controllers/market_breadth_controller.dart)

GetX controller managing market breadth data with **1-minute polling**:

```dart
class MarketBreadthController extends GetxController {
  // Reactive observables
  final Rxn<MarketBreadth> marketBreadth = Rxn();
  final isLoading = false.obs;
  final lastUpdateTime = Rxn<DateTime>();
  final errorMessage = Rxn<String>();
  
  // Polling every minute
  static const Duration _pollInterval = Duration(minutes: 1);
  
  // Core methods
  Future<void> fetchMarketBreadth({bool force = false})
  Future<void> refreshMarketBreadth()
}
```

**Key Features**:

| Feature | Details |
|---------|---------|
| **Polling Interval** | 1 minute (adjustable via `_pollInterval`) |
| **Market Hours** | 9:15 AM - 3:30 PM IST, Mon-Fri only |
| **Offline Support** | Caches data in SharedPreferences |
| **Auto-Resume** | Automatically resumes polling at 9:15 AM next trading day |
| **Smart Scheduling** | Only polls when market is open |

---

### 4. **UI Integration**

#### Dashboard Update
**File**: [lib/application/widgets/dashboard_market_summary_row.dart](lib/application/widgets/dashboard_market_summary_row.dart)

Updated the `_BreadthCard` to display live data:

```dart
GetX<MarketBreadthController>(
  builder: (controller) {
    final breadth = controller.marketBreadth.value;
    return _BreadthCard(
      ratio: breadth?.breadthRatio ?? 0,
      advancers: breadth?.advancers ?? 0,
      decliners: breadth?.decliners ?? 0,
      total: breadth?.totalStocks ?? 0,
      isPositive: breadth?.isPositive ?? false,
    );
  },
)
```

**Displays**:
- A/D Ratio
- Advancer/Decliner counts
- Visual progress bar (green for up, red for down)
- Sentiment indicator

---

#### Detailed Market Breadth Widget
**File**: [lib/application/widgets/market_breadth_widget.dart](lib/application/widgets/market_breadth_widget.dart)

Complete market breadth display with tabbed interface:

**Features**:
- Breadth ratio and sentiment display
- Statistics panel (Total / Advancers / Decliners / Unchanged)
- Tabbed stock lists (Advancers / Decliners / Unchanged)
- Per-stock details (symbol, price, change %, status)
- Refresh button with loading state
- Last update timestamp

---

## Integration Steps

### Step 1: Register the Controller
Add to your GetX binding or `main.dart`:

```dart
import 'package:stocbuy_application/application/controllers/market_breadth_controller.dart';

// In your binding class:
Get.put(MarketBreadthController());

// Or in GetMaterialApp:
home: HomePage() // The controller initializes automatically when the page loads
```

### Step 2: Dashboard Display (Already Done)
The breadth card in `DashboardMarketSummaryRow` now automatically shows live data:

```dart
const _BreadthCard(ratio: 1.8, advancePct: 0.64),  // OLD - hardcoded
                          ↓↓↓
GetX<MarketBreadthController>(
  builder: (controller) {
    // Now displays live data and updates every minute
  },
)
```

### Step 3: Add Detailed View (Optional)
Navigate to detailed breadth data:

```dart
import 'package:stocbuy_application/application/widgets/market_breadth_widget.dart';

// In your navigation:
Get.to(() => const MarketBreadthWidget());

// Or add to menu:
onPressed: () => Get.to(() => const MarketBreadthWidget()),
child: const Text('Market Breadth'),
```

---

## How 1-Minute Updates Work

### Polling Architecture

```
┌─────────────────────────────────────────────────┐
│  Market Open (9:15 AM)?                         │
└─────────────────────────────────────────────────┘
         ↓ YES           ↓ NO
    ┌─────────┐    ┌──────────────────┐
    │  Start  │    │  Schedule        │
    │  1-min  │    │  next 9:15 AM    │
    │ polling │    │  (skip weekends) │
    └─────────┘    └──────────────────┘
         │
         ↓
    ┌──────────────────────────────┐
    │ Timer every 60 seconds       │
    │ Calls fetchMarketBreadth()   │
    └──────────────────────────────┘
         │
         ↓
    ┌──────────────────────────────┐
    │ Check market still open?     │
    │ (if closed, reschedule)      │
    └──────────────────────────────┘
         │
         ↓
    ┌──────────────────────────────┐
    │ Update UI via GetX reactive  │
    │ widgets automatically update  │
    └──────────────────────────────┘
```

### State Flow

```dart
// 1. Initialize (app startup)
onInit() → _bootstrap()
          ├─ _loadSavedSnapshot()  // Load cached data
          ├─ fetchMarketBreadth()  // Initial fetch
          └─ _scheduleNextPoll()   // Start polling

// 2. On each poll tick (every 1 minute)
_onPollTick()
  ├─ Check if market still open
  └─ fetchMarketBreadth()
      ├─ DioClient.get(features/market-breadth/)
      ├─ Parse response
      ├─ Update marketBreadth observable
      ├─ _saveSnapshot() to cache
      └─ UI auto-updates via GetX

// 3. On app close
onClose() → _pollTimer?.cancel()
```

---

## Usage Examples

### Example 1: Display on Dashboard
```dart
// Already integrated! The breadth card updates every minute.
```

### Example 2: Manual Refresh
```dart
final controller = Get.find<MarketBreadthController>();
await controller.refreshMarketBreadth();
```

### Example 3: Access Data Directly
```dart
final breadth = controller.marketBreadth.value;
if (breadth != null) {
  print('Ratio: ${breadth.breadthRatio}');
  print('Advancers: ${breadth.advancers}');
  print('Decliners: ${breadth.decliners}');
  print('Sentiment: ${breadth.sentiment}');
}
```

### Example 4: Reactive Builder
```dart
GetX<MarketBreadthController>(
  builder: (controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const CircularProgressIndicator();
      }
      
      final breadth = controller.marketBreadth.value;
      return Text('A/D Ratio: ${breadth?.formattedBreadthRatio ?? "--"}');
    });
  },
)
```

---

## API Response Format

Expected response from `features/market-breadth/`:

```json
{
  "success": true,
  "message": "Market breadth data fetched successfully",
  "data": {
    "success": true,
    "message": "Market breadth calculated successfully",
    "data": {
      "timestamp": "2026-05-26T07:11:11.424681+00:00",
      "indexName": "NIFTY 50",
      "totalStocks": 50,
      "advancers": 25,
      "decliners": 25,
      "unchanged": 0,
      "breadthScore": 0,
      "breadthRatio": 1.0,
      "sentiment": "NEUTRAL",
      "marketStatus": "POSITIVE_MARKET",
      "stocks": [
        {
          "symbol": "ADANIENT.NS",
          "prev_close": 2849.7,
          "current_close": 2937.3,
          "change": 87.6,
          "change_pct": 3.07,
          "status": "UP"
        },
        // ... more stocks
      ]
    }
  }
}
```

---

## Configuration

### Change Polling Interval
Edit [market_breadth_controller.dart](lib/application/controllers/market_breadth_controller.dart):

```dart
static const Duration _pollInterval = Duration(minutes: 1);  // Change to your desired interval
```

### Change Market Hours
Edit the `_isMarketOpenIst()` method:

```dart
static bool _isMarketOpenIst(tz.TZDateTime now) {
  // Default: 9:15 AM - 3:30 PM IST, Mon-Fri
  final minutes = now.hour * 60 + now.minute;
  return minutes >= 9 * 60 + 15 && minutes <= 15 * 60 + 30;
}
```

### Change Index
```dart
// Use different index
Get.put(MarketBreadthController(indexName: 'SENSEX'));
```

---

## Troubleshooting

### Data Not Updating
1. Check if controller is registered: `Get.put(MarketBreadthController())`
2. Verify API endpoint is correct: `features/market-breadth/`
3. Check market hours (9:15 AM - 3:30 PM IST, Mon-Fri)
4. Manually refresh: `controller.refreshMarketBreadth()`

### No Cached Data on Startup
- Data is cached in SharedPreferences
- First load may show "--" until API responds
- Check internet connectivity

### Widget Not Rebuilding
- Ensure using `GetX<MarketBreadthController>` widget
- Use `Obx()` for reactive properties
- Don't use `const` on widgets that depend on dynamic data

---

## File Structure

```
lib/application/
├── models/
│   └── market_breadth.dart                    ← Data models
├── controllers/
│   └── market_breadth_controller.dart          ← 1-min polling logic
├── networks/dio/features_dio/
│   └── market_breadth_dio.dart                ← API client
├── widgets/
│   ├── dashboard_market_summary_row.dart      ← Updated dashboard
│   └── market_breadth_widget.dart             ← Detailed view
```

---

## Summary

✅ **1-minute polling** - Updates every minute during market hours
✅ **Smart scheduling** - Auto-pauses after market close, resumes at 9:15 AM
✅ **Offline support** - Caches data locally
✅ **Reactive UI** - GetX automatic updates
✅ **Error handling** - Graceful fallbacks
✅ **Dashboard integration** - Live A/D ratio and visualization
✅ **Detailed widget** - Full market breadth with per-stock data
