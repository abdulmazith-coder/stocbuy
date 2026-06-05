import yfinance as yf
from concurrent.futures import ThreadPoolExecutor, as_completed


class TopCompanies:

    # OPTIMIZED: tuple is faster than list for a fixed constant
    _TOP_COMPANIES = (
        "RELIANCE.NS", "TCS.NS", "INFY.NS", "HDFCBANK.NS", "ICICIBANK.NS",
        "SBIN.NS", "BHARTIARTL.NS", "ITC.NS", "LT.NS", "KOTAKBANK.NS",
        "HINDUNILVR.NS", "AXISBANK.NS", "BAJFINANCE.NS", "ASIANPAINT.NS",
        "MARUTI.NS", "SUNPHARMA.NS", "TITAN.NS", "ULTRACEMCO.NS",
        "WIPRO.NS", "ADANIENT.NS",
    )

    @staticmethod
    def _fetch_one(symbol: str) -> dict | None:
        """
        Fetch a single ticker and return the formatted dict.
        Returns None if data is missing or change_percent can't be computed.
        """
        try:
            info = yf.Ticker(symbol).info
            if not info:
                return None

            current_price = info.get("currentPrice")
            previous_close = info.get("previousClose")

            # OPTIMIZED: guard against None / zero before dividing
            if current_price is None or not previous_close:
                return None

            change_percent = (current_price - previous_close) / previous_close * 100

            return {
                "company": (info.get("symbol") or symbol).replace(".NS", ""),
                "current_price": current_price,
                "change_percent": round(change_percent, 2),
            }
        except Exception:
            return None

    def get_top_companies(self) -> list[dict]:
        """
        OPTIMIZED: fetch all 20 tickers in parallel instead of sequentially.
        Sequential: ~20 × 0.5–1 s = 10–20 s total.
        Parallel (20 workers): ~0.5–1 s total (limited by the slowest single call).
        Output format is identical to the original.
        """
        results = []

        with ThreadPoolExecutor(max_workers=20) as executor:
            future_map = {
                executor.submit(self._fetch_one, symbol): symbol
                for symbol in self._TOP_COMPANIES
            }
            for future in as_completed(future_map):
                data = future.result()
                if data is not None:
                    results.append(data)

        # OPTIMIZED: restore original list order (as_completed is unordered)
        order = {s.replace(".NS", ""): i for i, s in enumerate(self._TOP_COMPANIES)}
        results.sort(key=lambda x: order.get(x["company"], 999))

        return results