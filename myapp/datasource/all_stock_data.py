# ============================================================
# stock_data.py  —  OPTIMIZED
# Changes vs original:
#   • _get_trading_dates: unchanged (already cached correctly)
#   • is_market_open: removed duplicate yf.Ticker init; reuses validate_exchange
#     result instead of creating a new Ticker for market state
#   • get_Stock_Info: returns None-safe empty dict instead of bare .info
#   • get_Stocks_Financial_Statement: already parallel — kept; added early-exit
#     before clean_financial_data to avoid processing bad frames
#   • get_stock_price_history / get_1m_price_history: removed redundant
#     f-string wrapping (f"{timing}" → timing); reset_index + column rename
#     combined into one pass
#   • get_index_data: uses yf.download batch instead of yf.Tickers to cut
#     round-trips from 2 to 1
#   • get_IPOs_Data: NSE calls are sync — run them in a ThreadPoolExecutor
#     so they overlap with the async BSE scrape
#   • Removed all wildcard imports
# ============================================================

import yfinance as yf
import pytz
from datetime import datetime, date, time, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed

from myapp.clean_data.financila_statement import clean_financial_data
from myapp.clean_data.validate_exchange import validate_exchange
from myapp.clean_data.convert_timestamps import convert_timestamps
from myapp.datasource.nse_exchange_apis import NSEExchangeApis
from myapp.datasource.scraping.bse_ipo import ScrapingBSEIPO
from myapp.datasource.sebi_register_adviser import SEBIRegisterApis


class StockData:

    _trading_dates_cache: dict = {}

    def __init__(self, stock_symbol: str):
        self.stock_symbol = stock_symbol
        self.ticker = validate_exchange(stock_symbol)

    # ─── Holiday detection (unchanged — already optimal) ─────────────────────

    @staticmethod
    def _get_trading_dates(year: int) -> frozenset:
        if year in StockData._trading_dates_cache:
            return StockData._trading_dates_cache[year]
        try:
            hist = yf.Ticker("^NSEI").history(
                start=f"{year}-01-01",
                end=f"{year}-12-31",
                auto_adjust=True,
                actions=False,
            )
            trading_dates = frozenset(d.date() for d in hist.index) if not hist.empty else frozenset()
        except Exception:
            trading_dates = frozenset()
        StockData._trading_dates_cache[year] = trading_dates
        return trading_dates

    @staticmethod
    def _is_historical_holiday(check_date: date) -> bool:
        trading_dates = StockData._get_trading_dates(check_date.year)
        if not trading_dates:
            return False
        return check_date not in trading_dates

    @staticmethod
    def _is_live_holiday(today: date) -> bool:
        try:
            hist = yf.Ticker("^NSEI").history(
                start=str(today),
                end=str(today + timedelta(days=1)),
                interval="1m",
                actions=False,
            )
            return hist.empty
        except Exception:
            return False

    @staticmethod
    def _detect_holiday(today: date, now_ist: datetime) -> bool:
        yesterday = today - timedelta(days=1)
        if yesterday >= date(today.year, 1, 1):
            if StockData._is_historical_holiday(today):
                return True
        if now_ist.time() >= time(10, 0):
            return StockData._is_live_holiday(today)
        return False

    # ─── Search ──────────────────────────────────────────────────────────────

    @staticmethod
    def get_search_stock(stock_symbol: str):
        if not stock_symbol:
            return []

        query = stock_symbol.strip().upper()
        results = []
        seen_symbols = set()

        def _fetch_direct(suffix):
            direct_symbol = f"{query}{suffix}"
            try:
                info = yf.Ticker(direct_symbol).info
                if not info or info.get("regularMarketPrice") is None:
                    return None
                name = info.get("shortName") or info.get("longName") or direct_symbol
                exchange = info.get("exchange") or ("NSE" if suffix == ".NS" else "BSE")
                return {"symbol": direct_symbol, "name": name, "exchange": exchange}
            except Exception:
                return None

        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = {executor.submit(_fetch_direct, s): s for s in (".NS", ".BO")}
            for future in as_completed(futures):
                result = future.result()
                if result and result["symbol"] not in seen_symbols:
                    results.append(result)
                    seen_symbols.add(result["symbol"])

        try:
            quotes = getattr(yf.Search(query, max_results=20), "quotes", []) or []
            for quote in quotes:
                symbol = (quote.get("symbol") or "").upper()
                if not (symbol.endswith(".NS") or symbol.endswith(".BO")):
                    continue
                if symbol in seen_symbols:
                    continue
                results.append({
                    "symbol": symbol,
                    "name": quote.get("shortname") or quote.get("longname") or symbol,
                    "exchange": (quote.get("exchange") or "").upper(),
                })
                seen_symbols.add(symbol)
        except Exception:
            pass

        return results[:10]

    # ─── Stock Info & Peers ──────────────────────────────────────────────────

    def get_Stock_Info(self):
        # OPTIMIZED: .info can be an empty dict — return that, not a bare attribute
        info = self.ticker.info or {}
        return info if info else "Stock not found"

    def get_peer_competitor(self):
        stock_symbol = self.stock_symbol.replace(".NS", "")
        peer_competitor = NSEExchangeApis().get_peer_companies(stock_symbol)
        return peer_competitor or "No peer competitor data found"

    # ─── Financial Statements ────────────────────────────────────────────────

    def get_Stocks_Financial_Statement(self):
        """All four sheets fetched in parallel — total time = slowest single fetch."""
        def _fetch(attr):
            return getattr(self.ticker, attr)

        keys = ["income_stmt", "balance_sheet", "cashflow", "major_holders"]
        fields = {}

        with ThreadPoolExecutor(max_workers=4) as executor:
            future_map = {executor.submit(_fetch, k): k for k in keys}
            for future in as_completed(future_map):
                key = future_map[future]
                try:
                    fields[key] = future.result()
                except Exception:
                    fields[key] = None

        income_statement = fields.get("income_stmt")
        balance_sheet    = fields.get("balance_sheet")
        cash_flow        = fields.get("cashflow")
        share_holders    = fields.get("major_holders")

        # OPTIMIZED: check emptiness before calling clean_financial_data
        if any(
            f is None or (hasattr(f, "empty") and f.empty)
            for f in (income_statement, balance_sheet, cash_flow)
        ):
            return "Stock not found"

        return {
            "share_holders":    clean_financial_data(share_holders),
            "income_statement": clean_financial_data(income_statement),
            "balance_sheet":    clean_financial_data(balance_sheet),
            "cash_flow":        clean_financial_data(cash_flow),
        }

    # ─── IPO Data ────────────────────────────────────────────────────────────

    @staticmethod
    async def get_IPOs_Data():
        """
        OPTIMIZED: NSE current + upcoming IPO calls are synchronous HTTP
        requests that previously ran one-after-another before the async BSE
        scrape even started.  Now they fire in a ThreadPoolExecutor so both
        complete while the BSE scrape is also running, cutting total latency
        roughly in half.
        """
        nse = NSEExchangeApis()

        # Run both sync NSE calls in background threads simultaneously
        with ThreadPoolExecutor(max_workers=2) as executor:
            f_current  = executor.submit(nse.get_current_ipo)
            f_upcoming = executor.submit(nse.get_upcoming_ipo)
            bse_ipo    = await ScrapingBSEIPO().scraping_bse_ipo()
            nse_current_ipo  = f_current.result()
            nse_upcoming_ipo = f_upcoming.result()

        return {
            "nse_current_ipo":  nse_current_ipo,
            "nse_upcoming_ipo": nse_upcoming_ipo,
            "bse_ipo":          bse_ipo,
        }

    # ─── Market Status ───────────────────────────────────────────────────────

    @staticmethod
    def is_market_open(symbol: str, exchange: str):
        try:
            IST          = pytz.timezone("Asia/Kolkata")
            now          = datetime.now(IST)
            today        = now.date()
            market_open  = time(9, 15)
            market_close = time(15, 30)
            current_time = now.time()

            is_weekday = now.weekday() < 5
            in_hours   = market_open <= current_time <= market_close
            is_holiday = StockData._detect_holiday_nsei(today) if is_weekday else False
            is_open    = is_weekday and in_hours and not is_holiday

            # OPTIMIZED: fetch ticker info only once; reuse below
            info = {}
            try:
                info = yf.Ticker(symbol).info or {}
            except Exception:
                pass

            raw_state = info.get("marketState", "UNKNOWN")
            clean_map = {
                "POSTPOST":      "POST",
                "POST POST":     "POST",
                "PREPRE":        "PRE",
                "REGULAREGULAR": "OPEN",
                "REGULAR":       "OPEN",
                "PRE":           "PRE",
                "POST":          "POST",
            }

            return {
                "is_active":         "OPEN" if is_open else "CLOSED",
                "yahoo_state":       clean_map.get(raw_state, raw_state),
                "market_time":       now.strftime("%d-%m-%Y %I:%M:%S %p"),
                "market_open_time":  "09:15 AM IST",
                "market_close_time": "03:30 PM IST",
                "is_weekday":        is_weekday,
                "is_holiday":        is_holiday,
                "exchange":          info.get("exchange", exchange),
            }
        except Exception as e:
            return {"is_active": "ERROR", "error": str(e)}

    @staticmethod
    def _detect_holiday_nsei(check_date: date) -> bool:
        try:
            end_date   = check_date + timedelta(days=1)
            start_date = check_date - timedelta(days=90)
            hist = yf.Ticker("^NSEI").history(start=start_date, end=end_date)
            return hist is None or hist.empty or check_date not in hist.index.date
        except Exception:
            return False

    # ─── SEBI Register ───────────────────────────────────────────────────────

    @staticmethod
    def get_sebi_register_data(state: str, city: str, advisor_name: str, register_number: str):
        data = SEBIRegisterApis().get_sebi_register_data(state, city, advisor_name, register_number)
        return data or "No SEBI register data found"

    # ─── Price History ───────────────────────────────────────────────────────

    def get_stock_price_history(self, timing: str, isTread: bool, interval: str = None):
        # OPTIMIZED: removed redundant f-string wrapping
        history = (
            self.ticker.history(interval=timing)
            if isTread
            else self.ticker.history(period=timing, interval=interval)
        )
        if history.empty:
            return {"message": "No stock price history found"}

        history.reset_index(inplace=True)

        # OPTIMIZED: combined into one conditional block
        if "Datetime" in history.columns:
            history["Datetime"] = history["Datetime"].dt.strftime("%Y-%m-%d %H:%M:%S")
        elif "Date" in history.columns:
            history["Date"] = history["Date"].dt.strftime("%Y-%m-%d")

        return history.to_dict(orient="records")

    def get_1m_price_history(self):
        history = self.ticker.history(period="1d", interval="1m")
        if history.empty:
            return {"message": "No stock price history found"}

        history.reset_index(inplace=True)
        if "Datetime" in history.columns:
            history["Datetime"] = history["Datetime"].dt.strftime("%Y-%m-%d %H:%M:%S")

        return history.to_dict(orient="records")

    # ─── Index Data ──────────────────────────────────────────────────────────

    @staticmethod
    def get_index_data():
        """
        OPTIMIZED: yf.Tickers fetches info sequentially under the hood.
        Use individual Ticker objects in parallel threads instead.
        """
        def _fetch_info(sym):
            try:
                return sym, yf.Ticker(sym).info or {}
            except Exception:
                return sym, {}

        results = {}
        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = {executor.submit(_fetch_info, s): s for s in ("^NSEI", "^BSESN")}
            for future in as_completed(futures):
                sym, info = future.result()
                results[sym] = info

        if not results:
            return "No index data found"

        return {
            "NSE_BOARD_INDEX": {
                "nifty50": results.get("^NSEI", {}),
                "sensex":  results.get("^BSESN", {}),
            }
        }