import json
from dataclasses import dataclass, asdict
from datetime import datetime, UTC
from typing import List, Dict, Any
from io import StringIO

import pandas as pd
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import yfinance as yf


# =========================================================
# CONFIG
# =========================================================

@dataclass
class MarketBreadthConfig:
    period: str = "5d"
    interval: str = "1d"


# =========================================================
# DATA MODELS
# =========================================================

@dataclass
class StockBreadthResult:
    symbol: str
    prev_close: float
    current_close: float
    change: float
    change_pct: float
    status: str


@dataclass
class MarketBreadthResult:
    timestamp: str
    index_name: str
    total_stocks: int
    advancers: int
    decliners: int
    unchanged: int
    breadth_score: int
    breadth_ratio: float
    sentiment: str
    market_status: str
    stocks: List[Dict[str, Any]]


# =========================================================
# MARKET BREADTH SERVICE
# =========================================================

class MarketBreadthService:

    def __init__(self, config: MarketBreadthConfig):
        self.config = config
        self.session = self._build_session()

    # =====================================================
    # BUILD HTTP SESSION
    # =====================================================
    def _build_session(self) -> requests.Session:

        session = requests.Session()

        retry = Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET"]
        )

        adapter = HTTPAdapter(max_retries=retry)

        session.mount("https://", adapter)
        session.mount("http://", adapter)

        return session

    # =====================================================
    # FETCH NIFTY 50 SYMBOLS
    # =====================================================
    def _get_index_symbols(self) -> List[str]:

        url = (
            "https://archives.nseindia.com/"
            "content/indices/ind_nifty50list.csv"
        )

        headers = {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            "Referer": "https://www.nseindia.com",
            "Accept": "text/csv,*/*",
        }

        try:

            response = self.session.get(
                url=url,
                headers=headers,
                timeout=20
            )

            response.raise_for_status()

            csv_data = StringIO(response.text)

            df = pd.read_csv(csv_data)

            if "Symbol" not in df.columns:
                return []

            symbols = (
                df["Symbol"]
                .dropna()
                .astype(str)
                .str.strip()
                .tolist()
            )

            yahoo_symbols = [
                f"{symbol}.NS"
                for symbol in symbols
            ]

            print(f"[INFO] Total Symbols: {len(yahoo_symbols)}")

            return yahoo_symbols

        except Exception as e:
            print(f"[ERROR] NSE Symbol Fetch Failed: {e}")
            return []

    # =====================================================
    # DOWNLOAD MARKET DATA
    # =====================================================
    def _download_market_data(self, symbols: List[str]):

        try:

            data = yf.download(
                tickers=symbols,
                period=self.config.period,
                interval=self.config.interval,
                auto_adjust=True,
                progress=False,
                threads=False,
                group_by="ticker"
            )

            if data is None or data.empty:
                print("[ERROR] Empty Market Data")
                return None

            print("[INFO] Download Success")
            print(data.columns)

            return data

        except Exception as e:
            print(f"[ERROR] Download Failed: {e}")
            return None

    # =====================================================
    # EXTRACT STOCK DATA
    # =====================================================
    def _extract_stock_df(
        self,
        symbol: str,
        market_data
    ) -> pd.DataFrame:

        try:

            # ---------------------------------------------
            # MULTI INDEX CASE
            # ---------------------------------------------
            if isinstance(
                market_data.columns,
                pd.MultiIndex
            ):

                level0 = market_data.columns.get_level_values(0)

                level1 = market_data.columns.get_level_values(1)

                # -----------------------------------------
                # CASE 1
                # RELIANCE.NS -> Close
                # -----------------------------------------
                if symbol in level0:

                    stock_df = market_data[symbol]

                    return stock_df

                # -----------------------------------------
                # CASE 2
                # Close -> RELIANCE.NS
                # -----------------------------------------
                if symbol in level1:

                    stock_df = market_data.xs(
                        symbol,
                        axis=1,
                        level=1
                    )

                    return stock_df

                return pd.DataFrame()

            # ---------------------------------------------
            # SINGLE STOCK CASE
            # ---------------------------------------------
            return market_data

        except Exception as e:
            print(f"[ERROR] Extract {symbol}: {e}")
            return pd.DataFrame()

    # =====================================================
    # ANALYZE STOCK
    # =====================================================
    def _analyze_stock(
        self,
        symbol: str,
        market_data
    ):

        try:

            stock_df = self._extract_stock_df(
                symbol=symbol,
                market_data=market_data
            )

            if stock_df.empty:
                print(f"[WARN] Empty DF: {symbol}")
                return None

            if "Close" not in stock_df.columns:
                print(f"[WARN] Close Missing: {symbol}")
                return None

            close_prices = (
                stock_df["Close"]
                .dropna()
            )

            if len(close_prices) < 2:
                print(f"[WARN] Not Enough Data: {symbol}")
                return None

            prev_close = float(close_prices.iloc[-2])

            current_close = float(close_prices.iloc[-1])

            if (
                pd.isna(prev_close)
                or pd.isna(current_close)
                or prev_close == 0
            ):
                return None

            # ---------------------------------------------
            # CALCULATE CHANGE
            # ---------------------------------------------
            change = current_close - prev_close

            change_pct = (
                (change / prev_close) * 100
            )

            # ---------------------------------------------
            # STATUS
            # ---------------------------------------------
            if current_close > prev_close:
                status = "UP"

            elif current_close < prev_close:
                status = "DOWN"

            else:
                status = "FLAT"

            return StockBreadthResult(
                symbol=symbol,
                prev_close=round(prev_close, 2),
                current_close=round(current_close, 2),
                change=round(change, 2),
                change_pct=round(change_pct, 2),
                status=status
            )

        except Exception as e:
            print(f"[ERROR] Analyze {symbol}: {e}")
            return None

    # =====================================================
    # SENTIMENT
    # =====================================================
    def _get_sentiment(
        self,
        breadth_score: int
    ) -> str:

        if breadth_score >= 20:
            return "STRONG_BULLISH"

        elif breadth_score >= 5:
            return "BULLISH"

        elif breadth_score <= -20:
            return "STRONG_BEARISH"

        elif breadth_score <= -5:
            return "BEARISH"

        return "NEUTRAL"

    # =====================================================
    # MARKET STATUS
    # =====================================================
    def _get_market_status(
        self,
        breadth_ratio: float
    ) -> str:

        if breadth_ratio >= 2:
            return "HEALTHY_MARKET"

        elif breadth_ratio >= 1:
            return "POSITIVE_MARKET"

        elif breadth_ratio < 0.7:
            return "WEAK_MARKET"

        return "SIDEWAYS_MARKET"

    # =====================================================
    # MAIN CALCULATION
    # =====================================================
    def calculate(self):

        # -------------------------------------------------
        # FETCH SYMBOLS
        # -------------------------------------------------
        symbols = self._get_index_symbols()

        if not symbols:
            return {
                "success": False,
                "message": "Unable to fetch NIFTY symbols"
            }

        # -------------------------------------------------
        # DOWNLOAD DATA
        # -------------------------------------------------
        market_data = self._download_market_data(symbols)

        if market_data is None:
            return {
                "success": False,
                "message": "Unable to download market data"
            }

        # -------------------------------------------------
        # VARIABLES
        # -------------------------------------------------
        advancers = 0
        decliners = 0
        unchanged = 0

        stock_results = []

        # -------------------------------------------------
        # PROCESS STOCKS
        # -------------------------------------------------
        for symbol in symbols:

            print(f"[INFO] Processing {symbol}")

            result = self._analyze_stock(
                symbol=symbol,
                market_data=market_data
            )

            if result is None:
                continue

            # ---------------------------------------------
            # COUNT
            # ---------------------------------------------
            if result.status == "UP":
                advancers += 1

            elif result.status == "DOWN":
                decliners += 1

            else:
                unchanged += 1

            stock_results.append(
                asdict(result)
            )

        # -------------------------------------------------
        # FINAL METRICS
        # -------------------------------------------------
        total_stocks = (
            advancers
            + decliners
            + unchanged
        )

        breadth_score = (
            advancers - decliners
        )

        breadth_ratio = (
            advancers / decliners
            if decliners != 0
            else float(advancers)
        )

        sentiment = self._get_sentiment(
            breadth_score
        )

        market_status = self._get_market_status(
            breadth_ratio
        )

        # -------------------------------------------------
        # FINAL RESULT
        # -------------------------------------------------
        result = MarketBreadthResult(
            timestamp=datetime.now(
                UTC
            ).isoformat(),

            index_name="NIFTY 50",

            total_stocks=total_stocks,

            advancers=advancers,

            decliners=decliners,

            unchanged=unchanged,

            breadth_score=breadth_score,

            breadth_ratio=round(
                breadth_ratio,
                2
            ),

            sentiment=sentiment,

            market_status=market_status,

            stocks=stock_results
        )

        return {
            "success": True,
            "message": "Market breadth calculated successfully",
            "data": asdict(result)
        }


# =========================================================
# MAIN
# =========================================================

# if __name__ == "__main__":

#     config = MarketBreadthConfig()

#     service = MarketBreadthService(config)

#     result = service.calculate()

#     print(
#         json.dumps(
#             result,
#             indent=2
#         )
#     )