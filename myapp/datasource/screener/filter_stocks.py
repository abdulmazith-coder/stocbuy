import yfinance as yf


class FilterStocks:


    def filter_penny_stocks(self, stocks):

        filtered_stocks = []
        total = len(stocks)

        for index, stock in enumerate(stocks, start=1):

            symbol = ""

            try:

                symbol = stock.get("symbol", "")

                if not symbol:
                    continue

                yield {
                    "type": "checking",
                    "symbol": symbol,
                    "message": f"Checking {symbol} ({index}/{total})"
                }

                info = yf.Ticker(symbol).info

                # --- Pull metrics ---
                price            = info.get("currentPrice") or info.get("regularMarketPrice")
                eps              = info.get("trailingEps")
                pe               = info.get("trailingPE")
                roe              = info.get("returnOnEquity")
                debt             = info.get("debtToEquity")
                revenue_growth   = info.get("revenueGrowth")
                profit_margin    = info.get("profitMargins")
                operating_margin = info.get("operatingMargins")
                pb               = info.get("priceToBook")
                revenue          = info.get("totalRevenue")
                inst             = info.get("heldPercentInstitutions")
                change_52w       = info.get("52WeekChange")
                market_cap       = info.get("marketCap")
                volume           = info.get("regularMarketVolume")
                current_ratio    = info.get("currentRatio")
                sector           = info.get("sector", "") or ""
                name             = info.get("shortName", "") or ""

                # =========================================
                # HARD FILTERS
                # =========================================

                # EPS CHECK
                if eps is None or eps <= 0:
                    yield {"type": "rejected", "symbol": symbol, "reason": "Bad EPS"}
                    continue

                yield {"type": "passed", "symbol": symbol, "message": "EPS passed"}

                # PE CHECK
                if pe is None or pe <= 0 or pe > 50:
                    yield {"type": "rejected", "symbol": symbol, "reason": "Bad PE Ratio"}
                    continue

                yield {"type": "passed", "symbol": symbol, "message": "PE passed"}

                # DEBT CHECK
                is_financial = sector in ("Financial Services", "Banking")
                if not is_financial and debt is not None and debt > 3.0:
                    yield {"type": "rejected", "symbol": symbol, "reason": "High Debt"}
                    continue

                yield {"type": "passed", "symbol": symbol, "message": "Debt passed"}

                # 52 WEEK CHECK
                if change_52w is not None and change_52w < -0.65:
                    yield {"type": "rejected", "symbol": symbol, "reason": "52 Week Crash"}
                    continue

                yield {"type": "passed", "symbol": symbol, "message": "52 Week passed"}

                # REVENUE CHECK
                if revenue is not None and revenue < 10_000_000:
                    yield {"type": "rejected", "symbol": symbol, "reason": "Low Revenue"}
                    continue

                yield {"type": "passed", "symbol": symbol, "message": "Revenue passed"}

                # PROFIT MARGIN CHECK
                if profit_margin is not None and profit_margin < -0.10:
                    yield {"type": "rejected", "symbol": symbol, "reason": "Bad Profit Margin"}
                    continue

                yield {"type": "passed", "symbol": symbol, "message": "Profit Margin passed"}

            
                # =========================================
                # GOOD STOCK
                # =========================================
                good_stock = {
                    "symbol":           symbol,
                    "name":             name,
                    "sector":           sector,
                    "price":            round(price, 2) if price else None,
                    "eps":              round(eps, 2) if eps else None,
                    "pe":               round(pe, 2) if pe else None,
                    "roe":              round(roe * 100, 2) if roe else None,
                    "revenue_growth":   round(revenue_growth * 100, 2) if revenue_growth else None,
                    "profit_margin":    round(profit_margin * 100, 2) if profit_margin else None,
                    "operating_margin": round(operating_margin * 100, 2) if operating_margin else None,
                    "debt_equity":      round(debt, 2) if debt else 0,
                    "pb":               round(pb, 2) if pb else None,
                    "institution":      round(inst * 100, 2) if inst else 0,
                    "current_ratio":    round(current_ratio, 2) if current_ratio else None,
                    "market_cap_cr":    round(market_cap / 10_000_000, 2) if market_cap else None,
                    "volume":           volume,
                    "change_52w":       round(change_52w * 100, 2) if change_52w else None,
                }

                filtered_stocks.append(good_stock)

                yield {
                    "type": "success",
                    "symbol": symbol,
                    "stock": good_stock
                }

            except Exception as e:

                yield {
                    "type": "error",
                    "symbol": symbol,
                    "message": str(e)
                }

        # FINAL
        yield {
            "type": "completed",
            "message": "Filtering completed",
            "total_good_stocks": len(filtered_stocks),
            "good_stocks": filtered_stocks
        }