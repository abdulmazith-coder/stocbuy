# Market Breadth Feature - Quick Start

## ✅ Implementation Complete

Your Stocbuy application now has a fully functional **market breadth feature with 1-minute auto-updates**.

## What's Been Created

### 📁 Files Created

1. **Model** - `lib/application/models/market_breadth.dart`
   - `MarketBreadth` data structure
   - `BreadthStock` for individual stocks
   - Serialization support

2. **API Client** - `lib/application/networks/dio/features_dio/market_breadth_dio.dart`
   - Fetches data from `features/market-breadth/` endpoint
   - Handles nested response parsing
   - Error handling

3. **State Controller** - `lib/application/controllers/market_breadth_controller.dart`
   - **1-minute polling** ⏱️
   - Market hours awareness (9:15 AM - 3:30 PM IST, Mon-Fri)
   - Local caching with SharedPreferences
   - Reactive GetX observables

4. **UI Widgets**
   - Updated `dashboard_market_summary_row.dart` - Shows live A/D ratio
   - New `market_breadth_widget.dart` - Detailed view with tabbed stock lists

5. **Documentation** - `MARKET_BREADTH_GUIDE.md`
   - Complete implementation guide
   - Integration steps
   - Usage examples

## 🚀 Quick Integration

### Step 1: Register Controller
```dart
// In your main.dart or binding
Get.put(MarketBreadthController());
```

### Step 2: Done! 
The dashboard breadth card now updates every minute automatically.

### Step 3 (Optional): Navigate to Detailed View
```dart
import 'package:stocbuy_application/application/widgets/market_breadth_widget.dart';

// In your navigation code
Get.to(() => const MarketBreadthWidget());
```

## 📊 Data Displayed

### Dashboard Card Shows:
- Advance/Decline (A/D) Ratio
- Advancers vs Decliners count
- Visual progress bar
- Updates every 1 minute

### Detailed Widget Shows:
- Breadth ratio and sentiment
- Statistics panel (advancers, decliners, unchanged)
- Tabbed view of individual stocks
- Per-stock: symbol, price, change %, status

## ⏲️ Update Interval

- **During Market Hours**: 9:15 AM - 3:30 PM IST, Mon-Fri
  - Updates every **1 minute** automatically
- **After Market Close**: Pauses polling
- **Next Day**: Automatically resumes at 9:15 AM

## 📱 Reactive Updates

All UI widgets automatically update when data changes - no manual refresh needed (except market breadth widget has optional refresh button).

## 🔧 Configuration

See `MARKET_BREADTH_GUIDE.md` for:
- Changing polling interval
- Modifying market hours
- Using different indices
- Troubleshooting

## 📝 API Response

Your backend should respond to `features/market-breadth/` with:
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

## ✨ Features

- ✅ 1-minute auto-update during market hours
- ✅ Smart market hours detection (IST)
- ✅ Offline support (local caching)
- ✅ Reactive UI with GetX
- ✅ Error handling and fallbacks
- ✅ Dashboard integration
- ✅ Detailed breadth widget
- ✅ Per-stock tracking
- ✅ Sentiment indicators

## 📚 Learn More

See `MARKET_BREADTH_GUIDE.md` for complete documentation including:
- Architecture details
- State flow diagrams
- Usage examples
- Troubleshooting guide

---

**Ready to go!** Just register the controller and you're all set. 🎉
